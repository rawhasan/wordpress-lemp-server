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

Now we can safely run the security script (**Enable unix_socket instead of using root password, Disallow root login remotely**):

```
sudo mysql_secure_installation
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
```

Create the server block in Nginx:

```
cd /etc/nginx/sites-available
```

```
sudo cp single-site-with-caching.com EXAMPLE.COM
```

Replace **EXAMPLE.COM** with the **Domain Name** in the file and Save with **CTRL-X** and **Y**.

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























