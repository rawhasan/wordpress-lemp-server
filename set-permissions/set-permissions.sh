#!/bin/bash

# === Detect current user ===
CURRENT_USER=$(whoami)

# === Input domain name ===
read -p "Enter the domain name (e.g., example.com): " DOMAIN

# === Base path ===
SITE_ROOT="/sites/$DOMAIN"

# === Validate site path ===
if [ ! -d "$SITE_ROOT" ]; then
    echo "❌ Directory $SITE_ROOT does not exist."
    exit 1
fi

echo "🔧 Applying ownership and permissions to $SITE_ROOT as user '$CURRENT_USER'..."

# === Set ownership to current user and www-data group ===
chown -R "$CURRENT_USER:www-data" "$SITE_ROOT"

# === Set general permissions ===
# Directories: 750
find "$SITE_ROOT" -type d -exec chmod 750 {} \;

# Files: 640
find "$SITE_ROOT" -type f -exec chmod 640 {} \;

# === Special writable directories ===
WRITABLE_DIRS=(
  "public/wp-content/uploads"
  "cache"
)

for REL_PATH in "${WRITABLE_DIRS[@]}"; do
  TARGET="$SITE_ROOT/$REL_PATH"
  if [ -d "$TARGET" ]; then
    echo "📂 Making writable: $TARGET"
    chmod -R 775 "$TARGET"
  else
    echo "⚠️ Not found: $TARGET"
  fi
done

echo "✅ Permissions successfully set for $DOMAIN"
