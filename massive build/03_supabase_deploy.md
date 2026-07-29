# 03 — Supabase deploy

> Deploy-volgorde: (1) backup, (2) secrets, (3) migraties, (4) edge functions, (5) smoke.

---

## Pre-deploy

- [ ] **Backup snapshot** van productie-DB (Supabase Dashboard → Database → Backups → Create new backup, of `pg_dump` naar lokale file)
- [ ] **Zet in maintenance-mind** — geen breaking changes aan gebruikers doorvoeren zonder korte comms. Migraties 0028-0032 zijn additief, maar reken op 5-15 min waarin realtime iets kan haperen.
- [ ] **Verify huidige migratie-staat** — check `supabase_migrations.schema_migrations` — laatste toegepaste zou 0027 moeten zijn.

---

## Backwards-compatibility check

**KRITIEK:** de huidige live-app is `1.2.3+13`. Die kent NIET:

- `dac7_reporting_state` / `dac7_tin_submissions` tabellen
- Booking-extend RPC
- OCPP charging_sessions realtime schema (indien schema-wijzigingen na 0022)
- Nieuwe kolommen op `chargers` uit 0030

**Design-eis:** migraties mogen bestaande queries van de OUDE app niet breken. Dat betekent:

- Geen kolommen droppen die 1.2.3+13 nog gebruikt
- Geen NOT NULL toevoegen zonder default
- Geen RLS strenger maken op paden die 1.2.3+13 gebruikt
- Nieuwe RPCs zijn oké (oude app roept ze niet aan)
- Payouts-block in `create-payment-stripe` is oké: fired alleen wanneer owner al DAC7-drempel raakt, en dat is pas mogelijk NA deze deploy

**Actie:** loop migraties 0028 → 0032 kort door en bevestig dat elke `ALTER TABLE ... ADD COLUMN` een default heeft of nullable is. Als één van deze migraties destructive is → herzien vóór deploy.

---

## Secrets

- [ ] **`DAC7_ENCRYPTION_KEY`** — 32-byte random, base64-encoded. Zet in Supabase Dashboard → Edge Functions → Secrets. Bewaar backup in `secrets/` folder (add to `.gitignore`). Genereer met:
  ```bash
  openssl rand -base64 32
  ```
- [ ] Verify existing secrets nog steeds gezet:
  - `STRIPE_SECRET_KEY` (live)
  - `STRIPE_WEBHOOK_SECRET` (live)
  - `RESEND_API_KEY`
  - `FCM_SERVER_KEY` / APNs credentials
  - `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` (auto-set door Supabase)
- [ ] **CSMS HTTP-API shared secret** (voor remote-start/stop van edge → CSMS) — moet aan beide kanten identiek zijn.

---

## Migrations — deploy volgorde

Alle migraties in `supabase/migrations/` van 0028 en hoger. Toepasbaar via Supabase CLI:

```bash
supabase link --project-ref <prod-ref>
supabase db push
```

Of één-voor-één via Dashboard → SQL editor als je exacte controle wil.

| # | Bestand | Wat |
|---|---|---|
| 0028 | `booking_window_auto_stop.sql` | Auto-stop cron + 15-min warning trigger |
| 0029 | `booking_extend_flow.sql` | `extend_booking()` RPC + availability guard |
| 0030 | `chargers_column_grants.sql` | SECURITY DEFINER `my_chargers()` + column-level GRANTs (#241) |
| 0031 | `quarterly_statements.sql` | Kwartaaloverzicht tabel + PDF-metadata (#163) |
| 0032 | `dac7_bsn_flow.sql` | DAC7 tabellen + RPC + triggers + encryption (#263) |

**Smoke per migratie (niet één big-bang):**

Na 0028: run `SELECT * FROM pg_proc WHERE proname = 'auto_stop_booking';` — bestaat?
Na 0029: `SELECT extend_booking('<any-booking-uuid>', 15);` in staging?
Na 0030: `SELECT my_chargers();` als authenticated user?
Na 0031: check tabel `quarterly_statements` bestaat?
Na 0032: `SELECT dac7_status_for_owner();` en check dat het een row returned met promptState = 'not_required' voor een owner zonder transacties?

---

## Edge functions — deploy volgorde

```bash
supabase functions deploy submit-tin --no-verify-jwt=false
supabase functions deploy create-payment-stripe --no-verify-jwt=false
supabase functions deploy remote-start-session
supabase functions deploy remote-stop-session
supabase functions deploy generate-quarterly-statement
# de rest is ongewijzigd of al gedeployed
```

Volledige lijst functies die in productie moeten staan:

- create-payment  *(oud, kan blijven staan als fallback)*
- create-payment-opp  *(oud, kan verwijderd worden na deze deploy — apart cleanup-taak)*
- **create-payment-stripe** — GEWIJZIGD (DAC7 payouts-block)
- **generate-quarterly-statement** — NIEUW
- mollie-webhook  *(oud, mag verwijderd — apart cleanup-taak)*
- opp-onboard-merchant  *(oud, mag verwijderd)*
- opp-webhook  *(oud, mag verwijderd)*
- **remote-start-session** — NIEUW
- **remote-stop-session** — NIEUW
- send-email
- send-payment-reminders
- send-push
- send-welcome-email
- stripe-checkout-return
- stripe-onboard-account
- stripe-onboarding-return
- stripe-refresh-account
- stripe-webhook
- **submit-tin** — NIEUW (DAC7)

**Config check:** in `supabase/config.toml` — verify `verify_jwt = true` op alle functies behalve webhooks/callbacks van externe partijen.

---

## Post-migratie smoke

- [ ] `SELECT count(*) FROM bookings;` — moet gelijk zijn aan pre-deploy (geen data-verlies)
- [ ] `SELECT count(*) FROM chargers;` — idem
- [ ] `SELECT count(*) FROM profiles WHERE stripe_account_id IS NOT NULL;` — idem
- [ ] Realtime channel `charging_sessions` accepteert nog subscriptions vanuit oude app
- [ ] Één owner met een testboeking: run `SELECT dac7_status_for_owner()` als die owner → verwacht `prompt_state = 'not_required'`
- [ ] Één owner met een fake-boeking voor huidige jaar met bedrag > €2000 → verwacht `prompt_state = 'required'` en `payouts_blocked_at IS NOT NULL`

---

## Cleanup (na de dust settlet)

- Oude Mollie/OPP edge functions verwijderen (aparte taak, niet in deze deploy)
- Oude migratie-testdata purgen als die er nog is
- Backup roteren
