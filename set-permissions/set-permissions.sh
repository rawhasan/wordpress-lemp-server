#!/bin/bash

# === Detect current user ===
CURRENT_USER=$(whoami)

# === Input domain name ===
read -p "Enter the domain name (e.g., example.com): " DOMAIN

# === Base path ===
SITE_ROOT="/sites/$DOMAIN"

if [ ! -d "$SITE_ROOT" ]; then
    echo "❌ Directory $SITE_ROOT does not exist."
    exit 1
fi

echo "🔧 Applying permissions to $SITE_ROOT as user $CURRENT_USER..."

# === Set ownership: current user + www-data group ===
chown -R "$CURRENT_USER:www-data" "$SITE_ROOT"

# === Set base permissions ===
find "$SITE_ROOT" -type d -exec chmod 750 {} \;
find "$SITE_ROOT" -type f -exec chmod 640 {} \;

# === Special case: wp-content/uploads ===
UPLOADS="$SITE_ROOT/public/wp-content/uploads"
if [ -d "$UPLOADS" ]; then
    echo "📂 Making uploads directory writable: $UPLOADS"
    chmod -R 775 "$UPLOADS"
else
    echo "⚠️ Uploads directory not found at $UPLOADS"
fi

echo "✅ Ownership and permissions set for $DOMAIN"
