"""
Trek kandidaat-adressen voor Nieuwland (Amersfoort) uit PDOK/BAG en
schrijf naar addresses_nieuwland.py in TEST_ADDRESSES-formaat.

Doel: eengezinswoningen met (waarschijnlijk) oprit — dus goede kandidaten
voor de brief-mailing / grassroots route. De scanner beoordeelt daarna zelf
of er al een laadpaal hangt.

Draaien:
    python3 fetch_nieuwland.py                        # snel, alleen dedupe-heuristiek
    python3 fetch_nieuwland.py --enrich               # + BAG-verrijking (oppervlakte, pand-VBOs)
    python3 fetch_nieuwland.py --wijk Kattenbroek     # andere wijk
    python3 fetch_nieuwland.py --limit 500            # test-run

Bronnen:
- PDOK Locatieserver v3_1 (adres-index, gratis, geen key)
- PDOK BAG WFS v2_0        (oppervlakte + pand-VBOs, gratis, geen key) — alleen bij --enrich

Over EV per adres: NIET publiek (privacy — RDW koppelt kenteken niet aan
adres in open data). Beste proxie is PC4-aggregaat via
https://klimaatmonitor.databank.nl of NAL EV Dashboard. Nog niet ingebouwd —
voor nu is de mail-doelgroep "eengezinswoning met oprit + scanner zegt
geen paal" een goede eerste filter.
"""

import argparse
import json
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

import requests

SCRIPT_DIR = Path(__file__).parent
LOCATIESERVER = "https://api.pdok.nl/bzk/locatieserver/search/v3_1/free"
BAG_WFS = "https://service.pdok.nl/lv/bag/wfs/v2_0"
UA = "PluggoScanner/1.0 (contact: m.sloothovenier@gmail.com)"

DEFAULT_WIJK = "Nieuwland"
DEFAULT_WOONPLAATS = "Amersfoort"

# Drempels voor filter
MIN_OPPERVLAKTE_EENGEZINS_M2 = 80   # kleiner = waarschijnlijk appartement
MAX_VBOS_PER_PAND = 3               # meer = flat / seniorencomplex

# ─────────────────────────────────────────────────────────────
# PDOK Locatieserver — adres-lookup

def pull_adressen(wijk, woonplaats, limit=None):
    """Pagineer door alle adres-hits in wijk. Return: list of docs."""
    adressen = []
    start = 0
    rows = 100
    print(f"→ Locatieserver: adressen ophalen in wijk '{wijk}', {woonplaats}...")
    while True:
        params = [
            ("q", "*"),
            ("fq", "type:adres"),
            ("fq", f"woonplaatsnaam:{woonplaats}"),
            ("fq", f"wijknaam:{wijk}"),
            ("rows", rows),
            ("start", start),
            ("wt", "json"),
            # Return de velden die we nodig hebben
            ("fl", "id,weergavenaam,straatnaam,huisnummer,huisletter,"
                   "huisnummertoevoeging,postcode,woonplaatsnaam,"
                   "wijknaam,buurtnaam,centroide_ll,adresseerbaarobject_id,"
                   "nummeraanduiding_id"),
        ]
        try:
            r = requests.get(LOCATIESERVER, params=params,
                             headers={"User-Agent": UA}, timeout=30)
            r.raise_for_status()
        except requests.RequestException as e:
            print(f"   ⚠️  Fout bij Locatieserver (start={start}): {e}")
            break
        docs = r.json().get("response", {}).get("docs", [])
        if not docs:
            break
        adressen.extend(docs)
        print(f"   ...{len(adressen)} adressen")
        if limit and len(adressen) >= limit:
            adressen = adressen[:limit]
            break
        if len(docs) < rows:
            break
        start += rows
        time.sleep(0.2)  # wees lief voor PDOK
    print(f"→ Totaal opgehaald: {len(adressen)} adressen")
    return adressen

# ─────────────────────────────────────────────────────────────
# BAG WFS — oppervlakte + pand-VBOs per adres (optioneel, --enrich)

def _build_ogc_filter_xml(chunk, count):
    """Bouw een WFS 2.0 GetFeature POST-body met OGC Filter XML.
    PDOK BAG WFS negeert cql_filter en resourceID via GET, maar respecteert
    dit filter wél (standaard OGC/WFS 2.0 conform).
    """
    if len(chunk) == 1:
        filter_body = (
            f'<fes:PropertyIsEqualTo>'
            f'<fes:ValueReference>identificatie</fes:ValueReference>'
            f'<fes:Literal>{chunk[0]}</fes:Literal>'
            f'</fes:PropertyIsEqualTo>'
        )
    else:
        eqs = "".join(
            f'<fes:PropertyIsEqualTo>'
            f'<fes:ValueReference>identificatie</fes:ValueReference>'
            f'<fes:Literal>{v}</fes:Literal>'
            f'</fes:PropertyIsEqualTo>'
            for v in chunk
        )
        filter_body = f'<fes:Or>{eqs}</fes:Or>'
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<wfs:GetFeature '
        'xmlns:wfs="http://www.opengis.net/wfs/2.0" '
        'xmlns:fes="http://www.opengis.net/fes/2.0" '
        'xmlns:bag="http://bag.geonovum.nl" '
        f'service="WFS" version="2.0.0" '
        f'outputFormat="application/json" count="{count}">'
        '<wfs:Query typeNames="bag:verblijfsobject">'
        f'<fes:Filter>{filter_body}</fes:Filter>'
        '</wfs:Query>'
        '</wfs:GetFeature>'
    )


def enrich_via_bag(adressen, batch_size=20):
    """Voor elk adres: haal oppervlakte + pandidentificatie op via BAG WFS.
    POST OGC Filter XML — werkt bij PDOK waar GET+CQL en GET+resourceID falen.

    Return: dict[vbo_id] -> {oppervlakte, gebruiksdoel, pand_id}
    """
    enriched = {}
    ids = [a.get("adresseerbaarobject_id") for a in adressen
           if a.get("adresseerbaarobject_id")]
    ids = list(dict.fromkeys(ids))  # dedupe, behoud volgorde
    print(f"→ BAG WFS verrijking voor {len(ids)} adressen ({batch_size} per call, POST XML)...")
    if not ids:
        print("   ⚠️  Geen adresseerbaarobject_ids gevonden in Locatieserver-hits.")
        return enriched

    diagnostic_done = False
    prev_enriched_size = 0
    stuck_batches = 0
    for i in range(0, len(ids), batch_size):
        chunk = ids[i:i + batch_size]
        xml_body = _build_ogc_filter_xml(chunk, batch_size)
        try:
            r = requests.post(BAG_WFS, data=xml_body,
                              headers={"User-Agent": UA,
                                       "Content-Type": "application/xml"},
                              timeout=60)
            r.raise_for_status()
        except requests.RequestException as e:
            print(f"   ⚠️  BAG WFS fout (batch {i}): {e}")
            continue
        try:
            payload = r.json()
        except ValueError:
            # Sommige errors komen als XML terug
            snippet = r.text[:300].replace("\n", " ")
            print(f"   ⚠️  BAG WFS gaf geen JSON (batch {i}): {snippet}")
            if not diagnostic_done:
                diagnostic_done = True
                print(f"   [diag] request-body sample: {xml_body[:250]}")
            continue
        features = payload.get("features", [])

        # Diagnostisch print bij eerste batch: matchen request en response?
        if not diagnostic_done:
            diagnostic_done = True
            resp_ids = [str(f.get("properties", {}).get("identificatie") or "")
                        for f in features[:3]]
            print(f"   [diag] request-IDs: {chunk[:3]}")
            print(f"   [diag] response-IDs: {resp_ids}")
            print(f"   [diag] {len(features)} features in batch 1")
            if features:
                p0 = features[0].get("properties", {})
                print(f"   [diag] property-keys: {list(p0.keys())[:10]}")

        for feat in features:
            props = feat.get("properties", {})
            vbo_id = str(props.get("identificatie") or "")
            if not vbo_id:
                continue
            doel = props.get("gebruiksdoel") or props.get("gebruiksdoelVerblijfsobject")
            if isinstance(doel, list):
                doel = ",".join(str(x) for x in doel)
            enriched[vbo_id] = {
                "oppervlakte": props.get("oppervlakte"),
                "gebruiksdoel": doel,
                "pand_id": str(props.get("pandidentificatie")
                               or props.get("maaktDeelUitVanPand") or ""),
            }

        # Detecteer of dict niet meer groeit (filter kapot / server negeert filter)
        if len(enriched) == prev_enriched_size:
            stuck_batches += 1
        else:
            stuck_batches = 0
        prev_enriched_size = len(enriched)
        if stuck_batches >= 10:
            print(f"   ⚠️  10 batches lang geen groei — filter lijkt kapot. Abort.")
            break

        if (i // batch_size) % 20 == 0:
            print(f"   ...{len(enriched)}/{len(ids)} verrijkt")
        time.sleep(0.3)
    print(f"→ BAG-verrijking klaar: {len(enriched)}/{len(ids)} adressen verrijkt")
    return enriched

# ─────────────────────────────────────────────────────────────
# Filtering

def group_size_by_pandkey(adressen):
    """Zonder BAG kunnen we geen echte pand-id lookup doen. Proxy:
    (postcode, huisnummer) — 1 pand, meerdere toevoegingen = appartementencomplex.
    """
    groups = defaultdict(list)
    for a in adressen:
        key = (a.get("postcode"), a.get("huisnummer"))
        groups[key].append(a)
    return groups

def filter_eengezins_heuristic(adressen):
    """Geen BAG-info → gebruik (postcode, huisnummer) group-size als proxy voor
    'zit in flat vs eengezins'. Groepen groter dan MAX_VBOS_PER_PAND droppen.
    """
    groups = group_size_by_pandkey(adressen)
    kept, dropped = [], 0
    for key, items in groups.items():
        if len(items) <= MAX_VBOS_PER_PAND:
            kept.extend(items)
        else:
            dropped += len(items)
    print(f"→ Heuristische dedupe: {dropped} appartement-adressen weg, "
          f"{len(kept)} eengezins-kandidaten over")
    return kept

def filter_eengezins_bag(adressen, enriched):
    """Met BAG-data: filter op woonfunctie + oppervlakte + pand-VBO-telling."""
    # Groepeer VBOs per pand voor telling
    pand_vbo_count = defaultdict(int)
    for nid, info in enriched.items():
        pid = info.get("pand_id")
        if pid:
            pand_vbo_count[str(pid)] += 1

    kept = []
    reasons = defaultdict(int)
    for a in adressen:
        # enriched is gekeyed op VBO-identificatie == adresseerbaarobject_id
        vbo = a.get("adresseerbaarobject_id")
        info = enriched.get(vbo)
        if not info:
            reasons["geen_bag_data"] += 1
            continue
        doel = info.get("gebruiksdoel") or ""
        opp = info.get("oppervlakte")
        pid = str(info.get("pand_id") or "")
        vbo_count = pand_vbo_count.get(pid, 1)

        if "woonfunctie" not in str(doel).lower():
            reasons["geen_woonfunctie"] += 1
            continue
        if opp is None:
            reasons["opp_missing"] += 1
            continue
        try:
            opp = int(opp)
        except (TypeError, ValueError):
            reasons["opp_bad"] += 1
            continue
        if opp < MIN_OPPERVLAKTE_EENGEZINS_M2:
            reasons["opp_te_klein"] += 1
            continue
        if vbo_count > MAX_VBOS_PER_PAND:
            reasons["pand_te_veel_vbos"] += 1
            continue
        # Voeg toe met verrijkte info
        a["_bag_oppervlakte"] = opp
        a["_bag_vbo_count_pand"] = vbo_count
        kept.append(a)

    print(f"→ BAG-filter: {len(kept)} kandidaten over. Redenen voor drop:")
    for reason, count in sorted(reasons.items(), key=lambda x: -x[1]):
        print(f"     {reason}: {count}")
    return kept

# ─────────────────────────────────────────────────────────────
# Output

def format_adres(doc, woonplaats):
    """Bouw 'Straatnaam 12A, Amersfoort'."""
    straat = doc.get("straatnaam", "").strip()
    huisnr = doc.get("huisnummer")
    huisletter = (doc.get("huisletter") or "").strip()
    toev = (doc.get("huisnummertoevoeging") or "").strip()
    nummer = str(huisnr) if huisnr is not None else ""
    # Format: 12, 12A, 12-3, 12A-3
    if huisletter:
        nummer += huisletter
    if toev:
        # toev kan '-3' of '3' zijn
        if not toev.startswith("-"):
            nummer += "-"
        nummer += toev
    return f"{straat} {nummer}, {woonplaats}".strip()

_CENTROIDE_RE = re.compile(r"POINT\(\s*([\-\d\.]+)\s+([\-\d\.]+)\s*\)")

def parse_centroide_ll(val):
    """PDOK levert 'POINT(lng lat)' (EPSG:4326). Return (lat, lng) of (None, None).

    Belangrijk: WKT-volgorde is (lng lat), NIET (lat lng) — makkelijk om te
    verwarren. Test-adres: Poortersdreef 12 hoort ergens rond 52.19N, 5.42E.
    """
    if not val:
        return None, None
    m = _CENTROIDE_RE.search(str(val))
    if not m:
        return None, None
    try:
        lng = float(m.group(1))
        lat = float(m.group(2))
        return lat, lng
    except ValueError:
        return None, None

def sort_key(item):
    """Sorteer op straatnaam, dan huisnummer numeriek."""
    m = re.match(r"^(.+?)\s+(\d+)", item["adres"])
    if m:
        return (m.group(1), int(m.group(2)))
    return (item["adres"], 0)

def write_output(items, path, wijk, source_note):
    with open(path, "w", encoding="utf-8") as f:
        f.write('"""\n')
        f.write(f"Kandidaat-adressen in wijk {wijk} (Amersfoort).\n\n")
        f.write(source_note + "\n\n")
        f.write("expected_has_charger=None omdat we hier geen ground truth\n")
        f.write("hebben — de scanner beoordeelt zelf en sorteert in by_verdict/.\n")
        f.write('"""\n\n')
        f.write("TEST_ADDRESSES = [\n")
        for it in items:
            adres = it["adres"].replace('"', '\\"')
            extra = ""
            if it.get("_bag_oppervlakte"):
                extra = f"  # {it['_bag_oppervlakte']}m²"
                if it.get("_bag_vbo_count_pand"):
                    extra += f", {it['_bag_vbo_count_pand']}vbo"
            lat = it.get("lat")
            lng = it.get("lng")
            if lat is not None and lng is not None:
                # Exacte VBO-coordinaat uit PDOK — scanner skipt dan Nominatim
                # (Nominatim heeft in NL vaak alleen straat-middelpunten voor
                # huisnummers, wat leidt tot verkeerde-huis snap in Look Around)
                f.write(
                    f'    {{"adres": "{adres}", "lat": {lat:.7f}, '
                    f'"lng": {lng:.7f}, "expected_has_charger": None}},{extra}\n'
                )
            else:
                f.write(
                    f'    {{"adres": "{adres}", "expected_has_charger": None}},{extra}\n'
                )
        f.write("]\n")

# ─────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description=__doc__.strip().split("\n")[0])
    p.add_argument("--wijk", default=DEFAULT_WIJK,
                   help=f"Wijknaam (default: {DEFAULT_WIJK})")
    p.add_argument("--woonplaats", default=DEFAULT_WOONPLAATS,
                   help=f"Woonplaats (default: {DEFAULT_WOONPLAATS})")
    p.add_argument("--enrich", action="store_true",
                   help="Verrijk via BAG WFS met oppervlakte + pand-VBO-telling (trager, betere filter)")
    p.add_argument("--limit", type=int, default=0,
                   help="Max aantal adressen van Locatieserver (0 = alles)")
    p.add_argument("--out", default=None,
                   help="Output-bestand (default: addresses_<wijk_lower>.py)")
    args = p.parse_args()

    limit = args.limit if args.limit > 0 else None
    adressen = pull_adressen(args.wijk, args.woonplaats, limit=limit)

    if not adressen:
        print("⚠️  Geen adressen gevonden — check wijk-spelling. "
              "Wijknamen in PDOK zijn exact ('Nieuwland', niet 'nieuwland').")
        sys.exit(1)

    if args.enrich:
        enriched = enrich_via_bag(adressen)
        if len(enriched) == 0:
            print("\n⚠️  BAG-verrijking gaf 0 hits — waarschijnlijk API-issue bij PDOK.")
            print("    Val terug op heuristiek (postcode+huisnummer group size).")
            kept = filter_eengezins_heuristic(adressen)
            source_note = (
                f"Bron: PDOK Locatieserver (BAG-verrijking gefaald, fallback op heuristiek).\n"
                f"Filter: (postcode, huisnummer) groepen ≤{MAX_VBOS_PER_PAND} — proxy voor eengezins.\n"
            )
        else:
            kept = filter_eengezins_bag(adressen, enriched)
            source_note = (
                f"Bron: PDOK Locatieserver + BAG WFS.\n"
                f"Filter: gebruiksdoel=woonfunctie, oppervlakte>={MIN_OPPERVLAKTE_EENGEZINS_M2}m², "
                f"≤{MAX_VBOS_PER_PAND} VBO's per pand.\n"
            )
    else:
        kept = filter_eengezins_heuristic(adressen)
        source_note = (
            f"Bron: PDOK Locatieserver (zonder BAG-verrijking).\n"
            f"Filter: (postcode, huisnummer) groepen ≤{MAX_VBOS_PER_PAND} — proxy voor eengezins.\n"
            f"Voor scherpere filter: draai met --enrich.\n"
        )

    items = []
    zonder_coord = 0
    for d in kept:
        lat, lng = parse_centroide_ll(d.get("centroide_ll"))
        if lat is None:
            zonder_coord += 1
        items.append({
            "adres": format_adres(d, args.woonplaats),
            "lat": lat,
            "lng": lng,
            "_bag_oppervlakte": d.get("_bag_oppervlakte"),
            "_bag_vbo_count_pand": d.get("_bag_vbo_count_pand"),
        })
    if zonder_coord:
        print(f"→ ⚠️  {zonder_coord}/{len(items)} adressen zonder PDOK-coordinaat "
              f"(scanner valt terug op Nominatim voor die).")
    items = sorted(items, key=sort_key)

    out_path = Path(args.out) if args.out else \
               SCRIPT_DIR / f"addresses_{args.wijk.lower()}.py"
    write_output(items, out_path, args.wijk, source_note)
    print(f"\n✓ {len(items)} adressen → {out_path.name}")
    print(f"\nStraks in scanner:")
    print(f"    python3 apple_web_scanner.py --wijk {args.wijk.lower()} --limit 20")

if __name__ == "__main__":
    main()
