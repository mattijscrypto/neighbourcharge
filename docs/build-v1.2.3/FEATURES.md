# FEATURES — Grote OCPP Onboarding Build

> **Pluggo v1.2.3+13 (working tree) → target v1.3.0+14 na version bump**
> **Diff-scope:** alles sinds v1.2.1+11 (productie-release 18 juni 2026)
> **Datum-scope:** 18 juni → 15 juli 2026 (~4 weken werk)
> **Deployed backend:** Supabase migraties 0018→0034 + 21 Edge Functions + CSMS op Hetzner CX22
> **Testmoment:** morgen — eerste fysieke OCPP paal binnen (Sjef's Alfen Eve Mini / #318)

Dit document is de "wat zit er in de build"-catalogus. Voor de bijhorende **testscenario's** zie `TESTPLAN.md` in deze folder.

---

## 0. Executive summary

Deze build is de grootste van 2026 en verandert de identiteit van Pluggo:

- **Van manuele afspraak-app → hybride app + platform.** Palen die aan de Pluggo CSMS hangen zijn nu **"smart palen"** — de boeker start en stopt de laadsessie direct uit de app, ziet live SoC en kWh, en krijgt push-notificaties bij milestones. Bestaande "manuele palen" blijven ongewijzigd; de app toont ze naast elkaar op de kaart met duidelijke visuele differentiatie.
- **Compliance-laag klaar voor 2027.** DAC7 BSN-drempelflow werkt: eigenaars die richting de €2.000 / 30-transacties-drempel gaan krijgen tijdig een banner en kunnen hun BSN indienen. Zonder BSN → automatische payout-blokkade tot boekhoudkundige eind-van-jaar-cutoff. Kwartaaloverzicht-engine draait als cron.
- **Security-schuld weggewerkt.** Column-level GRANTs op `chargers`, SECURITY DEFINER `my_chargers()`, RLS-recursie fix — alle Security Advisor errors uit juni gefixt.

---

## 1. OCPP live-charging (het grote verhaal)

Nieuwe stack die parallel aan de bestaande manuele-flow bestaat. Zonder OCPP-koppeling verandert er niets voor eigenaars die het niet willen gebruiken.

### 1.1 CSMS infrastructuur (`pluggo-csms/` — inmiddels privé repo)

- **Hetzner CX22 VPS** in Falkenstein, DE — `csms.pluggoapp.nl`
- **OCPP 1.6-JSON** WebSocket server (Node.js + `ocpp-rpc`) op `wss://ocpp.pluggo.eu/ocpp`
- **HTTP API** voor admin/whitelist (`X-CSMS-API-Key` shared secret) op `https://csms.pluggoapp.nl`
- **Handlers geïmplementeerd:** BootNotification, Heartbeat, StatusNotification, Authorize, StartTransaction, MeterValues, StopTransaction
- **Supabase-bridge:** CSMS schrijft sessies + live kWh direct naar Supabase-tabellen via service-role key
- **Security profile 2 (Basic Auth over TLS)** — task #272, nog pending voor productie hardening
- **Bijhorende taken:** #266, #268, #269, #270, #271, #275, #290

### 1.2 Data model uitbreiding (migraties 0021, 0023, 0025, 0028, 0029)

**`chargers` tabel — nieuw:**

- `ocpp_charger_id text NULL UNIQUE` — de OCPP identity waaronder de paal bij de CSMS is geregistreerd. NULL = manuele paal. Set = smart paal.
- `max_power_kw numeric` — voor ETA-berekening in live-widget

**`profiles` tabel — nieuw:**

- `vehicle_model text` — bv. "Tesla Model 3", "VW ID.3"
- `battery_capacity_kwh numeric`
- `default_soc_target int` — bv. 80 (%)
- `preferred_charging_speed_kw numeric`

**`bookings` tabel — nieuw:**

- `starting_soc int NULL`, `target_soc int NULL`
- `status`-enum uitgebreid met `charging`, `completed_charging`
- `auto_stopped_at timestamptz` — voor #291 (auto-stop bij einde boekingsvenster)

**Nieuwe tabellen:**

- `charging_sessions` (0021) — OCPP-side truth: kwh_delivered, meter_start, meter_stop, connector_id, ocpp_status
- `charging_session_meter_values` — 30-sec granulariteit voor live widget
- `charging_session_push_events` (0025) — dedupe-guard voor milestone-pushes

### 1.3 Nieuwe paal-aanmaak vertakking (#310)

Bij "Paal toevoegen" krijgt de eigenaar een **keuzescherm smart vs manueel** met duidelijke copy over de trade-offs. Voor smart palen wordt na de basis-info direct de **Koppelwizard** (#311) gestart.

### 1.4 Koppelwizard — 4 stappen (#311, #312, #313)

Nieuw scherm `CouplingWizardScreen` in `main.dart` (~r7100-r7500):

1. **Merk kiezen** — Alfen / EVBox / Wallbox / etc, met branded logo's
2. **Instructies** — merk-specifieke stappen om paal in OCPP 1.6-J modus te zetten + CSMS URL te configureren
3. **Gegevens invoeren** — Charge Point Identity (max 20 chars, alfanumeriek + `-_`) + password (min 8 chars)
4. **Test-verbinding** — Edge Function `ocpp-provision-charger` whitelistet de identity op de CSMS; UI polt om de 3 sec `ocpp_charger_status` view voor eerste BootNotification/Heartbeat. Timeout 3 min met begrijpelijke error.

**Help-sheet in wizard (#312):** `mailto:` pre-filled naar Pluggo support met paal-context (merk, identity, error state), belofte van 24u antwoord.

**Achteraf koppelen (#313):** paal-instellingen krijgt nieuwe sectie "Koppel deze paal" voor bestaande manuele palen die owner alsnog smart wil maken.

### 1.5 Smart-vs-manueel visueel op de kaart (#307, #308, #309)

- **Custom markers:** smart palen = bliksem-icoontje, manuele palen = outlined stekker. Solar palen behouden zon-icoontje, met bliksem-badge als smart+solar.
- **Filter chips:** `[Alle palen]` `[⚡ Start in app]` `[🔌 Handmatig]` — voor booker-discovery
- **Legende + tooltip:** één tap toont "smart palen kun je vanuit de app starten en stoppen"
- **Migratie 0033:** `chargers_public` view exposes `ocpp_charger_id` zodat de client de smart-vlag kan afleiden zonder RLS-uitbreiding

### 1.6 Paal-detailsheet branching (#314)

- **Smart paal + confirmed booking + binnen tijdsvlak:** grote groene "Start laden"-knop
- **Manuele paal:** ongewijzigd — "Reserveer"-knop of "Contact eigenaar"
- **Smart + geen booking:** normale reserveer-knop (start-knop verschijnt pas na confirmed)

### 1.7 Booking-detailscherm OCPP knoppen (#293)

- "Start laden" → Edge Function `remote-start-session` → RemoteStartTransaction command naar CSMS → paal opent stekker
- "Stop laden" → Edge Function `remote-stop-session` → RemoteStopTransaction
- **Idempotency:** dubbel tikken op start binnen 3s wordt gedebounced client-side + server-side reject als er al een `charging`-sessie loopt

### 1.8 Live laadschatting widget (#287)

Nieuwe files: `lib/live_charging_widget.dart` (763 regels) + `lib/charging_estimator.dart` (155 regels)

- **Groene laadbalk** met percentage SoC (start-SoC + geladen kWh / battery_capacity)
- **ETA-tekst** — "Nog ~24 min tot 80%" op basis van huidige kW-tarief
- **Live kW-display** met sparkline van laatste 15 minuten
- **Kalibratie-suggestie** als voertuigmodel niet matcht met gemeten curve

Data-flow: Supabase realtime subscription op `charging_session_meter_values` — update elke 30 sec bij een normale MeterValues-frequentie.

### 1.9 Vehicle preset dropdown (#286)

Nieuwe file: `lib/vehicle_presets.dart` (141 regels)

~30 populairste NL EV's als preset (Tesla 3/Y, VW ID.3/4/5/7, Kia EV6, Hyundai IONIQ 5/6, Skoda Enyaq, BMW i4/iX/iX1/iX3, Audi Q4/Q6/Q8 e-tron, Volvo EX30/EX40, Renault Megane/Scenic, Peugeot 208/2008, Opel Corsa/Mokka, Fiat 500e, MG4/MG5, Polestar 2/3/4). Preset zet battery_capacity_kwh en typische AC-max in het profiel.

### 1.10 Push notificaties OCPP events (#288, #291)

Nieuwe file: `lib/push_actions.dart` (155 regels) + migraties 0025-0027

Events geïmplementeerd:

- **T-15 startwaarschuwing** (0034) — "Je boeking begint over 15 min bij [paal-naam]"
- **Charging-start** (0025) — "⚡ Laden begonnen — 3.6 kW"
- **80% milestone** — "Nog ~10 min tot 80% (batterij-vriendelijk stoppunt)"
- **ETA-10min** — "Nog 10 minuten in je boekingsvenster"
- **Auto-stop-warning** — "Sessie stopt over 5 min ivm einde boekingsvenster. Tik voor +15/+30/+60 min"
- **Charging-stopped** — "Sessie gestopt. Totaal: 12.4 kWh — €4,58"

### 1.11 Auto-stop bij einde boekingsvenster (#291)

Migratie 0028 — cron `booking_window_auto_stop_tick()` draait elke minuut, vindt actieve sessies voorbij hun `bookings.end_time + 5 min` grace, en triggert een RemoteStopTransaction via de CSMS.

### 1.12 Booking-verlengen via lockscreen (#292 — in progress)

Bij de "eind-van-boeking over X min"-push krijgt de booker actie-knoppen `+15`, `+30`, `+60` min. Tap → `push_actions.dart` handler → RPC `extend_booking(booking_id, minutes)` → checkt availability → verlengt window als vrij, geeft anders duidelijke error-push.

- iOS: `UNNotificationCategory` in `AppDelegate.swift`
- Android: notification actions in `AndroidManifest.xml`

**Status:** code klaar, notif-registratie moet nog geverifieerd op device.

### 1.13 Edge Functions (nieuw)

- `remote-start-session` (~370 regels) — auth → booking check → CSMS POST `/chargers/{id}/remote-start`
- `remote-stop-session` — spiegelbeeld voor stop
- `ocpp-provision-charger` (~350 regels, geschreven vandaag) — auth → owner-check → uniqueness → CSMS PUT `/chargers/{identity}` → UPDATE chargers.ocpp_charger_id, met best-effort rollback bij half-state
- `ocpp-deprovision-charger` (~200 regels, geschreven vandaag) — auth → owner-check → CSMS DELETE → UPDATE ocpp_charger_id = null. Volgorde CSMS-eerst-DB-daarna is bewust, zie header-comment.
- `send-push` — refactored voor multi-event support (was al bestaand, refactor deze build)

---

## 2. Booker experience improvements

### 2.1 Boekingsagenda zichtbaar per paal (#283)

Op paal-detailscherm nieuwe agenda-view die geboekte tijdsvlakken toont (grijs = bezet, wit = vrij). Voorkomt frustratie bij dubbele booking-attempts.

### 2.2 "Booking begint zo"-banner (#315 — in progress)

Op paal-detail: T-15 min voor booking → banner met start-knop bovenaan het scherm (bij smart palen). Verdwijnt T+X min na start.

### 2.3 First-time tutorial (#316, #317 — pending)

- 3-slide overlay bij eerste booking op smart paal (start-flow uitleg → stekker in → betaling)
- 2-slide welkom bij eerste app-open (smart palen concept)
- Persistence via `shared_preferences` — bewust géén server-side flag (one-shots hoeven niet te syncen tussen devices)

### 2.4 Segmented filter op kaart (#309)

Zie 1.5.

---

## 3. Owner experience improvements

### 3.1 Voertuig-onboarding scherm (#286)

Nieuw profiel-scherm sectie: voertuig-model dropdown, batterijcapaciteit, standaard SoC-target, voorkeur kW. Optioneel, maar suggested tijdens onboarding.

### 3.2 OCPP-status kolom in "Mijn palen" (#308)

Palen-lijst toont per paal een badge: 🔌 Handmatig / ⚡ Smart / 🔴 Smart offline.

### 3.3 Kwartaaloverzicht-engine (#163)

Migratie 0031 + `generate-quarterly-statement` Edge Function. Draait als cron ieder kwartaal-einde voor BTW-plichtige paaleigenaars (dus KOR-eigenaars overslaan). Genereert PDF met totale kWh + totale omzet + Pluggo-fee gespecificeerd.

### 3.4 Auto-stop notificatie voor owner

Bij auto-stop van sessie krijgt owner ook een informatieve push (geen action buttons): "Sessie automatisch gestopt bij [paal] — 12.4 kWh — €4,58 (Pluggo fee €0,37)".

---

## 4. Payments & compliance

### 4.1 Stripe Connect Express hardening (#253)

- **Live-mode webhook fix:** `handleAccountUpdatedV2` schreef niet naar profile (task #185, #253). Root cause: `account.updated` events kwamen binnen zonder `metadata.pluggo_user_id`, silent-failden. Nu: fallback op `stripe_account_id → profile` lookup + explicit error logging + retry-mechanisme.
- **`stripe-refresh-account`** Edge Function: `verify_jwt=false` voor admin sb_secret-modus

### 4.2 DAC7 BSN-drempelflow (#263 — in progress)

**Wet:** Art. 10c AWR + Uitv.reg. WIB (NL grondslag BSN-uitvraag), DAC7 EU-richtlijn 2021/514.

**Drempels per kalenderjaar (Europe/Amsterdam):**

- ≥30 transacties **OF** ≥€2.000 omzet → DAC7-rapportageplicht voor Pluggo aan Belastingdienst
- Zonder BSN → geen rapportage mogelijk → payouts worden geblokkeerd tot BSN geleverd

**Flow:**

- **≥75% van drempel:** `early_warning` banner in owner-inbox — vriendelijke prompt om BSN te leveren
- **≥100% van drempel:** `required` blocking banner + `dac7_reporting_state.payouts_blocked_at` gezet + boekers krijgen 409 bij checkout op deze paal ("Deze eigenaar heeft nog een verplichte gegevens-update openstaan, probeer 't over een paar dagen opnieuw")
- **BSN submit** via `Dac7TinPromptScreen` — live elfproef-validatie (weights `[9,8,7,6,5,4,3,2,-1]`), AVG-disclosure over doelbinding + bewaartermijn
- **Server-side** in `submit-tin` Edge Function: BSN nogmaals gevalideerd, AES-256-GCM encrypted (WebCrypto met `DAC7_ENCRYPTION_KEY` secret), stored met alleen `tin_last4` in plain
- **Post-submit:** banner verdwijnt, `payouts_blocked_at` gecleared, boekingen weer mogelijk

**Migratie:** 0032 (721 regels — states, submissions tabel, encryption helpers, RPCs, triggers)

### 4.3 IBAN validatie (#144)

Migratie 0018 + client-side validator (Nederlandse IBAN checksum). Voorkomt typo's bij Stripe Connect setup.

### 4.4 Payout-blokkade in checkout (#263)

`create-payment-stripe` gemodificeerd: als `payouts_blocked_at IS NOT NULL` voor huidige kalenderjaar → 409 met NL error naar de booker.

---

## 5. Auth & signup

### 5.1 Password confirmation (#305)

Rob D. feedback: signup vroeg 1x wachtwoord in, mensen typten typo's. Nu 2x-veld + tooltip op show/hide toggle.

### 5.2 Password reset web-flow (#304 — in progress)

- `docs/reset-password.html` — Supabase auth recovery landing (Cloudflare pages)
- `resetPasswordForEmail(redirectTo: '...')` in main.dart aangepast
- Nog te doen: deep-link `pluggo://auth/reset` (task #245)

### 5.3 Welcome-email trigger (#20 aanvulling)

Migratie 0020: trigger op `auth.users` insert → `send-welcome-email` Edge Function → Pluggo-branded HTML (Resend SMTP #244)

---

## 6. Security hardening (Security Advisor + follow-ups)

Alles al deployed en groen in Security Advisor per juni, hier ter volledigheid:

- **0015** `security_advisor_auth_users_views` — auth.users email lek gefixt (#186)
- **0016** `security_advisor_definer_views` — 4 SECURITY DEFINER views naar security_invoker + RLS chargers (#187)
- **0017** `fix_chargers_rls_recursion` — RLS-recursie hotfix (#191)
- **0030** `chargers_column_grants` — column-level GRANTs zodat anon/authenticated alleen safe kolommen kunnen SELECTen (#188)
- **`my_chargers()` SECURITY DEFINER function** (#241 — in progress) — vervangt de "USING true"-hack policy

### 6.1 DAC7 encryption

`DAC7_ENCRYPTION_KEY` (32-byte, base64) als Supabase secret. BSN nooit in plain in database — alleen encrypted blob + last-4 voor UX.

---

## 7. Bug fixes & regressions

- **#282** Bookings-status_check violation — kon geen weiger/annuleer voltooien; enum-uitbreiding + trigger-fix
- **#149** REGRESSIE: push notifications werkten in test, niet in productie — root cause: FCM scope + user-project header ontbrak
- **#147** Google Maps API key restrictions — REST calls faalden voor sommige testers; nieuwe key + billing-alert
- **#150** Bottom-button overlap Android nav-bar — safe-area padding-fix uitgerold naar detailscherm (#153)
- **#152** "Notificaties"-menu voor permission recovery — bij denied push kun je nu via profiel-instellingen opnieuw prompten

---

## 8. Marketing & website (buiten app, wel deze build)

Site-changes gepushed naar `pluggoapp.nl` (Cloudflare Pages) sinds v1.2.1+11:

- **Pioniers-teller live** — `pioneer_public_count` view uit migratie 0019
- **Homepage clarity** (#259) — wat is Pluggo wel/niet + paal-compatibiliteit FAQ
- **Nieuwe SEO landings:** `zonnepanelen-verdienen.html`, `goedkoop-laden.html`, `welke-laadpaal-werkt.html`, `auto-opladen-bij-particulier.html`, `salderingsregeling-alternatief.html`
- **"Vanaf €0,28/kWh" softer** (#265) — bandbreedte-formulering + eigenaar-bepaalt-zelf disclaimer
- **Softlaunch app-store links live** — Google Play + App Store buttons zichtbaar
- **Eichrecht-referenties verwijderd** — focus op privé-thuispalen, lease-palen als enige blocker
- **Cloudflare Web Analytics beacon** op alle pagina's
- **`account-verwijderen.html`** voor Google Play Data Safety compliance
- **Landing pages Mollie → Stripe** vervangen (#190)
- **Terms + Privacy** — APV-clausule (#192), self-billing (#158), continuïteit-tekst

---

## 9. Migraties in deze build (chronologisch)

| # | Bestand | Task | Deployed |
|---|---------|------|----------|
| 0018 | `iban_validation.sql` | #144 | ✅ |
| 0019 | `pioneer_auto_flag.sql` | #115 | ✅ |
| 0020 | `welcome_email_trigger.sql` | | ✅ |
| 0021 | `ocpp_charging_sessions.sql` | #269, #270 | ✅ |
| 0022 | `bookings_status_expand.sql` | #282 | ✅ |
| 0023 | `ocpp_data_model.sql` | #285 | ✅ |
| 0024 | `dev_fake_sessions.sql` | dev-tool | ✅ (dev-only) |
| 0025 | `charging_session_push_events.sql` | #288 | ✅ |
| 0026 | `charging_start_push_honest_copy.sql` | | ✅ |
| 0027 | `charging_push_soc_jargon_fix.sql` | | ✅ |
| 0028 | `booking_window_auto_stop.sql` | #291 | ✅ |
| 0029 | `booking_extend_flow.sql` | #292 | ✅ |
| 0030 | `chargers_column_grants.sql` | #188 | ✅ |
| 0031 | `quarterly_statements.sql` | #163 | ✅ |
| 0032 | `dac7_bsn_flow.sql` | #263 | ✅ (721 regels) |
| 0033 | `chargers_public_ocpp_visibility.sql` | #308 | ✅ (vandaag) |
| 0034 | `booking_starting_soon_push.sql` | #288 | ✅ (vandaag) |

---

## 10. Edge Functions in deze build

**Nieuw:**

- `submit-tin` (#263)
- `generate-quarterly-statement` (#163)
- `send-welcome-email` (#20/#244)
- `stripe-refresh-account` (#253)
- `remote-start-session` (#284)
- `remote-stop-session` (#290)
- `ocpp-provision-charger` (vandaag geschreven)
- `ocpp-deprovision-charger` (vandaag geschreven)

**Gewijzigd:**

- `send-push` (multi-event uitbreiding)
- `create-payment-stripe` (DAC7 payouts-block, refactor Stripe Checkout)

---

## 11. Nieuwe Flutter files

- `lib/live_charging_widget.dart` (763 regels)
- `lib/charging_estimator.dart` (155 regels)
- `lib/vehicle_presets.dart` (141 regels)
- `lib/push_actions.dart` (155 regels)

`lib/main.dart` is uitgebreid met CouplingWizard (~400 regels), DAC7 banners + prompt (~500 regels), booking-detail smart branching (~200 regels), en talloze kleinere wijzigingen — totaal ~21.500 regels.

---

## 12. Wat NIET in deze build zit

Bewust doorgeschoven om scope te beperken:

- **Task #272** — CSMS Security Profile 2 (Basic Auth over TLS) op productie: nog in Profile 1 (open). Prioriteit na fysieke test morgen.
- **Task #289** — Auto-stop bij target-SoC via RemoteStop: kandidaat voor v1.3.1
- **Task #274** — EV-simulator hardware: hebben we niet nodig meer, morgen echte paal
- **Task #279/#280/#281** — Internationaal (BE, DE, i18n): Q4 2026
- **Task #298** — B2B auto-bookable tijdsblokken: separate track met #277 pilot-host
- **Task #316/#317** — Onboarding tutorial slides: pending, kandidaat voor 1.3.1
- **Deep-link `pluggo://auth/confirm`** (#245): nog niet in build, gebruikers moeten voorlopig weblink openen

---

## 13. Blockers & bekende risico's voor morgen

1. **CSMS is nog in Security Profile 1** (Basic Auth over plain WebSocket, geen TLS) — voor de eerste fysieke test acceptabel, maar VOOR productie-launch van OCPP publiek moet #272 af.
2. **Nog geen echte paal getest** (#275 blocker) — morgen de eerste keer. Alles wat we tot nu weten is uit de JS-testclient (#267).
3. **DAC7 encryption key ontbreekt mogelijk in prod-env** — check `DAC7_ENCRYPTION_KEY` in Supabase secrets vóór testen (submit-tin faalt anders met 500).
4. **iOS notification categories niet geverifieerd op device** — de +15/+30/+60 lockscreen buttons moeten in Xcode → Push Notifications capability geregistreerd zijn.
5. **Version bump niet gedaan** — pubspec staat op 1.2.3+13, wil je naar 1.3.0+14 voor de review kan er verwarring komen als je met de huidige nummer submit.

---

**Volgende actie:** lees `TESTPLAN.md` voor de complete E2E scenario-lijst.
