# 06 — Gaps & open items

> Dingen die makkelijk vergeten worden bij een big-bang deploy. Gevonden via gap-scan van de codebase op 8 juli 2026.

---

## Kritiek — moet vóór de deploy geregeld zijn

### 1. `docs/privacy.html` mist DAC7 / BSN-blok

**Bevinding:** grep op `docs/privacy.html` naar `DAC7|BSN|belastingdienst|belastingnummer` → 0 hits.

**Waarom kritiek:** vanaf deze deploy verzamelen we BSN/RSIN van paaleigenaren die de drempel raken. Onder AVG art. 13 moet je bij verzameling van bijzondere persoonsgegevens (BSN valt daaronder) de betrokkene informeren over doel, grondslag, bewaartermijn, en delen met derden (Belastingdienst). Als de privacy policy dit niet noemt, staat de app open voor AVG-claims én kan de Belastingdienst dit als niet-transparante verwerking aanmerken.

**Actie voor deploy:**

- [ ] Nieuwe sectie in privacy.html — "Belastingrapportage (DAC7)":
  - Wat we verzamelen: BSN of RSIN
  - Grondslag: wettelijke verplichting (Art. 10c AWR + Uitv.reg. WIB art. 8, EU-richtlijn 2021/514)
  - Wanneer: bij nadering / overschrijding van ≥30 transacties of ≥€2.000 in kalenderjaar
  - Doel: jaarlijkse rapportage aan Belastingdienst
  - Bewaartermijn: 10 jaar (fiscale bewaarplicht)
  - Beveiliging: encryptie at rest (AES-256-GCM), alleen laatste 4 cijfers zichtbaar in app
  - Rechten: inzage, correctie via support@pluggoapp.nl (BSN kan niet worden gewist zolang rapportageplicht geldt)
- [ ] Ook terms.html §4 uitbreiden: "Fiscale gegevens" sectie verwijzen naar DAC7-verplichting

Terms.html noemt al Belastingdienst 2x (fiscale advies-disclaimer) — dat is een startpunt maar niet voldoende voor de nieuwe BSN-verzameling.

### 2. `_internal/app_store_reviewer_notes.md` is stale

**Bevindingen:**

- Vermeldt "Mollie is in TEST mode" — Pluggo draait sinds v1.2.0 op **Stripe live-mode**
- 0 hits op `dac7` of `bsn`
- Datum onderaan: "Laatste update: mei 2026"

**Actie voor deploy:**

- [ ] Update Mollie → Stripe references door hele doc
- [ ] Verwijder "test mode" claims — er zijn NIETS meer test-payments in productie-app
- [ ] Voeg sectie "New features in 1.3.0" toe met korte uitleg over OCPP, live charging, DAC7
- [ ] Voeg DAC7 disclosure toe: "For Dutch tax reporting (DAC7 / EU directive 2021/514), charger owners who exceed 30 transactions OR €2000 revenue per calendar year are prompted to provide their Dutch tax ID (BSN/RSIN). This is stored encrypted and reported yearly to the Dutch tax authority. Reviewer will not encounter this flow unless testing with fake threshold data."
- [ ] Update datum: "Laatste update: juli 2026"

### 3. Nieuwe App Store / Play Store screenshots?

**Bevinding:** LiveChargingCard is nieuw en visueel prominent. Huidige screenshots tonen 'm niet.

**Actie:**

- [ ] Beslissing: nieuwe screenshot #4 met LiveChargingCard tijdens laden? Zo ja, één sessie op fysieke paal, screenshot in-app maken, in Figma/Photoshop framen.
- [ ] Niet strikt nodig voor approval, maar goede marketing.

### 4. Privacy Nutrition Labels update (iOS + Play Data Safety)

**Bevinding:** we voegen "Government ID" data-type toe (BSN/RSIN). Beide stores vereisen dat deze data-collectie opgegeven wordt.

**Actie voor deploy:**

- [ ] **iOS App Store Connect → App Privacy** → voeg toe:
  - Data Type: **Sensitive Info** → *Other Sensitive Info* (BSN valt hier onder in Apple's taxonomie, hebben ze niet als aparte category)
  - Linked to Identity: **Yes**
  - Purpose: **App Functionality** (legal/compliance)
- [ ] **Play Data Safety** → voeg toe:
  - Personal Info → *Other info* → "Dutch tax identification number (BSN/RSIN)"
  - Collected: Yes / Shared: No (we delen met Belastingdienst maar dat is niet "shared with third party" in Play's zin)
  - Optional: No (verplicht boven drempel)
  - Purpose: Compliance
  - Encryption in transit: Yes / at rest: Yes

---

## Belangrijk — sterk aanbevolen vóór deploy

### 5. FAQ-updates op pluggoapp.nl

**Actie:**

- [ ] Nieuwe FAQ-item: "Wat gebeurt er als ik veel palen verhuur? Vraagt Pluggo mijn BSN?"
- [ ] Nieuwe FAQ-item: "Wat is live laadinformatie? Hoe accuraat is de State of Charge?"
- [ ] Nieuwe FAQ-item: "Kan ik mijn boeking verlengen tijdens het laden?"
- [ ] Nieuwe FAQ-item: "Wat is OCPP en waarom is mijn paal daarmee compatibel?"
- [ ] Update landing pages `auto-opladen-bij-particulier.html` en `zonnepanelen-verdienen.html` met nieuwe features (kort)

### 6. Pluggo Pioniers-mail voorbereiden

**Actie:**

- [ ] Draft in `/sessions/relaxed-laughing-cori/mnt/neighbourcharge/marketing/` of `pioniers-mails/`
- [ ] Onderwerp: "Pluggo 1.3 — laden zoals het hoort te zijn"
- [ ] Inhoud: live info, boekingsverlengen, OCPP-integratie, kwartaaloverzicht (voor BTW-plichtigen), DAC7-uitleg (voor als drempel wordt geraakt)
- [ ] Timing: verstuur op de dag dat BEIDE stores live zijn (iOS approval blokkeert dit meestal 1-3 dagen)
- [ ] Optie: pré-warmen met een teaser 1-2 dagen vóór live ("Update komt eraan")

### 7. LinkedIn + Facebook launch-post

**Actie:**

- [ ] LinkedIn: Mattijs + Raka + Pluggo-bedrijfspagina — post over de update
- [ ] Facebook (als bedrijfspagina staat — check #228): launch-post
- [ ] Instagram (idem): reel of carousel

### 8. Communicatie-window t.a.v. tester bypass-emails

**Bevinding:** #148 heeft dynamische bypass-emails opgezet via Supabase. Met de nieuwe versie live, de test-accounts hebben mogelijk een andere flow.

**Actie:**

- [ ] Verify dat `apple-review@pluggoapp.nl` nog kan inloggen en flow doorlopen
- [ ] Verify dat interne test-accounts geen DAC7-blocker triggeren tijdens smoke (unless getest)

---

## Middel — kandidaat om mee te nemen in de build, niet blockering

### 9. #288 — NL push templates voor OCPP events

Status: pending. Als voor deploy klaar → in de build. Anders → volgende build. Gemis is niet critical maar wel jammer voor UX.

### 10. #289 — Auto-stop bij target-SoC

Status: pending. "Batterij-vriendelijk laden" is een marketable feature. Als klaar → mee. Anders → volgende build.

### 11. #272 — OCPP Security profile 2 (Basic Auth over TLS)

Status: pending. Voor productie-hardening. Blocker #2 (fysieke paal) draait op profile 1. Sec-profile 2 kan een week later ingevoerd worden per-paal, want CSMS ondersteunt beide.

### 12. #245 — Deep-link `pluggo://auth/confirm` handler

Status: pending. Verbetert onboarding UX (Resend email confirm redirect). Als klaar → mee.

### 13. Cleanup oude edge functions (Mollie/OPP)

Status: NA deze deploy. Nog niet nu — is een aparte "housekeeping" taak (create-payment-opp, mollie-webhook, opp-* moeten verwijderd worden).

---

## Laag prioriteit — na de dust settlet

### 14. #250 — Supply-conversie audit

Signups komen binnen maar 0 palen live (behalve testpaal). Na 1.3.0 live, wéér auditen om te zien of de nieuwe features (OCPP → automatisering, live info) meer signups converteren.

### 15. #251 — Egbert Kingma & Mathijs Hendriks Stripe follow-up

Persoonlijk. Kan na de deploy.

### 16. #162 — Invoice-engine v1

Volgende sprint. Kwartaaloverzicht #163 dekt de basis-behoefte tijdelijk.

---

## Missende items die MOGELIJK vergeten zijn (dubbelchecken)

- [ ] **Firebase / APNs certs geldig?** — verify dat certificates niet verlopen zijn (APNs cert vervalt jaarlijks)
- [ ] **Stripe webhook endpoint URLs** — sinds edge functions veranderen kan Stripe Dashboard nog verwijzen naar oude endpoints? Verify.
- [ ] **Cloudflare firewall** — geen blocking rules die de app breken? Cloudflare Web Analytics is aan, controleer.
- [ ] **DNS TTL** — voor `csms.pluggoapp.nl` (nieuw record). Zet lage TTL (300s) vóór deploy zodat je snel kan schakelen bij problemen.
- [ ] **Supabase Auth email templates** — nog steeds Resend? Templates NL? Verify.
- [ ] **Rate limits Supabase** — met OCPP realtime traffic + DAC7 checks per checkout — mag je huidige plan aankunnen? Verify quota-plan.
- [ ] **Sentry / error tracking** — is dit ingericht? Zo niet, overwegen om vóór deploy iets als Sentry / Bugsnag toe te voegen zodat je fouten in productie live ziet. Kan ook post-deploy.
- [ ] **Support-inbox** — support@pluggoapp.nl wordt gemonitord? Verwacht spike in vragen na 1.3.0 release.
- [ ] **Runbook voor OCPP downtime** — wat als CSMS crasht om 20:00 op vrijdag? Wie kan restarten? Systemd auto-restart aan? PagerDuty / basic alerting?
- [ ] **VPS backup** — Hetzner heeft snapshots. Aanzetten en beleid definiëren (dagelijks, 7 dagen retentie).
- [ ] **Handover-doc updaten** — na deploy: `marketing/handover.md` of soortgelijke → wat er nu live is, wat de status is.
- [ ] **Bookings status enum** — check of `charging`, `completed`, `awaiting_payment` etc. allemaal correct in `bookings_status_check` constraint zitten (was #282 fix).

---

## Samenvatting: wat er kritiek ontbreekt

1. `docs/privacy.html` DAC7-blok (AVG-verplicht)
2. `_internal/app_store_reviewer_notes.md` refresh (Mollie → Stripe + DAC7 + OCPP + datum)
3. App Store Privacy + Play Data Safety updaten met BSN/RSIN
4. FAQ + landing pages licht updaten
5. Pluggo Pioniers-mail voorbereiden (draft)
6. LinkedIn/Facebook launch-post voorbereiden
7. APNs cert + Stripe webhook URLs verify
