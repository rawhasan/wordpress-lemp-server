# WordPress Manual Backup Script — Usage Guide

This guide covers `wp-backup.sh`, the manual multi-site backup script for WordPress installations under `/sites/<site-name>/public/` on a Linux/LEMP server.

## 1. What the script does

- Finds WordPress installations under `/sites/` when each has both `public/wp-config.php` and `public/wp-content/`.
- Presents a numbered site-selection menu, or accepts a site name or path on the command line.
- Creates a dated compressed archive containing **`wp-content`**, a **MySQL SQL dump**, **`wp-config.php`**, and a short `README.txt`.
- Tests the compressed archives, checks the SQL dump's completion marker, compares archived contents against the source files, and writes a SHA-256 checksum.
- Prints Git Bash `scp` download commands using a detected SSH username and server address.
- Does **not** schedule backups, remove older backups, change the WordPress database, or automatically transfer files to another computer.

**Scope:** This is a WordPress content-and-database backup, **not a full server backup**. It excludes WordPress core, Nginx configuration, SSL certificates, PHP configuration, installed packages, and other server files. It also does not perform a test restore.

## 2. Expected directory structure

```text
/sites/
├── nijhoom.com/
│   ├── public/
│   │   ├── wp-config.php
│   │   └── wp-content/
│   ├── shells/
│   │   └── wp-backup.sh
│   └── backups/
└── another-site.com/
    └── public/
        ├── wp-config.php
        └── wp-content/
```

The script can be stored in `/sites/nijhoom.com/shells/` and still back up **any** detected site under `/sites/`.

## 3. Prerequisites

- SSH access to the server with a normal account that can run `sudo`.
- WordPress CLI (`wp`), `mysqldump`, `tar`, `gzip`, `sha256sum`, `mktemp`, `flock`, `python3`, `readlink`, `realpath`, and `cmp` available.
- Sufficient free disk space for the temporary `wp-content` archive, SQL dump, and final archive. The script builds intermediate files before cleanup, so peak usage can exceed the size of the completed backup.
- The site database credentials available as standard `DB_NAME`, `DB_USER`, `DB_PASSWORD`, and `DB_HOST` constants in `wp-config.php`.
- A MySQL-compatible server supported by the script's `mysqldump` options.

Check disk space before a large backup:

```bash
df -h /sites
```


## 4. Install the Script

Create the scripts directory and enter it:

```bash
sudo mkdir -p /sites/nijhoom.com/shells
cd /sites/nijhoom.com/shells
```

Create the script:

```bash
sudo nano wp-backup.sh
```

Paste the complete script from GitHub. Press `Ctrl+O`, `Enter`, then `Ctrl+X` to save and exit.

Set permissions and check for syntax errors:

```bash
sudo chmod 700 wp-backup.sh
sudo bash -n wp-backup.sh
```

Create a global command:

```bash
sudo ln -sfn "$(pwd)/wp-backup.sh" /usr/local/bin/wp-backup
```

Run the script from anywhere:

```bash
sudo wp-backup
```

The script displays a menu of detected WordPress sites.

To back up a specific site without the menu:

```bash
sudo wp-backup nijhoom.com
```

**Note:** Replace `nijhoom.com` in the installation path with any site directory under `/sites/`. The global command works for all detected WordPress sites.

## 5. Run a manual backup

### Interactive menu (recommended)

From **any directory** on the server:

```bash
sudo wp-backup
```

Example menu (only sites actually found on your server appear):

```text
===== AVAILABLE WORDPRESS SITES =====
  1) nijhoom.com
  2) dev.nijhoom.com

Select site number (or q to quit):
```

Enter a site number and press Enter. Enter `q` to exit.

### Select a site without the menu

```bash
sudo wp-backup nijhoom.com
```

Or use its public directory:

```bash
sudo wp-backup /sites/nijhoom.com/public
```

This is useful for scripting or a terminal session without interactive input. **No cron job is configured by this guide.**

## 6. Output and file locations

For `nijhoom.com`, completed files are written to:

```text
/sites/nijhoom.com/backups/
```

Example filenames:

```text
nijhoom.com-wp-2026-10-12_123000.tar.gz
nijhoom.com-wp-2026-10-12_123000.tar.gz.sha256
```

The archive includes:

```text
nijhoom.com-wp-content-2026-10-12_123000.tar.gz
nijhoom.com-db-2026-10-12_123000.sql
nijhoom.com-wp-config-2026-10-12_123000.php
README.txt
```

A successful run prints **“Backup completed and verified.”** It also displays the archive path, checksum path, file sizes, and download instructions.

The script uses a lock to prevent concurrent backups of the same site and cleans up temporary files when it exits. It **does not automatically delete previous completed backups**.

## 7. Backup file permissions

The script is designed to run using `sudo` from a normal SSH account. By default, it uses that account's primary group for completed backup files.

| Item | Ownership | Permissions |
| --- | --- | --- |
| Backup directory | `root:<sudo-user-primary-group>` | `750` |
| Completed archive | `root:<sudo-user-primary-group>` | `640` |
| Checksum file | `root:<sudo-user-primary-group>` | `640` |
| Temporary files | Root-restricted | Private |

For example, when invoked with `sudo` by `rhcomadmin`, the script normally grants that account group read access to completed files. Check the actual group with:

```bash
id -gn
```

Inspect the results:

```bash
ls -ld /sites/nijhoom.com/backups
ls -lh /sites/nijhoom.com/backups
```

If you need a different backup-reader group, you can override it when invoking the script (the group must already exist):

```bash
sudo BACKUP_READ_GROUP=backupreaders wp-backup nijhoom.com
```

**Security:** The archive contains `wp-config.php` and a full database dump. Treat it as highly sensitive. Do not move it into `/sites/<site>/public/` or give it world-readable permissions.

## 8. Download to Windows using Git Bash

After success, the script prints commands resembling these, with the actual username, address, and filenames:

```bash
scp rhcomadmin@SERVER_IP:/sites/nijhoom.com/backups/nijhoom.com-wp-2026-10-12_123000.tar.gz .
scp rhcomadmin@SERVER_IP:/sites/nijhoom.com/backups/nijhoom.com-wp-2026-10-12_123000.tar.gz.sha256 .
sha256sum -c nijhoom.com-wp-2026-10-12_123000.tar.gz.sha256
```

**Run these commands in Git Bash on your Windows PC, not inside the server's SSH session.** The final dot (`.`) means “download to the current local directory.”

For example, download to your Windows Downloads folder:

```bash
cd ~/Downloads
```

Then paste the two `scp` commands printed by the backup script. Enter your SSH password when prompted.

Verify the downloaded archive:

```bash
sha256sum -c nijhoom.com-wp-2026-10-12_123000.tar.gz.sha256
```

Expected:

```text
nijhoom.com-wp-2026-10-12_123000.tar.gz: OK
```

If the checksum fails, do not use the downloaded file for restoration; download it again.

### About automatic IP and username detection

- The SSH username is normally taken from the account that ran `sudo`.
- The script attempts to detect the SSH-connected server address, then falls back to a network-interface address.
- A server may have multiple addresses, or the detected address may be private. **Review the generated `scp` commands before using them.**
- To override either value for the printed instructions, run:

```bash
sudo BACKUP_SSH_HOST=your.public.ip.or.hostname BACKUP_SSH_USER=your-ssh-user wp-backup nijhoom.com
```

These overrides only affect the printed download instructions; they do not change the backup contents.

## 9. Verify an archive on the server

Substitute your actual filename:

```bash
cd /sites/nijhoom.com/backups
sha256sum -c nijhoom.com-wp-2026-10-12_123000.tar.gz.sha256
tar -tzf nijhoom.com-wp-2026-10-12_123000.tar.gz
```

The first command checks the checksum; the second lists the archive contents without extracting them.

To test the compressed archive format:

```bash
gzip -t nijhoom.com-wp-2026-10-12_123000.tar.gz
```

**Note:** Archive integrity is not the same as a successful disaster-recovery restore. Periodically test restoring to an isolated staging environment.

## 10. Common problems

**`Permission denied` when entering `backups/`**

Check directory ownership and your group:

```bash
ls -ld /sites/nijhoom.com/backups
id -gn
```

The directory should have `750` permissions and a group your account belongs to. A fresh successful backup should set these permissions automatically. Avoid `chmod 777`.

**`wp-backup: command not found`**

Check the symbolic link and target:

```bash
ls -l /usr/local/bin/wp-backup
readlink -f /usr/local/bin/wp-backup
```

**No sites found**

Verify that the WordPress installations use the expected layout:

```bash
ls -l /sites/*/public/wp-config.php
ls -ld /sites/*/public/wp-content
```

**The download command shows a private or incorrect IP**

Use the public IP address or DNS hostname that you normally use for SSH, or set `BACKUP_SSH_HOST` as shown above.

**The backup fails or disk space runs low**

Check the reported error and free disk space. Do not assume an incomplete archive is usable. The script does not automatically delete older completed backups, so review disk usage periodically:

```bash
du -sh /sites/*/backups 2>/dev/null
```

**Backup contains a database dump but no full server configuration**

This is expected. Preserve Nginx configuration, TLS certificates, server provisioning instructions, and any non-WordPress files separately if you need full server recovery.

## 11. Recommended manual-backup routine

1. Run `sudo wp-backup` and select the site.
2. Confirm **“Backup completed and verified.”**
3. On Windows, open Git Bash and download both the archive and `.sha256` file using the printed `scp` commands.
4. Run `sha256sum -c ...` on Windows and confirm `OK`.
5. Keep the verified copy outside the server, ideally in more than one secure location.
6. Periodically perform a restoration test in a separate environment.

---

**Script location used in this guide:** `/sites/nijhoom.com/shells/wp-backup.sh`  
**Global command:** `sudo wp-backup`  
**Backup destination:** `/sites/<selected-site>/backups/`  
**Mode:** Manual; no automatic scheduling or retention.
