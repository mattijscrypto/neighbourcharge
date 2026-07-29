# 04 — Flutter build

> Volgorde: version bump → clean build → TestFlight → App Store submit → Play Console Closed Track → Play productie release. iOS-review kan 1-3 dagen duren, plan comms daaromheen.

---

## Version bump

**Huidig live:** `1.2.3+13`
**Doel:** `1.3.0+14`

Rationale major-minor bump (1.2 → 1.3): OCPP + DAC7 + boekingsverlengen zijn substantiële feature-toevoegingen, niet patches. Als je liever incrementeel bumpt zou 1.2.4+14 kunnen, maar dan verlies je signalling naar gebruikers dat er iets nieuws is.

**Actie:**

```yaml
# pubspec.yaml regel 5
version: 1.3.0+14
```

Ook checken:

- `android/app/build.gradle` — `versionCode` en `versionName` (mag afgeleid uit pubspec, verify)
- `ios/Runner/Info.plist` — `CFBundleShortVersionString` + `CFBundleVersion` (mag afgeleid, verify)

---

## Pre-build checklist

- [ ] `flutter pub get`
- [ ] `flutter analyze` — 0 errors, warnings screenen
- [ ] `flutter test` — alle tests groen (indien tests bestaan)
- [ ] `dart run` op main.dart brace/paren balance sanity check
- [ ] Verify dat DAC7-flow icon assets aanwezig zijn (banner icons — zijn deze nodig? Check Dac7Banner implementatie)
- [ ] Verify pluggo-csms env-var of `csms.pluggoapp.nl` hardcoded is in edge functions (moet configureerbaar, of duidelijk gedocumenteerd)
- [ ] Verify iOS notification categories geregistreerd voor #292 lockscreen action buttons
- [ ] Verify Android notification action receivers geregistreerd voor #292

---

## iOS build

```bash
flutter build ios --release
# open ios/Runner.xcworkspace in Xcode
# Product → Archive
# Distribute App → App Store Connect → Upload
```

**Xcode dingen om te checken:**

- Signing team correct
- Provisioning profile up-to-date
- Bundle ID: `nl.pluggo.app` (of wat er nu draait — verify)
- Push notification entitlement aanwezig
- Background modes: remote notifications + audio (voor als er sound zit op OCPP-alerts?) → alleen wat écht nodig is
- Info.plist strings up-to-date (NSCameraUsageDescription, NSLocationWhenInUseUsageDescription, NSPhotoLibraryUsageDescription)

**Na upload:**

1. Wacht ~15 min tot build in TestFlight verschijnt
2. Interne test: install via TestFlight op eigen device, doorloop happy path
3. Extern: 1-2 Pluggo Pioniers als beta tester toevoegen (optioneel — of skip en direct submit)
4. Submit for App Review:
   - **App Store Connect → Versies → 1.3.0**
   - Update "What's New in this Version": zie template hieronder
   - Bijgewerkte reviewer notes plakken uit `_internal/app_store_reviewer_notes.md` (moet eerst geactualiseerd — zie 06_gaps_and_open_items.md)

**Template "What's New in this Version" (NL):**

```
Deze update brengt live laadinformatie, boekingsverlengen vanuit je vergrendelscherm, en OCPP-integratie voor slimme starten/stoppen van je laadsessie.

• Zie realtime je laadvermogen, State of Charge en verwachte eindtijd tijdens het opladen
• Verleng je boeking direct vanaf je vergrendelscherm met +15/+30/+60 minuten
• Automatische stop wanneer je boekingstijd afloopt, met een waarschuwing 15 minuten vooraf
• Voor paaleigenaren: kwartaaloverzichten voor je administratie

Kleine bugfixes en snelheidsverbeteringen inbegrepen.
```

**Vertaling EN (voor App Store multi-locale):**

```
This update brings live charging info, extending your booking from your lock screen, and OCPP integration for smart start/stop of your session.

• See your real-time power, state of charge, and estimated end time while charging
• Extend your booking directly from your lock screen with +15/+30/+60 minutes
• Automatic stop when your booked window ends, with a 15-minute heads-up
• For charger owners: quarterly statements for your admin

Small bug fixes and performance improvements included.
```

---

## Android build

```bash
flutter build appbundle --release
# output: build/app/outputs/bundle/release/app-release.aab
```

**Play Console:**

1. **Closed Track eerst** — internal testing → upload .aab → propageer naar test-account → smoke on device
2. **Production release** — upload .aab (of promote van Closed Track) → release notes plakken (zelfde tekst als iOS "What's New")
3. **Rollout %:** starten met 20% staged rollout is voorzichtig, of 100% als E2E-test alle boxes tikt en je vertrouwen hebt
4. Play Data Safety form — check of nieuwe DAC7-data-collection expliciet vermeld moet (Personal info → Government ID → BSN). Waarschijnlijk ja. Voeg toe indien nog niet.

---

## App Store & Play Console — bijgewerkte metadata

- [ ] **App Store Connect Privacy Nutrition Labels** — voeg "Government ID" toe (BSN/RSIN voor paaleigenaren die drempel raken)
- [ ] **Play Data Safety** — idem
- [ ] **Screenshots** — check of iets sterk veranderd is dat nieuwe screenshots vereist (LiveChargingCard is nieuw en visueel prominent — potentiële nieuwe screenshot #4?)
- [ ] **App description** — hoeft niet, maar overweeg toevoegen "live laadinformatie" bij feature-bullets
- [ ] **Keywords iOS** — geen aanpassing nodig

---

## Post-approval

- **iOS:** zodra Apple approves — kies "Manual Release" i.p.v. "Automatic" zodat je het moment kan coordineren met Play productie push en Pioniers-comms
- **Android:** als productie al is uitgerold — pauzeer eventueel de staged rollout tot iOS ook live is, om iOS-users niet achter te laten
- **Beide live:** verstuur Pioniers-mail + LinkedIn-post + Facebook launch (zie 06_gaps_and_open_items.md)

---

## Rollback

Zie 07_rollback_plan.md. Voor Flutter specifiek: er is geen "downgrade" in stores. Als er iets goed mis is:

- Play Store: halt rollout en publish 1.3.1+15 met fix
- App Store: expedited review request bij Apple + 1.3.1+15 hotfix

Cushion: min-supported-version check in de app zelf zodat je een kill-switch hebt (verify of die er zit — anders overwegen om nu snel toe te voegen).
