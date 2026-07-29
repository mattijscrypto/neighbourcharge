# 01 — Pre-build blockers

> Deze gate blijft dicht totdat álle onderstaande punten groen zijn. Geen submissie naar App Store / Play Store voordat we zeker weten dat OCPP werkt op een echte paal.

---

## Blocker 1 — Hetzner VPS provisioning (#266) ✅ DONE

**Status:** completed (8 juli 2026)

**Wat er staat:**

- Hetzner **CPX12** VPS live in Falkenstein (eu-central)
- Naam: `ubuntu-2gb-fsn1-1`
- Public IP: `46.224.132.111`
- Deploy-scripts uit `pluggo-csms/deploy/` gedraaid (setup-vps.sh, systemd, nginx, certbot)
- Tests naar server zijn uitgevoerd (per Mattijs bevestigd)

Volledig detail: `_internal/INFRASTRUCTURE.md` sectie "OCPP CSMS".

**Nog te verifiëren vóór de big-bang:**

- [ ] `curl https://csms.pluggoapp.nl/health` → 200 OK (bevestigen dat 't er nog steeds staat)
- [ ] Hetzner snapshots aangezet (dagelijks, 7 dagen retentie) — zie #266-vervolgstappen
- [ ] Env-file backup naar veilige plek

---

## Blocker 2 — Fysieke OCPP-paal (#273)

**Status:** in_progress

**Wat er staat te gebeuren:**

- Tweedehands OCPP 1.6J-paal aanschaffen (Marktplaats — Alfen S-line 11kW €475 in Veghel is een kandidaat)
- Configuratie:
  - `chargeBoxId` = uniek per paal (bv. `test-alfen-001`)
  - CSMS URL: `wss://csms.pluggoapp.nl/ocpp/test-alfen-001`
  - Voor eerste test: Security profile 1 (unauthenticated over TLS)
  - Later: Security profile 2 (Basic Auth over TLS) — zie #272 (blijft open voor productie-hardening)
- Aansluiten in werkplaats/kantoor met echte 3-fase aansluiting of Type 2 dummy-adapter

**Definition of done:**

- Paal boot en meldt zich met BootNotification bij CSMS
- Heartbeat elke 5 min
- Authorize/StartTransaction/StopTransaction lopen door

---

## Blocker 3 — Fysieke E2E-test happy-path (#275)

**Status:** pending — kan pas als blocker 1 en 2 groen zijn

**Test-scenario (must-pass):**

1. **Boeking maken** vanuit app (booker) → Stripe Connect Express betaling → boeking is `confirmed`
2. **Remote start** — booker tikt "Start laden" → app roept `remote-start-session` edge function → CSMS stuurt `RemoteStartTransaction` naar paal → paal gaat open → `StartTransaction` terug → boeking is `charging`
3. **Live UI update** — LiveChargingCard toont kW / kWh / SoC realtime (via Supabase realtime channel)
4. **Auto-stop bij einde boekingsvenster** — 15-min warning push arriveert, RemoteStopTransaction fires bij t=0 (#291)
5. **StopTransaction** — paal levert final meter values → boeking is `completed` → owner kan/hoeft geen kWh in te vullen (automatisch uit meter values)
6. **Betaling** — als het pay-after-charge model was: booker krijgt payment request, betaalt via Stripe, geld gaat via destination charge naar owner
7. **Kwartaaloverzicht** — als het einde-van-kwartaal is: PDF wordt gegenereerd (#163 — kan getest worden met een dummy-boeking in vorig kwartaal)

**Nice-to-have in dezelfde sessie:**

- **Booking verlengen** (#292) — vanuit lockscreen push +15/+30/+60 min
- **OCPP stop-knop handmatig** (#293) — booker of owner drukt stop, sessie sluit netjes af

**Definition of done:**

- Geen enkele stap breekt
- Alle push notifications arriveren in NL (zie #288 — kandidaat om alsnog in deze build mee te nemen)
- Supabase logs tonen geen errors
- Testboeking staat correct in `charging_sessions` + `bookings` tabellen

---

## Wanneer gaat de gate open?

Zodra blockers 2 en 3 een ✅ hebben (blocker 1 is al DONE), en Mattijs (én bij voorkeur ook Raka) de E2E-test met eigen ogen heeft zien lopen op de fysieke paal — start `03_supabase_deploy.md`.

Als één van de blockers rood is, gaat er niets naar productie. Ook geen "gedeeltelijke deploy" van alleen DAC7 of alleen boekingsverlengen. **Big-bang of niet.** De reden: elke gedeeltelijke deploy voegt schuld toe (comms, reviewer notes, migraties in halve staat) en verhoogt de kans op regressies.

---

## Open OCPP-items die NA de big-bang komen (dus NIET blockers)

- #272 — Security profile 2 (Basic Auth over TLS) op productie — kan later
- #288 — Push notifications OCPP events NL templates — kan meegenomen worden in de big-bang mits klaar
- #289 — Auto-stop bij target-SoC via RemoteStopTransaction — nice-to-have, kandidaat voor deze build
- #274 — EV-simulator (Type 2 control-pilot dummy) — alleen nodig voor dev/regressie, niet voor launch
- #277 — B2B pilot-host identificeren + contract-template — post-launch business
- #278/#279/#280/#281 — Internationale expansie (BE/DE/i18n) — post-launch
