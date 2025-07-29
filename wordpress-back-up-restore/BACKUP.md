# WordPress Backup Script

This script creates a full backup of a WordPress site — including the database and `wp-content` directory — and compresses everything into a single archive.

## 📄 What It Does

- Extracts MySQL credentials from `wp-config.php`
- Backs up the `wp-content` directory
- Dumps the MySQL database
- Packages everything into a compressed `.tar.gz` archive
- Cleans up temporary files

## 📁 File Naming Convention

All output files are named using this pattern:

```
example.com-wp-YYYY-MM-DD_HHMM.tar.gz
├── example.com-db-YYYY-MM-DD_HHMM.sql
└── example.com-wp-content-YYYY-MM-DD_HHMM.tar.gz
```

## ⚙️ Configuration

You only need to set:

```bash
SITE_NAME="example.com"
```

The script will automatically derive:

- `WP_PATH`: `/sites/example.com/public`
- `BACKUP_DIR`: `/sites/example.com/backups`

## 🚀 How to Use

1. Open the script and edit the `SITE_NAME` variable with your domain.
2. Run the script:

```bash
bash wp-backup.sh
```

3. The backup archive will be saved to:

```
/sites/example.com/backups/
```

## 🔐 Security Notes

- The script securely reads DB credentials from `wp-config.php`.
- Avoids hardcoded credentials.
- Uses a temporary `/tmp` directory during packaging.

## 🧹 Cleanup

Temporary working directory is deleted after the archive is created.

## 🧰 Requirements

- Bash shell
- `mysqldump`
- `tar`
- `grep`, `sed`, `date` (standard GNU tools)

## ✅ Sample Output

```bash
📦 Backing up wp-content...
🛢️ Backing up MySQL database...
🗜️ Creating final archive: /sites/example.com/backups/example.com-wp-2025-07-28_2145.tar.gz
✅ Backup created: /sites/example.com/backups/example.com-wp-2025-07-28_2145.tar.gz
```

---
Created for safe, timestamped WordPress backups.

