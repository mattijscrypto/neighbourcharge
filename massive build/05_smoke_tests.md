# 05 — Post-deploy smoke tests

> Direct na Supabase deploy uitvoeren. Voor mobile: zodra de nieuwe versie op je test-device staat (TestFlight installe + Play Internal test-track).

---

## Laag 1 — Regressie (moet ook op de OUDE app 1.2.3+13 nog kloppen)

Test met een device dat NIET geüpdatet is (of TestFlight rollback naar 1.2.3+13):

- [ ] Login → oude flow werkt
- [ ] Map opent, palen zichtbaar
- [ ] Boeking maken op bestaande paal
- [ ] Stripe Connect Express onboarding — start-fresh account
- [ ] Betaling maken via Checkout Session
- [ ] Pay-after-charge trigger nog werkt
- [ ] Chat werkt
- [ ] Reviews werken

**Als één van deze breekt** → migraties niet backwards-compatible → onmiddellijk rollback (zie 07).

---

## Laag 2 — Nieuwe features (op v1.3.0+14)

### DAC7 (#263)

- [ ] Login als test-owner die NOG onder de drempel zit → geen banner zichtbaar
- [ ] Manipuleer testdata: zet `dac7_reporting_state.total_amount_cents` naar €1600 voor huidig jaar → refresh app → **early_warning banner** zichtbaar (75%)
- [ ] Zet naar €2100 → refresh → **required banner** blocking + payouts_blocked_at wordt gezet
- [ ] Klik banner → Dac7TinPromptScreen opent → typ ongeldige BSN → live validation blokkeert submit
- [ ] Typ geldige BSN (testcase: `111222333` zou moeten falen elfproef; gebruik echte test-BSN) → submit
- [ ] Verify: `dac7_tin_submissions` heeft encrypted row, `dac7_reporting_state.tin_provided_at IS NOT NULL`, `payouts_blocked_at IS NULL`
- [ ] Retry boeking-checkout → 200, geen 409
- [ ] Booker probeert boeking te maken op een owner die WEL geblokkeerd is → 409 met NL error-msg (zie `create-payment-stripe/index.ts` return-string)

### OCPP live (#287, #293)

- [ ] Op fysieke paal: start een boeking
- [ ] Druk manual start-knop → paal opent → StartTransaction naar CSMS → sessie zichtbaar in Supabase realtime
- [ ] LiveChargingCard toont live kW / kWh / SoC
- [ ] Manual stop-knop → RemoteStopTransaction → paal sluit → sessie completed
- [ ] Vehicle preset (Tesla / VW / Kia) — verify ETA klopt binnen 10% van werkelijk

### Boekingsverlengen (#292)

- [ ] Boeking richting einde → 15-min warning push arriveert
- [ ] Op lockscreen: long-press push → action buttons zichtbaar (iOS)
- [ ] Tap "+30" → notification confirmeert → check DB: `bookings.end_at` is verlengd met 30 min
- [ ] Probeer verlengen wanneer volgende slot bezet is → RPC returned failure → notification meldt "niet mogelijk"

### Auto-stop (#291)

- [ ] Boeking loopt richting einde → RemoteStopTransaction fires automatisch → sessie completed
- [ ] Werkt ook wanneer app op achtergrond staat (cron edge function is server-side)

### Kwartaaloverzicht (#163)

- [ ] Trigger `generate-quarterly-statement` voor een owner met > 5 boekingen in vorig kwartaal
- [ ] PDF gegenereerd + gemaild via send-email
- [ ] Bedragen kloppen met sum van completed bookings
- [ ] BTW correct berekend (of KOR-notitie zichtbaar bij particulier-KOR eigenaar)

### #241 chargers grants

- [ ] Login als user A → probeer paal van user B te updaten via directe SQL — moet falen (RLS blokkeert)
- [ ] Login als user A → `SELECT * FROM my_chargers();` returned alleen eigen palen
- [ ] Anonymous user → kan alleen safe kolommen zien via public view (fuzzy locatie, geen exact adres)

---

## Laag 3 — OCPP CSMS gezondheid

- [ ] `curl https://csms.pluggoapp.nl/health` → 200
- [ ] `systemctl status pluggo-csms` → active running
- [ ] `journalctl -u pluggo-csms -f` — geen error spam
- [ ] Simulator connect via `wscat` → BootNotification accepted
- [ ] Meerdere concurrent connections (2+ palen tegelijk) → beide connected, geen resource leak

---

## Laag 4 — Externe integraties

- [ ] Stripe webhook events verwerken nog (test-event via Stripe Dashboard)
- [ ] Send-push naar test-device werkt (FCM + APNs)
- [ ] Send-email naar test-inbox arriveert (Resend)
- [ ] Google Maps geocoding + places nog werken

---

## Go/no-go criterium

- **Laag 1**: 100% groen, geen enkele fail. Anders → rollback.
- **Laag 2**: 100% groen voor DAC7 + OCPP. #291 + #292 + #163 minimaal 90%.
- **Laag 3**: 100% groen.
- **Laag 4**: minimaal 3 uit 4 groen (email is meest verstoorbaar — check twice).

Als alles groen → publiceer Pluggo Pioniers-mail en LinkedIn launch.
Als één rood → escaleer, rollback laag, opnieuw.
