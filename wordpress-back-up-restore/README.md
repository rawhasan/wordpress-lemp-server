```markdown
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
- Pulling the backup from a remote server via `scp`
- Extracting and importing the SQL database
- Replacing the `wp-content` directory
- Cleaning up temporary files

If `wp-config.php` is unavailable, it prompts for DB credentials manually.

---

## ✅ Benefits

- Zero hardcoded credentials
- Timestamped, human-readable filenames
- Works across servers
- Simple, auditable Bash scripts
- Compatible with any LEMP stack using `/sites/<domain>/public` structure

---

Created for safe, portable, and efficient WordPress migrations and disaster recovery.
```
