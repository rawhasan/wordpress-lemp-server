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
usermod -a -G sudo abe
```

Now ensure your new account is working by logging out of your current SSH session and initiating a new one:

```
logout
```

Then login with the new account:

```
ssh USERNAME@SERVER_IP
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























