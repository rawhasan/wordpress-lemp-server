#!/bin/bash

# === Detect current user ===
CURRENT_USER=$(whoami)

# === Block script from being run as root ===
if [ "$CURRENT_USER" = "root" ]; then
  echo "❌ Do NOT run this script as root."
  echo "➡️  Please run it as your regular SSH user (e.g., rawhasan)."
  exit 1
fi

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
    echo "⚠️  Not found: $TARGET"
  fi
done

echo ""
echo "✅ Permissions successfully set for $DOMAIN"

# === Final permission tree output (up to 3 levels deep) ===
echo ""
echo "📁 Final tree with numeric permissions (up to 3 levels deep) under: $SITE_ROOT"
echo ""

cd "$SITE_ROOT" || exit 1

# List all first-level subdirectories
for top in */; do
  echo ""
  echo "🔹 ${top%/}/"

  find "$top" -maxdepth 1 -print0 | while IFS= read -r -d '' item; do
    perms=$(stat -c '%a' "$item")
    owner=$(stat -c '%U' "$item")
    group=$(stat -c '%G' "$item")
    relpath="${item#./}"
    indent=$(echo "$relpath" | sed -e 's|[^/][^/]*/|│   |g' -e 's|│   \([^│]*\)$|└── \1|')
    printf "%s [%s %s:%s]\n" "$indent" "$perms" "$owner" "$group"
  done
done
