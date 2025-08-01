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
- Displays a summary tree (depth 1) of each top-level folder after permission changes

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
sudo chown -R rawhasan:www-data /sites/example.com
```

The re-run the script.
---

## 📁 Example Output (Depth: 1)

```bash
🔹 public/
└── wp-content [750 rawhasan:www-data]

🔹 cache/
└── plugin-cache [775 rawhasan:www-data]

🔹 logs/
└── error.log [640 rawhasan:www-data]
```

---

## 🔐 Security Notes

- Never use `777` permissions — they expose your site to serious security risks.
- Upload and cache folders must remain writable by `www-data` for WordPress functionality.
- All other folders are restricted from public access by default and should be protected further via Nginx if needed.
- This setup ensures your SSH user can manage files, and WordPress can function without asking for FTP credentials.
