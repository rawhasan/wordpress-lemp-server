#!/usr/bin/env bash
# Manual, portable LEMP/WordPress disaster-recovery bundle.
# Ubuntu/Debian; /sites/<domain>/public layout. No WordPress core or caches.
set -Eeuo pipefail
umask 077
ROOT=/sites
[[ ${EUID} -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
for c in tar gzip mysqldump wp python3 sha256sum flock mktemp; do command -v "$c" >/dev/null || { echo "Missing: $c" >&2; exit 1; }; done
[[ -d $ROOT ]] || { echo "Missing $ROOT" >&2; exit 1; }
mapfile -t SITES < <(find "$ROOT" -mindepth 3 -maxdepth 3 -type f -path '*/public/wp-config.php' -printf '%h\n' | sed 's@/public$@@' | sort)
((${#SITES[@]})) || { echo 'No WordPress sites found.' >&2; exit 1; }
# Output outside the web root, in the first site's backups directory.
BACKUP_HOME=${SERVER_BACKUP_DIR:-${SITES[0]}/backups}
[[ $BACKUP_HOME == /sites/* && $BACKUP_HOME != */public && $BACKUP_HOME != */public/* ]] || { echo 'Unsafe output directory' >&2; exit 1; }
mkdir -p "$BACKUP_HOME"
SSH_USER=${BACKUP_SSH_USER:-${SUDO_USER:-}}
[[ -n $SSH_USER && $SSH_USER != root ]] || { echo 'Run via sudo from an SSH user, or set BACKUP_SSH_USER.' >&2; exit 1; }
READER_GROUP=${BACKUP_READ_GROUP:-$(id -gn "$SSH_USER")}
getent group "$READER_GROUP" >/dev/null || { echo 'Reader group not found.' >&2; exit 1; }
chown root:"$READER_GROUP" "$BACKUP_HOME"
chmod 750 "$BACKUP_HOME"
exec 9>"$BACKUP_HOME/.server-backup.lock"
flock -n 9 || { echo 'Another server backup is running.' >&2; exit 1; }
STAMP=$(date +%Y-%m-%d_%H%M%S)
NAME="$(hostname -s)-server-$STAMP"
FINAL="$BACKUP_HOME/$NAME.tar.gz"
PARTIAL="$BACKUP_HOME/.$NAME.partial.tar.gz"
TMP=$(mktemp -d "$BACKUP_HOME/.$NAME.work.XXXXXXXX")
DONE=0
cleanup() { rc=$?; rm -rf -- "$TMP"; if (( ! DONE )); then rm -f -- "$PARTIAL"; fi; if ((rc)); then echo "Backup failed (exit $rc)." >&2; fi; }
trap cleanup EXIT
mkdir -p "$TMP"/{system,sites,metadata}
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
# Capture relevant configuration, secrets included. Preserve original paths in tar.
CONFIG_PATHS=(/etc/nginx /etc/letsencrypt /etc/ssl /etc/php /etc/mysql /etc/mysql.conf.d /etc/my.cnf /etc/valkey /etc/redis /etc/ufw /etc/fail2ban /etc/ssh /etc/systemd/system /etc/cron.d /etc/cron.daily /etc/crontab /etc/logrotate.d /etc/apt /etc/default /etc/environment /etc/hosts /etc/hostname /etc/fstab /etc/sudoers /etc/sudoers.d /etc/passwd /etc/group /etc/subuid /etc/subgid /etc/netplan /etc/cloud /etc/sysctl.conf /etc/sysctl.d /etc/security/limits.conf /etc/security/limits.d /etc/profile.d /etc/rsyslog.d /etc/postfix /etc/opendkim /etc/dovecot /etc/supervisor /etc/supervisor.conf /etc/supervisor.d /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly /etc/cron.yearly /etc/ca-certificates)
EXISTING=()
for p in "${CONFIG_PATHS[@]}"; do [[ -e $p || -L $p ]] && EXISTING+=("${p#/}"); done
log 'Capturing Nginx, TLS, PHP, MySQL, SSH, firewall, systemd and other configuration...'
if ((${#EXISTING[@]})); then tar -czf "$TMP/system/etc-config.tar.gz" -C / "${EXISTING[@]}"; fi
# Preserve local custom binaries and site-adjacent scripts, excluding package-managed system files.
for p in /usr/local/bin /usr/local/sbin /usr/local/etc /opt; do
  if [[ -e $p ]]; then
    tar -czf "$TMP/system/$(echo "$p" | tr / _).tar.gz" -C / "${p#/}";
  fi
done
# Read-only inventory and troubleshooting data; do not archive live /var/lib/mysql.
dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' > "$TMP/metadata/packages.tsv"
apt-mark showmanual > "$TMP/metadata/manually-installed-packages.txt" 2>/dev/null || true
systemctl list-unit-files --no-pager --no-legend > "$TMP/metadata/systemd-unit-files.txt" 2>/dev/null || true
systemctl list-timers --all --no-pager > "$TMP/metadata/systemd-timers.txt" 2>/dev/null || true
systemctl list-units --type=service --state=running --no-pager > "$TMP/metadata/running-services.txt" 2>/dev/null || true
ss -lntup > "$TMP/metadata/listening-ports.txt" 2>/dev/null || true
ip -br addr > "$TMP/metadata/network-interfaces.txt" 2>/dev/null || true
ip route > "$TMP/metadata/routes.txt" 2>/dev/null || true
lsblk -f > "$TMP/metadata/block-devices.txt" 2>/dev/null || true
findmnt -r > "$TMP/metadata/mounts.txt" 2>/dev/null || true
uname -a > "$TMP/metadata/kernel.txt"
lsb_release -a > "$TMP/metadata/os-release.txt" 2>&1 || cat /etc/os-release > "$TMP/metadata/os-release.txt"
command -v nginx >/dev/null && nginx -T > "$TMP/metadata/nginx-effective-config.txt" 2>&1 || true
command -v php >/dev/null && php -m > "$TMP/metadata/php-modules.txt" 2>&1 || true
command -v ufw >/dev/null && ufw status numbered > "$TMP/metadata/ufw-status.txt" 2>&1 || true
command -v crontab >/dev/null && crontab -l > "$TMP/metadata/root-crontab.txt" 2>&1 || true
# Back up application content, DB, config, and non-public site scripts. No WP core.
for site in "${SITES[@]}"; do
  domain=${site##*/}
  [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { echo "Unsafe site directory: $domain" >&2; exit 1; }
  dest="$TMP/sites/$domain"
  mkdir -p "$dest"
  log "Backing up WordPress data: $domain"
  # tar will capture symlinks as links; ensure linked wp-content is not silently omitted.
  [[ ! -L "$site/public/wp-content" ]] || { echo "Symlinked wp-content unsupported: $site" >&2; exit 1; }
  tar -czf "$dest/wp-content.tar.gz" -C "$site/public" wp-content
  cp -p "$site/public/wp-config.php" "$dest/wp-config.php"
  # Capture custom top-level public files (not core); includes robots.txt and .htaccess.
  mkdir -p "$dest/public-extra"
  for file in "$site/public"/* "$site/public"/.[!.]*; do
    [[ -f $file && ! -L $file ]] || continue
    bn=${file##*/}
    case "$bn" in index.php|wp-*.php|xmlrpc.php|license.txt|readme.html|wp-config.php) continue;; esac
    cp -p -- "$file" "$dest/public-extra/$bn"
  done
  # Other site directories, including custom shell scripts and environment files.
  tar -czf "$dest/site-extras.tar.gz" -C "$site" \
    --exclude='./public' --exclude='./backups' --exclude='./cache' \
    --exclude='./logs' --exclude='./tmp' --exclude='./.git' .
  get_db() { wp config get "$1" --type=constant --path="$site/public" --allow-root --quiet; }
  dbname=$(get_db DB_NAME); dbuser=$(get_db DB_USER); dbpass=$(get_db DB_PASSWORD); dbhost=$(get_db DB_HOST)
  [[ -n $dbname && -n $dbuser && -n $dbhost ]] || { echo "Missing DB config: $domain" >&2; exit 1; }
  host=$dbhost; port=''; socket=''
  if [[ $dbhost == *:* ]]; then
    host=${dbhost%%:*}; suffix=${dbhost#*:}
    if [[ $suffix =~ ^[0-9]+$ ]]; then port=$suffix
    elif [[ $suffix == /* ]]; then socket=$suffix
    else echo "Unsupported DB_HOST: $domain" >&2; exit 1; fi
  fi
  mysql_escape() { python3 -c 'import sys; s=sys.stdin.read(); print(s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n"),end="")'; }
  cnf="$dest/.mysql-client.cnf"
  { printf '[client]\nuser="%s"\npassword="%s"\nhost="%s"\n' \
      "$(printf %s "$dbuser" | mysql_escape)" "$(printf %s "$dbpass" | mysql_escape)" "$(printf %s "$host" | mysql_escape)"
    [[ -z $port ]] || printf 'port=%s\nprotocol=tcp\n' "$port"
    [[ -z $socket ]] || printf 'socket="%s"\nprotocol=socket\n' "$socket"
  } > "$cnf"
  unset dbpass
  mysqldump --defaults-extra-file="$cnf" --single-transaction --quick --no-tablespaces \
    --default-character-set=utf8mb4 --set-gtid-purged=OFF "$dbname" > "$dest/database.sql"
  rm -f "$cnf"
  grep -q -- '-- Dump completed on' "$dest/database.sql" || { echo "Incomplete SQL export: $domain" >&2; exit 1; }
  printf 'Site: %s\nDatabase: %s\n' "$domain" "$dbname" > "$dest/site-info.txt"
done
cat > "$TMP/README-RESTORE.txt" <<'README'
LEMP SERVER DISASTER RECOVERY BUNDLE (SENSITIVE — KEEP PRIVATE)

Contains: /etc configuration (including private TLS keys), /usr/local and /opt,
package and service inventories, all detected /sites/<domain> WordPress wp-content,
wp-config.php, SQL databases, and custom site scripts/configuration.
WordPress core is intentionally excluded. Also excluded: full OS/disk image,
MySQL physical data directory, live caches/logs, package binaries, user home
folders, /root, /var/spool, /var/lib and other application data not listed.

RESTORE OUTLINE:
1. Create a fresh compatible Ubuntu droplet; install Nginx, PHP versions/extensions,
   MySQL, Valkey, Certbot, WordPress CLI and other packages per inventories.
2. Review and selectively restore /etc configs (do NOT blindly overwrite /etc
   passwd, SSH, network or systemd settings on a different Ubuntu version).
3. Restore TLS files carefully, preserving private-key permissions and symlinks.
4. Download clean WordPress core, restore wp-content and wp-config.php per site.
5. Create DBs/users, import each database.sql, and update credentials if needed.
6. Restore scripts and custom site settings; validate Nginx and PHP-FPM, DNS,
   SSL renewal, firewall, Wordfence, mail and scheduled tasks.
7. Test privately before directing public DNS to the replacement server.

NOTE: This is a rebuild kit, NOT a bootable droplet image or one-command restore.
Consistency: --single-transaction provides a consistent InnoDB DB snapshot,
but files and DB are not atomically snapshotted together on a live site.
README
log 'Creating final archive and testing integrity...'
tar -czf "$PARTIAL" -C "$TMP" .
gzip -t "$PARTIAL"
tar -tzf "$PARTIAL" >/dev/null
[[ ! -e $FINAL ]] || { echo "Backup already exists: $FINAL" >&2; exit 1; }
mv -- "$PARTIAL" "$FINAL"
(cd "$BACKUP_HOME" && sha256sum "${FINAL##*/}" > "${FINAL##*/}.sha256" && sha256sum -c "${FINAL##*/}.sha256")
chown root:"$READER_GROUP" "$FINAL" "$FINAL.sha256"
chmod 640 "$FINAL" "$FINAL.sha256"
DONE=1
log "Server backup complete: $FINAL"
ls -lh "$FINAL" "$FINAL.sha256"
SSH_HOST=${BACKUP_SSH_HOST:-}
if [[ -z $SSH_HOST && -n ${SSH_CONNECTION:-} ]]; then read -r _ _ SSH_HOST _ <<< "$SSH_CONNECTION"; fi
if [[ -z $SSH_HOST ]]; then SSH_HOST=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}'); fi
[[ -n $SSH_HOST ]] || SSH_HOST=$(hostname -I | awk '{print $1}')
[[ -n $SSH_HOST ]] || SSH_HOST='<SERVER_IP_OR_DNS>'
if [[ $SSH_HOST =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.) ]]; then
  echo 'WARNING: Detected a private IP; set BACKUP_SSH_HOST to your public address if necessary.'
fi
printf '\n===== DOWNLOAD ON WINDOWS (GIT BASH) =====\n'
printf 'scp %s@%s:%q .\n' "$SSH_USER" "$SSH_HOST" "$FINAL"
printf 'scp %s@%s:%q .\n' "$SSH_USER" "$SSH_HOST" "$FINAL.sha256"
printf 'sha256sum -c %q\n' "${FINAL##*/}.sha256"
echo 'Keep the archive AND checksum off the Droplet. Contains secrets and TLS private keys.'
