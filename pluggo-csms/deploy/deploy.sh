#!/usr/bin/env bash
#
# Pluggo CSMS — update deployment
#
# Draai dit ALS 'deploy' USER op de VPS om een nieuwe versie live te zetten:
#   ssh deploy@csms.pluggo.app
#   bash /opt/pluggo-csms/pluggo-csms/deploy/deploy.sh
#
# Wat 'ie doet:
#   1. git pull in /opt/pluggo-csms
#   2. npm ci --omit=dev
#   3. systemctl restart pluggo-csms
#   4. Check dat 'ie weer draait via /health
#
# Faalt vroeg + duidelijk bij problemen, roll-back niet automatisch
# (dat is een handmatige `git checkout <old-sha>` gevolgd door herhalen).

set -euo pipefail

REPO_DIR="/opt/pluggo-csms"
APP_DIR="/opt/pluggo-csms/pluggo-csms"
HEALTH_URL="http://localhost:9001/health"

if [[ ! -d "$APP_DIR" ]]; then
  echo "FOUT: $APP_DIR bestaat niet. Deployment nooit uitgevoerd?" >&2
  exit 1
fi

echo "==> [1/4] Huidige versie ophalen"
cd "$REPO_DIR"
OLD_SHA=$(sudo -u pluggo git rev-parse HEAD)
echo "    HEAD nu: $OLD_SHA"

echo "==> [2/4] git pull"
sudo -u pluggo git fetch --all
sudo -u pluggo git pull --ff-only
NEW_SHA=$(sudo -u pluggo git rev-parse HEAD)

if [[ "$OLD_SHA" == "$NEW_SHA" ]]; then
  echo "    Geen nieuwe commits — deploy overgeslagen."
  exit 0
fi
echo "    HEAD nieuw: $NEW_SHA"

echo "==> [3/4] npm ci --omit=dev"
cd "$APP_DIR"
sudo -u pluggo npm ci --omit=dev

echo "==> [4/4] Service herstarten"
sudo systemctl restart pluggo-csms

# Wacht max 10 sec op health-check
echo "    Wacht op /health..."
for i in {1..10}; do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    echo "    Health OK (na ${i}s)"
    curl -s "$HEALTH_URL"
    echo ""
    echo ""
    echo "======================================================================"
    echo " Deployment compleet: $OLD_SHA → $NEW_SHA"
    echo "======================================================================"
    exit 0
  fi
  sleep 1
done

echo "" >&2
echo "FOUT: /health reageert niet na 10s. Check logs:" >&2
echo "  sudo journalctl -u pluggo-csms -n 100 --no-pager" >&2
exit 1
