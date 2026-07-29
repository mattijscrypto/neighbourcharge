# Pluggo — Massive Build Roadmap

> **Strategie:** big-bang deploy. Alles wat sinds v1.2.3+13 (huidige live-build) in code staat gaat in één ronde live.
> **Blocker:** OCPP moet eerst getest zijn op een echte fysieke paal (#273 + #275). Zonder groen licht daar gaat er niets naar de app-stores.
>
> **Huidige live-versie:** `1.2.3+13`
> **Doel-versie na build:** `1.3.0+14` (major bump want OCPP + DAC7 + boekingsverlengen zijn nieuwe features)

---

## Volgorde-lock (mag niet worden omgedraaid)

1. **Pre-build blockers groen** — zie `01_pre_build_blockers.md`
   - ✅ Hetzner VPS live met CSMS (#266) — DONE (CPX12, 46.224.132.111, Falkenstein)
   - 🟡 Tweedehands OCPP-paal binnen (#273)
   - ⏸ Fysieke E2E-test: paal → CSMS → Supabase → app happy-path (#275)
2. **Supabase deploys** — zie `03_supabase_deploy.md`
   - Migrations 0028 → 0032 op productie
   - Alle nieuwe/gewijzigde edge functions
   - `DAC7_ENCRYPTION_KEY` secret gezet in Supabase
3. **Flutter build + submissies** — zie `04_flutter_build.md`
   - Version bump naar 1.3.0+14
   - iOS TestFlight → App Store review
   - Android Closed Track → Production
4. **Post-live smoke tests** — zie `05_smoke_tests.md`
5. **Communicatie naar Pluggo Pioniers** — zie `06_gaps_and_open_items.md`

---

## Wat gaat er allemaal live in deze build

Volledig detail in `02_code_inventory.md`. Kort:

- **#241** — SECURITY DEFINER `my_chargers()` + column-level GRANTs op `chargers` (migratie 0030)
- **#263** — DAC7 BSN-drempelflow (migratie 0032 + `submit-tin` edge function + `create-payment-stripe` payouts-block + Flutter UI)
- **#287** — Live laadschatting UI (LiveChargingCard widget)
- **#292** — Boekingsverlengen via lockscreen action buttons (extend_booking RPC + push_actions.dart)
- **#293** — OCPP start/stop knoppen op booking-detailscherm
- **#163** — Kwartaaloverzicht-engine (migratie 0031 + generate-quarterly-statement edge function)
- **#289** — (optioneel, kandidaat) Auto-stop bij target-SoC via RemoteStopTransaction

Plus de OCPP-stack die op de VPS draait (buiten de app om, maar wél nieuw en live-gaand):

- OCPP 1.6J CSMS op `csms.pluggoapp.nl` (pluggo-csms folder → Hetzner VPS)
- WebSocket-server + Supabase realtime bridge
- Remote start/stop via edge functions

---

## Rollback

Zie `07_rollback_plan.md`. Kort: elke laag heeft een eigen rollback-pad. Supabase migraties zijn additief (geen destructive drops in 0028-0032), edge functions kunnen naar vorige versie, en de mobile builds kunnen niet echt "terug" — dus de app moet backwards-compatible zijn met de OUDE database. Dat is een expliciete design-eis, zie `03_supabase_deploy.md`.

---

## Checklist (top-level)

- [ ] Pre-build blockers 100% groen
- [ ] Supabase productie backup gemaakt (pre-deploy snapshot)
- [ ] Migrations gedeployed + smoke check
- [ ] Edge functions gedeployed + secrets gezet
- [ ] Flutter build 1.3.0+14 gemaakt (iOS + Android)
- [ ] TestFlight interne test doorlopen
- [ ] App Store submission (met bijgewerkte reviewer notes)
- [ ] Google Play Closed Track smoke
- [ ] Google Play productie release
- [ ] iOS release na Apple-approval
- [ ] privacy.html DAC7-blok live
- [ ] app_store_reviewer_notes.md geactualiseerd (Stripe live-mode + DAC7 + OCPP)
- [ ] FAQ / T&Cs updates live
- [ ] Pluggo Pioniers-mail verstuurd
- [ ] LinkedIn / Facebook launch-post
- [ ] Post-live smoke tests groen
- [ ] Bij groen licht: date deze roadmap als "shipped" en archiveer

---

## Bestandsindex in deze folder

- `ROADMAP.md` — dit bestand (master overzicht)
- `01_pre_build_blockers.md` — de gate die dicht blijft tot OCPP is gevalideerd
- `02_code_inventory.md` — wat er per feature in de codebase klaar staat
- `03_supabase_deploy.md` — DB migraties, edge functions, secrets, deploy-volgorde
- `04_flutter_build.md` — version bump, TestFlight, App Store, Play Console
- `05_smoke_tests.md` — end-to-end validatie na de deploy
- `06_gaps_and_open_items.md` — dingen die makkelijk vergeten worden (privacy.html DAC7, reviewer notes, FAQ, comms)
- `07_rollback_plan.md` — plan B per laag
