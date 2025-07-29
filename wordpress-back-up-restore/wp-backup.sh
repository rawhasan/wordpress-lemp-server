#!/bin/bash

# === CONFIGURATION ===
SITE_NAME="example.com"  # Change only this

# === DERIVED PATHS ===
WP_PATH="/sites/${SITE_NAME}/public"
BACKUP_DIR="/sites/${SITE_NAME}/backups"
DB_HOST="localhost"
WPCONFIG_PATH="${WP_PATH}/wp-config.php"

# === EXTRACT DB CREDENTIALS FROM wp-config.php ===
DB_NAME=$(grep -oP "define\s*\(\s*'DB_NAME'\s*,\s*'\K[^']+" "$WPCONFIG_PATH")
DB_USER=$(grep -oP "define\s*\(\s*'DB_USER'\s*,\s*'\K[^']+" "$WPCONFIG_PATH")
DB_PASS=$(grep -oP "define\s*\(\s*'DB_PASSWORD'\s*,\s*'\K[^']+" "$WPCONFIG_PATH")

# === VALIDATION ===
if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
  echo "❌ Failed to extract database credentials from wp-config.php"
  exit 1
fi

# === TIMESTAMP FORMATTING ===
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")
BACKUP_NAME="${SITE_NAME}-wp-${TIMESTAMP}"
TEMP_DIR="/tmp/${BACKUP_NAME}_backup"
ARCHIVE_PATH="$BACKUP_DIR/$BACKUP_NAME.tar.gz"

# === PREPARE TEMP DIR ===
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# === BACKUP wp-content ===
echo "📦 Backing up wp-content..."
tar -czf "$TEMP_DIR/${SITE_NAME}-wp-content-${TIMESTAMP}.tar.gz" -C "$WP_PATH" wp-content

# === BACKUP DATABASE ===
echo "🛢️ Backing up MySQL database..."
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$TEMP_DIR/${SITE_NAME}-db-${TIMESTAMP}.sql"

# === CREATE FINAL ARCHIVE ===
echo "🗜️ Creating final archive: $ARCHIVE_PATH"
mkdir -p "$BACKUP_DIR"
tar -czf "$ARCHIVE_PATH" -C "$TEMP_DIR" .

# === CLEAN UP ===
rm -rf "$TEMP_DIR"

# === DONE ===
echo "✅ Backup created: $ARCHIVE_PATH"
