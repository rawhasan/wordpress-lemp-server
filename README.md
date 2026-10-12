# SpinupWP Ubuntu 24.04 WordPress LEMP Server — Chapter-by-Chapter Cheat Sheet

> **Scope and source fidelity:** This is a practical, command-focused companion to SpinupWP’s ten-chapter *Install WordPress on Ubuntu 24.04* guide. It follows the guide’s sequence and examples: DigitalOcean VPS, Ubuntu 24.04 LTS x64, Nginx mainline, PHP 8.4-FPM, WP-CLI, MySQL 8.4, HTTPS/HTTP/3, cache, cron, S3 backups, hardening, migration, maintenance, and the final Nginx configuration kit. Examples use the guide’s sample names (`abe`, `pluto.turnipjuice.media`, `globex.turnipjuice.media`, `globex`, `password`, and sample S3 bucket) and must be replaced with your own values before use.
>
> The source guide’s commands and decisions are reproduced or condensed by chapter below; this is not a claim that the source guide has been tested against a different Ubuntu release. Do not run sample secrets or leave example domain names in production. See the linked chapter for any UI-only steps, full config file, diagrams, and qualifications.

## Before starting

- Follow this exact edition on a new **Ubuntu 24.04 LTS x64** server. Chapter 1 uses DigitalOcean and specifies at least 2 GB RAM, a Regular CPU, a region near the audience, a hostname, and free improved metrics monitoring.
- Have a domain/subdomain and access to its DNS. The guide’s sample server hostname is `pluto.turnipjuice.media`; its WordPress site is `globex.turnipjuice.media`.
- Keep a provider recovery route available before hardening SSH. Test new SSH access in another terminal before ending the working session.
- In the examples below, `<...>` means substitute a value. Never literally type angle-bracket placeholders. Some of the original examples include `abe`, `globex`, and `password`; replace all with your own values.

## Chapter index

1. [Set up and secure a VPS](#chapter-1--set-up-and-secure-a-vps)
2. [Install Nginx, PHP 8.4, WP-CLI, and MySQL 8.4](#chapter-2--install-nginx-php-84-wp-cli-and-mysql-84)
3. [Configure Nginx, HTTPS, and WordPress](#chapter-3--configure-nginx-https-and-wordpress)
4. [Configure Valkey object cache and Nginx FastCGI page cache](#chapter-4--configure-valkey-object-cache-and-nginx-fastcgi-page-cache)
5. [Configure WordPress cron and outgoing email](#chapter-5--configure-wordpress-cron-and-outgoing-email)
6. [Automate site backups to Amazon S3](#chapter-6--automate-site-backups-to-amazon-s3)
7. [Harden SSH, TLS, and browser security headers](#chapter-7--harden-ssh-tls-and-browser-security-headers)
8. [Migrate WordPress to a new server](#chapter-8--migrate-wordpress-to-a-new-server)
9. [Monitor and maintain the server](#chapter-9--monitor-and-maintain-the-server)
10. [Use the complete Nginx configuration kit](#chapter-10--use-the-complete-nginx-configuration-kit)

---

## Chapter 1 — Set up and secure a VPS

**Source chapter:** [Set Up and Secure a VPS on DigitalOcean](https://spinupwp.com/hosting-wordpress-setup-secure-virtual-server/)

### 1. Provision and connect

In DigitalOcean, create a Droplet using the guide’s choices: Ubuntu 24.04 LTS x64, Regular CPU, at least 2 GB RAM, a region/datacenter near the audience, improved metrics monitoring enabled, and the intended server hostname. The source initially uses a password for setup, then disables root and password SSH login after creating and testing a sudo account with an SSH key.

From your workstation, connect as root using the server’s IP address:

```bash
ssh root@<SERVER_IP>
```

### 2. Set hostname and DNS

```bash
hostnamectl hostname pluto.turnipjuice.media
```

Create an A record for the hostname pointing to the server IP. If Cloudflare DNS is used, the guide says to turn proxying off for this hostname. After DNS resolves, test SSH by hostname:

```bash
ssh root@pluto.turnipjuice.media
```

### 3. Set timezone and update packages

The source uses UTC; substitute a valid zone if your server needs another one.

```bash
timedatectl set-timezone UTC
timedatectl
apt update
apt dist-upgrade
apt autoremove
reboot now
```

After the reboot, reconnect:

```bash
ssh root@pluto.turnipjuice.media
```

### 4. Enable unattended security updates

```bash
apt install unattended-upgrades
dpkg-reconfigure unattended-upgrades
```

Choose **Yes** in the configuration prompt. Edit the allowed origins:

```bash
nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Keep the Ubuntu release and security origins enabled; the source comments out general updates, proposed, and backports. The relevant settings shown in the guide are:

```text
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}";
        "${distro_id}:${distro_codename}-security";
        "${distro_id}ESMApps:${distro_codename}-apps-security";
        "${distro_id}ESM:${distro_codename}-infra-security";
//      "${distro_id}:${distro_codename}-updates";
//      "${distro_id}:${distro_codename}-proposed";
//      "${distro_id}:${distro_codename}-backports";
};
```

The guide notes the automatic reboot setting can be disabled or scheduled. For example, to disable automatic reboot, uncomment/set:

```text
Unattended-Upgrade::Automatic-Reboot "false";
```

To schedule it instead, the guide gives:

```text
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
```

Enable daily unattended-upgrade runs:

```bash
nano /etc/apt/apt.conf.d/20auto-upgrades
```

Ensure this line is present:

```text
APT::Periodic::Unattended-Upgrade "1";
```

Restart the service:

```bash
systemctl restart unattended-upgrades.service
```

### 5. Create and test a sudo user

The source example uses `abe`; choose your own login name.

```bash
adduser abe
usermod -aG sudo abe
logout
```

From your workstation, connect as the new user:

```bash
ssh abe@pluto.turnipjuice.media
```

### 6. Create and install an SSH key

Run this **on your workstation**, not on the server:

```bash
ssh-keygen -t ed25519 -C "abe@laptop"
```

On the server, while logged in as the new user:

```bash
mkdir ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
```

Paste the contents of the workstation’s public key (`~/.ssh/id_ed25519.pub`) into that file and save. Then set its permissions:

```bash
chmod 600 ~/.ssh/authorized_keys
```

The original guide uses `pbcopy` to copy the key on macOS; on another workstation, display/copy the public key using its available clipboard method:

```bash
cat ~/.ssh/id_ed25519.pub
```

Log out and verify that key-based login works before continuing.

### 7. Disable root and password SSH authentication

Edit SSH server configuration:

```bash
sudo nano /etc/ssh/sshd_config
```

Set:

```text
PermitRootLogin no
PasswordAuthentication no
```

Restart SSH:

```bash
sudo systemctl restart ssh.service
```

Keep the current SSH session open. Open a **second terminal** and test the normal user’s key login:

```bash
ssh abe@pluto.turnipjuice.media
```

If password login remains possible, inspect `/etc/ssh/sshd_config.d/` for an included setting that overrides it, as the guide describes. Correct that override and retest before closing the working session.

### 8. Configure UFW and Fail2ban

Allow SSH, HTTP, and HTTPS before enabling the firewall:

```bash
sudo apt install ufw
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw show added
sudo ufw enable
sudo ufw status verbose
```

Install and enable Fail2ban:

```bash
sudo apt install fail2ban
sudo systemctl enable --now fail2ban.service
sudo systemctl status fail2ban.service
```

If IPv6 causes the warning described in the guide, create `/etc/fail2ban/fail2ban.local` with:

```ini
[DEFAULT]
allowipv6 = auto
```

Then restart Fail2ban:

```bash
sudo systemctl restart fail2ban.service
```

---

## Chapter 2 — Install Nginx, PHP 8.4, WP-CLI, and MySQL 8.4

**Source chapter:** [Install Nginx, PHP 8.4, WP-CLI, MySQL for WordPress on Ubuntu 24.04](https://spinupwp.com/hosting-wordpress-yourself-nginx-php-mysql/)

Reconnect as the sudo user:

```bash
ssh abe@pluto.turnipjuice.media
```

### 1. Install Nginx from the official mainline repository

```bash
sudo apt update
sudo apt install curl gnupg2 ca-certificates lsb-release ubuntu-keyring
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx
sudo apt update
sudo apt install nginx
nginx -v
```

The guide then configures `/etc/nginx/nginx.conf`: set the Nginx worker user to the server’s unprivileged user (`abe` in its example), set `worker_processes auto`, `worker_connections 1024`, and `multi_accept on`; set `tcp_nopush on`, `keepalive_timeout 15`, `server_tokens off`, and `client_max_body_size 64m`; enable gzip and the source’s listed `gzip_vary`, `gzip_proxied`, `gzip_comp_level`, `gzip_min_length`, and `gzip_types` directives. The complete example is included in Chapter 10’s linked kit.

Record the open-file limit before editing, as the source directs:

```bash
ulimit -n
sudo nano /etc/nginx/nginx.conf
```

After editing, validate and enable/restart Nginx:

```bash
sudo nginx -t
sudo systemctl restart nginx.service
sudo systemctl enable --now nginx.service
```

### 2. Install PHP 8.4-FPM and WordPress extensions

The source uses the Ondřej Surý PHP PPA:

```bash
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install php8.4-fpm php8.4-common php8.4-mysql \
  php8.4-xml php8.4-intl php8.4-curl php8.4-gd \
  php8.4-imagick php8.4-cli php8.4-dev php8.4-imap \
  php8.4-mbstring php8.4-opcache php8.4-redis \
  php8.4-soap php8.4-zip -y
```

The source configures PHP-FPM and PHP settings, including OPcache file override (`opcache.enable_file_override = 1`) in `/etc/php/8.4/fpm/php.ini`, tests the FPM config, and restarts PHP-FPM:

```bash
sudo nano /etc/php/8.4/fpm/php.ini
sudo php-fpm8.4 -t
sudo systemctl restart php8.4-fpm.service
```

### 3. Test Nginx + PHP, then remove the test file

Edit the default Nginx server config and enable its PHP location with the guide’s PHP-FPM socket:

```bash
sudo nano /etc/nginx/conf.d/default.conf
```

The PHP location shown in the guide is:

```nginx
location ~ \.php$ {
  root          /usr/share/nginx/html;
  fastcgi_pass  unix:/run/php/php8.4-fpm.sock;
  fastcgi_index index.php;
  fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
  include       fastcgi_params;
}
```

Test/reload, create the temporary PHP info file, visit it, then delete it immediately after testing:

```bash
sudo nginx -t
sudo systemctl restart nginx.service
cd /usr/share/nginx/html
sudo nano info.php
```

File contents:

```php
<?php phpinfo();
```

Set ownership as the guide demonstrates, visit `http://<SERVER_HOSTNAME>/info.php`, then remove the file:

```bash
sudo chown abe info.php
sudo rm /usr/share/nginx/html/info.php
```

### 4. Configure Nginx catch-all

Remove the default site and add a default server block under the `include /etc/nginx/conf.d/*.conf;` line in `nginx.conf`:

```bash
sudo rm /etc/nginx/conf.d/default.conf
sudo nano /etc/nginx/nginx.conf
```

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    return 444;
}
```

Test and restart:

```bash
sudo nginx -t
sudo systemctl restart nginx.service
```

### 5. Install WP-CLI

```bash
cd ~/
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
php wp-cli.phar --info
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
wp
```

### 6. Install MySQL 8.4 from the MySQL APT repository

The guide downloads and installs the MySQL APT config package, selects the MySQL 8.4 series in its interactive menu, updates package lists, and installs MySQL:

```bash
wget https://dev.mysql.com/get/mysql-apt-config_0.8.36-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.36-1_all.deb
sudo apt update
sudo apt install mysql-server -y
```

Set the MySQL root password when prompted. Run the secure setup wizard and follow the chapter’s answers: enable password validation at `STRONG` (2), keep the existing root password, remove anonymous users, disallow remote root login, remove the test database, and reload privileges.

```bash
sudo mysql_secure_installation
```

The source notes that its MySQL repository did not support ARM at publication time; on ARM, `apt` may use Ubuntu’s repository instead. Consult the current chapter before applying this version-specific step.

---

## Chapter 3 — Configure Nginx, HTTPS, and WordPress

**Source chapter:** [Configure Nginx to Serve WordPress over HTTPS on Ubuntu 24.04](https://spinupwp.com/hosting-wordpress-yourself-setting-up-sites/)

### 1. Extend the catch-all to HTTPS/HTTP/3

Create a self-signed certificate for the default catch-all server:

```bash
sudo mkdir -p /etc/nginx/ssl/default
sudo openssl req -x509 -newkey rsa:4096 -days 36500 \
  -keyout /etc/nginx/ssl/default/privkey.pem \
  -out /etc/nginx/ssl/default/cert.pem \
  -subj "/CN=default" -nodes
```

In the default server block, add listeners for TLS and QUIC, the certificate paths, and retain the `return 444;`:

```nginx
listen 443 ssl default_server deferred;
listen [::]:443 ssl default_server deferred;
listen 443 quic reuseport default_server;
listen [::]:443 quic reuseport default_server;
ssl_certificate /etc/nginx/ssl/default/cert.pem;
ssl_certificate_key /etc/nginx/ssl/default/privkey.pem;
```

### 2. DNS and Let’s Encrypt

Create DNS records for the site and `www` hostname as in the chapter. The source recommends CNAMEs pointing to the server hostname and says Cloudflare proxying should be disabled while obtaining certificates.

Install Certbot and the Nginx plugin:

```bash
sudo apt install software-properties-common
sudo add-apt-repository universe
sudo apt update
sudo apt install certbot python3-certbot-nginx
```

Request the certificate (replace both sample domains):

```bash
sudo certbot --nginx certonly -d globex.turnipjuice.media -d www.globex.turnipjuice.media
sudo certbot renew --dry-run
```

The chapter says Certbot handles renewals automatically; record the returned `fullchain.pem` and `privkey.pem` paths.

### 3. Create the site directories and Nginx server blocks

The source puts each site under the home directory with `logs` and `public` subdirectories:

```bash
cd ~/
mkdir -p globex.turnipjuice.media/logs globex.turnipjuice.media/public
chmod -R 755 globex.turnipjuice.media
sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/sites-enabled
```

Create `/etc/nginx/sites-available/globex.turnipjuice.media`. The primary HTTPS server uses the site root, log paths, PHP 8.4 socket, HTTP/3 advertisement, and WordPress front-controller fallback; the other two blocks redirect `www` and HTTP to the canonical HTTPS hostname:

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    listen 443 quic;
    listen [::]:443 quic;
    http2 on;

    server_name globex.turnipjuice.media;
    ssl_certificate /etc/letsencrypt/live/globex.turnipjuice.media/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/globex.turnipjuice.media/privkey.pem;
    access_log /home/abe/globex.turnipjuice.media/logs/access.log;
    error_log /home/abe/globex.turnipjuice.media/logs/error.log;
    root /home/abe/globex.turnipjuice.media/public/;
    index index.php;
    add_header Alt-Svc 'h3=":443"; ma=86400' always;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    listen 443 quic;
    listen [::]:443 quic;
    http2 on;
    server_name www.globex.turnipjuice.media;
    ssl_certificate /etc/letsencrypt/live/globex.turnipjuice.media/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/globex.turnipjuice.media/privkey.pem;
    add_header Alt-Svc 'h3=":443"; ma=86400' always;
    return 301 https://globex.turnipjuice.media$request_uri;
}

server {
    listen 80;
    listen [::]:80;
    server_name globex.turnipjuice.media www.globex.turnipjuice.media;
    return 301 https://globex.turnipjuice.media$request_uri;
}
```

In `/etc/nginx/nginx.conf`, include the enabled sites beneath the existing `conf.d` include:

```nginx
include /etc/nginx/sites-enabled/*;
```

Enable and test the site:

```bash
sudo ln -s /etc/nginx/sites-available/globex.turnipjuice.media /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx.service
```

### 4. Create a database and install WordPress

Create a database and a dedicated database user. Replace the sample name/password; use a unique strong password.

```bash
mysql -u root -p
```

At the MySQL prompt:

```sql
CREATE DATABASE globex CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;
CREATE USER 'globex'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON globex.* TO 'globex'@'localhost';
FLUSH PRIVILEGES;
exit;
```

The source mentions `SELECT, INSERT, UPDATE, DELETE` as a narrower alternative but cautions that plugins and major WordPress updates can require additional privileges.

Install WordPress through WP-CLI:

```bash
cd ~/globex.turnipjuice.media/public
wp core download
wp core config --dbname=globex --dbuser=globex --dbpass='password'
wp core install --skip-email \
  --url=https://globex.turnipjuice.media \
  --title='Globex Corporation' \
  --admin_user=abe \
  --admin_password='<STRONG_ADMIN_PASSWORD>'
```

### Add another site

Repeat the chapter’s order for each new site: add DNS, obtain its certificate, create `logs` and `public`, copy/edit a server block, enable it via symlink, test/reload Nginx, create a separate database/user, then install and configure WordPress with WP-CLI.

---

## Chapter 4 — Configure Valkey object cache and Nginx FastCGI page cache

**Source chapter:** [Configure Redis Object Cache and Nginx FastCGI Page Cache for WordPress](https://spinupwp.com/hosting-wordpress-yourself-server-monitoring-caching/)

The current chapter uses **Valkey** (with Redis compatibility) for object caching. The WordPress admin interface still refers to the Redis Object Cache plugin.

### 1. Install and enable Valkey; enable the plugin

```bash
sudo apt install valkey-server valkey-redis-compat -y
sudo systemctl enable --now valkey-server.service
```

Install and activate the **Redis Object Cache** WordPress plugin. In WordPress, go to **Settings → Redis** and click **Enable Object Cache**. The same screen can flush the object cache.

### 2. Configure FastCGI page cache

Edit the site virtual host:

```bash
sudo nano /etc/nginx/sites-available/globex.turnipjuice.media
```

Before the server block, add a cache path/zone (match the zone name in the PHP location):

```nginx
fastcgi_cache_path /home/abe/globex.turnipjuice.media/cache levels=1:2 keys_zone=globex.turnipjuice.media:100m inactive=60m;
```

In the server block, add the skip-cache conditions before the `Alt-Svc` header. They bypass POST requests, query strings, administrative/API/feed/system endpoints, and logged-in/recent-commenter cookies:

```nginx
set $skip_cache 0;

# POST requests should always go to PHP
if ($request_method = POST) {
    set $skip_cache 1;
}

# URLs containing query strings should always go to PHP
if ($query_string != "") {
    set $skip_cache 1;
}

# Don't cache uris containing the following segments
if ($request_uri ~* "/wp-admin/|/wp-json/|/xmlrpc.php|wp-.*.php|/feed/|index.php|sitemap(_index)?.xml") {
    set $skip_cache 1;
}

# Don't use the cache for logged in users or recent commenters
if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
    set $skip_cache 1;
}
add_header Fastcgi-Cache $upstream_cache_status;
```

In the PHP-FPM `location` block, add:

```nginx
fastcgi_cache globex.turnipjuice.media;
fastcgi_cache_bypass $skip_cache;
fastcgi_no_cache $skip_cache;
fastcgi_cache_valid 60m;
```

In `/etc/nginx/nginx.conf`, inside `http`, add below the gzip settings:

```nginx
fastcgi_cache_key "$scheme$request_method$http_host$request_uri";
```

Test and restart Nginx:

```bash
sudo nginx -t
sudo systemctl restart nginx.service
```

Install the **Nginx Cache** plugin and set its cache zone path to the same directory in `fastcgi_cache_path`. Inspect the `Fastcgi-Cache` response header: `MISS` on first request, `HIT` for a cached page, and `BYPASS` where the skip logic applies. The guide also gives this manual full-cache purge:

```bash
sudo rm -Rf /home/abe/globex.turnipjuice.media/cache/*
```

### 3. WooCommerce exclusions

For a WooCommerce site, add these conditions to the server block’s skip-cache rules:

```nginx
# Don’t use cache for WooCommerce pages
if ($request_uri ~* "/cart/|/checkout/|/my-account/") {
    set $skip_cache 1;
}

# Don't use the cache when cart contains items
if ($http_cookie ~* "woocommerce_items_in_cart") {
    set $skip_cache 1;
}
```

Then validate and reload:

```bash
sudo nginx -t
sudo systemctl reload nginx.service
```

The chapter says to add equivalent exclusions for dynamic paths created by other plugins (it names Easy Digital Downloads, WP eCommerce, BuddyPress, and bbPress). Determine each plugin’s paths from its own documentation before adding exclusions.

---

## Chapter 5 — Configure WordPress cron and outgoing email

**Source chapter:** [WordPress Cron and Email Sending](https://spinupwp.com/hosting-wordpress-yourself-cron-email-automatic-backups/)

### 1. Move WordPress cron to the system crontab

In `wp-config.php`, disable request-triggered WordPress cron:

```php
define('DISABLE_WP_CRON', true);
```

Edit the server user’s crontab:

```bash
crontab -e
```

Add one line per site to run due events every five minutes (replace the path):

```cron
*/5 * * * * cd /home/abe/globex.turnipjuice.media/public; /usr/local/bin/wp cron event run --due-now --quiet
```

The guide recommends WP-CLI over `wget`/`curl` because those make web requests through Nginx and inherit web-request timeouts. `--quiet` prevents cron output email to the Unix user.

### 2. Send mail through an email provider

The source does **not** recommend operating a mail server on this VPS. Configure WordPress to send outgoing mail through an established provider using a mail plugin/transactional sending service; it names WP Offload SES and WP Mail SMTP as examples. Configure the selected provider’s own credentials and DNS records according to its instructions.

### 3. Test cron/email, then disable the test

The chapter supplies a temporary plugin that schedules an email to the admin every five minutes. It is a test only; remove/deactivate it once cron and delivery have been verified. Full source code and installation steps are on the linked chapter page under “Testing Cron and Outgoing Email.”

---

## Chapter 6 — Automate site backups to Amazon S3

**Source chapter:** [Automated Backups to Amazon S3](https://spinupwp.com/backup-wordpress-amazon-glacier/)

The source distinguishes provider-level full-server backups/snapshots from per-site backups. A per-site backup includes the site database and **all** files, not only uploads.

### 1. Create the backup directory and script

```bash
cd /home/abe/globex.turnipjuice.media
mkdir backups
nano backup.sh
```

Use the chapter’s script, replacing only the home path or site layout if yours differs:

```bash
#!/bin/bash

NOW=$(date +%Y%m%d%H%M%S)
SQL_BACKUP=${NOW}_database.sql
FILES_BACKUP=${NOW}_files.tar.gz

DB_NAME=$(sed -n "s/define( *'DB_NAME', *'\([^']*\)'.*/\1/p" wp-config.php)
DB_USER=$(sed -n "s/define( *'DB_USER', *'\([^']*\)'.*/\1/p" wp-config.php)
DB_PASSWORD=$(sed -n "s/define( *'DB_PASSWORD', *'\([^']*\)'.*/\1/p" wp-config.php)
DB_HOST=$(sed -n "s/define( *'DB_HOST', *'\([^']*\)'.*/\1/p" wp-config.php)

# Backup database
mysqldump --add-drop-table -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" "$DB_NAME" > ../backups/"$SQL_BACKUP"

# Compress the database dump file
gzip ../backups/"$SQL_BACKUP"

# Backup the entire public directory
tar -zcf ../backups/"$FILES_BACKUP" .
```

Make it executable and schedule it. Example: weekly Sunday at 05:00 server time:

```bash
chmod u+x backup.sh
crontab -e
```

```cron
0 5 * * 0 cd /home/abe/globex.turnipjuice.media/public/; /home/abe/globex.turnipjuice.media/backup.sh >/dev/null 2>&1
```

For a daily schedule, the source uses:

```cron
0 5 * * * cd /home/abe/globex.turnipjuice.media/public/; /home/abe/globex.turnipjuice.media/backup.sh >/dev/null 2>&1
```

Set the frequency to fit how often the site’s data changes; the article says weekly may suffice for sites updated infrequently and more frequent runs may suit ecommerce.

### 2. Retain local backups and copy them off-server

The article adds a cleanup line to the script to remove the backup files matching the date one month ago:

```bash
rm -f ../backups/"$(date +%Y%m%d --date='1 month ago')"*.gz
```

The chapter creates an S3 bucket in the AWS console, creates an IAM user/access key, installs AWS CLI, and configures it for the bucket’s region:

```bash
sudo snap install aws-cli --classic
aws configure
```

Do not paste access keys into a shared document or shell transcript. The article’s sample keys are illustrative and should not be reused. Add these lines to upload both backups to the selected bucket using Standard-IA:

```bash
aws s3 cp ../backups/"$SQL_BACKUP".gz s3://<YOUR_BUCKET>/ --quiet --storage-class STANDARD_IA
aws s3 cp ../backups/"$FILES_BACKUP" s3://<YOUR_BUCKET>/ --quiet --storage-class STANDARD_IA
```

### 3. Generic script, old-backup cleanup, and S3 lifecycle

The article refactors the script to accept a bucket name argument, checks for the backups directory, uploads only when a bucket argument is passed, and moves the script to `/home/abe/scripts/`. Full refactored script and the AWS console lifecycle-rule steps are in the source chapter. Its example cron line is:

```cron
0 5 * * * cd /home/abe/globex.turnipjuice.media/public/; /home/abe/scripts/backup.sh <YOUR_BUCKET> >/dev/null 2>&1
```

The AWS console example moves current objects to Glacier after 30 days and expires them after one year. The article calls out minimum storage duration and retrieval delays for archival classes; confirm current AWS pricing/retention behavior before choosing a storage class or lifecycle rule.

---

## Chapter 7 — Harden SSH, TLS, and browser security headers

**Source chapter:** [Server Security Hardening for Running WordPress](https://spinupwp.com/hosting-wordpress-yourself-nginx-security-tweaks-woocommerce-caching-auto-server-updates/)

### 1. SSH audit and host keys

The source recommends running a Standard Audit with SSH-Audit, then applying the reported recommendations. Its sample commands remove and recreate host keys and filter weak Diffie-Hellman moduli:

```bash
sudo rm /etc/ssh/ssh_host_*
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
sudo ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
sudo awk '$5 >= 3071' /etc/ssh/moduli | sudo tee /etc/ssh/moduli.safe > /dev/null
sudo mv /etc/ssh/moduli.safe /etc/ssh/moduli
```

The chapter creates `/etc/ssh/sshd_config.d/ssh_hardening.conf`, adds the algorithm directives shown in the linked chapter, then restarts `ssh.service`. The web text available for this guide masks some algorithm strings as email-like placeholders, so I have not reconstructed those values here. Use the linked chapter for that exact block; retain a working recovery session and retest SSH before disconnecting.

### 2. HSTS, TLS, and TLS session cache

In the site’s HTTPS server block, add the HSTS header (the source example includes subdomains):

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";
```

In the `http` block of `/etc/nginx/nginx.conf`, use the chapter’s Mozilla Intermediate TLS settings:

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ecdh_curve X25519:prime256v1:secp384r1;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers off;
ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;
```

The source explicitly says not to enable OCSP stapling for its Let’s Encrypt setup, noting the change in Let’s Encrypt support. Test and reload after edits:

```bash
sudo nginx -t
sudo systemctl reload nginx.service
```

### 3. Browser security headers

The chapter discusses CSP, XSS, clickjacking, MIME sniffing, referrer policy, and permissions policy. The sample directives below are those shown in the chapter; CSP may need adjustment for a site’s external assets. Put them in the site’s HTTPS server block and test the site after applying:

```nginx
add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval';" always;
add_header X-XSS-Protection "0" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=*, camera=(self 'https://example.com'), microphone=()";
```

The source’s sample CSP is a starting point; it may cause browser console errors for assets and needs to be adjusted to actual services the site loads. Scan with SecurityHeaders.com and SSL Labs, then review the source chapter before tightening policy.

```bash
sudo nginx -t
sudo systemctl reload nginx.service
```

---

## Chapter 8 — Migrate WordPress to a new server

**Source chapter:** [Migrating WordPress to a New Ubuntu 24.04 Server on DigitalOcean](https://spinupwp.com/hosting-wordpress-yourself-moving-wordpress-to-a-new-server/)

The chapter recommends a fresh server and testing it before moving DNS. This outline preserves that workflow; adjust source/destination IPs, users, and paths.

### 1. Set up SSH/SCP access and copy site files

On the new server:

```bash
ssh-keygen -t ed25519 -C "<NEW_SERVER_IP_OR_HOSTNAME>"
cat ~/.ssh/id_ed25519.pub
```

Add the public key to the old server’s `~/.ssh/authorized_keys` and verify SSH from new to old. The chapter then uses SCP to copy the site directory; use the source’s command pattern and your actual paths:

```bash
scp -r abe@<OLD_SERVER_IP>:~/globex.turnipjuice.media ~/globex.turnipjuice.media
```

Copy the Nginx site config to the new server, put it in place, assign root ownership, and enable it:

```bash
scp -r abe@<OLD_SERVER_IP>:/etc/nginx/sites-available/globex.turnipjuice.media ~/globex.turnipjuice.media
sudo mv globex.turnipjuice.media /etc/nginx/sites-available
sudo chown root:root /etc/nginx/sites-available/globex.turnipjuice.media
sudo ln -s /etc/nginx/sites-available/globex.turnipjuice.media /etc/nginx/sites-enabled/globex.turnipjuice.media
```

> **Check before running:** The source chapter’s exact file-copy commands should be followed with your actual directory target. Review the resulting file layout and ownership; do not blindly copy the sample path.

### 2. Copy certificates temporarily; test the new site without changing public DNS

The source copies the existing certificate/key to the old user’s home, copies them to the new server, updates the Nginx paths, then validates/reloads:

```bash
# On old server
sudo cp /etc/letsencrypt/live/globex.turnipjuice.media/fullchain.pem ~/
sudo cp /etc/letsencrypt/live/globex.turnipjuice.media/privkey.pem ~/
sudo chown abe *.pem

# From new server
scp abe@<OLD_SERVER_IP>:~/*.pem ~/
sudo nano /etc/nginx/sites-available/globex.turnipjuice.media
```

Temporarily point the `ssl_certificate` and `ssl_certificate_key` directives to the copied files, then:

```bash
sudo nginx -t
sudo systemctl reload nginx.service
```

On your local workstation, temporarily add the new server IP/domain mapping to the hosts file to test against the new server while public DNS still points to the old one:

```text
<NEW_SERVER_IP>    globex.turnipjuice.media
```

The source notes that after local DNS spoofing, SSH by hostname may route to the new server; use each server’s IP address until migration is complete.

### 3. Create/import database and test

Create a database/user on the new server as in Chapter 3. Export from the old server, copy the dump, import on the new server, and update `wp-config.php` if credentials differ:

```bash
# On new server, create database/user first
mysql -u root -p
```

```sql
CREATE DATABASE globex CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;
CREATE USER 'globex'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON globex.* TO 'globex'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

```bash
# On old server
mysqldump --add-drop-table -u <DB_USER> -p <DB_NAME> > ~/export.sql

# On new server
scp abe@<OLD_SERVER_IP>:~/export.sql ~/
mysql -u <DB_USER> -p <DB_NAME> < export.sql
```

Test the site through the local hosts-file override before switching public DNS.

### 4. Final sync and DNS switch with a write freeze

For a busy site, the source’s minimum-downtime sequence is: show a “Back Soon” page on the old site, export/import the database again, then switch DNS. It edits the old Nginx `index` directive to:

```nginx
index index.html index.php;
```

Place the maintenance `index.html` in the web root, reload Nginx, verify visitors see it, then perform a final database export/import. After verifying the new copy, change the DNS A records to the new server. The guide recommends lowering DNS TTL in advance if it is high; its example uses 300 seconds.

After the switch, issue a new Let’s Encrypt certificate on the new server and complete the cron and backup setup from Chapters 5 and 6. Confirm the new server is serving the site before retiring the old server.

---

## Chapter 9 — Monitor and maintain the server

**Source chapter:** [Monitoring Your Ubuntu 24.04 Server and Keeping WordPress Secure and Performant](https://spinupwp.com/hosting-wordpress-yourself-server-maintenance/)

### 1. Monitoring and alerts

Enable DigitalOcean monitoring during Droplet creation or install its metrics agent. In the Droplet’s **Monitoring** tab, create alert policies for CPU, memory, and disk utilization; the source’s starting example is 80%.

Investigate alerts over SSH:

```bash
ssh abe@pluto.turnipjuice.media
htop
```

Use `htop` to inspect memory processes; press `F6` to change the sort column when investigating CPU load.

### 2. Logs, persistent WordPress debug log, and rotation

The chapter describes watching Nginx/PHP/WordPress logs and sending them to a log service. For a persistent WordPress debug log outside the public web root, it gives these `wp-config.php` settings:

```php
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_DISPLAY', false );
define( 'WP_DEBUG_LOG', '/home/abe/globex.turnipjuice.media/logs/debug.log' );
```

Deny access to sensitive file extensions in the site’s Nginx server block:

```nginx
location ~\.(ini|log|conf)$ {
    deny all;
}
```

Create `/etc/logrotate.d/globex.turnipjuice.media`:

```bash
sudo nano /etc/logrotate.d/globex.turnipjuice.media
```

```text
/home/abe/globex.turnipjuice.media/logs/*.log {
    daily
    rotate 14
    size 1M
    compress
    missingok
    notifempty
    dateext
    create 0664 abe abe
    sharedscripts
    postrotate
        if [ -f /run/nginx.pid ]; then
            kill -USR1 `cat /run/nginx.pid`
        fi
    endscript
}
```

### 3. Software updates and PHP upgrades

Security updates are configured to apply daily in Chapter 1. For general package updates, the guide says to create a full provider snapshot first, then run:

```bash
sudo apt update
sudo apt dist-upgrade
```

For a major PHP upgrade, the article demonstrates installing PHP 8.4 packages side by side via the Ondřej Surý PPA, configuring PHP as in Chapter 2, then changing each site’s `fastcgi_pass` to the new FPM socket. Test/reload Nginx and verify WordPress Site Health before repeating for every site:

```bash
sudo apt update
sudo apt install php8.4-fpm php8.4-common php8.4-mysql \
  php8.4-xml php8.4-intl php8.4-curl php8.4-gd \
  php8.4-imagick php8.4-cli php8.4-dev php8.4-imap \
  php8.4-mbstring php8.4-opcache php8.4-redis \
  php8.4-soap php8.4-zip -y
sudo nano /etc/nginx/sites-available/globex.turnipjuice.media
```

```nginx
location ~ \.php$ {
    try_files $uri =404;
    fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
}
```

```bash
sudo nginx -t
sudo systemctl reload nginx.service
```

The source recommends staging and testing critical paths before changing production sites. It advises building a fresh server and migrating rather than upgrading a live Ubuntu OS in place.

---

## Chapter 10 — Use the complete Nginx configuration kit

**Source chapter:** [Complete Nginx Configuration Kit for WordPress](https://spinupwp.com/hosting-wordpress-yourself-complete-nginx-configuration/)

The kit includes examples for a single HTTPS site, single site with FastCGI cache, and WordPress multisite using subdomains or subdirectories. It combines prior chapter directives and includes inline documentation. The source offers a downloadable kit on the chapter page.

The chapter’s usage sequence is:

1. Back up the existing Nginx directory.
2. Copy an example from the kit’s `sites-available` to a domain-specific config.
3. Edit server name/paths, create referenced directories, and ensure required access/permissions.
4. Symlink the site into `sites-enabled`.
5. Test Nginx and reload.

Commands shown in the article:

```bash
sudo mv /etc/nginx /etc/nginx.backup
sudo cp /etc/nginx/sites-available/single-site.com /etc/nginx/sites-available/yourdomain.com
sudo nano /etc/nginx/sites-available/yourdomain.com
sudo ln -s /etc/nginx/sites-available/yourdomain.com /etc/nginx/sites-enabled/yourdomain.com
sudo nginx -t
sudo systemctl reload nginx.service
```

The `cp` command assumes the kit’s files have already been placed under `/etc/nginx`. Inspect the kit and the active Nginx layout before replacing a working configuration. The final chapter contains the complete configurations; use the source download rather than reconstructing the unshown files from this abbreviated cheat sheet.

---

## Quick verification commands

These commands recur throughout the source guide for checking services and configuration:

```bash
sudo nginx -t
sudo systemctl status fail2ban.service
sudo ufw status verbose
sudo certbot renew --dry-run
htop
```

For Nginx edits, run `sudo nginx -t` before reloading/restarting. For SSH edits, keep a session open and test a new login before closing it. For backups, the guide’s procedure should be paired with a restore test as part of your own recovery checks; the linked article itself focuses on creating and off-site storing the backups.

## Source guide

- Main guide and chapter index: [How to Install WordPress on Ubuntu 24.04 and Speed Up Your Sites](https://spinupwp.com/install-wordpress-ubuntu/)
- Chapters 1–10 are linked above at the start of each chapter section.

**Version note:** The cited guide is specifically an Ubuntu 24.04 guide. It names PHP 8.4 and MySQL 8.4 in its current chapter titles, but package availability, repository instructions, and provider screens can change. Recheck the source chapter at execution time. This document does not silently substitute Ubuntu 26.04 or different package versions.
