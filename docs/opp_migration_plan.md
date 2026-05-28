# OPP (Online Payment Platform) migratie — implementatieplan

**Status:** v1 — draft  
**Auteur:** Mattijs + Claude  
**Datum:** 21 mei 2026  
**Vervangt:** `mollie_connect_refactor_plan.md` (gearchiveerd, Mollie Connect bleek niet geschikt — particulieren konden niet onboarden als Connected Merchant)  
**Cutover doel:** 26 juni 2026 (10 dagen voor 7 juli boekingen-launch)  
**Geschatte effort:** 14-18 werkdagen, 3-4 weken doorlooptijd

---

## 1. Achtergrond & beslissing

Pluggo's huidige Mollie Payments-integratie laat álle geld via één Pluggo-bankrekening lopen, waarna Pluggo het deel van de paaleigenaar handmatig uitbetaalt. Onder PSD2 / Wft is dat aanhouden van "geld voor derden" en vergunningsplichtig. We hadden Mollie Connect als oplossing gekozen, maar Mollie bevestigde dat alleen **bedrijven met KvK-inschrijving** als Connected Merchant kunnen onboarden — niet particulieren. Aangezien >95% van de paaleigenaren particulier is, was Mollie Connect een dealbreaker voor v1.

**Online Payment Platform (OPP)** is de Nederlandse marketplace-PSP met eigen PSD2-vergunning die *wél* particuliere "consumer merchants" ondersteunt via getrapte KYC. Pluggo blijft buiten de geldstroom (geen Wft-vergunning nodig), elke paaleigenaar krijgt een eigen OPP-merchant, en geld stroomt rechtstreeks van boeker naar paaleigenaar minus een platform-fee voor Pluggo.

## 2. Kerneigenschappen OPP (research samenvatting)

| Aspect | OPP |
|---|---|
| API base (sandbox) | `https://api-sandbox.onlinebetaalplatform.nl/v1/` |
| API base (productie) | `https://api.onlinebetaalplatform.nl/v1/` (verifiëren bij sales) |
| Files API (sandbox) | `https://files-sandbox.onlinebetaalplatform.nl/v1/uploads` |
| Auth | Bearer-token (partner API-key) |
| Particulieren ondersteund | Ja, via "consumer merchant" |
| KYC-getrap | Level 100 (created) → 200 (Low KYC, bankaccount verified) → 400 (High KYC, iDIN) |
| Low KYC drempels | €250/transactie of €1.500 lifetime → daarna iDIN verplicht |
| iDIN seamless redirect | Ja, via `payment_method=ideal&issuer={SWIFT}` |
| Compliance-check OPP | Binnen 24u op werkdagen |
| Transactie-creatie | Voor full price naar `merchant_uid` (paaleigenaar) |
| Platform fee mechaniek | Te bevestigen bij sales — vermoedelijk via partner balance settlement of split-payload |
| Webhook (notify_url) | Per merchant + per transactie configureerbaar, `verification_hash` voor signatuur |
| Escrow | Beschikbaar (kunnen we negeren voor v1) |

### Open vragen voor OPP sales/integratie-call

1. Exacte pricing iDEAL (per transactie) en kosten KYC per merchant
2. Hoe wordt Pluggo's platform-fee (€0,06/kWh) afgehouden — split-payload in `/transactions` of partner balance settlement achteraf?
3. Self-billing factuur (art. 35e Wet OB) — genereert OPP die zelf voor particulieren of moeten wij dat blijven doen?
4. Production base URL bevestigen (`onlinebetaalplatform.nl` vs `onlinepaymentplatform.com`)
5. Webhook signatuur — hoe verifiëren we `verification_hash`? HMAC-SHA256 met partner secret?
6. Onboarding fee voor consumer KYC level 400 — wie betaalt (platform of merchant)?

## 3. Architectuur na migratie

```
Boeker (Flutter app)
  │
  │ 1. POST /functions/create-payment  (booking_id)
  ▼
Edge Function (Supabase)
  │
  │ 2. POST {OPP}/v1/transactions
  │     { merchant_uid: paaleigenaar.opp_merchant_uid,
  │       total_price: bedrag_in_cents,
  │       products: [...],
  │       partner_fee: pluggo_fee_cents,  ← TE BEVESTIGEN
  │       return_url, notify_url, metadata }
  ▼
OPP API
  │
  │ 3. response { transaction_uid, redirect_url, status:'created' }
  ▼
Edge Function
  │
  │ 4. INSERT INTO payments (opp_transaction_uid, ...)
  │    UPDATE bookings SET payment_status='pending'
  │
  │ 5. return { checkout_url: redirect_url } → app opent in browser
  ▼
Boeker betaalt iDEAL → OPP routeert geld → paaleigenaar's opp_merchant_uid
  │
  │ 6. OPP POST webhook → /functions/opp-webhook
  ▼
Edge Function
  │
  │ 7. GET {OPP}/v1/transactions/{uid} (server-side verifiëren)
  │    UPDATE payments + bookings SET payment_status='paid'
  │    Trigger: invoice-engine genereert self-billing PDF
  ▼
Paaleigenaar krijgt automatisch uitbetaald door OPP (niet door Pluggo)
```

## 4. Datamodel — Migratie 0012

Nieuwe migratie `supabase/migrations/0012_opp_payment_schema.sql` voegt OPP-velden toe **náást** de bestaande Mollie-kolommen. Tijdens cutover-periode draaien beide; in 0013 droppen we de Mollie-kolommen.

### profiles uitbreidingen
- `opp_merchant_uid` text unique — OPP merchant ID
- `opp_compliance_level` smallint default 0 — 100/200/400
- `opp_compliance_status` text — 'unverified' | 'verified' | 'rejected' | 'review'
- `opp_can_receive_payments` boolean default false
- `opp_can_receive_payouts` boolean default false
- `opp_bank_account_uid` text
- `opp_bank_account_status` text — 'new' | 'pending' | 'approved' | 'disapproved'
- `opp_contact_uid` text — voor consumer merchant
- `business_type` enum — 'particulier' | 'eenmanszaak' | 'bv' | 'overig'
- `kvk_number` text
- `vat_number` text
- `vat_status` enum — 'none' | 'kor' | 'btw_plichtig'
- `invoice_counter` integer default 0 — voor zelfgenereerde Pluggo platform-facturen (KOR)
- `ytd_revenue_cents` bigint default 0 — informatief, niet voor real-time KOR-warnings (uit scope v1)

### bookings uitbreidingen
- `owner_vat_amount_cents` integer — alleen ingevuld bij BTW-plichtige paaleigenaar
- `platform_fee_vat_cents` integer — BTW op Pluggo's €0,06/kWh (21%)

### payments uitbreidingen
- `opp_transaction_uid` text unique — vervangt mollie_payment_id
- `platform_fee_cents` integer — wat Pluggo afhoudt
- `owner_payout_cents` integer — wat de paaleigenaar krijgt (incl. of excl. BTW afhankelijk van vat_status)
- `opp_status` text — OPP's transaction status (created/pending/completed/failed/cancelled/expired)

### Nieuwe tabel: invoices
Self-billing facturen voor paaleigenaren + Pluggo's eigen platform-facturen.
```sql
create table public.invoices (
  id                     uuid primary key default gen_random_uuid(),
  booking_id             uuid references public.bookings(id) on delete restrict,
  payment_id             uuid references public.payments(id) on delete restrict,
  invoice_type           text not null check (invoice_type in ('self_billing_owner','platform_fee_pluggo')),
  invoice_number         text not null unique,
  recipient_profile_id   uuid references public.profiles(id),
  issuer_profile_id      uuid references public.profiles(id),
  subtotal_cents         integer not null,
  vat_amount_cents       integer not null default 0,
  total_cents            integer not null,
  vat_rate              numeric(4,2) not null default 0,
  vat_clause             text,  -- 'art 25 Wet OB (KOR)' / 'art 35e Wet OB (self-billing)' / null
  pdf_url                text,
  issued_at              timestamptz not null default now(),
  created_at             timestamptz not null default now()
);
```

### payouts tabel: deprecated
Onder OPP gaat de paaleigenaar zijn geld rechtstreeks van OPP krijgen, niet via Pluggo. We droppen `payouts` in 0013 ná cutover. Voor backward compat blijft 'm in 0012 staan maar wordt 'm niet meer beschreven.

## 5. Implementatie fasen

### Fase A — Voorbereiding (parallel: gebruiker doet aanvraag)
- [x] OPP API research → `docs/opp_api_research.md` (deze doc dient als research-output)
- [ ] OPP partneraanvraag (USER) — start onboarding op https://onlinepaymentplatform.com/contact, vraag expliciet: marketplace v1, ~200 consumer merchants, NL only, low-friction onboarding voor particulieren
- [ ] Sales-call met OPP — pricing, fee-mechaniek, self-billing, productie URL bevestigen
- [ ] Sandbox credentials in handen → partner_id, API key, partner_slug

### Fase B — Datalaag
- [ ] DB-migratie 0012 schrijven (zie sectie 4) — *deze taak: nu starten*
- [ ] Migratie testen op een Supabase dev-branch
- [ ] RLS-policies voor `invoices` tabel
- [ ] Helper SQL views: `merchant_onboarding_status`, `pending_invoices`

### Fase C — Edge functions
- [ ] Nieuwe Edge Function `create-payment-opp` (naast bestaande create-payment)
- [ ] Nieuwe Edge Function `opp-webhook` (vervangt mollie-webhook na cutover)
- [ ] Edge Function `opp-onboard-merchant` — wordt aangeroepen vanuit Flutter na BTW-vragenlijst
- [ ] Edge Function `opp-bank-verify-redirect` — geeft seamless iDEAL redirect-URL terug
- [ ] Edge Function `generate-self-billing-invoice` — genereert PDF na payment completed
- [ ] Idempotency guard hergebruiken uit bug #72 fix (per booking_id)
- [ ] Webhook signatuur verifiëren met `verification_hash`

### Fase D — Flutter onboarding-flow
- [ ] BTW-vragenlijst-scherm (ondernemer? KvK? VAT? → schrijft naar profiles.business_type/vat_status)
- [ ] OPP merchant aanmaken-scherm (server-side call, polling tot success)
- [ ] Bankrekening-koppelen-scherm (seamless iDEAL-redirect of bank-detail-formulier)
- [ ] Identity-verificatie-scherm (alleen tonen als compliance_level=400 nodig is, met iDIN-redirect)
- [ ] Onboarding status-overzicht op profile-screen
- [ ] Paal-publicatie blokkeren tot `opp_can_receive_payments=true`

### Fase E — Boekflow refactor
- [ ] BookingScreen → roept nu `create-payment-opp` aan i.p.v. `create-payment`
- [ ] Payment success / failure handling: lezen van `payments.opp_status`
- [ ] In-app weergave van transactie-details (welk deel naar wie)

### Fase F — Self-billing engine
- [ ] PDF-template voor self-billing factuur (factuur door Pluggo namens paaleigenaar)
- [ ] PDF-template voor Pluggo's eigen platform-fee factuur (KOR-clausule "art 25 Wet OB")
- [ ] Resend mail-trigger na PDF-generatie (paaleigenaar krijgt mail met PDF-bijlage)
- [ ] Supabase Storage bucket `invoices/` met RLS

### Fase G — Privacy + ToS
- [ ] `privacy.html` updaten: vervanging Mollie door OPP, KYC-verwerking door OPP, bewaartermijnen
- [ ] `terms.html` updaten: self-billing-clausule (paaleigenaar machtigt Pluggo om namens hem te factureren — art. 35e Wet OB), OPP als payment processor
- [ ] BTW-vragenlijst FAQ in `terms.html`

### Fase H — Cutover & verificatie
- [ ] E2E smoke test op sandbox: testgebruiker → BTW-quiz → merchant aanmaken → bankrekening → identiteit (mock iDIN) → testboeking → iDEAL test → webhook → factuur → uitbetaling
- [ ] Live-mode switch: productie API-key, productie webhook URLs, real partner_slug
- [ ] Bestaande Mollie testdata in `payments` migreren of archiveren
- [ ] €1,79 test-saldo bij OPP (zelfde aanpak als Mollie sandbox-test)
- [ ] Mollie Connect plan gearchiveerd, Mollie standalone-account afsluiten of behouden voor backup

## 6. Pricing impact (te bevestigen bij OPP sales)

Voorlopige aanname op basis van marktconforme tarieven (Mollie iDEAL = €0,29 ex BTW):

| Item | Geschat OPP-tarief | Pluggo-impact |
|---|---|---|
| iDEAL transactie | €0,29-€0,35 ex BTW | Verwerkt in €0,40 small-session fee + Pluggo's €0,06/kWh |
| KYC consumer level 200 | €0 (alleen bankcheck) | Geen, betalen we eenmalig |
| KYC consumer level 400 (iDIN) | €0,50-€1,50 per onboarding | Niet doorbelasten in v1 — kost weinig zolang we onder Low KYC blijven |
| Maandelijkse partner fee | €99-€199 | Neem mee in winst-en-verlies |
| Refund kosten | Mogelijk €0,25-€0,50 | Doorbelasten of accepteren als platform-kost |

→ **Actie:** OPP sales bevestigen, dan exacte cijfers in `pricing_model.md` zetten.

## 7. KOR & BTW (ongewijzigd t.o.v. Mollie Connect plan)

- **Pluggo BV** staat in KOR via bestaande KvK → platform fees zijn vrijgesteld van BTW (clausule "art. 25 Wet OB").
- **Paaleigenaar** → afhankelijk van vat_status:
  - `none` (particulier zonder KvK): geen BTW, factuur zonder BTW
  - `kor` (KOR-ondernemer): geen BTW, clausule "art. 25 Wet OB" op factuur
  - `btw_plichtig` (BTW-plichtige ondernemer): 21% BTW op stroomdeel, Pluggo factureert namens paaleigenaar (self-billing art. 35e Wet OB)
- Realtime KOR-drempelwaarschuwingen blijven uit scope v1 (niemand komt boven €20k bijverdienste met laadpaal-sharing).

## 8. Cutover-strategie

**Parallelle run periode:** 14 dagen (12 juni — 26 juni).
- Beide endpoints `create-payment` (Mollie) en `create-payment-opp` (OPP) actief.
- Nieuwe boekingen gaan default naar OPP zodra paaleigenaar OPP-onboarded is.
- Paaleigenaren zonder OPP-onboarding krijgen een "voltooi je payment-setup om boekingen te ontvangen" banner.
- Cutover op 26 juni: feature flag `usePppForPayments=true`, oude Mollie-endpoint terug naar 410 Gone.
- Mollie test data wordt geëxporteerd, niet gemigreerd (te weinig data om te benodigen).

## 9. Risico's & mitigaties

| Risico | Kans | Mitigatie |
|---|---|---|
| OPP sales-call duurt >5 werkdagen | Middel | Aanvraag dinsdag indienen, pas in week 21 ECHT bouwen, plan-doc nu klaar zodat alles klaar staat |
| OPP pricing onverwacht hoog | Laag | Worst-case nog steeds onder PSD2-vergunning route; valt mee bij hun marketplace-focus |
| KYC level 400 vereist iDIN-koppeling die wij niet hebben | Laag | OPP regelt iDIN-redirect zelf, wij hoeven alleen de redirect-URL door te geven |
| Self-billing factuur niet conform Belastingdienst | Middel | Juridisch consult #158 dekt dit — clausule op factuur + ondertekend "Self-billing overeenkomst" via T&Cs |
| Particuliere paaleigenaar weigert bankrekening-verificatie | Hoog | Geen onboarding = geen publicatie van paal. Helder in onboarding flow communiceren. |
| Productie partner ID vertraagt cutover | Middel | Sandbox-werk afronden, productie-keys pas activeren bij go-live op 26 juni |

## 10. Gerelateerde docs

- `docs/mollie_connect_refactor_plan.md` — gearchiveerd, niet meer geldig
- `supabase/migrations/0001_mollie_payment_schema.sql` — huidige schema (Mollie)
- `supabase/migrations/0012_opp_payment_schema.sql` — nieuwe migratie (te schrijven)
- OPP guides: https://guides.onlinepaymentplatform.com/
- OPP API docs: https://docs.onlinepaymentplatform.com/

---

## Appendix A — Voorbeeld POST bodies (uit OPP docs)

### Consumer merchant aanmaken
```http
POST https://api-sandbox.onlinebetaalplatform.nl/v1/merchants
{
  "country": "nl",
  "emailaddress": "paaleigenaar@example.com",
  "phone": "+31612345678",
  "notify_url": "https://pluggo.app/functions/v1/opp-webhook"
}
```

### Bankrekening aanmaken
```http
POST https://api-sandbox.onlinebetaalplatform.nl/v1/merchants/{merchant_uid}/bank_accounts
{
  "return_url": "https://pluggo.app/onboarding/bank-return",
  "notify_url": "https://pluggo.app/functions/v1/opp-webhook"
}
```

### Transactie aanmaken (boeking-betaling)
```http
POST https://api-sandbox.onlinebetaalplatform.nl/v1/transactions
{
  "merchant_uid": "{paaleigenaar_opp_uid}",
  "products": [{
    "name": "Laadsessie 12 kWh @ €0,34/kWh",
    "price": 408,
    "quantity": 1
  }],
  "total_price": 408,
  "payment_method": "ideal",
  "return_url": "https://pluggo.app/booking-paid/{booking_id}",
  "notify_url": "https://pluggo.app/functions/v1/opp-webhook",
  "metadata": {
    "booking_id": "{uuid}",
    "platform_fee_cents": "72"
  }
}
```

### Webhook payload (transaction.status.changed)
```json
{
  "uid": "{notification_uid}",
  "type": "transaction.status.changed",
  "created": 1621944238,
  "object_uid": "{transaction_uid}",
  "object_type": "transaction",
  "object_url": "https://api-sandbox.onlinebetaalplatform.nl/v1/transactions/{transaction_uid}",
  "verification_hash": "f81fed5c48918d..."
}
```
