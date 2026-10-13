#!/usr/bin/env bash
# Manual WordPress content + database backup for any site under /sites/<site>/.
# Run: sudo /sites/example.com/shell/wp-backup.sh
#      sudo wp-backup                    (symlink to a site's shell script)
#      sudo wp-backup example.com        (explicit override)
#      sudo wp-backup /sites/example.com/public
set -Eeuo pipefail
umask 077

SITES_ROOT="/sites"

# Resolve the actual script location even when invoked through /usr/local/bin.
SCRIPT_REAL="$(readlink -f -- "${BASH_SOURCE[0]}")"

site_from_path() {
  local path="$1" rest name
  [[ "$path" == "$SITES_ROOT/"* ]] || return 1
  rest="${path#"$SITES_ROOT"/}"
  name="${rest%%/*}"
  [[ -n "$name" && "$rest" == */* ]] || return 1
  printf '%s\n' "$name"
}

# Discover WordPress installations from the standard server layout.
# Only directories with both wp-config.php and wp-content qualify.
declare -a AVAILABLE_SITES=()
for candidate in "$SITES_ROOT"/*; do
  [[ -d "$candidate/public" && -f "$candidate/public/wp-config.php" && -d "$candidate/public/wp-content" ]] || continue
  AVAILABLE_SITES+=("${candidate##*/}")
done
(( ${#AVAILABLE_SITES[@]} > 0 )) || {
  echo "ERROR: No WordPress installations found under $SITES_ROOT/<site>/public." >&2
  exit 1
}

if (( $# > 1 )); then
  echo 'Usage: sudo wp-backup [site-name | /sites/site-name/public]' >&2
  exit 1
fi

if (( $# == 1 )); then
  if [[ "$1" == /* ]]; then
    SITE_NAME="$(site_from_path "$(realpath -m -- "$1")")" || {
      echo 'ERROR: Site path must be inside /sites/<site>/.' >&2; exit 1;
    }
  else
    SITE_NAME="$1"
  fi
else
  echo '===== AVAILABLE WORDPRESS SITES ====='
  for i in "${!AVAILABLE_SITES[@]}"; do
    printf '  %d) %s\n' "$((i+1))" "${AVAILABLE_SITES[i]}"
  done
  if [[ ! -t 0 ]]; then
    echo 'ERROR: Interactive terminal required for site selection; pass a site name instead.' >&2
    exit 1
  fi
  while :; do
    read -r -p 'Select site number (or q to quit): ' choice
    [[ "$choice" == q || "$choice" == Q ]] && exit 0
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice <= ${#AVAILABLE_SITES[@]} )); then
      SITE_NAME="${AVAILABLE_SITES[10#$choice-1]}"
      break
    fi
    echo 'Invalid selection. Enter a listed number or q.'
  done
fi

if [[ ! "$SITE_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ || "$SITE_NAME" == *..* ]]; then
  echo 'ERROR: Invalid site name.' >&2; exit 1
fi

SITE_FOUND=0
for site in "${AVAILABLE_SITES[@]}"; do
  if [[ "$site" == "$SITE_NAME" ]]; then SITE_FOUND=1; break; fi
done
(( SITE_FOUND )) || { echo "ERROR: WordPress site not found: $SITE_NAME" >&2; exit 1; }
echo "Selected site: $SITE_NAME"

WP_PATH="$SITES_ROOT/${SITE_NAME}/public"
BACKUP_DIR="$SITES_ROOT/${SITE_NAME}/backups"
WPCONFIG_PATH="${WP_PATH}/wp-config.php"

# The invoking sudo user's primary group can read completed backups.
# Override with BACKUP_READ_GROUP=group if required.
BACKUP_READ_GROUP="${BACKUP_READ_GROUP:-${SUDO_USER:-}}"
if [[ -z "$BACKUP_READ_GROUP" || "$BACKUP_READ_GROUP" == root ]]; then
  echo 'ERROR: Run via sudo from a normal account, or set BACKUP_READ_GROUP.' >&2
  exit 1
fi
BACKUP_READ_GROUP="$(id -gn "$BACKUP_READ_GROUP" 2>/dev/null)" || {
  echo 'ERROR: Cannot determine backup reader group.' >&2; exit 1;
}

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || { echo "ERROR: Run this script with sudo." >&2; exit 1; }
getent group "$BACKUP_READ_GROUP" >/dev/null || { echo "ERROR: Group $BACKUP_READ_GROUP does not exist." >&2; exit 1; }

for cmd in wp mysqldump tar gzip sha256sum mktemp flock python3 readlink realpath cmp; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing command: $cmd"
done
[[ -f "$WPCONFIG_PATH" ]] || fail "Missing $WPCONFIG_PATH"
[[ -d "$WP_PATH/wp-content" ]] || fail "Missing $WP_PATH/wp-content"

# Only one backup per site at a time; avoid racing with another run.
mkdir -p "$BACKUP_DIR"
chown root:"$BACKUP_READ_GROUP" "$BACKUP_DIR"
chmod 750 "$BACKUP_DIR"
exec 9>"$BACKUP_DIR/.wp-backup.lock"
flock -n 9 || fail 'Another backup is already running.'

STAMP="$(date '+%Y-%m-%d_%H%M%S')"
BASE="${SITE_NAME}-wp-${STAMP}"
FINAL="$BACKUP_DIR/${BASE}.tar.gz"
CHECKSUM="${FINAL}.sha256"
TMP="$(mktemp -d "$BACKUP_DIR/.${BASE}.tmp.XXXXXXXX")"
PARTIAL="$BACKUP_DIR/.${BASE}.partial.tar.gz"
SUCCESS=0
cleanup() {
  status=$?
  rm -rf -- "$TMP"
  if (( SUCCESS == 0 )); then rm -f -- "$PARTIAL"; fi
  if (( status != 0 )); then log "Backup FAILED (exit $status); no completed archive was published." >&2; fi
}
trap cleanup EXIT

# Read literal DB_* constants using WP-CLI's config parser, not shell grep or PHP execution.
get_db() { wp config get "$1" --type=constant --path="$WP_PATH" --allow-root --quiet; }
DB_NAME="$(get_db DB_NAME)" || fail 'Cannot read DB_NAME'
DB_USER="$(get_db DB_USER)" || fail 'Cannot read DB_USER'
DB_PASS="$(get_db DB_PASSWORD)" || fail 'Cannot read DB_PASSWORD'
DB_HOST="$(get_db DB_HOST)" || fail 'Cannot read DB_HOST'
[[ -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_HOST" ]] || fail 'Database configuration incomplete.'

# MySQL client option file keeps credentials out of process arguments and shell history.
# Handle common WordPress DB_HOST values: localhost, hostname/IP, hostname:port,
# and localhost:/path/to/socket. Reject other nonstandard formats explicitly.
MYSQL_HOST="$DB_HOST"; MYSQL_PORT=''; MYSQL_SOCKET=''
if [[ "$DB_HOST" == *:* ]]; then
  MYSQL_HOST="${DB_HOST%%:*}"
  suffix="${DB_HOST#*:}"
  if [[ "$suffix" =~ ^[0-9]+$ ]]; then MYSQL_PORT="$suffix"
  elif [[ "$suffix" == /* ]]; then MYSQL_SOCKET="$suffix"
  else fail "Unsupported DB_HOST format: $DB_HOST"; fi
fi
[[ "$MYSQL_HOST" != *$'\n'* && "$DB_USER" != *$'\n'* && "$DB_PASS" != *$'\n'* ]] || fail 'Unsupported newline in database credentials.'

# Escape MySQL option-file special characters in password and other fields.
mysql_escape() {
  python3 -c 'import sys; s=sys.stdin.read(); print(s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n"), end="")'
}
MYCNF="$TMP/mysql.cnf"
{
  printf '[client]\nuser="%s"\npassword="%s"\nhost="%s"\n' \
    "$(printf '%s' "$DB_USER" | mysql_escape)" \
    "$(printf '%s' "$DB_PASS" | mysql_escape)" \
    "$(printf '%s' "$MYSQL_HOST" | mysql_escape)"
  if [[ -n "$MYSQL_PORT" ]]; then printf 'port=%s\nprotocol=tcp\n' "$MYSQL_PORT"; fi
  if [[ -n "$MYSQL_SOCKET" ]]; then printf 'socket="%s"\nprotocol=socket\n' "$MYSQL_SOCKET"; fi
} > "$MYCNF"
chmod 600 "$MYCNF"
unset DB_PASS

CONTENT="${SITE_NAME}-wp-content-${STAMP}.tar.gz"
SQL="${SITE_NAME}-db-${STAMP}.sql"
CONFIG="${SITE_NAME}-wp-config-${STAMP}.php"

log 'Backing up wp-content...'
tar -czf "$TMP/$CONTENT" -C "$WP_PATH" wp-content
[[ -s "$TMP/$CONTENT" ]] || fail 'wp-content archive is empty.'
gzip -t "$TMP/$CONTENT" || fail 'wp-content gzip validation failed.'
tar -tzf "$TMP/$CONTENT" >/dev/null || fail 'wp-content tar validation failed.'

log 'Exporting MySQL database...'
mysqldump --defaults-extra-file="$MYCNF" \
  --no-tablespaces --single-transaction --quick \
  --default-character-set=utf8mb4 --set-gtid-purged=OFF \
  "$DB_NAME" > "$TMP/$SQL"
[[ -s "$TMP/$SQL" ]] || fail 'SQL dump is empty.'
grep -q -- '-- MySQL dump' "$TMP/$SQL" || fail 'SQL dump header missing.'
grep -q -- '-- Dump completed on' "$TMP/$SQL" || fail 'SQL dump completion marker missing.'

log 'Copying wp-config.php...'
cp -- "$WPCONFIG_PATH" "$TMP/$CONFIG"
chmod 600 "$TMP/$CONFIG"

cat > "$TMP/README.txt" <<README
Site: $SITE_NAME
Created: $(date -Is)
WordPress root: $WP_PATH
Contents: wp-content archive, MySQL SQL dump, wp-config.php
Not included: WordPress core, Nginx configuration, TLS certificates, system packages.
Restore only after inspecting and validating this backup.
README

log 'Building and verifying final archive...'
tar -czf "$PARTIAL" -C "$TMP" "$CONTENT" "$SQL" "$CONFIG" README.txt
[[ -s "$PARTIAL" ]] || fail 'Final archive is empty.'
gzip -t "$PARTIAL" || fail 'Final gzip validation failed.'
tar -tzf "$PARTIAL" >/dev/null || fail 'Final tar validation failed.'
# Compare all embedded files byte-for-byte with the originals before publishing.
for file in "$CONTENT" "$SQL" "$CONFIG" README.txt; do
  tar -xOzf "$PARTIAL" "$file" | cmp -s - "$TMP/$file" || fail "Verification failed: $file"
done

# Atomic publish within the same filesystem.
[[ ! -e "$FINAL" ]] || fail "Backup filename already exists: $FINAL"
mv -n -- "$PARTIAL" "$FINAL"
[[ -f "$FINAL" ]] || fail 'Could not publish final archive.'
(
  cd "$BACKUP_DIR"
  sha256sum "$(basename "$FINAL")" > "$(basename "$CHECKSUM")"
  sha256sum -c "$(basename "$CHECKSUM")"
)
# Publish completed backups as root-owned, group-readable files for SSH/SFTP download.
# Never expose the temporary SQL dump, credentials, or partial archives.
chown root:"$BACKUP_READ_GROUP" "$FINAL" "$CHECKSUM"
chmod 640 "$FINAL" "$CHECKSUM"
SUCCESS=1
log 'Backup completed and verified.' 
log "Archive: $FINAL"
log "SHA-256: $CHECKSUM"
ls -lh -- "$FINAL" "$CHECKSUM"

# Instructions must be executed on the Windows machine, not inside SSH.
# Prefer the local address used for this SSH connection when available.
# With sudo, SSH_CONNECTION may not be preserved; fall back to the primary IPv4.
SSH_HOST="${BACKUP_SSH_HOST:-}"
if [[ -z "$SSH_HOST" && -n "${SSH_CONNECTION:-}" ]]; then
  read -r _ _ SSH_HOST _ <<< "$SSH_CONNECTION"
fi
if [[ -z "$SSH_HOST" ]] && command -v ip >/dev/null 2>&1; then
  SSH_HOST="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')"
fi
if [[ -z "$SSH_HOST" ]]; then
  SSH_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
if [[ -z "$SSH_HOST" ]]; then SSH_HOST='<SERVER_IP_OR_HOSTNAME>'; fi
SSH_USER="${BACKUP_SSH_USER:-${SUDO_USER:-}}"
if [[ -z "$SSH_USER" || "$SSH_USER" == root ]]; then
  SSH_USER='<SSH_USERNAME>'
fi
ARCHIVE_NAME="$(basename "$FINAL")"
CHECKSUM_NAME="$(basename "$CHECKSUM")"

printf '\n%s\n' '===== DOWNLOAD TO WINDOWS (GIT BASH) ====='
printf 'Detected SSH user: %s\n' "$SSH_USER"
printf 'Detected server address: %s\n' "$SSH_HOST"

if [[ "$SSH_HOST" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.) ]]; then
  printf '%s\n' 'NOTE: Detected a private IP. Set BACKUP_SSH_HOST to your public IP or DNS name for internet access.'
fi

printf '\n%s\n' 'Open Git Bash on your Windows PC (not this SSH terminal).'
printf '%s\n' 'Navigate to your desired local download directory.'

printf '\n%s\n' '===== OPTION 1: SCP DOWNLOAD ====='
printf '\n  scp %s@%s:%q .\n' "$SSH_USER" "$SSH_HOST" "$FINAL"
printf '  scp %s@%s:%q .\n' "$SSH_USER" "$SSH_HOST" "$CHECKSUM"

printf '\n%s\n' '===== OPTION 2: SFTP DOWNLOAD (RESUMABLE) ====='
printf '%s\n' 'Connect using:'
printf '\n  sftp %s@%s\n' "$SSH_USER" "$SSH_HOST"

printf '\n%s\n' 'At the sftp> prompt, enter:'
printf '  get -a %s\n' "$FINAL"
printf '  get %s\n' "$CHECKSUM"
printf '  bye\n'

printf '\n%s\n' 'If interrupted, reconnect and repeat get -a to resume the archive download.'

printf '\n%s\n' '===== VERIFY DOWNLOADED BACKUP ====='
printf '%s\n' 'After downloading both files, run in Git Bash:'
printf '\n  sha256sum -c %q\n' "$CHECKSUM_NAME"
printf '  tar -tzf %q > /dev/null && echo "BACKUP ARCHIVE OK"\n' "$ARCHIVE_NAME"

printf '\n%s\n' 'Expected: checksum OK and BACKUP ARCHIVE OK.'
printf '%s\n' 'Keep a verified copy outside the server.'
printf '  sha256sum -c %q\n' "$CHECKSUM_NAME"
printf '\n%s\n' 'Expected: OK. Keep a copy outside the server.'
