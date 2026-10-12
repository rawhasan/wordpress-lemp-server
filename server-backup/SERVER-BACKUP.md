# Manual LEMP Server Disaster-Recovery Backup

`server-backup.sh` creates a **portable rebuild kit** for a DigitalOcean/Ubuntu LEMP server. It discovers **all WordPress sites** at `/sites/<domain>/public/` and backs them up in a single archive, along with important server configuration and package inventories. **WordPress core is intentionally excluded** because it can be downloaded again.

> This is **not a bootable disk image**, Droplet snapshot, or automated one-command restore. A new server must be provisioned and its services reinstalled before selectively restoring the archive. For exact whole-machine recovery, keep a DigitalOcean snapshot as an additional recovery option.

## What is included

| Category | Contents |
|---|---|
| WordPress sites | `wp-content`, `wp-config.php`, SQL dump, custom top-level public files, site-specific scripts/configuration outside `public` |
| Nginx | `/etc/nginx`, effective configuration output |
| SSL/TLS | `/etc/letsencrypt`, `/etc/ssl` including **private keys** |
| PHP | `/etc/php`, installed PHP modules inventory |
| Database | Per-site transactional SQL exports, `/etc/mysql`, `/etc/my.cnf` when present |
| Caching | `/etc/valkey`, `/etc/redis` when present; not volatile cache data |
| Security | UFW, Fail2ban, SSH, sudoers, relevant system configuration |
| System services | Custom systemd units, cron, logrotate, sysctl, relevant service configuration |
| Software inventory | Installed Debian packages, manually installed packages, active services and timers |
| Networking and storage | Interface/route/mount/block-device inventories, netplan/cloud-init settings |
| Custom programs | `/usr/local/bin`, `/usr/local/sbin`, `/usr/local/etc`, `/opt` when present |

## Not included

WordPress core; full OS/kernel/disk image; `/var/lib/mysql` physical database files; caches; logs; user home directories; `/root`; Docker volumes; arbitrary application data under `/var/lib`, `/srv`, `/mnt`, or `/var/spool`; external DNS/CDN account settings; and cloud provider settings. If your server stores important data outside the included paths, **extend the script before relying on it for disaster recovery**.

Database exports use `mysqldump --single-transaction` (best for InnoDB). WordPress files and databases are not captured as a single atomic snapshot, so avoid changing site content during a backup.

## Installation

Place the script outside the public web root, for example:

```bash
sudo mkdir -p /sites/nijhoom.com/shells
sudo cp server-backup.sh /sites/nijhoom.com/shells/server-backup.sh
sudo chown root:root /sites/nijhoom.com/shells/server-backup.sh
sudo chmod 700 /sites/nijhoom.com/shells/server-backup.sh
sudo ln -sfn /sites/nijhoom.com/shells/server-backup.sh /usr/local/bin/server-backup
sudo bash -n /usr/local/bin/server-backup
```

Dependencies: Bash, tar, gzip, WP-CLI (`wp`), `mysqldump`, Python 3, `sha256sum`, `flock`, and standard Ubuntu utilities. Run from a regular SSH account with `sudo` privileges; the script uses the invoking account's primary group to permit private downloads.

## Create a manual server backup

```bash
sudo server-backup
```

The script automatically discovers **every** site under `/sites/<domain>/public/` that contains `wp-config.php`. No site-selection menu is used for this **whole-server** backup. The archive is written to the first discovered site's `backups` directory (sorted alphabetically), or a custom location set with `SERVER_BACKUP_DIR`.

To specify the destination directory:

```bash
sudo SERVER_BACKUP_DIR=/sites/nijhoom.com/backups server-backup
```

The directory is `root:<SSH user primary group>` with mode `750`. Completed archives and checksum files are `root:<group>` with mode `640`. Temporary files are root-only. Ensure parent directories allow the SSH account to traverse them.

**Important:** This backup includes database passwords, `wp-config.php`, SSH configuration, and **TLS private keys**. Never put it in a public website directory or publicly accessible storage. Encrypt the downloaded archive for long-term storage and restrict access.

## Download to Windows using Git Bash

After a successful run, the script prints `scp` commands using the username from `sudo` and a detected server address. Copy those commands into **Git Bash on your Windows computer**, not the SSH session.

Example (illustrative placeholders, not hardcoded into the script):

```bash
scp sshuser@SERVER_IP:/sites/example.com/backups/server-server-YYYY-MM-DD_HHMMSS.tar.gz .
scp sshuser@SERVER_IP:/sites/example.com/backups/server-server-YYYY-MM-DD_HHMMSS.tar.gz.sha256 .
sha256sum -c server-server-YYYY-MM-DD_HHMMSS.tar.gz.sha256
```

`OK` confirms that the downloaded archive matches the checksum. If the automatically detected IP is private or not reachable from Windows, set `BACKUP_SSH_HOST` when running the script:

```bash
sudo BACKUP_SSH_HOST=your-public-ip-or-dns server-backup
```

If your SSH server uses a nonstandard port, add `-P PORT` to each `scp` command.

## Verify and inspect the archive

On Windows Git Bash (or Linux):

```bash
sha256sum -c ARCHIVE.tar.gz.sha256
tar -tzf ARCHIVE.tar.gz | head -60
```

The archive contains `system/`, `sites/`, `metadata/`, and `README-RESTORE.txt`. Inspect the archive in a secure directory. **Do not extract sensitive files into a publicly accessible web directory.** The script validates the outer gzip/tar archive and the SQL completion markers; periodically perform a test restore on a separate VM.

## Restore after a lost Droplet (overview)

1. Create a replacement Ubuntu Droplet with an appropriate OS version, disk size, SSH access, and firewall rules.
2. Transfer the backup and checksum, verify `sha256sum -c`, and extract in a root-only staging directory.
3. Review `metadata/packages.tsv` and `metadata/manually-installed-packages.txt`; reinstall Nginx, PHP versions/extensions, MySQL, Valkey, Certbot, WP-CLI, and other needed software.
4. **Selectively** restore Nginx, PHP, MySQL, Valkey, firewall, Fail2ban, and service configuration. Do not blindly overwrite SSH, network, sudoers, `/etc/passwd`, or systemd files across different OS versions.
5. Restore TLS certificates and keys with correct ownership, permissions, and symlink targets; verify Certbot renewal.
6. Create each site's `/sites/<domain>/public`, download fresh WordPress core, restore `wp-content` and `wp-config.php`, create MySQL databases/users, and import the site's SQL dump.
7. Restore custom site scripts and Nginx server blocks. Check ownership (`www-data` as appropriate), PHP-FPM sockets, Wordfence WAF bootstrap, Redis/Valkey, cron, SMTP, DNS/CDN origin, and cache exclusions.
8. Test using `curl --resolve` or a hosts-file override **before** updating DNS. Confirm homepage, forms, email, SSL, Yoast sitemaps, and Wordfence.

The backup itself does **not** perform restoration or reinstall packages. Practice recovery on a temporary Droplet before relying on it as your sole disaster-recovery strategy.

## Operational notes

- **Manual only:** no cron, systemd timer, or automatic deletion.
- **All sites:** one server archive, not separate selectable site archives.
- **No database import:** backups only export data.
- **Backup storage:** the archive is initially on the same Droplet; download it off-server after each run.
- **Sensitive secrets:** protect or encrypt archives and avoid sharing them in tickets or chat.
- **Disk space:** allow space for uncompressed SQL dumps, intermediate archives, and the final archive; the script temporarily needs substantially more than the final archive size.
- **Cloud-specific settings:** re-create DigitalOcean DNS, reserved IPs, firewall settings, monitoring, and any Cloudflare/BunnyCDN settings separately.
