# 🛠️ WordPress Backup Restoration Script

This script restores a WordPress site from a timestamped backup file pulled from a remote server. It restores both the database and `wp-content` directory, and supports modern backup naming conventions.

---

## 📂 Backup File Structure

The script expects the backup archive to follow this format:

```
example.com-wp-YYYY-MM-DD_HHMM.tar.gz
├── example.com-db-YYYY-MM-DD_HHMM.sql
└── example.com-wp-content-YYYY-MM-DD_HHMM.tar.gz
```

---

## ▶️ How to Use

1. **Upload the script** to your new server and make it executable:

   ```bash
   chmod +x restore-wp-backup.sh
   ```

2. **Run the script**:

   ```bash
   ./restore-wp-backup.sh
   ```

3. **Follow the prompts**:

   - Domain name (e.g., `example.com`)
   - Old server IP address
   - SSH username on the old server
   - Backup filename (e.g., `example.com-wp-20250719_1830.tar.gz`)
   - If `wp-config.php` is missing, it will also ask for DB credentials

---

## 🔧 What the Script Does

1. Prompts for the domain and backup information.
2. Creates necessary directories under `/sites/<domain>/`.
3. Pulls the specified backup archive from the old server via `scp`.
4. Extracts the backup archive into the `migrate` folder.
5. Reads DB credentials from `wp-config.php` or prompts for them.
6. Restores the database from the extracted `.sql` file.
7. Extracts and replaces the `wp-content` directory.
8. Cleans up all temporary files.

---

## 🧹 Cleanup Performed

After restoration, the script removes:
- The downloaded `.tar.gz` backup
- The extracted `.sql` file
- The extracted `wp-content-*.tar.gz`
- The temporary `wp-content/` directory in `migrate`

---

## ✅ Completion

Once successful, you will see:

```
✅ Restoration completed successfully for <domain>
```

---

## ⚠️ Notes

- Ensure the MySQL user has permissions to restore the database.
- SSH access to the old server is required.
- This script assumes WordPress is located at:  
  `/sites/<domain>/public`

