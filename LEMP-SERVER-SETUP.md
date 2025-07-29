# LEMP Server Setup

## Set Up and Secure a VPS

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

Ensure that the security origin is allowed and that all others are removed or commented out. It should look like this (no change needed by default):

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

Save the file using **CTRL + X** and then **Y**.

```
Unattended-Upgrade::Automatic-Reboot "false";
```
```
nano /etc/apt/apt.conf.d/20auto-upgrades
```

```
APT::Periodic::Unattended-Upgrade "1";
```
```
service unattended-upgrades restart
```
