# Nieuwe venture — briefing voor nieuw gesprek

## Context

Ik ben Mattijs, mede-oprichter van Pluggo (pluggoapp.nl) — een peer-to-peer laadpaal-verhuur platform voor elektrische auto's, gebouwd in Flutter + Supabase. Pluggo loopt goed maar ik wil parallel een tweede softwarebedrijf opzetten. Na uitgebreid brainstormen komen er twee concrete B2B SaaS-ideeën uit die ik wil uitwerken en lanceren.

---

## De twee producten

### Product 1 — Contract wake-up

**Het probleem:** Elk bedrijf tekent contracten met leveranciers, software-aanbieders, huurders, klanten — en vergeet ze dan. Verborgen in die contracten zitten: automatische verlengingsclausules (je bent er opeens aan 3 jaar vast), jaarlijkse prijsstijgingen ("conform CPI + 3%"), opzegtermijnen van 3-6 maanden, aansprakelijkheidsbeperkingen die je verrassen als er iets misgaat. Bedrijven ontdekken dit altijd te laat.

**De oplossing:** SaaS waarbij je al je contracten uploadt → AI extraheert alle relevante clausules, data, bedragen en verplichtingen → dashboard met alles overzichtelijk → alerts vóór elk kritiek moment ("dit contract verlengt automatisch over 47 dagen voor €14.400/jaar, wil je opzeggen?").

**Doelgroep:** Bedrijven met 10–200 werknemers, elke sector. In NL ~150.000 bedrijven.

**Prijsmodel:** €150–200/maand abonnement. Geen vergunningen, geen grote partners nodig.

**Bestaande concurrenten (marktcheck gedaan):**
- Zoho Contracts (~€30/user/mnd) en Signeasy (~€20/user/mnd): gericht op e-signing workflows voor nieuwe contracten, niet op het monitoren van bestaande contracten die je al ergens anders hebt getekend.
- LinkSquares: heeft wél AI-tagging en renewal alerts, maar is enterprise-geprijsd (€500+/mnd) en gericht op legal teams van grotere bedrijven.

**Positionering-conclusie:** de markt is niet leeg, maar het specifieke gat zit in "upload elk bestaand contract, ongeacht hoe of waar het getekend is" + MKB-prijspunt + NL/EU focus. Signing-tools zoals Zoho/Signeasy zijn geen directe concurrenten voor dit use case.

**Waarom unicorn-potentieel:**
- Lock-in is extreem hoog: zodra al je contracten erin zitten, haal je ze er nooit meer uit
- Data-moat: met genoeg contracten zie je welke clausules het vaakst tot problemen leiden → je wordt de standaard risicoradar voor zakelijk contractbeheer
- Europese schaal: product werkt in elke taal/markt, zelfde probleem overal

**Marktschatting:**
- NL realistisch jaar 1–3: 300–1.000 betalende klanten = €540k–€1,8M ARR
- Europees (5 jaar): 10.000–50.000 klanten = €18M–€90M ARR

---

### Product 2 — Concurrent-radar

**Het probleem:** Directeuren en marketeers willen weten wat hun concurrenten doen — nieuwe prijzen, nieuwe producten, nieuwe vacatures (signaal van opschaling), website-wijzigingen, nieuwe advertenties. Nu doen ze dit handmatig of helemaal niet. Enterprise-tools (Crayon, Klue) kosten €1.500+/maand. Er is niets betaalbaars voor MKB.

**De oplossing:** SaaS waarbij je je concurrenten invoert → systeem monitort continu hun website, LinkedIn, vacaturebanken, Google Ads, prijspagina's, persberichten → elke maandag een AI-gegenereerde brief: "Concurrent X verlaagde de prijs op product Y met 12%. Concurrent Z plaatste 3 salesvacatures — ze schalen op."

**Doelgroep:** Elk bedrijf met een commerciële functie en concurrenten. In NL ~200.000 bedrijven. Universeel: elke sector, elk land.

**Prijsmodel:** €150–250/maand. Geen vergunningen, geen grote partners, puur publieke data.

**Bestaande concurrenten (marktcheck gedaan):**
- Kompyte (van Semrush, €99–300/mnd): sterk in digitale marketing-monitoring (ads, SEO, content). Minder sterk in bredere bedrijfssignalen (vacatures, product launches, prijswijzigingen buiten de website).
- Visualping: puur website-change detection, geen interpretatie of synthese.
- Owler: company-nieuws aggregatie, geen AI-synthesized actie-brief.
- Crayon / Klue: uitgebreid maar €1.500+/mnd, gericht op enterprise.

**Positionering-conclusie:** "niets betaalbaars voor MKB" klopte niet helemaal — Kompyte en Owler bestaan. Het onderscheid moet zitten in: breder dan alleen marketing-signalen (ook vacatures, prijswijzigingen, product nieuws), én een wekelijkse AI-brief die echt leesbaar en actionable is in plaats van een ruwe data-dump. Niet "goedkoopste tool" maar "slimste brief."

**Waarom unicorn-potentieel:**
- Data-flywheel: hoe meer bedrijven het gebruiken, hoe rijker de benchmarkdata wordt ("jouw pricing vs sector gemiddelde")
- Europese schaal: product is direct exporteerbaar, zelfde probleem in DE, UK, FR, BE
- Upsell: Slack-integratie, diepere sector-analyses, alerting per event

**Marktschatting:**
- NL realistisch jaar 1–3: 500–2.000 betalende klanten = €900k–€3,6M ARR
- Europees (5 jaar): 30.000–150.000 klanten = €54M–€270M ARR

**Kritisch risico:** als de wekelijkse brief niet genuinely verrassend is, zeggen mensen na 3 maanden op. Kwaliteit en relevantie van de AI-output is alles.

---

## Bundel-optie

Beide producten samen aanbieden voor €220/maand. Hogere lifetime value per klant, meer lock-in, en logisch samen (je wil weten wat je concurrenten doen én je wil verrast worden door contracten).

---

## Marketing-aanpak (besproken)

- Cold email via KVK-lijsten gesegmenteerd op bedrijfsgrootte + sector
- Onderwerpregel contract wake-up: *"Je hebt waarschijnlijk een contract dat volgende maand automatisch verlengt."*
- Onderwerpregel concurrent-radar: *"Weet jij wat je concurrent gisteren aanpaste op zijn website?"*
- Geen enterprise sales, geen grote partners, geen vergunningen nodig

---

## Wat ik wil uitwerken in dit gesprek

1. **Naam en branding** voor beide producten (apart of als suite)
2. **MVP-scope**: wat is het absolute minimum om te lanceren en te valideren?
3. **Tech-stack**: hoe bouw ik dit snel (bij voorkeur aansluitend op wat ik al ken: Flutter/Supabase/Node)
4. **Go-to-market plan**: eerste 100 klanten, hoe en wanneer
5. **Pricing-strategie**: freemium, trial, of direct betaald?
6. **Wat eerst**: contract wake-up of concurrent-radar lanceren?
