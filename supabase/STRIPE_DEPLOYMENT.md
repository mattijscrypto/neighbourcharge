# Stripe Connect — deployment checklist

Pluggo's Stripe Connect Express (Accounts v2) integratie. Volgorde van uitvoeren is
belangrijk: secrets → migratie → functions → webhook registreren → test.

## 1. Supabase secrets zetten

```bash
# Test mode (nu meteen)
supabase secrets set STRIPE_SECRET_KEY=sk_test_<jouw_test_secret_key>
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...   # invullen na stap 4
supabase secrets set APP_DEEP_LINK_SCHEME=pluggo
```

```bash
# Live mode (na marketplace approval + 7 juli go-live)
supabase secrets set STRIPE_SECRET_KEY=sk_live_...
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
```

## 2. DB-migratie uitvoeren

```bash
supabase db push
```

Verifieer:
- `profiles.stripe_account_id` kolom bestaat
- `payments.stripe_payment_intent_id` kolom bestaat
- Tabel `stripe_webhook_events` bestaat
- View `stripe_onboarding_overview` query'baar

## 3. Edge Functions deployen

```bash
supabase functions deploy stripe-onboard-account
supabase functions deploy create-payment-stripe
supabase functions deploy stripe-webhook --no-verify-jwt
```

De `--no-verify-jwt` flag voor stripe-webhook is overbodig als `config.toml`
goed staat (zie regel `[functions.stripe-webhook] verify_jwt = false`), maar
schaadt niet.

## 4. Webhook endpoint registreren in Stripe Dashboard

Ga naar `https://dashboard.stripe.com/test/webhooks` → **Add endpoint**.

- **URL**: `https://<project-ref>.supabase.co/functions/v1/stripe-webhook`
- **API version**: laat default (latest)
- **Events**:
  - `payment_intent.succeeded`
  - `payment_intent.payment_failed`
  - `payment_intent.canceled`
  - `charge.refunded`
  - `account.updated`
  - `v2.core.account.updated` (als beschikbaar in v2 webhook config)

Kopieer het signing secret (`whsec_...`) → terug naar stap 1.

## 5. End-to-end test (test mode)

1. Maak nieuwe Pluggo-paaleigenaar test-account aan
2. Vul BTW-vragenlijst in
3. Trigger `stripe-onboard-account` vanuit Flutter
4. Doorloop Stripe-hosted KYC met test data
   - Test SSN: `000-00-0000`
   - Test IBAN: `NL39RABO0300065264` (Rabobank test)
   - Test telefoon: `+31201234567`
5. Verifieer dat `account.updated` webhook arriveert in
   `stripe_webhook_events` tabel
6. Verifieer dat `profiles.stripe_charges_enabled = true` na webhook
7. Maak boeking → eigenaar accepteert → vult kWh in → betaalverzoek
8. Boeker triggert `create-payment-stripe` → Flutter toont PaymentSheet
9. Betaal met testkaart `4242 4242 4242 4242` of iDEAL test
10. Verifieer `payment_intent.succeeded` webhook + booking
    `payment_status = 'paid'`

## 6. Cutover Mollie/OPP → Stripe

Plan: `0014_drop_legacy_psp.sql` na 7 juli 2026. Tot die tijd draaien
mollie/opp/stripe parallel. Flutter app selecteert PSP op basis van
welke kolommen op het profiel staan (stripe_account_id wint).
