# Pluggo CSMS

Central System Management System voor Pluggo — OCPP 1.6J server waar laadpalen mee praten.

## Wat is dit?

Dit is de server-tegenhanger van een OCPP-charger. Een laadpaal opent een WebSocket-verbinding met deze server, stuurt berichten als `BootNotification`, `Authorize`, `StartTransaction`, `MeterValues`, `StopTransaction`, en deze server antwoordt. Zo weet Pluggo wat er op de paal gebeurt zonder dat we een aparte backoffice-partij nodig hebben.

Naast de WebSocket-poort draait er een kleine HTTP-API waar de Pluggo-app (via een Supabase Edge Function) commands naartoe stuurt om laadsessies te starten en stoppen.

## Poorten

| Poort | Protocol | Doel |
|-------|----------|------|
| 9000  | WebSocket | Chargepoints praten hier OCPP |
| 9001  | HTTP      | App-driven commands (RemoteStart/Stop) |

## Roadmap

- **Fase 1 (klaar):** lokale skelet-server + JS-test-client + happy-path
- **Fase 2 (klaar):** Supabase-bridge — sessies opslaan, live kWh naar app
- **Fase 3 (klaar):** RemoteStartTransaction + RemoteStopTransaction via HTTP-API
- **Fase 4:** Hetzner CX22 deploy + TLS + Security Profile 2
- **Fase 5:** Supabase Edge Function `remote-start-session` — glue tussen app en CSMS
- **Fase 6:** Eerste echte paal aangesloten

## Setup lokaal

Vereist: Node.js 18+ (jij hebt 22, prima).

```bash
cd pluggo-csms
cp .env.example .env      # en vul SUPABASE_URL + SERVICE_ROLE_KEY in
npm install
npm run dev
```

Server luistert dan op `ws://localhost:9000` en `http://localhost:9001`.

## Testen

### Optie 1 — Happy-path (alles-in-één simulator)

In een tweede terminal-tab:

```bash
node test-charger.js
```

De test-client draait de volledige flow BootNotification → Authorize → StartTransaction → 3× MeterValues → StopTransaction en sluit af. Handig om te verifiëren dat basis-OCPP werkt.

### Optie 2 — Wachtmodus + RemoteStart via HTTP

Terminal tab 2: charger die connect en op commando's wacht

```bash
node test-charger.js --wait
```

Terminal tab 3: trigger een remote start

```bash
curl -X POST http://localhost:9001/chargers/CP-001/remote-start \
     -H "Content-Type: application/json" \
     -d '{"idTag":"PLUGGO-USER-1","connectorId":1}'
```

Je zou dan moeten zien:

- In tab 2 (charger): `← RemoteStartTransaction ontvangen`, gevolgd door StartTransaction en periodieke MeterValues
- In tab 1 (CSMS): `[HTTP] RemoteStart →`, gevolgd door `[START]` en `[METER]` logs

Stop de sessie:

```bash
curl -X POST http://localhost:9001/chargers/CP-001/remote-stop \
     -H "Content-Type: application/json" \
     -d '{"transactionId":<TX_ID_UIT_START_RESPONSE>}'
```

### Health check

```bash
curl http://localhost:9001/health
# → {"ok":true,"connections":1,"uptime_s":42}
```

## Env vars

Zie `.env.example`. Kort:

- `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` — voor DB-persistentie. Zonder deze draait de server, maar sessies worden niet opgeslagen.
- `CSMS_HTTP_PORT` — default 9001.
- `CSMS_API_KEY` — shared secret voor de HTTP-API. Zonder deze draait alles in dev-modus (geen auth). **In productie verplicht.**

## Volgende stappen (zie tasks #266-#277)

1. Hetzner CX22 provisioning (task #266)
2. Security Profile 2: Basic Auth over TLS (task #272)
3. Edge Function `remote-start-session` in Supabase — koppelt Pluggo booking → CSMS HTTP-call
4. B2B pilot-host identificeren (task #277)
5. Fysieke test-setup met echte paal (task #275)
