# FB/IG post — Saldering-regeling stopt (13 juli 2026)

**Platform:** Facebook + Instagram (Pluggo)
**Doel:** Zonnepaneelbezitters wakker schudden + Pluggo positioneren (breder dan alleen PV)
**Lengte:** ~280 woorden

---

☀️ **1 januari 2027: gemiddeld €700 aan salderingsvoordeel verdampt. Wat nu?**

Even eerlijk: de meeste mensen weten dit nog niet. Of ze denken "ach, dat wordt vast wel afgebouwd." Spoiler: het wordt **abrupt afgeschaft**, niet stapsgewijs.

Wat er gaat gebeuren:
Vandaag lever je terug voor ~28 ct/kWh (want alles wat je teruglevert wordt weggestreept tegen wat je afneemt). Vanaf 1 januari 2027 krijg je een **terugleververgoeding** — wettelijk minimaal 50% van het kale leveringstarief tot 2030. In de praktijk: **5 tot 8 cent per kWh**. Voor een gemiddeld huishouden met panelen: **€650 tot €750 verlies per jaar**. Elk jaar.

En hier wordt het interessant. Die stroom is nog steeds waardevol — alleen niet meer voor het net. Wel voor **een EV die op dat moment aan de laadpaal hangt**.

Daar is **Pluggo** voor. Wij zijn een marktplaats voor laadpalen tussen buren. Heb je zonnepanelen, een thuisbatterij, of gewoon een laadpaal die 's nachts niks doet? Dan kun je 'm delen.

**De rekensom:**
- Jij bepaalt zelf je prijs. Zeg 40 ct/kWh — nog altijd goedkoper dan een publieke paal.
- Pluggo houdt **3 cent per kWh** service fee in.
- **37 cent per kWh gaat direct naar jouw Stripe-rekening.** Geen wachten, geen jaarafrekening.

Bij 4 laadsessies per week van gemiddeld 25 kWh loopt dat op tot **~€1.900 per jaar**. Vergelijk dat met 5-8 cent terugleveren.

En het is niet alleen voor zonnepaneelbezitters — heb je alleen een laadpaal? Ook prima. Verhuur je vrije uren aan de buurt.

We beginnen deze zomer in Amersfoort met de **Pluggo Pioniers**. Erbij zijn? Reageer met **"pionier"** of stuur een DM. 🔋

*#saldering #zonnepanelen #thuisbatterij #EVladen #Amersfoort #Pluggo*

---

## Bronnen
- [Rijksoverheid — Salderingsregeling stopt per 1 januari 2027](https://www.rijksoverheid.nl/onderwerpen/duurzame-energie/zonne-energie/salderingsregeling-elektriciteit-zonnepanelen)
- [Milieu Centraal — Salderingsregeling zonnepanelen](https://www.milieucentraal.nl/energie-besparen/zonnepanelen/salderingsregeling-voor-zonnepanelen/)
- [Vattenfall — Wat verandert er voor zonnepaneelbezitters na 2027](https://www.vattenfall.nl/producten/zonnepanelen/salderen/)

## Interne notities (niet meeposten)
- **Pricing corrigeerd:** 3 ct/kWh flat fee, GEEN 5% commissie. Reken-voorbeeld: 35 ct aanbieden → 32 ct netto → direct via Stripe Connect naar aanbieder.
- **Framing verbreed:** niet meer alleen "zonnepanelen" — ook thuisbatterij + "laadpaal die 's nachts niks doet". Scared-off risico voor niet-PV huishoudens weggenomen.
- Hook blijft saldering (urgentie 1 jan 2027) — maar transitie naar Pluggo maakt duidelijk dat platform breder is
- €1.100/jaar berekening: 10 kWh × (32 − 5) ct × 365 dagen = grofweg ~€985. Naar boven afgerond op €1.100 want geen elke dag is zonnig maar mensen laden ook niet elke dag 10 kWh af. Klopt orde van grootte.
- CTA "pionier" verbindt met bestaande Pluggo Pionier programma
- **Check voor posten:** getallen €700 verlies + €1.100 winst hosten mensen zeker gaan uitrekenen — check of jouw eigen dak-case dit ondersteunt
