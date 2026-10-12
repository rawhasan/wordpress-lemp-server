# Fix Nginx Default-Server Traffic (HTTP, HTTPS, and HTTP/3)

Use these **four copy-and-paste steps** on an Ubuntu/Debian Nginx server to reject requests addressed to unknown hostnames or the server IP, while keeping configured websites working. The Nginx-specific `444` response closes the connection without sending an HTTP response.

**Before starting:** Run these commands **on the server** as a sudo-enabled user. The server must already have a working HTTPS website and certificate. These steps assume `/etc/nginx/sites-available/` and `/etc/nginx/sites-enabled/` exist, IPv4/IPv6 listeners are in use, and no other enabled server declares `default_server` on the same ports. **Replace `example.com` once in Step 1.** HTTP/3 directives are added only when existing Nginx configuration already enables QUIC. This is not a firewall or a replacement for a WAF.

## Step 1 — Back up and create the default server

**What it does:** Saves the current reject configuration if present, checks the existing TLS certificate, detects whether HTTP/3 is enabled, and creates a fallback virtual host that rejects unknown requests on HTTP and HTTPS, plus HTTP/3 when already in use.

```bash
# CHANGE THIS DOMAIN to one with a working Let's Encrypt certificate.
DOMAIN="example.com"

CONF="/etc/nginx/sites-available/00-default-reject"
CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

# Stop rather than create an invalid HTTPS listener.
if ! sudo test -r "$CERT" || ! sudo test -r "$KEY"; then
  echo "ERROR: Certificate/key missing or unreadable: $CERT / $KEY"
else
  # Back up any existing reject file before replacing it.
  if sudo test -e "$CONF"; then
    sudo cp -a "$CONF" "${CONF}.bak.$(date +%Y%m%d-%H%M%S)"
  fi

  # Include QUIC only when an existing Nginx site already uses it.
  QUIC_LISTEN=""
  if sudo nginx -T 2>/dev/null | grep -Eq '^[[:space:]]*listen[[:space:]]+[^;]*[[:space:]]quic([[:space:];]|$)'; then
    QUIC_LISTEN='    listen 443 quic default_server;
    listen [::]:443 quic default_server;'
  fi

  sudo tee "$CONF" >/dev/null <<EOF
# Reject requests for unknown hostnames and direct IP traffic.
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 444;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
$QUIC_LISTEN
    server_name _;
    ssl_certificate $CERT;
    ssl_certificate_key $KEY;
    return 444;
}
EOF
  echo "Created $CONF"
fi
```

**Note:** If your certificate is not managed by Let's Encrypt, change `CERT` and `KEY` to the actual paths before running. If your server does not use IPv6, remove the `[::]` `listen` lines. If it listens on specific IP addresses, adapt the `listen` directives accordingly.

## Step 2 — Enable the default server

**What it does:** Activates the catch-all configuration without editing any existing website's server block.

```bash
sudo ln -sfn \
  /etc/nginx/sites-available/00-default-reject \
  /etc/nginx/sites-enabled/00-default-reject
```

## Step 3 — Validate and reload Nginx

**What it does:** Checks for syntax errors or conflicting `default_server` declarations; reloads only when the configuration is valid.

```bash
sudo nginx -t && sudo systemctl reload nginx
```

If validation fails, **do not reload**. Check the error. To disable the new catch-all and return to the previously loaded configuration:

```bash
sudo rm -f /etc/nginx/sites-enabled/00-default-reject
sudo nginx -t && sudo systemctl reload nginx
```

## Step 4 — Verify rejection and legitimate website traffic

**What it does:** Confirms that unknown hostnames are rejected, the legitimate website still responds, and QUIC has a default listener when HTTP/3 is enabled.

```bash
# CHANGE THIS DOMAIN to the same domain used in Step 1.
DOMAIN="example.com"

echo '===== UNKNOWN HTTP HOST ====='
curl --noproxy '*' -sS \
  --resolve invalid-host.example:80:127.0.0.1 \
  -o /dev/null -w 'HTTP %{http_code}\n' \
  http://invalid-host.example/

echo '===== UNKNOWN HTTPS HOST ====='
curl --noproxy '*' -ksS \
  --resolve invalid-host.example:443:127.0.0.1 \
  -o /dev/null -w 'HTTPS %{http_code}\n' \
  https://invalid-host.example/

echo '===== LEGITIMATE WEBSITE ====='
curl --noproxy '*' -ksS \
  --resolve "$DOMAIN:443:127.0.0.1" \
  -o /dev/null -w 'Website HTTP %{http_code}\n' \
  "https://$DOMAIN/"

echo '===== DEFAULT HTTPS / QUIC LISTENERS ====='
sudo nginx -T 2>/dev/null | grep -E \
  'listen .*443.*default_server|listen .*443.*quic'
```

**Expected:** Unknown HTTP and HTTPS requests produce `000`, usually accompanied by `curl: (56) Recv failure: Connection reset by peer` or `Empty reply from server`. The real website returns its normal response, commonly `200` or `301`. On HTTP/3-enabled servers, the output should include `listen 443 quic default_server;` and `listen [::]:443 quic default_server;`.

**HTTP/3 verification:** The configuration check confirms the default QUIC listener exists, **not** that its rejection behavior has been tested. If `curl -V` lists `HTTP3`, test with an HTTP/3-capable curl:

```bash
curl --noproxy '*' --http3-only -ksS \
  --resolve invalid-host.example:443:127.0.0.1 \
  --max-time 10 -o /dev/null \
  -w 'Unknown HTTP/3 host: %{http_code}\n' \
  https://invalid-host.example/
```

If curl lacks `HTTP3`, skip that command and use another HTTP/3-capable client later. Also test your real domain over HTTP/3. **Requests that use your legitimate hostname still reach its website virtual host**, even if they are malicious; this fix only handles unmatched hostnames.
