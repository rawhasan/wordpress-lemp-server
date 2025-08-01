# 🔐 LEMP Server Permissions Script

This script applies best-practice file and directory permissions for a LEMP-based WordPress site under `/sites/<domain>`. It ensures that only the necessary users have access to sensitive directories, while keeping the public WordPress files readable by the web server.

---

## 🛠️ What It Does

- Prompts for the domain name (e.g., `example.com`)
- Applies secure file ownership:  
  - Owner: current Linux user  
  - Group: `www-data` (used by Nginx and PHP-FPM)
- Sets secure file and folder permissions:
  - Directories: `750` (owner full, group read+execute)
  - Files: `640` (owner read+write, group read)
- Makes the `wp-content/uploads` folder writable by PHP:
  - Sets permissions to `775` for uploads directory
- Checks if the `/sites/<domain>` path exists before proceeding

---

## 📂 Folder Structure Expected

```bash
/sites/<domain>/
├── public/       # WordPress root
├── logs/         # Logs (Nginx/PHP)
├── backups/      # Site backups
├── shells/       # Custom scripts
├── migration/    # Site migration scripts/files
```

---

## ▶️ Usage

1. Place the script on your server, e.g., `set-permissions.sh`
2. Make it executable:
   ```bash
   chmod +x set-permissions.sh
   ```
3. Run the script:
   ```bash
   ./set-permissions.sh
   ```
4. Enter the domain when prompted (e.g., `example.com`)

---

## 🔐 Security Notes

- Avoid using `777` permissions at all costs.
- `uploads` directory must remain writable by PHP (via `www-data`) to allow media uploads from the WP admin.
- Other directories should **not** be exposed publicly via Nginx.
- Ownership should be consistent with how you're deploying or editing files (e.g., SSH/SFTP via your user).