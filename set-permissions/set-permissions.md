```markdown
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
- Makes specific writable directories (`uploads` and `cache`) group-writable by PHP:
  - `wp-content/uploads` → for media files
  - `cache` → for caching plugins like WP Rocket, W3TC, etc.
- Checks if required directories exist before applying changes

---

## 📂 Folder Structure Expected

```bash
/sites/<domain>/
├── public/       # WordPress root
│   └── wp-content/
│       └── uploads/   # Writable media directory
├── cache/        # Writable cache directory (outside public)
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

## 🔧 Fixing Ownership Issues

If you previously ran the script as `root`, or see `Operation not permitted` errors, it means your regular SSH user no longer owns the files.

Run the following **as root** or using `sudo` to restore ownership:

```bash
chown -R SERVER-USER:www-data /sites/EXAMPLE.COM
```

Then re-run the script.
---

## 🔐 Security Notes

- Avoid using `777` permissions — they are unsafe and unnecessary.
- Both `uploads` and `cache` directories must be writable by PHP to avoid file permission errors in WordPress.
- All other folders are restricted from web access by default and should not be publicly exposed.
- Ownership ensures your SSH user can manage files via SFTP, and `www-data` can serve and write via Nginx/PHP.

---
```
