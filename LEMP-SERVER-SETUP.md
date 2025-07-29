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
Now you can try visiting the domain name pointing to your server’s IP address in your browser and you should see an Nginx welcome page. Make sure to type in http:// as browsers default to https:// now and that won’t work as we have yet to set up SSL.

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























