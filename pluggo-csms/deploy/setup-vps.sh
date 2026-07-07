#!/usr/bin/env bash
#
# Pluggo CSMS — initial VPS setup script
#
# Draai dit op een verse Ubuntu 22.04 of 24.04 Hetzner CX22 (of gelijkwaardig)
# ALS ROOT. Idempotent: veilig om vaker te draaien.
#
# Wat dit doet:
#   1. apt update + upgrade
#   2. Installeer Node.js 22, nginx, ufw, certbot, git, curl
#   3. Maak non-root 'pluggo' user aan (draait de service)
#   4. Maak 'deploy' user aan (voor code-updates via git pull)
#   5. Configureer ufw firewall: 22, 80, 443 open, rest dicht
#   6. Bereid /opt/pluggo-csms voor
#   7. Zet unattended-upgrades aan voor security patches
#
# Bewust NIET wat dit doet:
#   - Nginx configureren  (aparte stap na code-upload)
#   - TLS-cert regelen    (aparte stap met certbot)
#   - .env aanmaken       (bevat secrets — handmatig)
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Dit script moet als root draaien." >&2
  exit 1
fi

echo "==> [1/7] apt update + upgrade"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "==> [2/7] Installeer Node.js 22 + system packages"
if ! command -v node >/dev/null || ! node --version | grep -q "^v2[2-9]\."; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi
apt-get install -y \
  nginx \
  ufw \
  certbot \
  python3-certbot-nginx \
  git \
  curl \
  fail2ban \
  unattended-upgrades

echo "==> [3/7] User 'pluggo' aanmaken (draait de service)"
if ! id pluggo >/dev/null 2>&1; then
  useradd --system --create-home --shell /usr/sbin/nologin pluggo
fi

echo "==> [4/7] User 'deploy' aanmaken (voor code-updates)"
if ! id deploy >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash deploy
  # Kopieer root's authorized_keys zodat je met dezelfde SSH-key kan inloggen
  mkdir -p /home/deploy/.ssh
  if [[ -f /root/.ssh/authorized_keys ]]; then
    cp /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
    chown -R deploy:deploy /home/deploy/.ssh
    chmod 700 /home/deploy/.ssh
    chmod 600 /home/deploy/.ssh/authorized_keys
  fi
  # Geef deploy sudo-recht om als pluggo te draaien + service te herstarten
  cat > /etc/sudoers.d/deploy <<'EOF'
deploy ALL=(pluggo) NOPASSWD: ALL
deploy ALL=(root) NOPASSWD: /bin/systemctl restart pluggo-csms, /bin/systemctl status pluggo-csms, /bin/systemctl reload nginx, /usr/bin/journalctl -u pluggo-csms *
EOF
  chmod 440 /etc/sudoers.d/deploy
fi

echo "==> [5/7] Firewall configureren (ufw)"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment 'SSH'
ufw allow 80/tcp   comment 'HTTP (Let''s Encrypt renewal + redirect)'
ufw allow 443/tcp  comment 'HTTPS + WSS (paal + api)'
ufw --force enable
ufw status verbose

echo "==> [6/7] /opt/pluggo-csms voorbereiden"
mkdir -p /opt/pluggo-csms
chown pluggo:pluggo /opt/pluggo-csms
chmod 755 /opt/pluggo-csms

echo "==> [7/7] Automatische security updates"
dpkg-reconfigure -f noninteractive unattended-upgrades || true
systemctl enable --now unattended-upgrades

echo ""
echo "======================================================================"
echo " VPS bootstrap compleet."
echo ""
echo " Node.js:  $(node --version)"
echo " npm:      $(npm --version)"
echo " nginx:    $(nginx -v 2>&1)"
echo " certbot:  $(certbot --version)"
echo ""
echo " Users:"
echo "   pluggo — draait de service, geen shell login"
echo "   deploy — voor code-updates, sudo naar pluggo en systemctl restart"
echo ""
echo " Volgende stappen (zie deploy/README.md):"
echo "   1. Log in als 'deploy@<VPS_IP>' (SSH-key uit root/.ssh is gekopieerd)"
echo "   2. Clone repo naar /opt/pluggo-csms"
echo "   3. npm ci --omit=dev"
echo "   4. .env aanmaken met Supabase + CSMS_API_KEY"
echo "   5. Install systemd service"
echo "   6. Install nginx config"
echo "   7. certbot --nginx -d csms.pluggo.app"
echo "======================================================================"
