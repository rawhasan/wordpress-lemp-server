# ♻️ WordPress Restore Script

This script restores a WordPress site from a timestamped backup archive — either pulled from a remote server or already present on the local server.

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

- Creates target directories under `/sites/<domain>/`
- Extracts the `.tar.gz` archive into a `migrate` directory
- Reads DB credentials from `wp-config.php` or prompts for them
- Restores the database from the extracted SQL file
- Extracts and replaces the `wp-content` directory
- Cleans up all temporary files after success

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
📦 Pulling backup from old server...
📂 Extracting backup...
🔍 Extracting database credentials from wp-config.php...
🗄️ Restoring database...
📂 Extracting wp-content archive...
♻️ Replacing wp-content directory...
🧹 Cleaning up temporary files...
✅ Restoration completed successfully for example.com
```

---

Created to safely restore WordPress sites using domain-based, timestamped backups.
