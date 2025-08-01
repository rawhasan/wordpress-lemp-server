# 🔐 LEMP Server Permissions Script

This script applies best-practice file and directory permissions for a WordPress site hosted on a LEMP stack under `/sites/<domain>`. It ensures secure ownership and access for your server user and the web server (`www-data`), while preserving necessary write permissions for uploads and caching.

---

## 🛠️ What It Does

- Detects the current user running the script
- **Blocks execution as root** to prevent locking out the SSH user
- Prompts for the domain name (e.g., `example.com`)
- Applies secure file ownership:
  - Owner: the current user (e.g., `rawhasan`)
  - Group: `www-data` (for Nginx/PHP-FPM access)
- Applies permissions:
  - Directories → `750`
  - Files → `640`
- Grants write access to:
  - `public/wp-content/uploads`
  - `cache` (if exists)

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

0. Run this first:

```bash
sudo chown -R SERVER-USER:www-data /sites/example.com
```

1. Place the script on your server, e.g., `set-permissions.sh`
2. Make it executable:
   ```bash
   chmod +x set-permissions.sh
   ```
3. Run it as your SSH user (not root):
   ```bash
   ./set-permissions.sh
   ```
4. Enter the domain when prompted (e.g., `example.com`)

---

## 🛑 Do NOT Run as Root

Running this script as `root` will change ownership of files to `root`, locking out your regular SSH user from accessing or modifying files via SFTP or CLI.

If you accidentally ran the script as `root`, fix it by running the following as root or via `sudo`:

```bash
sudo chown -R SERVER-USER:www-data /sites/example.com
```

Then re-run the script.

---

## 📁 Expected File Structure After Running the Script

```bash
/sites/example.com/              rawhasan:www-data  750
├── public/                      rawhasan:www-data  750
│   ├── wp-content/              rawhasan:www-data  750
│   │   ├── uploads/             rawhasan:www-data  775   # Writable by PHP
│   │   │   ├── image.jpg        rawhasan:www-data  640
│   │   │   └── ...              rawhasan:www-data  640
│   │   └── plugins/             rawhasan:www-data  750
│   ├── wp-config.php            rawhasan:www-data  640
│   └── index.php                rawhasan:www-data  640
├── cache/                       rawhasan:www-data  775   # Writable by PHP
│   └── plugin-cache-data/       rawhasan:www-data  775
│       └── cached-file.html     rawhasan:www-data  640
├── logs/                        rawhasan:www-data  750
│   └── error.log                rawhasan:www-data  640
├── backups/                     rawhasan:www-data  750
│   └── site-backup.tar.gz       rawhasan:www-data  640
├── shells/                      rawhasan:www-data  750
│   └── set-permissions.sh       rawhasan:www-data  750
└── migration/                   rawhasan:www-data  750
    └── migrate.sql              rawhasan:www-data  640
```

---

### 🔑 Key Takeaways

- **Directories**: Set to `750`  
  ↳ Owner can read/write/enter, group (`www-data`) can access if needed  
- **Files**: Set to `640`  
  ↳ Owner can read/write, group can read, others have no access  
- **Writable directories**:  
  - `uploads/` and `cache/` → `775` so WordPress (via `www-data`) can write
- **Ownership**:  
  - All files and directories are owned by your SSH user (e.g., `rawhasan`)  
  - Group ownership is assigned to `www-data` for PHP/Nginx access
- This structure ensures:
  - ✅ No FTP prompts in WordPress
  - ✅ Secure and functional file operations for both SSH and PHP


## 🔐 Security Notes

- Never use `777` permissions — they expose your site to serious security risks.
- Upload and cache folders must remain writable by `www-data` for WordPress functionality.
- All other folders are restricted from public access by default and should be protected further via Nginx if needed.
- This setup ensures your SSH user can manage files, and WordPress can function without asking for FTP credentials.
