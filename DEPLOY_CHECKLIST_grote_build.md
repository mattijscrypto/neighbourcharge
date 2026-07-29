# Deploy-checklist — "Grote OCPP onboarding build"

Alles wat gebouwd is deze build in één rijtje, van links naar rechts:
Flutter pubspec → Supabase (SQL + Edge Functions) → app build → smoke test.

Alles is idempotent (kan opnieuw gedraaid worden zonder rare side-effects).
Als een stap faalt: los 'm op, draai 'm nogmaals, ga door.

---

## 1. Flutter — package + build voorbereiden

```bash
cd ~/dev/neighbourcharge   # of jouw eigen pad naar de app-repo

# a. Nieuwe dependency ophalen (shared_preferences voor tutorial-flags #316/#317)
flutter pub get

# b. Statische analyse — moet 0 errors geven
flutter analyze

# c. Format check (optioneel, mooi voor commit-diff)
dart format --set-exit-if-changed lib/main.dart
```

Als `flutter analyze` klaagt over onvoorziene issues: eerst fixen voordat je verder gaat. De `main.dart` is groot; typische issues zijn hier alleen unused imports of nullable-warnings.

---

## 2. Supabase — migrations pushen

Nieuwe migraties uit deze build:
- `0033_chargers_public_ocpp_visibility.sql` (task #308 / #314 — `chargers_public` view expose `ocpp_charger_id`)
- `0034_booking_starting_soon_push.sql` (task #288 — T-15 pre-start reminder push voor smart palen)

```bash
# a. Local dry-run — checkt SQL-syntax en RLS-conflicten
supabase db lint

# b. Push naar productie
supabase db push
```

Verifieer daarna in de Supabase SQL editor:

```sql
-- 0033: view moet ocpp_charger_id kolom bevatten
select column_name
  from information_schema.columns
 where table_schema = 'public'
   and table_name   = 'chargers_public'
 order by ordinal_position;
-- verwacht: ocpp_charger_id in de lijst.

-- 0034: nieuwe kolom + index bestaan
select column_name from information_schema.columns
 where table_name = 'bookings' and column_name = 'notified_starting_soon_at';
select indexname from pg_indexes where indexname = 'bookings_starting_soon_idx';

-- 0034: cron-job draait nog steeds elke minuut
select jobname, schedule from cron.job
 where jobname = 'process-booking-window-events';
```

---

## 3. Supabase — Edge Functions (her)deployen

De koppelwizard (#311) en ontkoppel-flow (#313) leunen op deze twee functies. Die zijn al eerder gedeployed, maar deze build gebruikt ze op nieuwe call-sites — dus voor de zekerheid opnieuw pushen om zeker te weten dat productie exact overeenkomt met wat main.dart aanroept.

```bash
supabase functions deploy ocpp-provision-charger
supabase functions deploy ocpp-deprovision-charger

# En de bestaande session-controls (voor #315-banner "Start"-knop)
supabase functions deploy remote-start-session
supabase functions deploy remote-stop-session

# send-push blijft ook staan — de T-15 startwarning gaat via _cs_fire_push
# in de SQL-trigger, die intern send-push aanroept.
supabase functions deploy send-push
```

Check daarna in de Supabase Studio → Edge Functions dashboard dat elke functie status "Active" heeft en de laatste deploy-tijd van vandaag is.

---

## 4. CSMS vault-secrets (alleen als 0028/0034 al eerder is gedraaid — quick check)

De T-15 push heeft géén CSMS-secrets nodig (die gaat over `_cs_fire_push` = Supabase FCM). Auto-stop (0028) heeft ze wél. Snelle sanity-check:

```sql
select name from vault.decrypted_secrets
 where name in ('csms_http_base', 'csms_api_key');
```

Verwacht: 2 rijen. Als één van beide mist, hangt de auto-stop; zie header van 0028 voor de create-syntax.

---

## 5. App-build → TestFlight + Play internal

```bash
# Version bumpen indien nodig (huidig: 1.2.3+13)
# Pas pubspec.yaml regel `version:` aan naar bv. 1.2.4+14

# iOS build
flutter build ios --release

# Android build
flutter build appbundle --release

# Upload via Xcode Organizer (iOS) en Play Console (Android)
```

Voor iOS: eerst in Xcode `Product → Archive` → Distribute → App Store Connect. Vandaar door naar TestFlight interne testers.

Voor Android: `.aab` uit `build/app/outputs/bundle/release/` uploaden naar de Play Console → Internal testing track.

---

## 6. Smoke test op echt device (na TestFlight/Play internal install)

Kort scriptje om te bevestigen dat de build doet wat 'ie moet:

1. **Onboarding (#317)** — verse install → welkom-slides verschijnen → "Aan de slag" → landt op LoginScreen. Uninstall + reinstall om herhaalbaar te testen.
2. **Paal-aanmaak vertakking (#310)** — voeg testpaal toe → kies "smart" → CouplingWizard opent. Kies "manueel" → naar AvailabilityScreen.
3. **Koppelwizard (#311/#312)** — merk → instructies → gegevens invullen → test verbinding (kan bij dev-paal DEV-FAKE gebruiken). Klik "Hulp nodig?" → mail-composer opent met pre-filled body.
4. **Ontkoppelen (#313)** — bewerk een gekoppelde paal → "Ontkoppelen" → dialog bevestig → status update.
5. **Map differentiatie (#308/#314)** — publieke kaart toont smart-badge/manueel-badge onder paalnaam. Detail-scherm toont badge + caption.
6. **Banner (#315)** — maak boeking op smart paal → wacht tot 15 min voor start → open paal-detail → groene banner met countdown + "Start"-knop bovenaan zichtbaar.
7. **Tutorial (#316)** — verse install + eerste smart-booking → succesdialog → 3-slide tutorial → volgende smart-booking laat 'em NIET meer zien.
8. **T-15 push (#288)** — boek smart paal 14 min in de toekomst → wacht ≤2 min → OS-push binnen: "Je laadsessie begint zo".

---

## 7. Vergeet niet — post-deploy

- [ ] Task-status flippen in je tracker: #310 t/m #317 + #288 → completed.
- [ ] Release-notes bijwerken op pluggoapp.nl met de OCPP-features (zichtbaar bij "Wat is er nieuw").
- [ ] Als je nieuwe testers wilt: `insert into public.bypass_emails (email) values ('...')` in de SQL editor (dynamische bypass, geen rebuild nodig).

---

## Samenvatting in één minuut

```bash
# Terminal
cd ~/dev/neighbourcharge
flutter pub get
flutter analyze
supabase db push
supabase functions deploy ocpp-provision-charger ocpp-deprovision-charger remote-start-session remote-stop-session send-push
flutter build ios --release
flutter build appbundle --release
# → daarna Xcode Archive + Play Console upload
```

Alles wat je in de Supabase Studio nog handmatig moet doen: één keer verifiëren dat 0033 + 0034 daadwerkelijk zijn geland (queries hierboven). Verder niets.
