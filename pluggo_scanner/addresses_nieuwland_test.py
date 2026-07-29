"""
Test-sample uit Nieuwland — 20 gecureerde adressen voor validatie van
scanner-uitbreiding met oprit-detectie (task #303).

Bevat expres:
- Anna Boelensgaarde (hofje/gaarde — testcase voor gedeelde-terrein detectie)
- 5 grote dreven (Poortersdreef 2×, Nieuwlandsedreef, Waterdreef, Kruidendreef, Patriciërslaan)
- Beroepen-cluster (De Vergulde Wagen, De Oude Munt, De Gouden Ploeg, De Vergulde Paarden)
- Kruiden-cluster (Waterscheerling, Parnaskruid, Heelkruid, Mattenbies, Waterviolier, Knoopkruid)
- Forel (vis-thema)

VERWIJDERD (v1 → v2, 14 juli 2026): Alpensalamander/Brilsalamander/Fanny
Blankers-Koenpad — te korte straten (2-4 huizen). Nominatim snapt die niet
en fuzzy-matched ze naar Vuursalamander (grote gelijkende straat), waardoor
we constant hetzelfde ander huis gescand kregen.

v3 (14 juli 2026): coordinaten worden opgezocht uit addresses_nieuwland.py
(exacte PDOK-VBO-centroide) i.p.v. Nominatim opnieuw te doen. Nominatim
heeft in NL vaak alleen straat-middelpunten voor huisnummers, dus
Poortersdreef 12 en 69 landen dan op bijna dezelfde plek en Apple Look
Around snapt naar dezelfde pano.

Elk adres = middelste huisnummer van die straat — meest representatief voor
het typische bebouwingsprofiel van die straat.

expected_has_charger=None want geen ground truth beschikbaar.
"""

# Adres-strings die we willen scannen. Coordinaten worden opgezocht in
# addresses_nieuwland.py hieronder — draai eerst `python3 fetch_nieuwland.py
# --enrich` zodat die file lat/lng heeft.
_WANTED = [
    "Anna Boelensgaarde 15, Amersfoort",
    "Poortersdreef 69, Amersfoort",
    "Poortersdreef 12, Amersfoort",
    "Nieuwlandsedreef 87, Amersfoort",
    "Nieuwlandsedreef 24, Amersfoort",
    "Waterdreef 316, Amersfoort",
    "Kruidendreef 74, Amersfoort",
    "Patriciërslaan 37, Amersfoort",
    "Waterscheerling 40, Amersfoort",
    "Parnaskruid 36, Amersfoort",
    "Heelkruid 36, Amersfoort",
    "Mattenbies 34, Amersfoort",
    "De Vergulde Wagen 58, Amersfoort",
    "De Oude Munt 43, Amersfoort",
    "De Gouden Ploeg 77, Amersfoort",
    "De Vergulde Paarden 56, Amersfoort",
    "Forel 70, Amersfoort",
    "Waterviolier 38, Amersfoort",
    "Knoopkruid 15, Amersfoort",
    "De Vergulde Wagen 20, Amersfoort",
]


def _build_test_addresses():
    """Zoek elk wanted adres op in addresses_nieuwland.TEST_ADDRESSES en
    kopieer de lat/lng erbij. Faalt met duidelijke message als er iets
    ontbreekt of nog geen coordinaat heeft.
    """
    try:
        from addresses_nieuwland import TEST_ADDRESSES as _FULL
    except ImportError as e:
        raise ImportError(
            "addresses_nieuwland.py niet gevonden. Draai eerst:\n"
            "    python3 fetch_nieuwland.py --enrich\n"
            "zodat de volledige adres-lijst met PDOK-coordinaten wordt "
            "aangemaakt."
        ) from e

    by_adres = {entry["adres"]: entry for entry in _FULL}
    result = []
    missing = []
    zonder_coord = []
    for wanted in _WANTED:
        entry = by_adres.get(wanted)
        if entry is None:
            missing.append(wanted)
            continue
        if entry.get("lat") is None or entry.get("lng") is None:
            zonder_coord.append(wanted)
            # Neem 'm alsnog mee — scanner valt terug op Nominatim.
            result.append({"adres": wanted, "expected_has_charger": None})
            continue
        result.append({
            "adres": wanted,
            "lat": entry["lat"],
            "lng": entry["lng"],
            "expected_has_charger": None,
        })

    if missing:
        raise LookupError(
            "Test-adressen niet gevonden in addresses_nieuwland.py:\n  - "
            + "\n  - ".join(missing)
            + "\n\nMisschien is de wijk-lijst veranderd of is de spelling af. "
              "Draai `python3 fetch_nieuwland.py --enrich` opnieuw."
        )
    if zonder_coord:
        print(
            "⚠️  addresses_nieuwland_test: {} adressen zonder PDOK-coord — "
            "scanner valt daarvoor terug op Nominatim: {}".format(
                len(zonder_coord), zonder_coord
            )
        )
    return result


TEST_ADDRESSES = _build_test_addresses()
