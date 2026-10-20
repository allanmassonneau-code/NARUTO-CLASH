#!/usr/bin/env bash
# One-time VPS setup for Naruto Clash (Ubuntu / Debian), run as root:
#
#   sudo bash vps_setup.sh --inventory                 # show what is on the box, change nothing
#   sudo bash vps_setup.sh --deploy-key "ssh-ed25519 AAAA... ci"          # install
#   sudo bash vps_setup.sh --wipe --deploy-key "ssh-ed25519 AAAA... ci"   # clean first, then install
#   sudo bash vps_setup.sh --https ninjabattle.fr      # only add HTTPS (Let's Encrypt) for a domain
#   sudo bash vps_setup.sh --no-auth                   # remove the old password protection of the site
#
# Installs: nginx (serves launcher updates on :80 /naruto-clash/), Godot headless,
# two game servers as systemd services (1v1 on UDP 7777, 2v2 on UDP 7778),
# a `deploy` user for CI (SSH key only, may only restart the game services).
set -euo pipefail

GODOT_VERSION="4.3-stable"
APP=/opt/naruto-clash
WWW=/var/www/naruto-clash
WIPE=0
INVENTORY=0
DEPLOY_KEY=""
DOMAIN=""
NO_AUTH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wipe) WIPE=1 ;;
    --inventory) INVENTORY=1 ;;
    --deploy-key) DEPLOY_KEY="$2"; shift ;;
    --https) DOMAIN="$2"; shift ;;
    --no-auth) NO_AUTH=1 ;;
    *) echo "Unknown option $1"; exit 1 ;;
  esac
  shift
done

[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)."; exit 1; }

inventory() {
  echo "== Running services (non-system) =="
  systemctl list-units --type=service --state=running --no-pager | grep -vE "systemd|dbus|cron|ssh|getty|polkit|udev|journal|rsyslog|networkd|resolved|timesyncd|snapd|unattended|multipathd|qemu|cloud" || true
  echo "== Custom unit files in /etc/systemd/system =="
  find /etc/systemd/system -maxdepth 1 -name "*.service" -type f -printf "%f\n" || true
  if command -v docker >/dev/null; then echo "== Docker containers =="; docker ps -a || true; fi
  if command -v pm2 >/dev/null; then echo "== pm2 =="; pm2 list || true; fi
  for svc in caddy apache2 nginx; do systemctl is-active --quiet "$svc" 2>/dev/null && echo "== $svc is running =="; done
  echo "== nginx sites =="; ls /etc/nginx/sites-enabled 2>/dev/null || echo "(no nginx)"
  echo "== /opt =="; ls -la /opt 2>/dev/null || true
  echo "== /srv =="; ls -la /srv 2>/dev/null || true
  echo "== /var/www =="; ls -la /var/www 2>/dev/null || true
  echo "== Root crontab =="; crontab -l 2>/dev/null || echo "(none)"
  echo "== Listening ports =="; ss -tulpn | head -40
}

wipe() {
  echo "!!! --wipe removes every previous app on this server (Docker, pm2, custom"
  echo "!!! systemd services, nginx sites, /opt, /srv, /var/www, root crontab)."
  echo "!!! SSH access, users and system packages are kept."
  read -r -p "Type WIPE to continue: " answer
  [[ "$answer" == "WIPE" ]] || { echo "Aborted."; exit 1; }
  if command -v docker >/dev/null; then
    docker ps -aq | xargs -r docker rm -f
    docker system prune -af --volumes || true
  fi
  if command -v pm2 >/dev/null; then pm2 delete all || true; pm2 save --force || true; fi
  # Other web servers would keep port 80 busy.
  for svc in caddy apache2 httpd; do
    systemctl disable --now "$svc" 2>/dev/null || true
  done
  rm -rf /etc/caddy 2>/dev/null || true
  for unit in /etc/systemd/system/*.service; do
    [[ -f "$unit" ]] || continue
    name="$(basename "$unit")"
    systemctl disable --now "$name" 2>/dev/null || true
    rm -f "$unit"
  done
  systemctl daemon-reload
  rm -f /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* /etc/nginx/conf.d/*.conf 2>/dev/null || true
  find /opt /srv /var/www -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  crontab -r 2>/dev/null || true
  echo "Wipe done."
}

setup_naruto() {
  [[ -n "$DEPLOY_KEY" ]] || { echo "--deploy-key \"<public key>\" is required."; exit 1; }
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y nginx curl unzip rsync ufw libfontconfig1

  id naruto >/dev/null 2>&1 || useradd --system --home "$APP" --shell /usr/sbin/nologin naruto
  id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy
  install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
  echo "$DEPLOY_KEY" > /home/deploy/.ssh/authorized_keys
  chown deploy:deploy /home/deploy/.ssh/authorized_keys
  chmod 600 /home/deploy/.ssh/authorized_keys

  # CI (deploy) writes the code, the service (naruto) writes its import cache.
  install -d -o deploy -g naruto -m 2775 "$APP/server"
  install -d -o deploy -g deploy "$WWW"
  install -d "$APP/bin"
  if [[ ! -x "$APP/bin/godot" ]]; then
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/godot.zip" "https://github.com/godotengine/godot/releases/download/$GODOT_VERSION/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    unzip -q "$tmp/godot.zip" -d "$tmp"
    install -m 755 "$tmp/Godot_v${GODOT_VERSION}_linux.x86_64" "$APP/bin/godot"
    rm -rf "$tmp"
  fi

  cat > /etc/systemd/system/naruto-server@.service <<UNIT
[Unit]
Description=Ninja Battle game server (%i)
After=network-online.target

[Service]
User=naruto
WorkingDirectory=$APP/server
ExecStartPre=-$APP/bin/godot --headless --path $APP/server --import
ExecStart=$APP/bin/godot --headless --path $APP/server -- --server --mode=%i
Restart=always
RestartSec=5
Environment=HOME=$APP

[Install]
WantedBy=multi-user.target
UNIT
  chown -R naruto:naruto "$APP/bin"
  install -d -o naruto -g naruto "$APP/.local"
  systemctl daemon-reload
  systemctl enable naruto-server@1v1 naruto-server@2v2

  cat > /etc/sudoers.d/naruto-deploy <<SUDO
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart naruto-server@1v1, /usr/bin/systemctl restart naruto-server@2v2, /bin/systemctl restart naruto-server@1v1, /bin/systemctl restart naruto-server@2v2
SUDO
  chmod 440 /etc/sudoers.d/naruto-deploy

  cat > /etc/nginx/sites-available/naruto-clash <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;

    location = / { return 302 /naruto-clash/; }

    location /naruto-clash/ {
        alias $WWW/;
        autoindex off;
        index index.html;
        location ~ version\.json\$ { add_header Cache-Control "no-cache"; }
    }
}
NGINX
  rm -f /etc/nginx/sites-enabled/default  # would clash with our default_server
  ln -sf /etc/nginx/sites-available/naruto-clash /etc/nginx/sites-enabled/naruto-clash
  install -d /var/www/html
  echo "Ninja Battle" > /var/www/html/index.html
  nginx -t
  systemctl reload nginx

  ufw allow OpenSSH
  ufw allow 80/tcp
  ufw allow 7777:7778/udp
  ufw --force enable

  echo
  echo "Setup done. Next: push to GitHub (CI deploys) or run deploy/deploy.sh from a build machine."
  echo "Launcher update URL: http://<this server>/naruto-clash/"
}

# HTTPS for a domain pointing at this box. The plain-HTTP site on the IP
# stays as it is (installed launchers use it); the domain gets a Let's
# Encrypt certificate and redirects HTTP -> HTTPS.
setup_https() {
  local domain="$1"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq certbot >/dev/null
  install -d /var/www/acme
  cat > /etc/nginx/sites-available/ninja-domain <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    location /.well-known/acme-challenge/ { root /var/www/acme; }
    location / { return 301 https://$domain\$request_uri; }
}
NGINX
  ln -sf /etc/nginx/sites-available/ninja-domain /etc/nginx/sites-enabled/ninja-domain
  nginx -t
  systemctl reload nginx
  ufw allow 443/tcp || true
  certbot certonly --webroot -w /var/www/acme -d "$domain" -d "www.$domain" \
    --non-interactive --agree-tos --register-unsafely-without-email --keep-until-expiring
  cat > /etc/nginx/sites-available/ninja-domain-tls <<NGINX
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain www.$domain;
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    root $WWW;
    index index.html;
    location = /naruto-clash { return 301 /naruto-clash/; }
    location /naruto-clash/ {
        alias $WWW/;
        index index.html;
        location ~ version\.json\$ { add_header Cache-Control "no-cache"; }
    }
    location ~ version\.json\$ { add_header Cache-Control "no-cache"; }
}
NGINX
  ln -sf /etc/nginx/sites-available/ninja-domain-tls /etc/nginx/sites-enabled/ninja-domain-tls
  nginx -t
  systemctl reload nginx
  # Renewals (certbot timer) reload nginx to pick up the new certificate.
  install -d /etc/letsencrypt/renewal-hooks/deploy
  printf '#!/bin/sh\nsystemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
  chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
  echo "HTTPS ready: https://$domain/"
}

# The download site is public (its address is simply not shared): removes the
# basic auth an older setup may have installed.
remove_auth() {
  local f
  for f in /etc/nginx/sites-available/naruto-clash /etc/nginx/sites-available/ninja-domain-tls; do
    [[ -f "$f" ]] && sed -i '/include snippets\/ninja-auth\(-root\)\?\.conf;/d' "$f"
  done
  rm -f /etc/nginx/snippets/ninja-auth.conf /etc/nginx/snippets/ninja-auth-root.conf /etc/nginx/ninja.htpasswd
  nginx -t
  systemctl reload nginx
  echo "Download site is public again"
}

if [[ -n "$DOMAIN" ]]; then setup_https "$DOMAIN"; fi
if [[ $NO_AUTH -eq 1 ]]; then remove_auth; fi
if [[ -n "$DOMAIN" || $NO_AUTH -eq 1 ]]; then exit 0; fi
if [[ $INVENTORY -eq 1 ]]; then inventory; exit 0; fi
if [[ $WIPE -eq 1 ]]; then inventory; wipe; fi
setup_naruto
