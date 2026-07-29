# 02 — Code inventory

> Wat er sinds `1.2.3+13` in de codebase is toegevoegd of veranderd. Dit is het "spul dat gaat live" in de big-bang.

---

## #241 — SECURITY DEFINER my_chargers() + column-level GRANTs

**Status:** in_progress (code klaar, wacht op deploy)

**Files:**

- `supabase/migrations/0030_chargers_column_grants.sql`

**Wat het doet:** volledige fix voor #188 — de `chargers` tabel had recursie in RLS. Nu een `SECURITY DEFINER` function `my_chargers()` die alleen voor de authenticated user diens eigen palen returned, plus expliciete column-level GRANTs (anon/authenticated alleen op safe kolommen: naam, locatie fuzzy, prijs, availability).

**Impact:** kritiek voor eigenaar-only updates. Zonder deze migratie werken sommige owner-flows niet betrouwbaar in productie.

**Blast radius:** RLS wijziging → smoke test onmiddellijk na deploy (zie 05_smoke_tests.md).

---

## #263 — DAC7 BSN-drempelflow

**Status:** in_progress (code compleet)

**Files:**

- `supabase/migrations/0032_dac7_bsn_flow.sql` (721 regels)
  - Nieuwe tabellen: `dac7_reporting_state`, `dac7_tin_submissions`
  - RPC: `dac7_status_for_owner()` — returned prompt-state, threshold-progressie, payouts_blocked_at
  - Triggers: transaction counter update op booking-paid, sticky threshold-logic
  - Encryption at rest voor TIN-waarde
- `supabase/functions/submit-tin/index.ts` — edge function die BSN/RSIN accepteert, elfproef valideert server-side, encrypt met `DAC7_ENCRYPTION_KEY` (AES-256-GCM via Deno WebCrypto), stored met alleen `tin_last4` in plain text
- `supabase/functions/create-payment-stripe/index.ts` — payouts-block guard (~40 regels): checkout gaat 409 als owner's `payouts_blocked_at` is set voor huidige kalenderjaar (Europe/Amsterdam)
- `lib/main.dart`:
  - `Dac7Status` model + `fetchDac7StatusSilent()`
  - `Dac7Banner` widget in `_IncomingBookingsScreenState` (warning bij early_warning, blocking bij required)
  - `Dac7TinPromptScreen` met live elfproef-validatie (weights [9,8,7,6,5,4,3,2,-1]) + AVG-disclosure
  - Submits via `supabase.functions.invoke('submit-tin', body: {'tin': _stripped(), 'tin_type': _tinType})`

**Drempels:** ≥30 transacties OF ≥€2.000 in kalenderjaar. Early warning bij 75%, hard-required (payouts geblokkeerd) bij 100%.

**Legal grondslag:** Art. 10c AWR + art. 8 Uitv.reg. WIB (NL grondslag voor BSN uitvraag), DAC7 (EU-richtlijn 2021/514).

**Vereist secret:** `DAC7_ENCRYPTION_KEY` (32-byte, base64). Zie 03_supabase_deploy.md.

**Gap:** privacy.html mist DAC7/BSN-blok. Zie 06_gaps_and_open_items.md.

---

## #287 — Live laadschatting UI

**Status:** in_progress (code klaar, LiveChargingCard geïntegreerd)

**Files:**

- `lib/live_charging_widget.dart` (763 regels — exporteert `LiveChargingCard`)
- `lib/charging_estimator.dart` (155 regels — reken-helpers)
- `lib/main.dart` regel 19 (import), regel 11310 (render binnen booking detail screen)

**Wat het doet:** groene laadbalk + SoC/ETA/kW display + kalibratie-suggestie op basis van vehicle preset (`lib/vehicle_presets.dart`, 141 regels — ~30 populairste NL EV's). Live-update via Supabase realtime subscription op `charging_sessions` tabel.

**Afhankelijk van:** OCPP MeterValues stream werkt (dus blocker #275).

---

## #292 — Boekingsverlengen via lockscreen action buttons

**Status:** in_progress (code klaar)

**Files:**

- `lib/push_actions.dart` (155 regels — handelt push action button taps af)
- `supabase/migrations/0029_booking_extend_flow.sql` — RPC `extend_booking(booking_id, minutes)` die availability check doet en booking window verlengt
- `lib/main.dart` — action buttons config bij push registratie
- iOS: `ios/Runner/AppDelegate.swift` — UNNotificationCategory registratie (verify)
- Android: `android/app/src/main/AndroidManifest.xml` — notification actions receiver (verify)

**Wat het doet:** bij 15-min-warning push (#291) verschijnen "+15" / "+30" / "+60" min knoppen. Tap → RPC `extend_booking` → als availability toestaat → booking window uitgebreid → nieuwe push bevestigt.

**Verify pre-deploy:** dat de action buttons ook op lockscreen zichtbaar zijn (iOS via long-press notification, Android direct).

---

## #293 — OCPP start/stop knoppen op booking-detailscherm

**Status:** in_progress (code klaar)

**Files:**

- `lib/main.dart` regel 11861 (start button call), regel 11871 (stop button call)
- Calls: `supabase.functions.invoke('remote-start-session')` en `remote-stop-session`
- Edge functions: `supabase/functions/remote-start-session/index.ts` + `remote-stop-session/index.ts`

**Wat het doet:** manual override boven op de auto-start/auto-stop. Handig voor troubleshooting én voor scenario's waar auto niet fired.

**Afhankelijk van:** OCPP CSMS bereikbaar (#266) + paal geregistreerd.

---

## #163 — Kwartaaloverzicht-engine

**Status:** completed (code) — pending deploy

**Files:**

- `supabase/migrations/0031_quarterly_statements.sql`
- `supabase/functions/generate-quarterly-statement/index.ts`

**Wat het doet:** genereert PDF-kwartaaloverzicht voor BTW-plichtige paaleigenaren. Cron/handmatige trigger, mailt PDF via send-email edge function.

**Verify pre-deploy:** één dummy statement genereren met echte owner-data, PDF openen, controleren op format en cijfers.

---

## OCPP CSMS (buiten de app, wél nieuw)

**Files:**

- `pluggo-csms/index.js` — main entry (WebSocket server)
- `pluggo-csms/lib/connections.js` — connection manager per chargeBoxId
- `pluggo-csms/lib/http-api.js` — REST API voor edge functions (start/stop triggers)
- `pluggo-csms/lib/supabase.js` — Supabase service-role client
- `pluggo-csms/deploy/` — VPS provisioning scripts (setup-vps.sh, systemd unit, nginx, deploy.sh)

**Wat het doet:** OCPP 1.6J CSMS voor Pluggo. Handelt BootNotification, Heartbeat, Authorize, StartTransaction, StopTransaction, MeterValues af. Bridges naar Supabase realtime channel + `charging_sessions` tabel.

**Deploy target:** Hetzner CX22 VPS in EU-datacenter.

---

## Overige "in de build" items

- **#291** — Auto-stop bij einde boekingsvenster + 15-min warning push. Migration `0028_booking_window_auto_stop.sql`. Cron edge function. Al completed, gaat live in deze deploy.
- **#286** — Voertuig-onboarding EV-model preset dropdown + profiel-scherm. Completed.
- **#283** — Boeker ziet geboekte tijdsvlakken op paal-detailscherm + agenda. Completed.
- **#282** — Bug fix: bookings kunnen niet worden geweigerd of geannuleerd (bookings_status_check violation). Completed.

---

## Kandidaten om alsnog mee te nemen (beslissing pre-deploy)

- **#288** — Push notifications OCPP events NL templates (start / milestone-80% / ETA-10min / stop). Als klaar → mee. Zo niet → volgende build.
- **#289** — Auto-stop bij target-SoC via RemoteStopTransaction. Nice-to-have.
- **#245** — Optie C deep-link `pluggo://auth/confirm` handler. Als klaar → mee (verbetert onboarding UX).
