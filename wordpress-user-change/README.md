# WordPress PHP-FPM User Switch Scripts

## 1. Steps to Change the Ownership

✅ **Run WordPress as `SERVER-USER` for `EXAMPLE.COM`**

### 1. Change PHP-FPM to Run as `SERVER-USER`

Edit the PHP-FPM pool config:

```bash
sudo nano /etc/php/8.3/fpm/pool.d/www.conf
```

Update these lines:

```ini
user = SERVER-USER
group = SERVER-USER

listen = /run/php/php8.3-fpm.sock
listen.owner = SERVER-USER
listen.group = SERVER-USER
listen.mode = 0660
```

Save and exit.

---

### 2. Allow Nginx (`www-data`) to Access PHP-FPM Socket

```bash
sudo usermod -aG SERVER-USER www-data
```

---

### 3. Change WordPress File Ownership

```bash
sudo chown -R SERVER-USER:SERVER-USER /sites/EXAMPLE.COM
```

---

### 4. Set Correct Permissions

```bash
find /sites/EXAMPLE.COM -type d -exec chmod 755 {} \;
find /sites/EXAMPLE.COM -type f -exec chmod 644 {} \;
```

---

### 5. Restart Services

```bash
sudo systemctl restart php8.3-fpm
sudo systemctl restart nginx
```

---

### 6. Confirm It's Working

Check PHP-FPM is running as `SERVER-USER`:

```bash
ps aux | grep php-fpm
```

Check PHP-FPM socket:

```bash
ls -l /run/php/php8.3-fpm.sock
```

You should see something like:

```bash
srw-rw---- 1 SERVER-USER SERVER-USER ... /run/php/php8.3-fpm.sock
```

---

### ✅ Nginx Config (Just for Confirmation)

Your site's Nginx config (e.g., `/etc/nginx/sites-available/EXAMPLE.COM`) should contain:

```nginx
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php8.3-fpm.sock;
}
```

---

## 2. How to Verify Ownership Change

- Check PHP-FPM is running as your user:

```bash
ps aux | grep php-fpm
```

- Check site file ownership:

```bash
ls -l /sites/EXAMPLE.COM
```

- Check PHP socket:

```bash
ls -l /run/php/php8.3-fpm.sock
```

You should see:
- PHP-FPM running under your user (e.g., `SERVER-USER`)
- Files and folders owned by your user
- Socket owned by your user and group-accessible by `www-data`

---

## 3. How the Change Script Works and How to Use It

**Script:** `switch-wp-user.sh`  
**Purpose:** Change the user that PHP-FPM and WordPress run as (from `www-data` to your current user).

### Key Features:
- Updates PHP-FPM pool config to use your user
- Updates socket permissions
- Changes file ownership and permissions
- Adds `www-data` to your user's group
- Restarts PHP-FPM and Nginx
- **Dry run shown first**
- Asks before applying
- Rolls back on error

### Usage:
```bash
sudo ./switch-wp-user.sh
```

---

## 4. How the Revert Script Works and How to Use It

**Script:** `revert-wp-user.sh`  
**Purpose:** Restore WordPress and PHP-FPM to run as `www-data`.

### Key Features:
- Updates PHP-FPM pool config to `www-data`
- Resets socket and file ownership
- Fixes file permissions
- Restarts services
- **Dry run shown first**
- Asks before applying
- Backs up pool config
- Rolls back on error

### Usage:
```bash
sudo ./revert-wp-user.sh
```
