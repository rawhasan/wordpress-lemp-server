# WordPress Site Backup & Restore Script Guide

This guide explains how to use the `wp-backup.sh` and `restore-wp-backup.sh` scripts to create a backup of the WordPress site's `wp-content` directory and MySQL database in the old server, and restore the back-up in a new server for site migration.

## 🔧 Prerequisites

- A Unix-based server (Ubuntu, Debian, etc.)
- Bash shell installed
- `tar` and `mysqldump` installed
- The script placed in an executable path (e.g., `/usr/local/bin/wp-backup.sh`)
- Correct configuration inside the script

---

## 📁 Script Location and Setup

1. **Place the script** in the following directory:
   ```bash
   /sites/example.com/shells/wp-backup.sh
   ```

2. **Open the script** in an editor and configure the following variables:

   ```bash
   SITE_NAME="example.com"
   WP_PATH="/sites/example.com/public"
   BACKUP_DIR="/sites/example.com/backups"
   DB_HOST="localhost"
   ```

   Replace these with the actual values for your site.

---

## 🚀 How to Run

To run the script:

```bash
bash wp-backup.sh
```

You will be prompted to enter:

- MySQL database name
- MySQL username
- MySQL password (hidden input)

---

## 📦 What It Does

1. Creates a temporary backup directory under `/tmp/`
2. Archives the `wp-content` folder into `wp-content.tar.gz`
3. Dumps the MySQL database into `db.sql`
4. Combines both into a single compressed file:
   ```
   /sites/example.com/backups/example.com-wp-YYYY-MM-DD.tar.gz
   ```
5. Deletes the temporary directory

---

## ✅ Backup Output

After completion, you’ll see a message like:

```
✅ Backup created: /sites/example.com/backups/example.com-wp-2025-07-19.tar.gz
```

This archive contains:
- `wp-content.tar.gz`
- `db.sql`

You can use this to restore your site manually if needed.

---

## 🔐 Security Tips

- Restrict access to the script: `chmod 700 wp-backup.sh`
- Secure the backup directory with proper permissions
- Consider automating it with `cron` and a `.my.cnf` file (if passwordless)

---

## 📅 Automation (Optional)

You can schedule regular backups using `cron`:

```bash
0 2 * * * /usr/local/bin/wp-backup.sh <<< $'your_db_name\nyour_db_user\nyour_db_pass'
```

Or rewrite the script to read credentials from a secure config file.

---
