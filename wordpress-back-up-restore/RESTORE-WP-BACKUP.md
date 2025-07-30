# ♻️ WordPress Restore Script

This script restores a WordPress site from a timestamped backup archive — either pulled from a remote server or already present on the local server. It ensures a clean restore by dropping existing database tables and deleting the current `wp-content` folder before applying the backup.

---

## 📦 Backup Archive Structure

The script expects a backup archive in the following format:

```
example.com-wp-YYYY-MM-DD_HHMM.tar.gz
├── example.com-db-YYYY-MM-DD_HHMM.sql
└── example.com-wp-content-YYYY-MM-DD_HHMM.tar.gz
```

---

## ▶️ How to Use

1. Make the script executable:

   ```bash
   chmod +x restore-wp-backup.sh
   ```

2. Run the script:

   ```bash
   ./restore-wp-backup.sh
   ```

3. Choose backup source when prompted:

   - `1`: Pull from old server using SCP
   - `2`: Use local backup file already uploaded to this server

4. Provide the required input:
   - Domain name (e.g., `example.com`)
   - If pulling: old server IP and SSH username
   - If local: path to `.tar.gz` backup
   - If `wp-config.php` not found: manual DB credentials

---

## 🔧 What It Does

- Creates directories under `/sites/<domain>/`
- Extracts the `.tar.gz` backup into `/sites/<domain>/migrate/`
- Reads DB credentials from `wp-config.php` or prompts the user
- **Drops all existing tables** from the target database
- **Deletes the existing `wp-content/` directory**
- Imports the SQL dump
- Replaces `wp-content/` with backed-up content
- Cleans up temporary files

---

## 🧹 Cleanup Performed

After restoration, it deletes:
- The pulled or local backup archive
- The SQL file
- The extracted wp-content archive
- Temporary directories inside `/sites/<domain>/migrate`

---

## ✅ Sample Output

```bash
📦 Using local backup: example.com-wp-2025-07-28_2145.tar.gz
📂 Extracting backup...
🔍 Extracting database credentials from wp-config.php...
🧨 Dropping all existing tables in example_com...
🗄️ Restoring database...
📂 Extracting wp-content archive...
🧺 Deleting old wp-content directory...
♻️ Replacing wp-content directory...
🧹 Cleaning up temporary files...
✅ Restoration completed successfully for example.com
```

---

Created for reliable, clean WordPress restoration across environments.
