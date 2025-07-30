# 🧰 WordPress Backup & Restore Toolkit

This toolkit provides two Bash scripts to **safely back up and restore** a WordPress site — including both the MySQL database and the `wp-content` directory — using timestamped, domain-based file naming.

---

## 📦 Backup Script

Creates a compressed `.tar.gz` archive containing:
- A SQL dump of the database
- A tarball of the `wp-content` folder

All credentials are securely extracted from `wp-config.php`. Output files are saved to `/sites/<domain>/backups/` using the format:

```
example.com-wp-YYYY-MM-DD_HHMM.tar.gz
├── example.com-db-YYYY-MM-DD_HHMM.sql
└── example.com-wp-content-YYYY-MM-DD_HHMM.tar.gz
```

---

## ♻️ Restore Script

Restores a WordPress site by:
- **Option 1**: Pulling the backup archive from a remote server via `scp`
- **Option 2**: Using a local backup archive already on the same server
- **Dropping all existing tables** in the database before restoring
- **Deleting the current `wp-content/` directory** before replacement
- Extracting and importing the SQL database
- Replacing `wp-content` with backed-up data
- Cleaning up temporary files

If `wp-config.php` is unavailable, it prompts for DB credentials manually.

---

## ✅ Benefits

- Zero hardcoded credentials
- Timestamped, human-readable filenames
- Works across servers or from local backups
- Fully clean restore process (DB and files)
- Compatible with any LEMP stack using `/sites/<domain>/public` structure

---

Created for safe, portable, and efficient WordPress migrations and disaster recovery.
