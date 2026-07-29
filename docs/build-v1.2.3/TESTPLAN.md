# TESTPLAN — Grote OCPP Onboarding Build (v1.2.3+13)

> **Doel:** volledige E2E-verificatie van alle nieuwe features vóór submissie naar App Store & Google Play, met bijzondere focus op de OCPP-flow die morgen voor het eerst op echte hardware getest wordt.
> **Fysieke test-paal:** Sjef's Alfen Eve Mini (#318) — binnenkomst morgen (16 juli 2026)
> **Verwachte tijdsinvestering:** 1 volledige testdag voor solo-runner (2 mensen = halve dag met parallelle owner/booker rollen)
> **Companion doc:** `FEATURES.md` in deze folder

---

## 0. Testomgeving setup (doen vóór je begint)

### 0.1 Devices

- [ ] **iPhone A** — booker test-account (`test-booker@pluggo-internal.nl`)
- [ ] **iPhone B of Android** — owner test-account (`test-owner@pluggo-internal.nl`)
- [ ] **Beide** met TestFlight-build / Play Internal-track van 1.2.3+13 geïnstalleerd
- [ ] **Push notifications geaccepteerd** op beide

### 0.2 Test-accounts (in Supabase Auth)

- [ ] `test-booker@pluggo-internal.nl` — geen palen, wel Stripe test-card ingericht, wel bevestigde emailadres
- [ ] `test-owner@pluggo-internal.nl` — Stripe Connect Express onboarding voltooid (test-mode), IBAN geverifieerd
- [ ] `test-dac7-triggered@pluggo-internal.nl` — owner die kunstmatig boven €2.000 zit voor DAC7-flow (manueel via SQL)

### 0.3 Test-paal

- [ ] Alfen Eve Mini fysiek aangesloten aan CEE-plug of vast
- [ ] Alfen ACE-service tool gebruikt om OCPP 1.6-J te enablen
- [ ] Backoffice URL ingesteld op `wss://ocpp.pluggo.eu/ocpp`
- [ ] Charge Point Identity: `PLG-TEST-01` (of iets van jouw keuze, hou 't uniek)
- [ ] Password: kies iets ≥8 tekens (schrijf 'm op — vergeten = ACE-tool opnieuw)

### 0.4 Test-EV

- [ ] Type 2 kabel bij de hand
- [ ] Auto met batterij ≥30% vrij (Model 3 of vergelijkbaar) — of gebruik alleen Type 2 kabel + laadmeter om te simuleren
- [ ] Als geen echte EV: **laadmeter/Openevse simulator** aansluiten (Sjef heeft er misschien een)

### 0.5 Backend monitoring open houden

- [ ] Supabase Studio → Table Editor tab open op `chargers`, `bookings`, `charging_sessions`, `dac7_reporting_state`
- [ ] Supabase Studio → Edge Functions → Logs tab open (filter op `ocpp-provision-charger`, `remote-start-session` etc.)
- [ ] `ssh root@46.224.132.111` naar Hetzner VPS met `journalctl -fu pluggo-csms.service` om live OCPP-berichten te zien
- [ ] Optional: BrowserStack / Charles Proxy voor request-inspecting als iets raar doet

---

## 1. Auth & signup regressie (5 scenarios)

**Doel:** zeker weten dat we bestaande auth-flows niet gebroken hebben met #304/#305.

| # | Scenario | Verwachte gedrag | Pass |
|---|----------|------------------|------|
| A1 | Signup nieuw account met matched wachtwoorden | Success → email-bevestigingsscherm → mail arriveert binnen 30s met Pluggo-branded template | ☐ |
| A2 | Signup met MISMATCHED wachtwoorden | Real-time error onder tweede veld: "Wachtwoorden komen niet overeen" — submit-knop disabled | ☐ |
| A3 | Signup met wachtwoord < 8 tekens | Error onder eerste veld: "Minimaal 8 tekens" | ☐ |
| A4 | Password reset flow: klik "Wachtwoord vergeten" → typ email → check mail → klik link | Opent `reset-password.html` in browser (niet in app) — nieuwe password invoeren werkt, redirect naar login-scherm | ☐ |
| A5 | Login met verkeerd wachtwoord | Friendly Nederlandse error, geen crash | ☐ |

---

## 2. Owner paal-lifecycle (10 scenarios)

**Doel:** verifieer smart/manueel branching + koppelwizard + ontkoppelen.

### 2A. Nieuwe manuele paal (regressie)

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| B1 | "Paal toevoegen" → kies "Handmatig" | Kort uitlegscherm, dan normale paal-form (naam, adres, prijs, foto's, type, cable, access, description, instructions) | ☐ |
| B2 | Complete manuele paal aanmaken | Paal verschijnt op eigen "Mijn palen"-lijst met 🔌 badge én op publieke kaart met outline-marker | ☐ |
| B3 | Manuele paal bewerken (prijs aanpassen) | Wijziging live binnen 5 sec — geen RLS-error in logs | ☐ |

### 2B. Nieuwe smart paal met koppelwizard

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| B4 | "Paal toevoegen" → kies "Slim / OCPP" | Uitlegscherm smart-benefits + basis paal-form | ☐ |
| B5 | Na basis-info: koppelwizard opent | Stap 1: merk-keuze scherm met logo's | ☐ |
| B6 | Kies "Alfen" → stap 2 | Alfen-specifieke instructies (ACE-tool, OCPP URL, endpoint = wss://ocpp.pluggo.eu/ocpp) | ☐ |
| B7 | Stap 3: identity `PLG-TEST-01`, password `test1234!` invullen | Volgende-knop enabled | ☐ |
| B8 | Stap 3: identity 21 tekens invullen | Client-side error "max 20 karakters" | ☐ |
| B9 | Stap 3: identity met spatie invullen | Client-side error (regex mismatch) | ☐ |
| B10 | Stap 4: klik "Test verbinding" — paal is UIT | `ocpp-provision-charger` returned 200 (whitelisted) → polling scherm → 3 min timeout → duidelijke error "Geen verbinding — controleer of paal aanstaat" | ☐ |

### 2C. Ontkoppelen

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| B11 | Paal-instellingen → "Ontkoppel deze paal" | Confirm dialog → `ocpp-deprovision-charger` → paal wordt 🔌 handmatig, kaart-marker verandert live binnen 10s | ☐ |
| B12 | Ontkoppelde paal opnieuw koppelen (via "Koppel deze paal" in instellingen, #313) | Wizard opent, kan andere identity gebruiken | ☐ |

**Backend checks tijdens 2:**

```sql
-- na B7-B10: identity PLG-TEST-01 moet in chargers.ocpp_charger_id staan
select id, name, ocpp_charger_id from chargers where owner_id = '<test-owner-uuid>';

-- na B11: ocpp_charger_id moet weer null zijn
```

En op de CSMS:

```bash
ssh root@46.224.132.111 'curl -s -H "X-CSMS-API-Key: $KEY" https://localhost:3000/chargers/PLG-TEST-01'
# na B7: 200 met identity gegevens
# na B11: 404
```

---

## 3. Fysieke paal aanzetten + BootNotification (5 scenarios)

**Doel:** eerste keer echte paal → CSMS verbinding valideren.

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| C1 | Paal aanzetten (net na koppelwizard B10) | Binnen 60s: BootNotification arriveert in CSMS logs, `ocpp_charger_status.last_boot_at` in DB gezet | ☐ |
| C2 | Poll-scherm in wizard detecteert boot | Groen vinkje "Paal verbonden 🎉" verschijnt | ☐ |
| C3 | Paal Heartbeat elke 5 min | `charging_sessions` blijft leeg (geen sessie), maar `ocpp_charger_status.online = true` blijft | ☐ |
| C4 | Kaart in booker-app | Marker toont bliksem-icoon i.p.v. outline binnen 30s | ☐ |
| C5 | Paal-detail booker-app | Toont badge "⚡ Start in app" + prijs + normale info | ☐ |

**Als C1 faalt** — troubleshoot:

- Alfen ACE: is OCPP daadwerkelijk enabled + endpoint correct?
- Firewall Hetzner: is port 80/443 open voor Alfen's IP?
- `journalctl -fu pluggo-csms`: zie je überhaupt een TCP-connect?
- Password mismatch: identiek getypt in app én in Alfen ACE?

---

## 4. Booker map & discovery (7 scenarios)

**Doel:** valideer visuele smart/manueel differentiatie + filters.

| # | # | Verwacht | Pass |
|---|---|----------|------|
| D1 | Booker opent kaart | Beide palen zichtbaar (smart PLG-TEST-01 met ⚡, manueel-testpaal met 🔌) | ☐ |
| D2 | Segmented filter → "⚡ Start in app" | Alleen smart palen zichtbaar | ☐ |
| D3 | Filter → "🔌 Handmatig" | Alleen manuele palen | ☐ |
| D4 | Filter → "Alle" | Beide terug | ☐ |
| D5 | Tap op smart-marker | Bottom-sheet toont smart-badge + prijs + snelheid indien ingevuld | ☐ |
| D6 | Tap op manueel-marker | Bottom-sheet zoals oude versie, geen misleidende "start"-knop | ☐ |
| D7 | Zoek-veld: adres van test-paal | Autocomplete werkt, kaart zoomt in | ☐ |

---

## 5. Manuele booking-flow (regressie — 6 scenarios)

**Doel:** manuele flow onaangetast door OCPP-werk.

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| E1 | Booker boekt manuele paal — 1h vanaf nu | Aanvraag naar owner, owner krijgt push binnen 5s | ☐ |
| E2 | Owner accepteert | Booker krijgt push, booking status `confirmed` | ☐ |
| E3 | Owner weigert (test opnieuw met andere booking) | Booker krijgt friendly reject-notif | ☐ |
| E4 | Na sessie: owner vult kWh in via "Mijn boekingen" | Payment-request → booker krijgt push, betaalt via Stripe Checkout | ☐ |
| E5 | Booker maakt fout (bv. dubbel-tap kwh-invul) | Guard voorkomt dubbele Stripe-charge (#90) | ☐ |
| E6 | Owner cancelt confirmed booking (#44) | Booker krijgt notificatie, geen orphan-payment | ☐ |

---

## 6. Smart booking flow — happy path (12 scenarios) 🌟

**Dit is de belangrijkste testblok van morgen. Doe deze in volgorde met 2 mensen — owner en booker.**

**Setup:** paal is gekoppeld (uit sectie 2/3), staat aan, is online groen.

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| F1 | Booker boekt PLG-TEST-01 voor **NU tot 45 min later** | Aanvraag → owner krijgt push | ☐ |
| F2 | Owner accepteert | Booker krijgt push binnen 5s | ☐ |
| F3 | Paal-detailscherm booker | Grote groene "Start laden"-knop verschijnt (want smart + confirmed + binnen tijdsvlak) | ☐ |
| F4 | Booker sluit stekker aan op auto | Auto ziet paal, hangt in "wachten op autorisatie"-modus | ☐ |
| F5 | Booker tikt "Start laden" | Loading-state → binnen 5s: paal opent stekker (klik-geluid), auto begint te laden | ☐ |
| F6 | Push arriveert: "⚡ Laden begonnen — X kW" | Correcte kW zichtbaar (test op 3.7 of 11 kW afhankelijk van paal-config) | ☐ |
| F7 | LiveChargingCard verschijnt in booking-scherm | Groene laadbalk update elke ~30s, SoC-percentage klopt met auto-scherm ±3% | ☐ |
| F8 | ETA-tekst | "Nog ~X min tot 80%" verschijnt en telt af | ☐ |
| F9 | Backend check: `charging_sessions` row bestaat | `status='charging'`, `meter_start` gezet, geen `meter_stop` | ☐ |
| F10 | Booker tikt "Stop laden" na ~10 min | Paal stopt binnen 5s (klik) → sessie in DB krijgt `meter_stop` + `status='completed_charging'` | ☐ |
| F11 | Push: "Sessie gestopt. Totaal: X kWh — €Y,ZZ" | Klopt met paal-display | ☐ |
| F12 | Stripe checkout arriveert (payment-request flow) | Booker betaalt via Apple Pay of card → geld naar owner Stripe (test-mode) | ☐ |

**Backend verificatie na F12:**

```sql
select b.id, b.status, b.total_amount_cents, cs.kwh_delivered, cs.status
from bookings b
left join charging_sessions cs on cs.booking_id = b.id
where b.id = '<booking-uuid>';
-- verwacht: booking.status='completed', charging_session.status='completed_charging', kwh_delivered > 0
```

---

## 7. Smart booking flow — edge cases (18 scenarios)

**Doel:** stress-test de OCPP flow. Alle scenarios hier apart, niet cumulatief.

### 7A. Tijdsvlak-tolerantie

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| G1 | Booker probeert start-knop **2 min voor start** | Werkt (binnen 2-min tolerance in `remote-start-session`) | ☐ |
| G2 | Booker probeert start-knop **10 min voor start** | 409 error: "Je boeking begint pas over 10 min — probeer 't dan opnieuw" | ☐ |
| G3 | Booker probeert start-knop **5 min na eind** | Werkt (binnen 5-min late tolerance) | ☐ |
| G4 | Booker probeert start-knop **10 min na eind** | 409 error: "Je boeking is verlopen" | ☐ |

### 7B. No-show en auto-stop

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| G5 | Booking NU tot NU+15 min. Booker doet NIETS. | Geen sessie in DB. Na 20 min → booking status → `no_show` of `completed_no_session`? Verify huidige gedrag. | ☐ |
| G6 | Booking gestart, booker laat auto op paal na einde tijdsvlak | Na `end_time + 5 min grace` → `booking_window_auto_stop_tick` cron → auto-stop-warning push (T-5 min) → RemoteStopTransaction → paal stopt | ☐ |
| G7 | T-5 min push arriveert met "+15/+30/+60" actie-knoppen | Zichtbaar op lockscreen (iOS én Android) | ☐ |
| G8 | Booker tikt "+15" op lockscreen | RPC `extend_booking(id, 15)` runs → availability check → booking.end_time += 15 min → bevestigings-push arriveert → sessie loopt gewoon door | ☐ |
| G9 | Booker tikt "+30" maar volgende booking is over 20 min | Failure-push arriveert: "+30 min niet mogelijk — er is een boeking om HH:MM" — sessie stopt gewoon om origineel eind | ☐ |
| G10 | Owner ontvangt informatieve push bij auto-stop | Zichtbaar in owner's app: "Sessie automatisch gestopt bij [paal] — X kWh — €Y,ZZ" | ☐ |

### 7C. Milestones & pushes

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| G11 | Sessie loopt door 80% SoC | Milestone-push arriveert **eenmalig** (dedupe via `charging_session_push_events`) | ☐ |
| G12 | Sessie loopt door 100% (batterij vol volgens auto) | Auto stopt zelf → StopTransaction → sessie completed, push met "sessie voltooid" | ☐ |
| G13 | T-15 min voor booking start | Push "Je boeking begint over 15 min bij [paal-naam]" (van migratie 0034) | ☐ |

### 7D. Fout-injectie

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| G14 | Paal UITSCHAKELEN tijdens sessie (trek stekker uit CSMS-kant) | Sessie in DB blijft `charging`, geen live updates meer, na X sec: `ocpp_charger_status.online = false`. Booker's LiveChargingCard toont "Verbinding met paal verbroken — probeer stop" | ☐ |
| G15 | Paal weer aan | Reconnect binnen 30s, sessie updates hervatten OF paal doet nieuwe StatusNotification | ☐ |
| G16 | Wifi drop op booker-device tijdens sessie (airplane mode) | LiveChargingCard bevriest maar app crasht niet. Wifi terug → widget haalt weer data op via realtime subscribe | ☐ |
| G17 | Booker forceert Stop terwijl paal offline is | UI toont loading-state, timeout na 12s (CSMS_HTTP_TIMEOUT_MS), begrijpelijke error "Paal reageert niet — sessie stopt vanzelf bij einde tijdsvlak" | ☐ |
| G18 | Twee bookers proberen te starten op zelfde paal | Alleen degene met confirmed booking op dit moment krijgt Accepted; ander krijgt 403 "Deze boeking is niet van jou" | ☐ |

### 7E. Idempotency

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| G19 | Booker dubbel-tapt "Start laden" binnen 1s | Alleen 1 RemoteStart naar CSMS (debounce client-side én server-side session-check) | ☐ |
| G20 | Booker sluit app tijdens laden en opent opnieuw | Booking-scherm herstelt met live sessie data uit Supabase realtime | ☐ |

---

## 8. DAC7 BSN-drempelflow (8 scenarios)

**Setup:** gebruik `test-dac7-triggered@pluggo-internal.nl` account.

```sql
-- Kunstmatig triggeren voor tests:
insert into dac7_reporting_state (owner_id, year, total_amount_cents, transaction_count)
values ('<test-owner-uuid>', 2026, 100000, 5)  -- €1000, 5 txns = onder drempel
on conflict (owner_id, year) do update
  set total_amount_cents = excluded.total_amount_cents,
      transaction_count = excluded.transaction_count;
```

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| H1 | Owner onder 75% drempel (€1000, 5 txns) | Geen banner zichtbaar in Ontvangen boekingen scherm | ☐ |
| H2 | Zet naar €1600 (75% van €2000) | Refresh → `early_warning` banner: "Bijna DAC7-drempel bereikt" met "Vul BSN in" CTA | ☐ |
| H3 | Zet naar 30 transacties + €500 | Ook `early_warning` — trigger op OF-conditie | ☐ |
| H4 | Zet naar €2100 | `required` blocking banner + `payouts_blocked_at` gezet in DB | ☐ |
| H5 | Booker probeert booking te maken bij deze owner | `create-payment-stripe` 409 met NL error naar Stripe checkout | ☐ |
| H6 | Owner klikt banner → BSN-invoerscherm | Live elfproef-validatie: typ `111222333` → invalid; typ echte test-BSN → valid, knop enabled | ☐ |
| H7 | Owner submit valid BSN | Backend: `submit-tin` runs, encrypted row in `dac7_tin_submissions`, `tin_provided_at` gezet, `payouts_blocked_at` cleared | ☐ |
| H8 | Refresh owner app | Banner weg, booker kan weer boeken (retry H5) | ☐ |

**Als H7 500-error geeft:** `DAC7_ENCRYPTION_KEY` secret ontbreekt in Supabase. Zet met `supabase secrets set DAC7_ENCRYPTION_KEY=$(openssl rand -base64 32)`.

---

## 9. Vehicle & profile presets (3 scenarios)

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| I1 | Booker gaat naar profiel → "Voertuig" | Dropdown met ~30 EV-modellen, selecteer "Tesla Model 3 LR" | ☐ |
| I2 | Profile bevat nu battery_capacity=75, preferred_kw etc | Verify in DB `select vehicle_model, battery_capacity_kwh from profiles where id = '<booker-uuid>'` | ☐ |
| I3 | Volgende smart-booking: LiveChargingCard gebruikt jouw batterij-info | ETA-berekening gebruikt 75 kWh capacity | ☐ |

---

## 10. Kwartaaloverzicht (2 scenarios)

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| J1 | Owner met BTW-status "zakelijk" en > 0 sessies dit kwartaal — trigger via `supabase functions invoke generate-quarterly-statement --body '{"owner_id":"<uuid>","quarter":"2026-Q2"}'` | PDF gegenereerd, email arriveert bij owner met attachment | ☐ |
| J2 | Owner met KOR-status | Cron slaat 'm over, geen PDF | ☐ |

---

## 11. Push notifications volledig overzicht (5 scenarios)

**Doel:** verifieer dat ALLE 6 push-events werken op zowel iOS als Android.

Voor ieder van deze events: check dat de push arriveert, correct rendered, en tap → deep-link naar juiste scherm.

| # | Event | Trigger | Deep-link Pass |
|---|-------|---------|-----|------|
| K1 | Nieuwe boekingsaanvraag → owner | Booker maakt aanvraag | Opens booking-detail als owner | ☐ |
| K2 | Boeking geaccepteerd → booker | Owner tikt accept | Opens booking-detail als booker | ☐ |
| K3 | T-15 start-warning → booker | 15 min voor start_time | Opens paal-detail met start-banner | ☐ |
| K4 | Charging-start → booker | RemoteStart accepted | Opens booking-detail met LiveChargingCard | ☐ |
| K5 | 80% milestone → booker | SoC ≥ 80 | Opens booking-detail | ☐ |
| K6 | Auto-stop warning met +15/+30/+60 actions → booker | 5 min voor end_time bij actieve sessie | Actions werken (zie G7-G9), tap opent booking-detail | ☐ |
| K7 | Sessie voltooid → booker | StopTransaction | Opens payment-scherm | ☐ |
| K8 | Payment-request (manuele paal) → booker | Owner submit kWh | Opens Stripe checkout deep-link | ☐ |

**Als een push niet arriveert:** check `user_devices` tabel (FCM token registered?), `send-push` Edge Function logs, en device-side notification permissions.

---

## 12. Security & permissions (5 scenarios)

**Doel:** valideer dat RLS + column-level GRANTs correct werken.

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| L1 | Anon (uitgelogd) opent app → kaart zichtbaar met palen | Palen zichtbaar met fuzzy locatie, GEEN owner email of exact lat/lng | ☐ |
| L2 | Anon doet raw REST call: `curl 'https://<project>.supabase.co/rest/v1/chargers?select=lat,lng' -H "apikey: <anon-key>"` | 401 of empty (want `lat`/`lng` niet in column grants voor anon) | ☐ |
| L3 | Ingelogde booker doet `select owner_email from chargers` via REST | Alleen als hij een confirmed booking heeft, anders empty | ☐ |
| L4 | Owner doet `select * from chargers` via app | Krijgt alleen zijn eigen palen (via `my_chargers()` security definer function) | ☐ |
| L5 | Supabase Studio → Security Advisor → "Run linter" | ZERO ERRORS (alle 4 juni-errors moeten weg blijven) | ☐ |

---

## 13. Payment edge cases (4 scenarios)

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| M1 | Booker's card gedeclined bij checkout | Stripe checkout toont retry-optie, booking status blijft `payment_pending` | ☐ |
| M2 | Booker doet succesvolle retry | Payment succeeds, booking `paid` | ☐ |
| M3 | Owner opent Stripe dashboard → doet refund op charge | `stripe-webhook` verwerkt, booking status → `refunded`, booker krijgt notif | ☐ |
| M4 | Payment blijft 7 dagen open → cron `send-payment-reminders` | Herinnering-email + account-pauze na X dagen (#62) | ☐ |

---

## 14. App crashen / restart survival (4 scenarios)

| # | Scenario | Verwacht | Pass |
|---|----------|----------|------|
| N1 | Force-quit app tijdens actieve sessie | Herstel bij openen: booking-scherm herstelt live data | ☐ |
| N2 | Reboot device tijdens sessie | Sessie loopt gewoon door (CSMS-side is stateful), app herstelt bij open | ☐ |
| N3 | Wisselen tussen accounts (uitloggen → inloggen ander) | Geen stale data van vorig account zichtbaar | ☐ |
| N4 | Account verwijderen in-app (#22) | Auth.user weg, palen wees, boeking-historie geanonimiseerd | ☐ |

---

## 15. Backend queries voor smoke-verificatie (SQL snippets)

Runnen in Supabase Studio SQL Editor als je twijfelt aan een test-uitkomst.

```sql
-- 1) OCPP paal status check
select
  c.name,
  c.ocpp_charger_id,
  os.online,
  os.last_boot_at,
  os.last_heartbeat_at
from chargers c
left join ocpp_charger_status os on os.charger_id = c.id
where c.ocpp_charger_id is not null
order by c.name;

-- 2) Live sessies zien
select
  cs.id,
  cs.status,
  cs.meter_start,
  cs.meter_stop,
  cs.kwh_delivered,
  cs.started_at,
  cs.ended_at,
  b.user_id as booker,
  c.name as paal
from charging_sessions cs
join bookings b on b.id = cs.booking_id
join chargers c on c.id = b.charger_id
where cs.status = 'charging'
order by cs.started_at desc;

-- 3) MeterValues live tail (voor debugging live-widget)
select
  csmv.recorded_at,
  csmv.soc_percent,
  csmv.kwh,
  csmv.power_kw
from charging_session_meter_values csmv
join charging_sessions cs on cs.id = csmv.session_id
where cs.status = 'charging'
order by csmv.recorded_at desc
limit 20;

-- 4) DAC7-state
select
  owner_id,
  year,
  transaction_count,
  total_amount_cents / 100.0 as amount_euro,
  early_warning_at,
  required_at,
  payouts_blocked_at,
  tin_provided_at
from dac7_reporting_state
where year = 2026
order by total_amount_cents desc;

-- 5) Push-events dedupe check
select
  session_id,
  event_type,
  sent_at
from charging_session_push_events
order by sent_at desc
limit 20;

-- 6) Verify: geen booking heeft twee actieve sessies
select booking_id, count(*)
from charging_sessions
where status = 'charging'
group by booking_id
having count(*) > 1;
-- verwacht: 0 rows
```

---

## 16. CSMS-side verificatie (SSH commandos)

Op de Hetzner VPS na een sessie:

```bash
# Live log tail
journalctl -fu pluggo-csms.service

# Whitelist check
curl -s -H "X-CSMS-API-Key: $KEY" https://localhost:3000/chargers | jq .

# Test WS reachability van buiten
wscat -c wss://ocpp.pluggo.eu/ocpp -s ocpp1.6 -a "PLG-TEST-01:test1234!"
# verwacht: connection established, dan handmatig BootNotification JSON pushen om te testen
```

---

## 17. Rollback triggers (weet wanneer je stopt)

Als een van deze faalt, **submit NIET naar App Store / Play Store**:

- ❌ Elke test in sectie 1 (auth regressie)
- ❌ B1-B3 manuele paal-flow gebroken
- ❌ F1-F12 happy path smart flow (het hele punt van deze build)
- ❌ H4-H5 DAC7 payout-blokkade wordt niet toegepast (compliance!)
- ❌ L1-L5 security-scan geeft rode errors

Als deze falen: **submit is OK maar log als bekend defect voor v1.3.1**:

- ⚠️ G14-G17 offline recovery — mag suboptimaal zijn zolang app niet crasht
- ⚠️ G8-G9 lockscreen extend actions — nice-to-have, kan uit met feature-flag
- ⚠️ K3 T-15 warning push — mag missen mits andere pushes werken
- ⚠️ J1-J2 kwartaaloverzicht — kan post-launch geactiveerd
- ⚠️ N4 account-verwijderen edge case

---

## 18. Sign-off

Wie: __________________ (Mattijs / Raka / andere tester)
Datum: __________________
Device iOS: __________________ (model + iOS-versie)
Device Android: __________________
App build: 1.2.3+13 (of hoger)

Scenarios totaal: **~90**
Geslaagd: ___ / 90
Faalt maar acceptabel: ___
Blocker-faal: ___

**Verdict:** ☐ Submit App Store ☐ Submit Play Store ☐ Hold — repareer eerst

Notities:

________________________________________________________________
________________________________________________________________
________________________________________________________________

---

## Bijlage — Test-BSN-generator

Voor sectie 8 DAC7 tests heb je geldige elfproef-BSN's nodig. Test-set (elfproef pass):

```
111222333  → FALSE (som % 11 ≠ 0) — voor invalid test
123456782  → TRUE  (som % 11 = 0) — voor valid test
```

⚠️ Gebruik NOOIT echte BSN's van jezelf of anderen tijdens tests. De test-set hierboven zijn officiële test-BSN's van de Belastingdienst (bekend als "Rekenvoorbeeld BSN") en veilig te gebruiken.

Voor RSIN-tests (zakelijk): eigen KvK-nummer is OK, of test-RSIN `123456789` (past nooit elfproef, gebruik voor invalid).
