#!/bin/bash
# fix-wp-perms-interactive.sh
# Interactive WordPress permission/ownership fixer (one site at a time)
#
# Model:
#   Owner  = current SSH user
#   Group  = www-data (PHP-FPM/nginx)
#   Global (except wp-content): dirs 750, files 640
#   wp-content subtree: dirs 2775 (setgid), files 664
#   Ensures common writable subdirs exist: uploads, cache, upgrade, wflogs
#   Optional ACLs if setfacl is available (keeps new files group-writable)

set -euo pipefail

# --- Defaults ---
OWNER="${USER}"
GROUP="www-data"
SITES_DIR="/sites"
TREE_DEPTH=1
USE_ACL=true

info()  { echo -e "➤ $*"; }
ok()    { echo -e "✅ $*"; }
warn()  { echo -e "⚠️  $*"; }
err()   { echo -e "❌ $*" >&2; }

# --- Safety checks ---
if [[ "$(whoami)" == "root" ]]; then
  err "Do NOT run as root. Use your regular SSH user with sudo."
  exit 1
fi
command -v sudo >/dev/null 2>&1 || { err "sudo is required."; exit 1; }

if ! id -nG "$OWNER" | grep -qw "$GROUP"; then
  warn "$OWNER is not in the '$GROUP' group. Consider: sudo usermod -aG $GROUP $OWNER && newgrp $GROUP"
fi

# --- Core permission function ---
apply_perms() {
  local domain="$1"
  local ROOT="$SITES_DIR/$domain"
  local PUBLIC="$ROOT/public"
  local WPC="$PUBLIC/wp-content"
  local SITE_CACHE="$ROOT/cache"

  if [[ ! -d "$ROOT" ]]; then err "[$domain] $ROOT not found."; return 1; fi
  if [[ ! -d "$WPC"  ]]; then err "[$domain] $WPC not found.";  return 1; fi

  info "[$domain] Setting ownership $OWNER:$GROUP (sudo)…"
  sudo chown -R "$OWNER:$GROUP" "$ROOT"

  info "[$domain] Baseline perms (exclude wp-content): dirs 750, files 640…"
  find "$PUBLIC" -path "$WPC" -prune -o -type d -exec chmod 750 {} +
  find "$PUBLIC" -path "$WPC" -prune -o -type f -exec chmod 640 {} +

  info "[$domain] wp-content perms: dirs 2775 (g+s), files 664…"
  find "$WPC" -type d -exec chmod 2775 {} +
  find "$WPC" -type f -exec chmod 664 {} +
  chmod g+s "$WPC" || true

  # Ensure common subdirs
  for d in uploads cache upgrade wflogs; do
    sudo install -d -m 2775 -o "$OWNER" -g "$GROUP" "$WPC/$d"
  done

  # Optional ACLs keep group-writable for new files
  if $USE_ACL && command -v setfacl >/dev/null 2>&1; then
    info "[$domain] Applying default ACLs for group '$GROUP' on wp-content (sudo)…"
    sudo setfacl -R -m g:"$GROUP":rwx -m d:g:"$GROUP":rwx "$WPC" || true
  fi

  # Site-level cache (if exists)
  if [[ -d "$SITE_CACHE" ]]; then
    info "[$domain] Making $SITE_CACHE writable (dirs 2775; files 664)…"
    find "$SITE_CACHE" -type d -exec chmod 2775 {} +
    find "$SITE_CACHE" -type f -exec chmod 664 {} +
  fi

  # Harden wp-config.php
  if [[ -f "$PUBLIC/wp-config.php" ]]; then
    chmod 640 "$PUBLIC/wp-config.php"
  fi

  ok "[$domain] Permissions applied."

  # Summary tree (depth = $TREE_DEPTH)
  echo
  echo "📁 [$domain] Summary (depth=$TREE_DEPTH) under: $ROOT"
  (
    cd "$ROOT"
    for top in */; do
      echo ""
      echo "🔹 ${top%/}/"
      find "$top" -maxdepth "$TREE_DEPTH" -print0 | while IFS= read -r -d '' item; do
        perms=$(stat -c '%a' "$item")
        owner=$(stat -c '%U' "$item")
        group=$(stat -c '%G' "$item")
        relpath="${item#./}"
        indent=$(echo "$relpath" | sed -e 's|[^/][^/]*/|│   |g' -e 's|│   \([^│]*\)$|└── \1|')
        printf "%s [%s %s:%s]\n" "$indent" "$perms" "$owner" "$group"
      done
    done
  )
  echo

  # Quick write test as PHP-FPM user/group
  if sudo -u "$GROUP" bash -lc "touch '$WPC/test-write' 2>/dev/null"; then
    rm -f "$WPC/test-write"
    ok "[$domain] Write test as $GROUP: OK"
  else
    warn "[$domain] Write test as $GROUP failed. Check PHP-FPM pool user/group."
  fi
}

# --- Discovery loop (one site at a time) ---
while true; do
  # Discover candidate sites: /sites/<domain>/public/wp-content
  mapfile -t DOMAINS < <(
    find "$SITES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | while read -r d; do
        [[ -d "$d/public/wp-content" ]] && basename "$d"
      done \
    | sort
  )

  if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    err "No WordPress sites found under $SITES_DIR (expected /sites/<domain>/public/wp-content)."
    exit 1
  fi

  echo
  echo "Detected WordPress sites in $SITES_DIR:"
  for i in "${!DOMAINS[@]}"; do
    printf "  [%d] %s\n" "$((i+1))" "${DOMAINS[$i]}"
  done
  echo "  [q] Quit"
  echo

  read -r -p "Select a site to fix (number), or 'q' to exit: " choice
  if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
    echo "Bye."
    exit 0
  fi

  # Validate numeric choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    warn "Invalid input. Please enter a number from the list."
    continue
  fi
  idx=$((choice-1))
  if (( idx < 0 || idx >= ${#DOMAINS[@]} )); then
    warn "Out of range. Try again."
    continue
  fi

  domain="${DOMAINS[$idx]}"
  echo
  read -r -p "Proceed to fix permissions for '$domain'? [y/N]: " yn
  if [[ ! "$yn" =~ ^[Yy]$ ]]; then
    echo "Skipped '$domain'."
  else
    apply_perms "$domain" || warn "Failed to apply perms for $domain."
  fi

  echo
  read -r -p "Fix another site? [y/N]: " again
  [[ "$again" =~ ^[Yy]$ ]] || { echo "Done."; exit 0; }
done
