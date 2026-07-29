# Verzekeringen — Pluggo roadmap

> **Doel:** overzicht van welke verzekeringen Pluggo nu nodig heeft, wanneer ze relevant worden, en hoe ze geregeld worden. Niet nu-nu-nu, maar wél voordat het pijn doet.
>
> **Laatst bijgewerkt:** 9 juli 2026
> **Bijgewerkt door:** Mattijs + Claude

---

## Sittings-samenvatting (TL;DR)

- **Nu (fase 0, geen budget):** niets. Kan tijdelijk maar risico is er.
- **Zodra AVB betaalbaar:** AVB (~€30-50/maand) — nuttig voor lease-outreach (aanspreekpunt-argument), niet strikt vereist.
- **Bij eerste ondertekende lease-partner (fase 1):** Producten-aansprakelijkheid erbij (~€30-50/maand extra).
- **Bij eerste €10k GMV/maand (fase 2):** Cyber-verzekering erbij (~€40-80/maand extra).
- **Bij ~200 hosts of €50k GMV/maand (fase 3):** Host-protection dekking via specialty broker (schaalt met transactievolume, ~0.3-0.8% van GMV).

---

## Belangrijke update (9 juli 2026) — lease-outreach vraagt minder verzekering dan eerst gedacht

Mattijs's inzicht: de lease-maatschappij is juridisch geen partij in de Pluggo-relatie. De thuis-paal is eigendom van de lease-klant, de laadsessie loopt tussen host en booker (met eigen auto), en de lease-EV komt in de flow niet voor. Dat betekent dat de pitch "toestemming + distributie" is, niet "partnerschap".

**Gevolg voor deze roadmap:**

- AVB blijft nuttig (voor aanspreekpunt-argument als er ooit een klantklacht via lease-maatschappij binnenkomt), maar is niet meer een blocker voor de lease-outreach zelf. Kan gestart worden voordat AVB rond is.
- Producten-aansprakelijkheid, Cyber en Host-protection blijven relevant voor Pluggo's eigen risico's, maar zijn NIET meer nodig als "pitch-ammunitie" richting lease-maatschappijen.
- Cyber blijft wél urgent zodra DAC7-flow live gaat en eerste BSN's worden opgeslagen — dat is Pluggo's eigen AVG-risico, los van lease-outreach.

Kortom: de druk om snel verzekeringen af te sluiten neemt af, behalve Cyber die aan DAC7-live gekoppeld blijft.

---

## Waarom verzekeringen relevant zijn voor Pluggo

Als P2P-platform (Airbnb-model) heeft Pluggo blootstelling op vier fronten:

1. **Bedrijfs-aansprakelijkheid.** Standaard voor elk bedrijf dat contracten sluit of derden bedient.
2. **Software-fouten die schade veroorzaken.** Bug in `remote-stop-session`, foute meter-values leiden tot verkeerde afrekening, verkeerd RemoteStart-signaal richting paal.
3. **Data-lek van BSN/DAC7/persoonsgegevens.** AVG-boete potentieel tot €20M of 4% wereldwijde omzet. Ook reputatie-schade.
4. **Schade booker ↔ host onderling.** Booker rijdt tegen host's paal aan. Host's paal-defect trekt booker's auto stuk. Etc. Klassiek Airbnb-scenario waar host-protection voor bedoeld is.

---

## De vier verzekeringen die relevant zijn

### 1. AVB — Aansprakelijkheidsverzekering voor Bedrijven

**Wat het dekt:** schade toegebracht aan derden door bedrijfsactiviteiten (kantoor-ongeval, cliënt-schade, etc). Basis-polis voor elk B2B-bedrijf.

**Waarom nodig:** minimum-niveau om überhaupt met een lease-maatschappij, installateur of partner te tekenen. Elke compliance-afdeling checkt hierop.

**Kosten:** €30-50/maand voor early-stage startup.

**Waar afsluiten:** direct online bij:
- Reaal ZZP/MKB
- Nationale-Nederlanden Business
- Interpolis Bedrijfscompact
- Achmea Zakelijk

Geen specialty-broker nodig voor deze polis. Kan in <30 minuten online.

**Wanneer noodzakelijk:** vóór eerste lease-outreach (dus wachten tot AVB rond is).

---

### 2. Producten-aansprakelijkheid

**Wat het dekt:** schade veroorzaakt door "het product" — in Pluggo's geval de app + het OCPP-platform. Voorbeeld: door een bug in de RemoteStop-flow eindigt een sessie niet netjes en er is schade aan de EV of paal.

**Waarom nodig:** zonder deze dekking heeft AVB gaten. Software-fouten die schade veroorzaken vallen buiten reguliere bedrijfs-aansprakelijkheid.

**Kosten:** €20-50/maand bovenop AVB.

**Waar afsluiten:** meestal bij dezelfde verzekeraar als AVB, of via specialty broker (Klap, Aon MKB, Meeus) als package-deal.

**Wanneer noodzakelijk:** bij eerste ondertekend partnership (lease, installateur, autodealer). Kan achteraf gestapeld op AVB.

---

### 3. Cyberverzekering

**Wat het dekt:** kosten van een datalek (forensisch onderzoek, notificatie-plicht, credit-monitoring gedupeerden, AVG-boete, PR-schade, ransomware).

**Waarom nodig:** Pluggo verwerkt bijzondere persoonsgegevens (BSN via DAC7) plus betalingsdata. Datalek-risico is niet nul en de kosten schalen niet met bedrijfsgrootte — een klein bedrijf kan hier failliet aan gaan.

**Kosten:** €40-80/maand voor early-stage, groeit naar €150-300/maand bij scale.

**Waar afsluiten:**
- Hiscox (cyber-specialist)
- Aon Cyber Solutions
- Chubb Cyber
- Via Klap Verzekeringen (broker)

**Wanneer noodzakelijk:** zodra DAC7-flow live gaat en eerste BSN's opgeslagen worden. Dat is dus tegelijk met de massive build 1.3.0+14. Als het budget krap is, kan het één-twee maanden later, maar het gat is een risico.

**Belangrijk voor Pluggo specifiek:** cyber-verzekeraars vragen om technische securityaudit voordat ze afsluiten. Wij hebben AES-256-GCM encryptie voor BSN + RLS in Supabase + het feit dat we bewust geen wachtwoorden opslaan (magic-link auth via Resend). Dat is goede input voor de aanvraag.

---

### 4. Host Protection / Guest Damage-cover

**Wat het dekt:** schade tussen booker en host onderling waar Pluggo faciliteert. Precies wat Airbnb voor hun hosts arrangeert ("$1M host guarantee").

**Waarom nodig:** dit is exact het scenario waar lease-maatschappijen naar gaan vragen. Zonder deze dekking is het gesprek bemoeilijkt.

**Kosten:** hier variabel. Specialty brokers rekenen typisch een percentage van GMV of een vast bedrag per gefaciliteerde transactie. Ballpark: **0.3-0.8% van GMV**. Bij €100k GMV/jaar = €300-800/jaar. Bij €1M GMV = €3-8k/jaar. Vaste polis kan ook: ~€200-400/maand bij low-volume.

**Waar afsluiten:** dit is specialty-broker terrein. Niet zelf online te regelen.
- **Klap Verzekeringen** (Rotterdam, tech-focus)
- **Aon MKB** (grote broker, platform-desk)
- **Meeus** (landelijk, MKB-tech-desk)
- **Voogd & Voogd** (Middelburg)

Bel er twee, vergelijk offertes.

**Wanneer noodzakelijk:** niet direct nodig bij 12 palen zonder sessies. Wél nodig zodra er echte transacties zijn én zodra lease-maatschappijen serieus vragen naar dekking. Fase 2-3.

---

## Concrete stappenplan

### Fase 0 — Nu (12 palen, 0 sessies, geen budget)

- Doe niks acuut
- Risico: klein, want geen actieve sessies = geen transactie-blootstelling = geen host-schade mogelijk. Wel data-lek risico (Supabase-data, magic-links) maar dat is klein bij deze schaal
- Wel: reserveer mentaal budget voor fase 1

### Fase 1 — Vóór eerste echte sessies + lease-outreach (weken na OCPP-launch)

**Actie:** AVB afsluiten.

**Stappen:**
1. Reaal / Nationale-Nederlanden / Interpolis online — quick quote (€30-50/maand)
2. Doorlopen aanvraag (~30 min online): bedrijfsactiviteit = "digitaal platform voor het delen van laadpalen (SaaS/marktplaats)"
3. Polis-nummer bewaren in `verzekeringen/polissen/`
4. Toevoegen aan `_internal/INFRASTRUCTURE.md` onder nieuwe sectie "Verzekeringen"

**Trigger voor deze fase:** OCPP is klaar én je gaat lease-outreach starten.

### Fase 2 — Producten + Cyber (bij eerste €5-10k GMV/maand)

**Actie:** uitbreiden.

**Stappen:**
1. Twee specialty-brokers bellen (Klap, Aon MKB) — vraag package quote voor Producten + Cyber
2. Vergelijken
3. Ondertekenen
4. Update INFRASTRUCTURE.md

**Trigger:** ~€5-10k GMV per maand OF ondertekening van eerste enterprise lease-partner.

### Fase 3 — Host Protection (bij scale)

**Actie:** specialty polis via broker.

**Stappen:**
1. Broker (Klap of Aon) een aparte host-protection quote laten maken
2. Kies model (vast maandbedrag óf percentage GMV, afhankelijk van welke gunstiger uitpakt bij verwachte volumes)
3. Onderteken
4. Update INFRASTRUCTURE.md

**Trigger:** ~200 hosts of ~€50k GMV/maand.

---

## Voor de pitch naar lease-maatschappijen

Voor het gesprek met een lease-partner ziet de compliance-check er ongeveer zo uit:

**Zij zullen vragen:** "welke dekking heeft u voor schade veroorzaakt via uw platform?"

**Jullie antwoord (fase 1, alleen AVB):**
> "Wij hebben op dit moment AVB via [Reaal/NN]. Producten-aansprakelijkheid en cyber-verzekering rondt onze broker af tegen het moment dat we operationeel-live gaan met uw klanten. Wij kunnen dat parallel doorlopen zodra we een intentieverklaring hebben getekend."

Dit is 100% waar zodra AVB rond is. Dekt hun compliance-vraag zonder overbelofte.

---

## Contact-lijstje brokers (nog niet gecontacteerd)

- **Klap Verzekeringen** — Rotterdam — https://www.klap.nl — tech/scale-up focus
- **Aon MKB Nederland** — Rotterdam — https://www.aon.nl — grote broker met platform-desk
- **Meeus** — landelijk — https://www.meeus.com — MKB-tech-desk
- **Voogd & Voogd** — Middelburg — praktisch, iets minder tech-focus

Standaard-openingszin bij eerste contact:
> "Wij zijn een Nederlands P2P-platform voor het delen van laadpalen. Ik zoek een offerte voor AVB + producten-aansprakelijkheid + cyber + host-protection, waarbij ik graag een variabel premiedeel wil dat meeschaalt met ons transactievolume. Kunnen we een intake plannen?"

---

## Open vragen om te beantwoorden vóór afsluiten

- [ ] Wat is de exacte rechtsvorm van Pluggo op dat moment (eenmanszaak / VOF / BV)? Beïnvloedt polis-structuur.
- [ ] Welke landen dekken we? Nederland-only nu, maar bij BE/DE uitbreiding wordt dit een issue voor de polis.
- [ ] Werken we met sub-contractors (bv. Stripe, Supabase, Resend)? Deze staan in de contracten en beïnvloeden data-processing-verantwoordelijkheid.

---

## Update-log

- **9 juli 2026** — bestand aangemaakt. Beslissing: nu nog geen polissen, wachten tot OCPP live is en er echte lease-outreach gestart wordt. AVB dan de eerste stap.
