#!/bin/bash

set -euo pipefail

# Prompt for domain name
read -p "Enter domain name (example.com): " DOMAIN

# Ask for backup source
echo "Select backup source:"
echo "1) Pull from old server via SCP"
echo "2) Use a local backup file already on this server"
read -p "Enter option [1 or 2]: " SOURCE_OPTION

# Set common paths
DEST_DIR="/sites/$DOMAIN"
MIGRATE_DIR="$DEST_DIR/migrate"
PUBLIC_DIR="$DEST_DIR/public"
WPCONFIG="$PUBLIC_DIR/wp-config.php"

mkdir -p "$MIGRATE_DIR" "$PUBLIC_DIR"

# Get backup file
if [[ "$SOURCE_OPTION" == "1" ]]; then
  read -p "Enter old server IP address: " OLD_SERVER_IP
  read -p "Enter SSH username on old server: " OLD_SERVER_USER
  read -p "Enter backup filename (e.g. example.com-wp-20250719_1830.tar.gz): " BACKUP_FILENAME
  echo "📦 Pulling backup from old server..."
  scp "${OLD_SERVER_USER}@${OLD_SERVER_IP}:/sites/${DOMAIN}/backups/${BACKUP_FILENAME}" "$MIGRATE_DIR/"
elif [[ "$SOURCE_OPTION" == "2" ]]; then
  read -p "Enter full path to local backup file: " LOCAL_BACKUP_PATH
  BACKUP_FILENAME=$(basename "$LOCAL_BACKUP_PATH")
  cp "$LOCAL_BACKUP_PATH" "$MIGRATE_DIR/"
  echo "📦 Using local backup: $BACKUP_FILENAME"
else
  echo "❌ Invalid option. Exiting."
  exit 1
fi

# Extract backup
echo "📂 Extracting backup..."
tar -xzf "$MIGRATE_DIR/$BACKUP_FILENAME" -C "$MIGRATE_DIR"

# Get DB credentials
if [[ -f "$WPCONFIG" ]]; then
  echo "🔍 Extracting database credentials from wp-config.php..."
  DB_NAME=$(grep DB_NAME "$WPCONFIG" | cut -d \' -f 4)
  DB_USER=$(grep DB_USER "$WPCONFIG" | cut -d \' -f 4)
  DB_PASS=$(grep DB_PASSWORD "$WPCONFIG" | cut -d \' -f 4)
else
  echo "⚠️ wp-config.php not found in $PUBLIC_DIR — please enter DB details manually."
  read -p "Enter MySQL database name: " DB_NAME
  read -p "Enter MySQL database user: " DB_USER
  read -s -p "Enter MySQL database password: " DB_PASS
  echo ""
fi

# Restore database
SQL_FILE=$(find "$MIGRATE_DIR" -name "*-db-*.sql" | head -n 1)
if [[ -f "$SQL_FILE" ]]; then
  echo "🗄️ Restoring database from $SQL_FILE..."
  mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SQL_FILE"
else
  echo "❌ No SQL file matching '*-db-*.sql' found in $MIGRATE_DIR"
  exit 1
fi

# Restore wp-content
WPCONTENT_ARCHIVE=$(find "$MIGRATE_DIR" -name "*-wp-content-*.tar.gz" | head -n 1)
if [[ -f "$WPCONTENT_ARCHIVE" ]]; then
  echo "📂 Extracting wp-content archive..."
  tar -xzf "$WPCONTENT_ARCHIVE" -C "$MIGRATE_DIR"

  echo "♻️ Replacing wp-content directory..."
  rm -rf "$PUBLIC_DIR/wp-content"
  mv "$MIGRATE_DIR/wp-content" "$PUBLIC_DIR/"
else
  echo "❌ wp-content archive matching '*-wp-content-*.tar.gz' not found in $MIGRATE_DIR"
  exit 1
fi

# Cleanup
echo "🧹 Cleaning up temporary files..."
rm -f "$MIGRATE_DIR/$BACKUP_FILENAME"
[ -f "$SQL_FILE" ] && rm -f "$SQL_FILE"
[ -f "$WPCONTENT_ARCHIVE" ] && rm -f "$WPCONTENT_ARCHIVE"
[ -d "$MIGRATE_DIR/wp-content" ] && rm -rf "$MIGRATE_DIR/wp-content"

echo "✅ Restoration completed successfully for $DOMAIN"
