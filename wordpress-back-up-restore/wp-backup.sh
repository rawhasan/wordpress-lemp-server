#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
SITE_NAME="dev.nijhoom.com"

# === DERIVED PATHS ===
WP_PATH="/sites/${SITE_NAME}/public"
BACKUP_DIR="/sites/${SITE_NAME}/backups"
WPCONFIG_PATH="${WP_PATH}/wp-config.php"

# === VALIDATION ===
if [[ ! -f "$WPCONFIG_PATH" ]]; then
    echo "❌ wp-config.php not found: $WPCONFIG_PATH"
    exit 1
fi

# === EXTRACT DATABASE CREDENTIALS ===
DB_NAME=$(grep -oP "define\s*\(\s*['\"]DB_NAME['\"]\s*,\s*['\"]\K[^'\"]+" "$WPCONFIG_PATH")
DB_USER=$(grep -oP "define\s*\(\s*['\"]DB_USER['\"]\s*,\s*['\"]\K[^'\"]+" "$WPCONFIG_PATH")
DB_PASS=$(grep -oP "define\s*\(\s*['\"]DB_PASSWORD['\"]\s*,\s*['\"]\K[^'\"]+" "$WPCONFIG_PATH")
DB_HOST=$(grep -oP "define\s*\(\s*['\"]DB_HOST['\"]\s*,\s*['\"]\K[^'\"]+" "$WPCONFIG_PATH")

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" || -z "$DB_HOST" ]]; then
    echo "❌ Failed to extract database credentials from wp-config.php"
    exit 1
fi

# === TIMESTAMP ===
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")

BACKUP_NAME="${SITE_NAME}-wp-${TIMESTAMP}"
WP_CONTENT_NAME="${SITE_NAME}-wp-content-${TIMESTAMP}.tar.gz"
DB_NAME_FILE="${SITE_NAME}-db-${TIMESTAMP}.sql"

TEMP_DIR="/tmp/${BACKUP_NAME}_backup"
ARCHIVE_PATH="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# === CLEANUP ON EXIT ===
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# === PREPARE DIRECTORIES ===
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
mkdir -p "$BACKUP_DIR"

# === BACKUP WP-CONTENT ===
echo "📦 Backing up wp-content..."

tar -czf \
    "$TEMP_DIR/$WP_CONTENT_NAME" \
    -C "$WP_PATH" \
    wp-content

echo "✅ wp-content backup completed."

# === BACKUP DATABASE ===
echo "🛢️ Backing up MySQL database..."

mysqldump \
    --host="$DB_HOST" \
    --user="$DB_USER" \
    --password="$DB_PASS" \
    --no-tablespaces \
    --single-transaction \
    --quick \
    "$DB_NAME" \
    > "$TEMP_DIR/$DB_NAME_FILE"

# Make sure the SQL dump isn't empty
if [[ ! -s "$TEMP_DIR/$DB_NAME_FILE" ]]; then
    echo "❌ Database backup is empty."
    exit 1
fi

echo "✅ Database backup completed."

# === CREATE FINAL ARCHIVE ===
echo "🗜️ Creating final archive..."

tar -czf \
    "$ARCHIVE_PATH" \
    -C "$TEMP_DIR" \
    .

# === VERIFY FINAL ARCHIVE ===
if [[ ! -s "$ARCHIVE_PATH" ]]; then
    echo "❌ Final backup archive was not created correctly."
    exit 1
fi

echo ""
echo "✅ Backup completed successfully."
echo "📁 $ARCHIVE_PATH"
