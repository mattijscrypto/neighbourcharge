# Pluggo CSMS — Deployment naar Hetzner CX22

Deze folder bevat alles wat je nodig hebt om de CSMS live te zetten op een verse
Hetzner CX22 (of vergelijkbare VPS met Ubuntu 22.04/24.04). Bij nette uitvoering
sta je binnen ~30 minuten met een TLS-beveiligde CSMS op
`wss://csms.pluggo.app/`.

## Wat we gaan bouwen

```
                       Internet
                          │
                          ▼
                   ┌────────────┐
                   │ Cloudflare │  (optioneel, DNS-only)
                   │    DNS     │
                   └──────┬─────┘
                          │
             csms.pluggo.app A record
                          │
                          ▼
                ┌──────────────────┐
                │  Hetzner CX22    │
                │  Ubuntu 24.04    │
                │                  │
                │  ┌────────────┐  │
                │  │   nginx    │  │  ← TLS termination (Let's Encrypt)
                │  │   :443     │  │
                │  └──┬──────┬──┘  │
                │     │      │     │
                │  /api/  /  │     │
                │  /health   │     │
                │     │      │     │
                │     ▼      ▼     │
                │  ┌────┐  ┌────┐  │
                │  │9001│  │9000│  │  ← systemd: pluggo-csms.service
                │  │HTTP│  │ WS │  │     draait als user 'pluggo'
                │  └────┘  └────┘  │
                │                  │
                │  ufw: 22,80,443  │
                └──────────────────┘
```

- **wss://csms.pluggo.app/CP-001** → paal WebSocket-verbinding
- **https://csms.pluggo.app/api/chargers/CP-001/remote-start** → Edge Function → CSMS
- **https://csms.pluggo.app/health** → publieke health check

## Vooraf regelen

1. **Hetzner account** met betaalmethode
2. **Domein control** — `csms.pluggo.app` A-record moet naar de VPS-IP kunnen wijzen (bij je huidige DNS-provider). Als je een ander subdomein wilt: zoek-en-vervang `csms.pluggo.app` overal in de files hieronder.
3. **SSH-key** — je publieke sleutel (`~/.ssh/id_ed25519.pub` of `id_rsa.pub`) klaar om in Hetzner Cloud Console te plakken.

## Stap 1 — Hetzner CX22 provisioneren

Doe dit in de [Hetzner Cloud Console](https://console.hetzner.cloud/):

1. **Add Server**
2. **Location:** Falkenstein of Nürnberg (goedkoopst, latency naar NL is prima ~20ms)
3. **Image:** Ubuntu 24.04
4. **Type:** CX22 (€3,29/maand, 2 vCPU, 4 GB RAM, 40 GB disk) — voldoende voor 50-100 palen
5. **Networking:** IPv4 + IPv6 aanvinken (default). Firewall: niet nu, doen we via ufw op de server zelf
6. **SSH Keys:** upload je public key
7. **Name:** `pluggo-csms-prod`
8. **Create & Buy Now**

Noteer het toegewezen IPv4-adres. Bijvoorbeeld `95.216.123.45`.

## Stap 2 — DNS instellen

Ga naar je DNS-provider (waar `pluggo.app` geregistreerd is) en voeg toe:

```
Type:  A
Name:  csms
Value: <VPS_IPV4>
TTL:   3600
```

Wacht 1-5 minuten en verifieer lokaal:

```bash
dig +short csms.pluggo.app
# → moet je VPS-IP teruggeven
```

Zonder dit werkt Let's Encrypt niet (HTTP-01 challenge faalt).

## Stap 3 — Initial VPS setup

SSH als root:

```bash
ssh root@<VPS_IPV4>
```

Kopieer `deploy/setup-vps.sh` naar de VPS en draai 'm:

```bash
# Vanaf je lokale machine:
scp deploy/setup-vps.sh root@<VPS_IPV4>:/tmp/

# Op de VPS:
bash /tmp/setup-vps.sh
```

Dit script:

- update apt + installeert Node.js 22, nginx, ufw, certbot, git
- maakt een non-root `pluggo` user aan (draait de service)
- maakt een `deploy` user aan (voor code-updates)
- configureert `ufw`: alleen 22, 80, 443 open
- maakt `/opt/pluggo-csms/` klaar

## Stap 4 — Code uploaden

Ik neem aan dat je code in git zit. Op je lokale machine, in de repo-root:

```bash
# Push naar remote (GitHub/GitLab) als dat nog niet is gebeurd
git push origin main

# Vanaf de VPS, als de deploy-user:
ssh deploy@<VPS_IPV4>
sudo -u pluggo git clone <YOUR_REPO_URL> /opt/pluggo-csms
cd /opt/pluggo-csms/pluggo-csms
sudo -u pluggo npm ci --omit=dev
```

Als je nog geen public repo hebt: `scp -r pluggo-csms/ deploy@<VPS_IP>:/tmp/` en dan `sudo mv /tmp/pluggo-csms /opt/ && sudo chown -R pluggo:pluggo /opt/pluggo-csms`.

## Stap 5 — Productie-env aanmaken

```bash
sudo -u pluggo cp /opt/pluggo-csms/pluggo-csms/.env.example /opt/pluggo-csms/pluggo-csms/.env
sudo -u pluggo nano /opt/pluggo-csms/pluggo-csms/.env
```

Vul in:

```
SUPABASE_URL=https://<jouw-project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
CSMS_HTTP_PORT=9001
CSMS_API_KEY=<GENEREER MET: openssl rand -hex 32>
```

**Belangrijk:** de `CSMS_API_KEY` moet exact matchen met wat de Supabase Edge Function (task #284) straks meestuurt. Bewaar 'm ook in Supabase → Edge Functions → Secrets.

Rechten aanscherpen:

```bash
sudo chmod 600 /opt/pluggo-csms/pluggo-csms/.env
sudo chown pluggo:pluggo /opt/pluggo-csms/pluggo-csms/.env
```

## Stap 6 — systemd service installeren

```bash
sudo cp /opt/pluggo-csms/pluggo-csms/deploy/pluggo-csms.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pluggo-csms
sudo systemctl start pluggo-csms
sudo systemctl status pluggo-csms
```

Je moet iets zien als `Active: active (running)`. Test lokaal op de VPS:

```bash
curl http://localhost:9001/health
# → {"ok":true,"connections":0,"uptime_s":5}
```

## Stap 7 — Nginx reverse proxy

```bash
sudo cp /opt/pluggo-csms/pluggo-csms/deploy/nginx-csms.conf /etc/nginx/sites-available/csms.pluggo.app
sudo ln -s /etc/nginx/sites-available/csms.pluggo.app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

## Stap 8 — TLS certificaat via Let's Encrypt

```bash
sudo certbot --nginx -d csms.pluggo.app \
     --non-interactive --agree-tos -m info@pluggoapp.nl \
     --redirect
```

Dit installeert automatisch het cert en past nginx aan zodat HTTP → HTTPS redirect. Verifieer:

```bash
curl https://csms.pluggo.app/health
# → {"ok":true,"connections":0,"uptime_s":...}
```

Certbot heeft een cron gezet voor auto-renewal. Verifieer:

```bash
sudo systemctl list-timers | grep certbot
```

## Stap 9 — End-to-end verifiëren

Vanaf je lokale machine — test de RemoteStart (met dev-modus API_KEY nog aan; in prod moet je `-H "X-CSMS-API-Key: <key>"` meesturen):

```bash
# Verbind een test-charger via wss
CSMS_URL=wss://csms.pluggo.app node pluggo-csms/test-charger.js --wait
```

En in een andere terminal:

```bash
curl -X POST https://csms.pluggo.app/api/chargers/CP-001/remote-start \
     -H "Content-Type: application/json" \
     -H "X-CSMS-API-Key: <jouw-key>" \
     -d '{"idTag":"PLUGGO-USER-1","connectorId":1}'
```

Als je een `{"accepted":true,...}` terugkrijgt: **live en werkend**.

## Stap 10 — Logs bekijken

```bash
# Live logs:
sudo journalctl -u pluggo-csms -f

# Laatste 100 regels:
sudo journalctl -u pluggo-csms -n 100

# Errors alleen:
sudo journalctl -u pluggo-csms -p err
```

## Update-workflow

Als je nieuwe code hebt gepusht:

```bash
ssh deploy@<VPS_IPV4>
bash /opt/pluggo-csms/pluggo-csms/deploy/deploy.sh
```

Dit script pullt de laatste code, doet `npm ci`, en herstart de service.

## Troubleshooting

**Service start niet:**

```bash
sudo journalctl -u pluggo-csms -n 50 --no-pager
```

Meestal: `.env` ontbreekt, ontbrekende SUPABASE-vars, of poort 9000/9001 al bezet.

**502 Bad Gateway van nginx:**

De Node-service is niet up. Check `systemctl status pluggo-csms`.

**Certificate expired:**

```bash
sudo certbot renew --dry-run
sudo systemctl reload nginx
```

**Paal kan geen verbinding maken:**

- Check DNS: `dig csms.pluggo.app` vanaf de VPS zelf
- Check firewall: `sudo ufw status`
- Check nginx access log: `sudo tail -f /var/log/nginx/csms.access.log`
- Sommige palen doen alleen `wss://` op poort 443, niet op custom poorten. Wij gebruiken 443 dus dat is prima.

## Beveiliging (post-launch verplicht)

- `CSMS_API_KEY` invoeren in .env (task #272 gaat verder met Basic Auth per paal)
- Fail2ban voor SSH: `sudo apt install fail2ban`
- Automatische security updates: `sudo dpkg-reconfigure -plow unattended-upgrades`
- Overweeg Hetzner Cloud Firewall bovenop ufw (dubbele bescherming, gratis)
