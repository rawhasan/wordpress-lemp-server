#!/bin/bash

# Exit on error
set -e

# --- Ensure running as root ---
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run with sudo or as root."
  exit 1
fi

# --- Get input ---
echo "=== WordPress User Switch Script ==="
read -p "Enter PHP version (e.g. 8.3): " PHP_VERSION
read -p "Enter domain name (e.g. bangladesh-travel-assistance.com): " DOMAIN

# --- Variables ---
USER=$(logname)
POOL_CONF="/etc/php/$PHP_VERSION/fpm/pool.d/www.conf"
SOCKET_PATH="/run/php/php$PHP_VERSION-fpm.sock"
SITE_PATH="/sites/$DOMAIN"
BACKUP_CONF="$POOL_CONF.bak"

# --- Logging function ---
log() {
  echo "$1"
}

log "Using user: $USER"
log "PHP-FPM config: $POOL_CONF"
log "Site path: $SITE_PATH"
log "Socket path: $SOCKET_PATH"

# --- Validate ---
if [[ ! -f "$POOL_CONF" ]]; then
  log "❌ PHP-FPM config not found: $POOL_CONF"
  exit 1
fi
if [[ ! -d "$SITE_PATH" ]]; then
  log "❌ Site path not found: $SITE_PATH"
  exit 1
fi

# --- Dry run output ---
log "🔍 Dry run preview (no changes applied yet):"
log "Would update user and group in $POOL_CONF to: $USER"
log "Would set socket owner/group/mode to: $USER/$USER/0660"
log "Would change ownership of $SITE_PATH to $USER"
log "Would set permissions to 755 (dirs) and 644 (files)"
log "Would add www-data to group: $USER"
log "Would restart php$PHP_VERSION-fpm and nginx"

echo
read -p "Apply these changes? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  log "❌ Operation cancelled. No changes made."
  exit 0
fi

# --- Backup original config ---
cp "$POOL_CONF" "$BACKUP_CONF"
log "🔄 Backed up pool config to $BACKUP_CONF"

# --- Trap for rollback on failure ---
rollback() {
  log "⚠️  An error occurred. Rolling back..."
  if [[ -f "$BACKUP_CONF" ]]; then
    cp "$BACKUP_CONF" "$POOL_CONF"
    systemctl restart php"$PHP_VERSION"-fpm
    log "✅ Rolled back to original config and restarted PHP-FPM."
  fi
  exit 1
}
trap rollback ERR

# --- Update PHP-FPM pool configuration ---
sed -i "s/^user = .*/user = $USER/" "$POOL_CONF"
sed -i "s/^group = .*/group = $USER/" "$POOL_CONF"
sed -i "s|^listen = .*|listen = $SOCKET_PATH|" "$POOL_CONF"
sed -i "/^listen.owner =/d" "$POOL_CONF"
sed -i "/^listen.group =/d" "$POOL_CONF"
sed -i "/^listen.mode =/d" "$POOL_CONF"
tee -a "$POOL_CONF" > /dev/null <<EOF
listen.owner = $USER
listen.group = $USER
listen.mode = 0660
EOF
log "✅ Updated PHP-FPM pool config."

# --- Change ownership of WordPress files ---
chown -R "$USER:$USER" "$SITE_PATH"
log "✅ Changed ownership of $SITE_PATH to $USER."

# --- Set correct permissions ---
find "$SITE_PATH" -type d -exec chmod 755 {} \;
find "$SITE_PATH" -type f -exec chmod 644 {} \;
log "✅ Set directory and file permissions."

# --- Add www-data to user's group ---
usermod -aG "$USER" www-data
log "✅ Added www-data to $USER's group."

# --- Restart services ---
systemctl restart php"$PHP_VERSION"-fpm
systemctl restart nginx
log "✅ Restarted PHP-FPM and Nginx."

log "🎉 Switched WordPress site at $SITE_PATH to run as user: $USER"
