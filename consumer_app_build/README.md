# Consumer App Build — Launch-blueprint

> **Doel van dit document:** de definitieve feature-blueprint voor de 1.3.0-launch. Alle features die voorheen als "fase 1" en "fase 2" waren beschreven, worden in één keer met de launch meegenomen. "Fase 3" is post-launch en schaal-afhankelijk. Deze blueprint is de bron voor de tasks en het bouwvolgorde-plan.
>
> **Laatst bijgewerkt:** 16 juli 2026 (finale versie na strategische scherpstellings-ronde)

---

## 1. Twee ankers — onze onneembare voorsprong

### 1.1 Geen abonnementskosten

- Shell Recharge Home: €1,95/maand voor de laadpas + activeringskosten
- Bluecurrent: €2,50-4/maand voor abonnementsvorm met werkgeversverrekening
- EVBox Everon: licentiekosten via de installateur (verborgen in leasetarief)
- Chargemap Pass: €19,90 eenmalig, %-marge op elke sessie
- **Pluggo: €0/maand voor host én booker. Alleen platform-fee per transactie.**

Privé-BEV-bezitters (primaire doelgroep per pivot #342) zijn prijs-gevoelig. Abonnement = instap-drempel. "Geen abo" is de one-liner die verkoopt.

### 1.2 P2P laadpaal-delen ingebouwd

Concurrenten: paal is van jou, punt. Alleen jij (of RFID-uitdelers) kan hem gebruiken.
Pluggo: paal is optioneel deelbaar. Eén tap "beschikbaar" → op de kaart → buren kunnen boeken → jij verdient.

Dit is de enige fundamentele feature-differentiatie die niet imiteerbaar is zonder platform-transformatie bij concurrenten. Alle andere features (ERE, MID, slim laden) kunnen gekopieerd worden; P2P kan alleen wij.

### 1.3 One-liner voor landing/onboarding

> "De enige laadpaal-app die je thuisladen slim regelt, je paal-inkomsten genereert, en je werkgeversvergoeding op orde brengt. Zonder abonnement."

---

## 2. UX-benchmark — wat we lenen van concurrenten

Kort per app, alleen wat we overnemen:

| App | Wat we lenen |
|-----|--------------|
| **Alfen Eve** | QR-pairing voor paal-onboarding, firmware-transparantie |
| **Wallbox myWallbox** | Tegel-based dashboard, weekelijkse/maandelijkse grafieken |
| **Easee** | Cleane visuele stijl, 3-stap onboarding, één-tap export |
| **Zaptec Go** | Live power-monitoring tijdens sessie |
| **Shell Recharge** | Kaart-filters (aanwezig/bezet/prijs), sessie-detail-layout (kWh + tarief + duur + kosten + CO2), prijs-transparantie vóór starten |
| **Bluecurrent** | Dynamisch stroomprijs-koppeling, beknopt home-scherm |
| **Tesla-app** (referentie) | Real-time status prominent, zeldzame maar relevante notificaties |
| **EVBox Everon** | Bulk-export voor werkgevers (schaal-gated, post-launch) |
| **ABRP/Chargemap** | Community-reviews (al bestaand in Pluggo, zonder foto's ivm AVG) |

Wat we bewust NIET jatten: Wallbox's overladen dashboard-2024, Shell's aggressive upsell, EVBox's wagenpark-focus, Chargemap's %-marge per sessie.

---

## 3. Launch-features (alles bij 1.3.0-refresh)

Alle features die de app tot dé beste maken, gegroepeerd per categorie. Fase 1 en fase 2 zijn samengevoegd — komen allemaal in één launch.

### A. Slim laden

**Twee niveaus, één engine, eerlijke communicatie.**

**Contract-type onboarding-vraag (bepaalt default configuratie):**

```
Wat voor stroomcontract heb je?
○ Vast tarief per kWh
○ Dynamisch tarief (uurprijzen — Tibber, EnergyZero, easyEnergy)
○ Weet ik niet
```

Bij dynamisch → default "Slim laden AAN met kosten-prioriteit". Slogan: "Bespaar gemiddeld 20-30% op je laadkosten."

Bij vast → default "Slim laden AAN met CO2/grid-prioriteit". Slogan: "Laad met de groenste stroom en ontlast het net." Discreet info-linkje: "Wist je dat een dynamisch contract je kan besparen?"

Bij weet-niet → toggle uit, help-tekst.

**Optimalisatie-engine (backend, één engine):**

- Bron: **ENTSO-E day-ahead prijzen** (gratis, universeel, wholesale)
- Bron: **Ned.nl grid-mix API** (gratis, real-time CO2/duurzaam)
- Genereert OCPP SmartCharging-profiel of Start/Stop op basis van gekozen prioriteit + eindtijd + minimale SoC

**UI-toggle in Host-tab:**

```
[toggle] Slim laden inschakelen
   ├─ Eindtijd: [07:00 ▾]
   ├─ Min. SoC bij eindtijd: [80% ▾]
   └─ Prioriteit: [Goedkoopst ▾] [Groenst] [Grid-vriendelijkst]
```

**Slim laadschema op eindtijd:** sub-feature van dezelfde engine, niet apart. "Vol om 7:00" is dezelfde optimalisatie met eindtijd-constraint.

**Kosten-weergave (strikt gescheiden van optimalisatie):**

Wholesale-prijzen (ENTSO-E) gebruiken we NIET om aan de gebruiker "je betaalt X" te tonen. Weergave altijd via host-input of directe retailer-koppeling.

- Default: host geeft bij paal-onboarding zijn eigen kWh-tarief op (vast) of spread (dynamisch)
- Optioneel: koppel Tibber-account of EnergyZero-account voor exacte live-tarieven
- Sessie-detail: "€0,32 × 12,5 kWh = €4,00 (jouw opgegeven tarief)" met tooltip
- Kleine disclaimer eerste sessie: "Kosten gebaseerd op jouw opgegeven tarief; check je jaarafrekening voor exacte cijfers"

**Waarom dit zo strikt gescheiden?** Voorkomt "genaaid"-gevoel bij fixed-contract-users die de wholesale-prijs anders zouden verwarren met hun retail-rekening.

### B. Zonne-overschot matching

**Beslissing: skip fabrikant-specifieke omvormer-APIs.** Enphase/SolarEdge/GoodWe zouden ~45% van hosts dekken met vijf integraties om te onderhouden. Niet de moeite.

**In plaats daarvan twee wegen:**

**1. Default (voor iedereen): dynamische stroomprijs als proxy.** Als wholesale-prijs relatief laag/negatief is, betekent dat meestal veel zon/wind in het net → automatisch goed moment om te laden. Werkt voor 100% van hosts zonder extra hardware.

**2. Opt-in premium: HomeWizard P1 Meter (~€30 host-hardware).** Host steekt HomeWizard P1 in zijn slimme meter (P1-poort — elke slimme meter in NL heeft die), koppelt aan Pluggo-app via HomeWizard's gratis publieke API. Wij zien real-time huishoud-verbruik + terug-levering. Bij >1 kW surplus: automatisch laden.

**Voordelen HomeWizard-route:**

- Universele omvormer-dekking (werkt met ALLE merken)
- Eén integratie ipv vijf, minimaal onderhoud
- Host betaalt hardware, niet wij
- HomeWizard-API is stabiel en publiek

**In-app CTA:** "Wil je nog slimmer laden op eigen zon? Bekijk de HomeWizard P1 (~€30, bol.com)." Geen affiliate, gewoon een linkje. Geen upsell-druk.

### C. Host-tooling

| Feature | Detail | Task |
|---------|--------|------|
| **Sticky Booker/Host-tabs** | Persistent tabs bovenaan home, één-tap wisselen tussen rollen | #346 |
| **Host-dashboard tegel-based** | Max 3 tegels: status + eigen laden deze maand + verhuur-inkomsten. Extra tegels tap-uit-klapbaar | #339 |
| **Prominente "Start laden"-knop** | RemoteStartTransaction via app, categorie = eigen laden | #340 |
| **Optionele eigen-tag-registratie** | Host tikt EENMALIG bestaande MSP-tag (Shell Recharge / ANWB / publieke laadpas) → whitelist. Voor gewoontedieren. Wij verkopen zelf geen tags | #340 |
| **One-tap availability-toggle** | "Deel paal nu / niet nu" vanaf home in één tap | #19 (bestaand, verifiëren) |
| **QR-config-transfer bij onboarding** | Scan QR op paal → koppelwizard velden pre-fill (Alfen v5+ / Wallbox 2025+ / Zaptec). Fallback: copy-buttons uit #311 | #345 |

**Auth-splitsing regel:** wie/wat authenticeert bepaalt categorisatie:

| Trigger | Categorie |
|---------|-----------|
| Host tapt Start in Host-tab | eigen laden |
| Host tikt whitelisted tag | eigen laden |
| Booker tapt Start via booking | gastladen |
| Onbekende tag / geen booking | Authorize.req deny (veilig) |

### D. Fiscaal & financieel

| Feature | Detail | Task |
|---------|--------|------|
| **MID-hardened werkgevers-PDF** | Maandelijkse PDF met signedMeterValue + CBS-tarief 2026 (€0,27-0,32/kWh benchmark) | #341 fase 1 |
| **Automatische ERE-verzilvering** | Via inboekdienstverlener-partner (Joulo / EcoHandel / Den Hartog / ere-registratie.nl te kiezen). Tegel op host-dashboard | #338 fase 1 |
| **Kwartaal BTW-overzicht** | Voor BTW-plichtige hosts | #163 (klaar) |
| **KOR-invoice per booking** | PDF voor particulier-paaleigenaar | #162 |
| **Maandelijkse MID-verbruiksrapport** | Voor host-inzicht + audit-trail | #330 |
| **Jaaroverzicht ZZP-ready PDF** | Aggregator bovenop bestaande engines. Bundelt: 4 kwartaal-BTW + 12 MID-maanden + KOR-invoices + kosten-kant + netto-resultaat. Voor inkomstenbelasting-aangifte | nieuwe task (uitbreiding op #163) |

### E. Booker-experience

| Feature | Detail | Task |
|---------|--------|------|
| **Prijs-transparantie vóór starten** | kWh-tarief van host + platform-fee zichtbaar vóór reservering | #133/#135 (bestaand) |
| **Sessie-detail Shell-stijl** | Op één kaart: kWh + tarief + duur + kosten + CO2 | uitbreiden bestaand |
| **Live €-teller tijdens OCPP-sessie** | Naast bestaande kWh-teller en groene laadbalk (#287) een actueel euro-bedrag | aanhaken bij #287 |
| **Buurt-view / netwerk-kaart** | Kaart-dots met beschikbaarheid: 🟢 nu / 🟠 binnen 2u geboekt / ⚫ niet beschikbaar. Bij inloggen zoom naar eigen postcode-4-wijk. Bannertje "12 palen in jouw wijk" | nieuwe task |

### F. Community & sociale laag

**Reviews:** volledig bestaand (#29-36). Niet aanraken.

- Foto-uploads bij reviews: **NIET DOEN** — AVG-risico (booker fotografeert privé-terrein van host).
- Publieke host-profielpagina: post-launch als user-vraag komt.
- Community-reviews Chargemap-stijl: al aanwezig, geen extra werk nodig.

**Buurt-view op host-dashboard (in aanvulling op kaart):**

- Tegel "In jouw buurt": aantal Pluggo-hosts in postcode-4, groei-indicator "deze week +2", gemiddelde host-rating in wijk
- Postcode-4-niveau (~2000-5000 huishoudens): significant genoeg voor "buurt"-gevoel, groot genoeg voor privacy
- Geen namen/adressen van andere hosts, geen chat, geen social feed
- Sociaal-proof voor host-werving (essentieel voor #342 pivot naar privé-BEV)

### G. Milieu-tracking

| Feature | Detail | Task |
|---------|--------|------|
| **CO2 per sessie** | Grams CO2 op basis van real-time Ned.nl grid-mix API. Op sessie-detail-kaart naast kWh/€ | nieuwe task |
| **Jaar-teller "CO2 vermeden"** | Tegel op host-dashboard: kg CO2 dit jaar, running total | nieuwe task |
| **Reset 1 januari** | Oude waarde archiveren, nieuwe jaar begint schoon | idem |
| **Op jaaroverzicht** | Aparte sectie "Milieu-impact 2026" met totaal + gemiddelde per kWh + benchmark grijze stroom | onderdeel van jaaroverzicht-task |

**Attributie-regel:** CO2 volgt de rijder van de auto, niet de paaleigenaar.

- Eigen laden op eigen paal → CO2 bij host
- Gastladen (booker op host's paal) → CO2 bij booker
- Eigen laden als host bij een andere Pluggo-paal → CO2 bij hem als booker

Geen dubbeltelling.

---

## 4. Post-launch features (schaal-gated)

Deze features komen NIET bij launch — niet omdat we ze niet willen, maar omdat ze scale-gated of investerings-gated zijn.

| Feature | Waarom later | Trigger voor start |
|---------|--------------|--------------------|
| **Automatische werkgevers-verrekening à la Shell Recharge** | €150-300k investering, 6-12 mnd bouw, directe MSP-concurrentie, B2B-onboarding werkgevers vereist | 5k+ hosts, echte HR-vraag vanuit lease-mij's |
| **Route-planner met Pluggo-palen** | Vergt landelijke dekking (te weinig palen buiten focus-steden) | 500+ hosts verspreid |
| **Multi-user per paal** | Gezinsleden met eigen sessies (Wallbox-model) | User-vraag na launch |
| **Eigen NEa-accreditatie voor ERE** | Vereist 2M kWh/jaar OF 200 authorizations | 300-500 hosts |
| **Plug&Charge ISO 15118** | Vereist paal-hardware-support, moderne EV's | Standaard onder hosts, ~2027 |
| **Publieke host-profielpagina** | Nice-to-have community-feature, geen launch-differentiator | User-vraag |
| **QR-booker-start** | Overbodig gegeven onze reservering-first flow | Alleen bij overweging ad-hoc-model |

---

## 5. Wat we bewust NIET bouwen (positionering-discipline)

- **Abonnement-tiers.** Ooit. Nooit.
- **Foto-uploads bij reviews.** AVG-risico (booker fotografeert privé-terrein van host).
- **In-app store voor accessoires of RFID-tags.** Wij verkopen geen hardware.
- **Social feed / likes / gamification.** We zijn een utility, geen sociaal netwerk.
- **Chatbot / AI-assistent.** Support via mail; als de app dat nodig heeft, is 'm te ingewikkeld.
- **Publieke tarief-vergelijker per publieke laadpaal.** Shell-terrein, niet ons voordeel.
- **Fabrikant-specifieke omvormer-APIs.** Te versplinterd, HomeWizard P1 is universeler.
- **Wholesale-prijzen tonen als retail-kosten.** Genaaid-risico.
- **Doen alsof vast-contract-users besparen bij slim laden.** Eerlijk over kosten- vs CO2-effect.
- **Pushy retail-switch-upsell.** Max één discrete info-linkje voor dynamisch-contract.

---

## 6. Design-principes (dwars door alle features heen)

1. **Home = maximaal 3 tegels + 1 primaire actie.** In <1 seconde te scannen.
2. **Progressive disclosure.** Geavanceerd (slim laden, HomeWizard, dynamisch tarief) staat standaard uit. Basis werkt zonder ook maar één instelling.
3. **Één-tap host-toggle.** "Beschikbaar / niet beschikbaar" vanaf home in 1 tap.
4. **Geen upsell-prompts.** Nergens "upgrade voor meer features". Alles zit in gratis basispakket.
5. **Zeldzame actionable notificaties.** Sessie voltooid, boeking ontvangen, wekelijkse samenvatting. Rest is opt-in. Geen spam.
6. **3-stap onboarding maximaal.** Account+QR → contract-type + profiel-keuze → (optioneel) tag-registratie + werkgever-mail. Klaar. Alles daarna optioneel.
7. **Fiscale/juridische secties altijd 1 tap ver.** Werkgevers-PDF, jaaroverzicht, ERE-status. Geen 5-lagen menu.
8. **Sticky Booker/Host-tabs.** Elke host is ook booker. Rol-switch in 1 tap.
9. **Eerlijke communicatie.** Wat we niet weten (retail-tarief) geven we niet als hard cijfer. Wat we niet doen (kostenbesparing voor vast contract) beloven we niet.

---

## 7. Feature-mapping: bestaande vs nieuwe tasks

### Bestaande tasks die (deels) gedekt zijn

| Task | Status | Feature |
|------|--------|---------|
| #19 | completed | One-tap availability-toggle |
| #29-36 | completed | Reviews-systeem volledig |
| #133/#135 | completed | Prijs-transparantie booker |
| #162 | pending | KOR-invoice per booking |
| #163 | completed | Kwartaal BTW-overzicht |
| #287 | in_progress | Live laadschatting UI — €-teller toevoegen |
| #311 | completed | Koppelwizard 4-staps + copy-buttons |
| #330 | pending | Maandelijkse MID-verbruiksrapport |
| #338 | pending | ERE-inboekdienstverlener partnership |
| #339 | pending | Host-dashboard tegel-based |
| #340 | pending | Owner Start-knop + optionele tag-whitelist |
| #341 | pending | Werkgevers-PDF fase 1 |
| #342 | pending | Host-werving pivot naar privé-BEV |
| #345 | pending | QR-config-transfer koppelwizard |
| #346 | pending | Sticky Booker/Host-tabs |

### Nieuw aan te maken tasks (bij bouwstart)

- Dynamische stroomprijs-engine (ENTSO-E + optionele Tibber/EnergyZero-koppeling)
- Slim laden UI met contract-type onboarding-vraag + prioriteit-keuze
- HomeWizard P1 optionele integratie
- CO2-tracking (Ned.nl grid-mix + per-sessie + jaar-teller)
- Buurt-view kaart-dots + host-dashboard-tegel (postcode-4)
- Live €-teller in OCPP-sessie (aanhaken bij #287)
- Jaaroverzicht ZZP-aggregator (bovenop #163 + #330 + KOR-invoices)
- Kosten-weergave: host-input tarief-flow bij paal-onboarding
- Sessie-detail-layout Shell-stijl (kWh + tarief + duur + kosten + CO2 op één kaart)

---

## 8. Positionering-zin (voor landing/marketing/pitches)

> "De enige laadpaal-app die je thuisladen slim regelt, je paal-inkomsten genereert, en je werkgeversvergoeding op orde brengt. Zonder abonnement."

Alternatieven per doelgroep:

- **Privé-BEV met zonnepanelen:** "Laad met je eigen zon, verdien met je eigen paal."
- **Privé-BEV met dynamisch contract:** "Slim laden op de goedkoopste stroom + verdien met je paal."
- **ZZP'er:** "Alle laadkosten en verdiensten fiscaal op orde. Jaaroverzicht klaar voor je aangifte."
- **Vast-contract-BEV:** "Laad groen zonder gedoe. Deel je paal voor extra inkomen."

---

## 9. Waarom deze combinatie werkt

De **hardware-fabrikanten** (Alfen, Wallbox, Easee, Zaptec) bouwen dit nooit — hun businessmodel is hardware verkopen, niet recurring software.

De **MSPs** (Shell, Bluecurrent, EVBox) hebben abonnement-DNA en géén host-rol in hun platform.

De **route-planners** (Chargemap, ABRP) hebben géén thuis-laad-focus.

Wij zitten precies in het gat: consumer-utility met dubbele rol (host + booker), geen abo, fiscaal ready, slim laden built-in, eerlijk over wat we wel/niet kunnen.

---

## 10. Update-log

- **16 juli 2026 (iteratie 3, definitieve versie)** — Blueprint gefinaliseerd na strategische scherpstellings-ronde. Belangrijkste beslissingen: (1) Fase 1 + fase 2 samengevoegd tot één launch. (2) Auth-splitsing (#340) vereenvoudigd naar owner-Start-knop + optionele tag-whitelist, geen Pluggo-verkochte tags. (3) Sticky Booker/Host-tabs (#346) als app-shell-wijziging. (4) QR-config-transfer (#345) voor koppelwizard. (5) Fabrikant-omvormer-APIs geskipt ten faveure van HomeWizard P1 (universele dekking). (6) Wholesale-optimalisatie (ENTSO-E) strikt gescheiden van retail-weergave (host-input of Tibber/EnergyZero-koppeling). (7) Contract-type onboarding-vraag bepaalt slim-laden-default (kosten vs CO2/grid). (8) CO2-attributie volgt rijder van de auto. (9) Foto-uploads bij reviews definitief geschrapt (AVG). (10) Jaaroverzicht ZZP als aggregator bovenop bestaande engines. Post-launch (voormalig fase 3) blijft schaal-gated.

- **16 juli 2026 (iteratie 2)** — Fase-2-features toegevoegd na strategisch gesprek: dynamische stroomprijs, zonne-overschot, slim laadschema, CO2, eigen NEa. Design-principes uitgeklapt. Feature-backlog met P0/P1/P2/P3.

- **16 juli 2026 (iteratie 1)** — Bestand aangemaakt met UX-benchmark per concurrent, missing-features-lijst per fase, design-principes.
