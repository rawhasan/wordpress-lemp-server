# Fix Unwanted Default-Server Traffic in Nginx (LEMP)

A reusable guide for Ubuntu servers running Nginx, PHP-FPM, and WordPress or other web applications.

## The problem

When Nginx has no explicit `default_server` for a listening address and port, it uses the **first server block** for that address and port as the default. Requests for unknown hostnames or direct IP addresses may therefore be processed by a real website's virtual host. Depending on its rules, the response may be a redirect, a website page, or an application response.

The objective is to reject unmatched hostnames **before they are passed to a production application's server block**, while preserving valid domain traffic.

> **Scope:** The configuration below covers TCP HTTP (port 80) and TLS HTTPS (port 443), including HTTP/1.1 and HTTP/2. **HTTP/3/QUIC uses UDP 443 and requires a separate check.** The fix does not stop requests addressed to your legitimate domain, and it is not a replacement for a firewall, CDN/WAF, or application security.

## Prerequisites

- Ubuntu with Nginx installed and a working production website.
- A sudo-enabled administrator account.
- A working certificate and key readable by Nginx (for the TLS catch-all block).
- Shell access to the server.

In this guide, replace `example.com` with your actual domain. Paths and listening directives must match your own Nginx installation.

## 1. Diagnose the default virtual hosts

```bash
sudo nginx -t
sudo nginx -T 2>/dev/null | grep -nE 'listen .*default_server|listen .*443|listen .*80|server_name'
ls -la /etc/nginx/sites-enabled/
```

Look for `default_server` on both `80` and `443 ssl`, for IPv4 and IPv6 if enabled. No explicit default usually means a normal site is acting as the fallback.

Test unmatched hostnames against **local Nginx** to avoid DNS/CDN interference:

```bash
curl --noproxy '*' -sS \
  --resolve invalid-host.example:80:127.0.0.1 \
  -o /dev/null -w 'HTTP %{http_code}\n' \
  http://invalid-host.example/

curl --noproxy '*' -ksS \
  --resolve invalid-host.example:443:127.0.0.1 \
  -o /dev/null -w 'HTTPS %{http_code}\n' \
  https://invalid-host.example/
```

A `200`, `301`, or `302` is evidence that an unmatched hostname is being handled by some virtual host rather than rejected. This **does not by itself prove** that PHP or WordPress executed.

## 2. Back up the current Nginx configuration

```bash
sudo mkdir -p /root/nginx-config-backups
sudo tar -czf "/root/nginx-config-backups/nginx-before-default-reject-$(date +%Y%m%d-%H%M%S).tar.gz" -C /etc nginx
```

Keep the backup private: it can include sensitive certificate references or configuration values.

## 3. Confirm the existing certificate paths

Find the certificate paths already used by a working HTTPS site:

```bash
sudo nginx -T 2>/dev/null | grep -E '^[[:space:]]*ssl_certificate(_key)?[[:space:]]'
```

Choose a working `ssl_certificate` / `ssl_certificate_key` pair. **Do not copy the example paths blindly.** The default HTTPS server needs a certificate to complete or reject TLS connections under this `ssl` configuration; the certificate does not need to match an unknown hostname because those requests will be rejected.

## 4. Create a dedicated catch-all server

Create a separate configuration file:

```bash
sudo nano /etc/nginx/sites-available/00-default-reject
```

Paste the following, **replacing the two certificate paths** with your verified paths:

```nginx
# Reject HTTP requests that do not match a configured virtual host.
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;
    return 444;
}

# Reject HTTPS requests that do not match a configured virtual host.
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;

    server_name _;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    return 444;
}
```

**Important details:**

- `default_server` on `listen` selects the fallback virtual host. `server_name _;` is just a conventional placeholder, **not** a wildcard mechanism.
- Nginx `444` closes the connection without sending an HTTP response. Curl usually reports `HTTP 000` and a connection-reset/empty-reply error.
- If your Nginx uses other listen addresses (specific IPs, IPv6 disabled, nonstandard ports), adapt the blocks to those address/port combinations.
- If another enabled server already uses `default_server` on the same address and port, remove or reconcile that conflicting declaration **before enabling this file**. Duplicate defaults cause `nginx -t` to fail.
- If your existing TLS server uses special SSL settings or includes, review compatibility rather than changing the production virtual host blindly.

## 5. Enable, validate, and reload

```bash
sudo ln -s /etc/nginx/sites-available/00-default-reject \
  /etc/nginx/sites-enabled/00-default-reject

sudo nginx -t && sudo systemctl reload nginx
```

**Do not reload** if `nginx -t` reports an error. Correct the error or roll back the new symlink first.

## 6. Verify both rejection and normal website traffic

```bash
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

echo '===== REAL WEBSITE DIRECTLY AT ORIGIN ====='
curl --noproxy '*' -ksS \
  --resolve example.com:443:127.0.0.1 \
  -o /dev/null -w 'Website HTTP %{http_code}\n' \
  https://example.com/
```

Expected for the unknown hostnames: `HTTP 000` / `HTTPS 000` with a curl connection-reset or empty-reply message. Expected for the legitimate site: its **normal** response, often `200` (or an intentional redirect). Also check `www.example.com` if it is configured, and verify the public website through your CDN if applicable.

For additional assurance, test direct-IP requests from an external machine and verify they do not serve your website. If IPv6 is enabled, test IPv6 separately.

## 7. HTTP/3 / QUIC: check separately

If your site configuration contains `listen 443 quic;` or `listen [::]:443 quic;`, it accepts HTTP/3 on **UDP** port 443. The TCP catch-all above does **not** establish how unknown hostnames are handled over QUIC.

Check whether your curl supports HTTP/3:

```bash
curl -V
```

If it lists `HTTP3`, test:

```bash
curl --noproxy '*' --http3-only -ksS \
  --resolve invalid-host.example:443:127.0.0.1 \
  --max-time 10 \
  -o /dev/null -w 'HTTP/3 %{http_code}\n' \
  https://invalid-host.example/
```

If HTTP/3 is not supported, use an HTTP/3-capable client or inspect the actual QUIC listener configuration. **Do not add a `listen 443 quic default_server;` directive without checking your Nginx version, QUIC/TLS settings, and current listeners**; validate any changes with `nginx -t` and retest the live site. You can also decide to disable QUIC only after reviewing the impact on your website.

## 8. Roll back safely

If valid requests fail or Nginx reports a configuration problem:

```bash
sudo rm -f /etc/nginx/sites-enabled/00-default-reject
sudo nginx -t && sudo systemctl reload nginx
```

The configuration file remains available under `sites-available` for troubleshooting. The full `/etc/nginx` backup from Step 2 is a further recovery option if other files were changed.

## 9. Understand what this does not fix

- **Bot probes using the real domain** still reach the website's virtual host and need appropriate WAF, rate limits, access rules, or application security.
- An access log showing requests for `/.env`, `/.git`, or `/wp-login.php` does not prove default-host routing; the normal log format may not include the HTTP `Host` header.
- If Nginx is behind Cloudflare or another proxy, the edge may accept or rewrite hostnames before traffic reaches the origin. Test both **origin behavior** and **edge behavior** when relevant.
- A TLS handshake can happen before Nginx processes the HTTP request. A `444` response is an HTTP-level rejection, not necessarily a pre-handshake TLS rejection.

## Verification checklist

- [ ] Nginx syntax test passes.
- [ ] One explicit default HTTP server exists for each relevant listen address.
- [ ] One explicit default HTTPS server exists for each relevant listen address.
- [ ] Unknown HTTP hostname is rejected.
- [ ] Unknown HTTPS hostname is rejected.
- [ ] Direct-IP requests do not expose the site.
- [ ] Legitimate apex and `www` domains still work.
- [ ] CDN/proxy requests still work, if applicable.
- [ ] HTTP/3/QUIC has been checked separately if enabled.
- [ ] Rollback instructions and original configuration backup are retained.

## Example of a verified result

In one Ubuntu/Nginx deployment, unmatched hostnames initially returned HTTP `301` over both HTTP and HTTPS. After adding the TCP catch-all blocks above, the tests returned `000` with a connection-reset message for both unknown hostnames, while the legitimate site returned `200`. This confirms the **TCP HTTP/HTTPS** default-host issue was corrected; HTTP/3 remained a separate verification item.
