# LEMP Server Setup

## 1. Set Up and Secure a VPS

### Set the Timezone
```
dpkg-reconfigure tzdata
```

### Install Software Updates
```
apt update
apt dist-upgrade
apt autoremove
```

```
reboot now
```

### Automatic Security Updates

```
apt install unattended-upgrades
```
```
dpkg-reconfigure unattended-upgrades
```

Choose `Yes` and hit **Enter**.

```
nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Ensure that the security origin is allowed and that all others are removed or commented out. It should look like this (**no change needed by default**):

```
// Automatically upgrade packages from these (origin:archive) pairs
//
// Note that in Ubuntu security updates may pull in new dependencies
// from non-security sources (e.g. chromium). By allowing the release
// pocket these get automatically pulled in.
Unattended-Upgrade::Allowed-Origins {
            "${distro_id}:${distro_codename}";
            "${distro_id}:${distro_codename}-security";
            // Extended Security Maintenance; doesn't necessarily exist for
            // every release and this system may not have it installed, but if
            // available, the policy for updates is such that unattended-upgrades
            // should also install from here by default.
            "${distro_id}ESMApps:${distro_codename}-apps-security";
            "${distro_id}ESM:${distro_codename}-infra-security";
//          "${distro_id}:${distro_codename}-updates";
//          "${distro_id}:${distro_codename}-proposed";
//          "${distro_id}:${distro_codename}-backports";
};
```

```
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
```

Save the file using **CTRL + X** and then **Y**.

Finally, set how often the automatic updates should run:

```
nano /etc/apt/apt.conf.d/20auto-upgrades
```

Ensure that `Unattended-Upgrade` is in the list.

```
APT::Periodic::Unattended-Upgrade "1";
```

The number indicates how often the upgrades will be performed in days. A value of 1 will run upgrades every day.

Save the file using **CTRL + X** and then **Y**.  Then restart the service to have the changes take effect:

```
service unattended-upgrades restart
```


### Create a New User

First, create the new user:

```
adduser USERNAME
```

Next, add the new user to the `sudo` group:

```
usermod -a -G sudo USERNAME
```

Now ensure your new account is working by logging out of your current SSH session and initiating a new one:

```
logout
```

Then login with the new account:

```
ssh USERNAME@SERVER_IP
```

### Configure Uncomplicated Firewall

Install Uncomplicated Firewall:

```
sudo apt install ufw
```

Now you can begin adding to the default rules, which deny all incoming traffic and allow all outgoing traffic. For now, add the ports for SSH (22), HTTP (80), and HTTPS (443):

```
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
```

To review which rules will be added to the firewall, enter the following command:

```
sudo ufw show added
```

It will show:

```
Added user rules (see 'ufw status' for running firewall):
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
```

Before enabling the firewall rules, ensure that the port for SSH is in the list of added rules – otherwise, you won’t be able to connect to your server! The default port is 22. If everything looks correct, go ahead and enable the configuration:

```
sudo ufw enable
```

To confirm that the new rules are active, enter the following command:

```
sudo ufw status verbose
```

You will see that all inbound traffic is denied by default except on ports 22, 80, and 443 for both IPv4 and IPv6, which is a good starting point for most servers.

```
abe@pluto.turnipjuice.media:~$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                  
80/tcp                     ALLOW IN    Anywhere                  
443/tcp                    ALLOW IN    Anywhere                  
22/tcp (v6)                ALLOW IN    Anywhere (v6)             
80/tcp (v6)                ALLOW IN    Anywhere (v6)             
443/tcp (v6)               ALLOW IN    Anywhere (v6)             
```


### Install Fail2ban

```
sudo apt install fail2ban
```

The default configuration should suffice, which will ban a host for 10 minutes after 6 unsuccessful login attempts via SSH. To ensure the fail2ban service is running enter the following command:

```
sudo service fail2ban start
```

And to check that it’s running, run the `status` command:

```
sudo service fail2ban status
```
```





```
## 2. Install Nginx, PHP 8.3, WP-CLI, and MariaDB

### Install Nginx

First, add the **Ondřej Surý** repository and update the package lists:

```
sudo add-apt-repository ppa:ondrej/nginx -y
sudo apt update
sudo apt dist-upgrade -y
```

```
sudo apt install nginx -y
```

```
nginx -v
```
Now you can try visiting the domain name pointing to your server’s IP address in your browser and you should see an Nginx welcome page. Make sure to type in `http://` as browsers default to `https://` now and that won’t work as we have yet to set up SSL.


### Copy the Nginx Kit (Enhanced)

Back up the current Nginx configuration:

```
ls -ld n*
sudo mv /etc/nginx /etc/nginx.backup
```

Clone the Nginx-kit-enhanced repository:

```
cd /etc
sudo git clone https://github.com/rawhasan/wordpress-nginx-kit-enhanced.git
```

```
ls -ld w*
sudo mv wordpress-nginx-kit-enhanced nginx
```

```
sudo nginx -t
sudo service nginx restart
```

If it’s not already running, you can start Nginx with:

```
sudo service nginx start
```

Visit the domain name pointing to the server’s IP address in your browser again. It should show **This site can’t be reached**.





### Install PHP 8.3
Just as with Nginx, the official Ubuntu package repository does contain PHP packages. However, they are not the most up-to-date. Again, I use one maintained by **Ondřej Surý** for installing PHP. Add the repository and update the package lists as you did for Nginx:

```
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
```

```
sudo apt install php8.3-fpm php8.3-common php8.3-mysql \
php8.3-xml php8.3-intl php8.3-curl php8.3-gd \
php8.3-imagick php8.3-cli php8.3-dev php8.3-imap \
php8.3-mbstring php8.3-opcache php8.3-redis \
php8.3-soap php8.3-zip -y

```

```
php-fpm8.3 -v
```



### Install WP-CLI

Navigate to your home directory:

```
cd ~/
```

Using cURL, download WP-CLI:

```
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

```

You can then check that it works by issuing:

```
php wp-cli.phar --info
```

The command should output information about your current PHP version and a few other details.

To access the command-line tool by simply typing `wp`, you need to move it into your server’s `PATH` and ensure that it has execute permissions:

```
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
```

You can now access the WP-CLI tool by typing `wp`.





### Install MariaDB

```
sudo apt update
```

```
sudo apt install mariadb-server
```

```
mariadb --version
```

```
sudo systemctl start mariadb
sudo systemctl enable mariadb

```

You can secure MySQL once it’s installed. Luckily, there’s a built-in script that will prompt you to change a few insecure defaults. However, you’ll first need to change the root user’s authentication method, because by default on Ubuntu installations the root user is not configured to connect using a password. Without the change, it will cause the script to fail and lead to a recursive loop which you can only get out of by closing your terminal window.

First, open the MySQL prompt:

```
sudo mysql
```

Next, run the following command to change the root user’s authentication method to the secure caching_sha2_password method and set a password:

```
ALTER USER 'root'@'localhost' IDENTIFIED BY 'YourNewPassword';
```

And then exit the MySQL prompt:

```
exit
```

Test if the root password is working:

```
mysql -u root -p
```

Now we can safely run the security script (**Keep oassword login for root, Disallow root login remotely**):

```
sudo mysql_secure_installation
```

```





```
## 3. Configure Nginx to Serve WordPress Over HTTPS

### Point DNS from Namecheap to the server IP

### Install Certbot

Now let’s install Certbot, the free, open source tool for managing Let’s Encrypt certificates:

```
sudo apt install software-properties-common
sudo add-apt-repository universe
sudo apt update
sudo apt install certbot python3-certbot-nginx
```

### Obtain an SSL Certificate

To obtain a certificate, you can now use the Nginx Certbot plugin, by issuing the following command. The certificate can cover multiple domains (100 maximum) by appending additional `d` flags.

```
sudo certbot --nginx certonly -d EXAMPLE.COM -d www.EXAMPLE.COM
```

After entering your email address and agreeing to the terms and conditions, the Certbot client will generate the requested certificate. Make a note of where the certificate file `fullchain.pem` and key file `privkey.pem` are created, as you will need them later.

```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/EXAMPLE.COM/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/EXAMPLE.COM/privkey.pem
```

Certbot will handle renewing all your certificates automatically, but you can test automatic renewals with the following command:

```
sudo certbot renew --dry-run
```


### Add an Nginx Configuration for the Site

Navigate to your home directory.

```
cd ~/ 
```

Create the required directories and set the correct permissions:

```
sudo mkdir -p /sites/EXAMPLE.COM/public /sites/EXAMPLE.COM/logs /sites/EXAMPLE.COM/backups /sites/EXAMPLE.COM/shells
chmod -R 755 EXAMPLE.COM
sudo chown -R SERVER-USER:SERVER-USER sites
```

Create the server block in Nginx:

```
cd /etc/nginx/sites-available
```

```
sudo cp single-site-with-caching.com EXAMPLE.COM
```

```
sudo nano EXAMPLE.COM
```

Replace **EXAMPLE.COM** with the **Domain Name** in the file and set **PHP-Pool**:

```
fastcgi_pass   php83;
```

Save with **CTRL-X** and **Y**

To enable the newly created site, symlink the file that you just created into the `sites-enabled` directory, using the same filename:

```
sudo ln -s /etc/nginx/sites-available/EXAMPLE.COM /etc/nginx/sites-enabled/EXAMPLE.COM
```

```
sudo nginx -t
```

```
sudo service nginx reload
```



### Create a Database
When hosting multiple sites on a single server, it’s good practice to create a separate database and database user for each individual site. You should also lock down the user privileges so that the user only has access to the databases that they require.

```
mariadb -u root -p
```

```
CREATE DATABASE database-name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;
```

```
CREATE USER 'user-name'@'localhost' IDENTIFIED BY 'password';
```

```
GRANT ALL PRIVILEGES ON database-name.* TO 'user-name'@'localhost';
```

```
FLUSH PRIVILEGES;
exit;
```

Test the database (Should show only one database):

```
mariadb -u user-name -p
show databases;
exit
```




### Install WordPress


```
cd /sites/EXAMPLE.COM/public
```

```
wp core download
```

```
wp core config --dbname=database-name --dbuser=user-name --dbpass='password'
```

```
wp core install --skip-email --url=https://EXAMPLE.COM --title='Site Title' --admin_user=wordpress-user-name --admin_email=email@email.com --admin_password='password'
```

You should now be able to visit the domain name in your browser and be presented with a default WordPress installation.




### Upload the Site Backup

In the local terminal:

```
rsync -a backup-filename-in-local-machine user-name@server-ip-address:/target-directory --progress
```



### Restore the backup

Copy the restore script from **Github** and run it.

Grannt directory ownership to WordPress:

```
sudo chown -R www-data:www-data /sites/EXAMPLE.COM
sudo chown -R SERVER-USER:SERVER-USER /sites/EXAMPLE.COM/shells
```

### Update the WordPress directory permissions

**TO-DO**
```





```
## 4. Configure Redis Object Cache

An object cache stores database query results so that instead of running the query again the next time the results are needed, the results are served from the cache. This greatly improves the performance of WordPress as there is no longer a need to query the database for every piece of data required to return a response.

Redis is an open-source option that is the latest and greatest when it comes to object caching.

To get the latest stable version of Redis, you can use the official Redis package repository. First add the repository with the signing key and update the package lists:

```
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
sudo apt update
```

Then issue the following commands to install the Redis server and restart PHP-FPM:

```
sudo apt install redis-server -y
sudo service php8.3-fpm restart
```

Now let’s make sure that Redis will start when the server is rebooted:

```
sudo systemctl enable redis-server
```

In order for WordPress to use Redis as an object cache, you need to install a Redis object cache plugin. Redis Object Cache by Till Krüss is an excellent choice.

Once installed and activated, go to **Settings > Redis**.

Click the **Enable Object Cache** button.

This is also the screen where you can flush the cache if required.

```





```
## 5. WordPress Cron
Cron should be configured using the operating system daemon (background process), available on Linux and all Unix-based systems. Because cron runs as a daemon it will run based on the server’s system time and no longer requires a user to visit the WordPress site.

Before configuring cron it’s recommended that you disable WordPress from automatically handling cron. Add the following line to your `wp-config.php` file:

```
define('DISABLE_WP_CRON', true);
```

### Set up Crontab
Scheduled tasks on a server are added to a text file called crontab and each line within the file represents one cron event. If you’re hosting multiple sites on your server, you will need one cron job per site and should consider staggering the execution of many cron jobs to avoid running them all at the same time and overwhelming your CPU.

Open the crontab using the following command. If this is the first time you have opened the crontab, you may be asked to select an editor. Nano is usually the easiest.

```
crontab -e
```

Adding the following to the end of the file will trigger WordPress cron every 5 minutes. Remember to update the file path to point to your WordPress installation and to repeat the entry for each site.

```
*/5 * * * * cd /sites/EXAMPLE.COM/public; /usr/local/bin/wp cron event run --due-now >/dev/null 2>&1
```

The >/dev/null 2>&1 part ensures that no emails are sent to the Unix user account initiating the WordPress cron job scheduler.





### Testing Cron and Outgoing Email

In order to test that both cron and outgoing emails are working correctly, I have written a small plugin that will send an email to the admin user every 5 minutes. This isn’t something that you’ll want to keep enabled indefinitely, so once you have established that everything is working correctly, remember to disable the plugin!

Create a new file called `cron-test.php` within your plugins directory, with the following code:


```
<?php
/**
 * Plugin Name: Cron & Email Test
 * Plugin URI: https://spinupwp.com/hosting-wordpress-yourself-cron-email-automatic-backups/
 * Description: WordPress cron and email test.
 * Author: SpinupWP
 * Version: 1.0
 * Author URI: http://spinupwp.com
 */

/**
 * Schedules
 *
 * @param array $schedules
 *
 * @return array
 */
function db_crontest_schedules( $schedules ) {
    $schedules['five_minutes'] = array(
        'interval' => 300,
        'display'  => 'Once Every 5 Minutes',
    );

    return $schedules;
}
add_filter( 'cron_schedules', 'db_crontest_schedules', 10, 1 );

/**
 * Activate
 */
function db_crontest_activate() {
    if ( ! wp_next_scheduled( 'db_crontest' ) ) {
        wp_schedule_event( time(), 'five_minutes', 'db_crontest' );
    }
}
register_activation_hook( __FILE__, 'db_crontest_activate' );

/**
 * Deactivate
 */
function db_crontest_deactivate() {
    wp_unschedule_event( wp_next_scheduled( 'db_crontest' ), 'db_crontest' );
}
register_deactivation_hook( __FILE__, 'db_crontest_deactivate' );

/**
 * Crontest
 */
function db_crontest() {
    wp_mail( get_option( 'admin_email' ), 'Cron Test', 'All good in the hood!' );
}
add_action( 'db_crontest', 'db_crontest' );
```

Upon activating the plugin, you should receive an email shortly after. If not, check your crontab configuration and SMTP Plugin settings.

```

```






```

```


```

```


```

```


```

```


```

```


```

```



```

```


```

```



```

```


```

```



```

```





```

```


```

```


```

```


```

```


```

```


```

```



```

```


```

```



```

```


```

```



```

```























