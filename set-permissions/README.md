# 🔐 LEMP Server Permissions Script

An interactive utility to **discover WordPress sites** under `/sites`, **fix file ownership and permissions** for one site at a time, and then **repeat or exit** based on your choice. It prevents WordPress from asking for FTP credentials during updates, plugin/theme installs, and media uploads—while keeping the rest of the codebase locked down.

---

## ✅ What it does

- Auto-discovers sites matching: `/sites/<domain>/public/wp-content`
- Lets you select **one site** to fix per run, then asks to **fix another or exit**
- Applies a **secure, WordPress-friendly** permission model:
  - Owner = your SSH user
  - Group = `www-data` (PHP-FPM/nginx)
  - Global (except `wp-content`): **dirs 750**, **files 640**
  - `wp-content`: **dirs 2775 (g+s)**, **files 664** (group-writable)
  - Creates common writable subfolders: `uploads`, `cache`, `upgrade`, `wflogs`
  - Optionally applies default ACLs (if `setfacl` is available) so new files inherit group write

---

## 🔧 Requirements

- Run as a **non-root** user with `sudo` privileges
- PHP-FPM/nginx group is **`www-data`** (default on Debian/Ubuntu). If your pool uses a different group, adjust in the script.
- Optional but recommended: make sure your SSH user is in the `www-data` group:
  ```bash
  sudo usermod -aG www-data "$(whoami)"
  # Apply group change in current session:
  newgrp www-data
  ```

---

## 🔒 Permission model (summary)

| Path / Scope                  | Owner        | Group     | Dirs | Files | Notes                         |
|------------------------------|--------------|-----------|------|-------|-------------------------------|
| Whole site (except wp-content) | your SSH user | www-data | 750  | 640   | Locked down                   |
| `public/wp-content/**`       | your SSH user | www-data | 2775 | 664   | g+s on dirs, group-writable   |
| `public/wp-config.php`       | your SSH user | www-data |  —   | 640   | Hardened                      |
| `/sites/<domain>/cache` (if exists) | your SSH user | www-data | 2775 | 664   | Writable cache                |

> Why `2775`? The **setgid bit** (`2`) on directories ensures new files/dirs inherit the **`www-data`** group, keeping WP updates/uploads smooth.

---

## 📦 Install

1. Save the script as `fix-wp-perms-interactive.sh` in any directory in your `$PATH` (or your home directory).
2. Make it executable:
   ```bash
   chmod +x fix-wp-perms-interactive.sh
   ```

---

## ▶️ Run

```bash
./fix-wp-perms-interactive.sh
```

You’ll see a numbered list of detected WordPress sites (based on `/sites/<domain>/public/wp-content`). Pick one to fix. After it completes, choose to **fix another** or **quit**.

---

## 🧪 Post-run checks (optional but useful)

- **Direct write test as PHP-FPM group**:
  ```bash
  DOMAIN=example.com
  WPC=/sites/$DOMAIN/public/wp-content
  sudo -u www-data bash -lc "touch '$WPC/test-write' && rm '$WPC/test-write' && echo OK" || echo FAIL
  ```
- **Force direct FS method in WordPress** (if you still see FTP prompts), add to `wp-config.php` above the “stop editing” line:
  ```php
  define('FS_METHOD', 'direct');
  define('FS_CHMOD_DIR', 02775);
  define('FS_CHMOD_FILE', 0664);
  ```
  Remove any `define('FTP_…')` lines if present.

---

## 🧰 How it works (in brief)

1. Recursively sets **owner:group** to `your-user:www-data` for the chosen site.
2. Applies **750/640** outside `wp-content` (tight by default).
3. Applies **2775/664** inside `wp-content` and ensures `uploads`, `cache`, `upgrade`, `wflogs` exist.
4. Applies **g+s** on `wp-content` to maintain group inheritance.
5. If `setfacl` exists, applies **default ACLs** so new files stay group-writable.
6. Hardens `wp-config.php` to `640`.
7. Prints a **permissions summary tree** (depth 1) for quick verification.
8. Offers to process another site or exit.

---

## 🐛 Troubleshooting

- **Still asks for FTP creds**
  - Confirm `wp-content` is **group-writable** (`664` files / `2775` dirs) and owned by `:www-data`.
  - Ensure PHP-FPM pool runs as **`www-data`** (or align the script’s `GROUP` with your pool group).
  - Add `FS_METHOD` constants shown above.
- **Your user not writing smoothly**
  - Add your user to `www-data` group and re-login or run `newgrp www-data`.

---

## 🧹 Reverting (if needed)

To revert to stricter, read-only mode for `wp-content`, you can run:
```bash
DOMAIN=example.com
ROOT=/sites/$DOMAIN
PUBLIC=$ROOT/public
WPC=$PUBLIC/wp-content

sudo chown -R "$(whoami):www-data" "$ROOT"
find "$PUBLIC" -path "$WPC" -prune -o -type d -exec chmod 750 {} +
find "$PUBLIC" -path "$WPC" -prune -o -type f -exec chmod 640 {} +
find "$WPC" -type d -exec chmod 750 {} +
find "$WPC" -type f -exec chmod 640 {} +
```

> Note: Reverting will likely bring back the FTP prompt during updates.

---

## 📄 License

Use and modify freely within your environment.

