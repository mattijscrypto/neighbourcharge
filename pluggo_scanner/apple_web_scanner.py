"""
Pluggo Scanner — Apple Maps Web edition (maps.apple.com Look Around)

Waarom deze route (vs apple_scanner.py / MKLookAroundSnapshotter):
  Apple's public MapKit-API laat GEEN heading/POV controle toe op snapshots.
  Voor multi-angle shots van rijtjeshuizen (waar de wallbox vaak op de
  zijgevel zit) moeten we door de panorama's kunnen navigeren.
  maps.apple.com toont dezelfde verse Look Around data als de desktop-app.
  We driven 't via Playwright + WebKit.

Voorbereiding:
    pip install playwright requests
    playwright install webkit    # WebKit engine, geen Chromium

    # Ollama draait al lokaal (zelfde als browser_scanner)

    # !! VPN aan (Mullvad NL exit oid) VÓÓRDAT je 't script runt.
    # Playwright pakt automatisch de systeem-proxy.

Gebruik:
    # Eerste keer: debug-mode. Opent Look Around bij Gibraltar 170,
    # dumpt URL/DOM zodat we weten waar de nav-controls zitten.
    python3 apple_web_scanner.py --debug

    # Daarna: gewone scan
    python3 apple_web_scanner.py --wijk vathorst --limit 5
    python3 apple_web_scanner.py --wijk vathorst --limit 0
"""

import argparse
import asyncio
import base64
import csv
import hashlib
import json
import math
import re
import shutil
import time
from pathlib import Path

import requests
from playwright.async_api import async_playwright

from importlib import import_module

def load_addresses_for_wijk(wijk):
    """Zoek `addresses_<wijk>.py` (nieuwe conventie), val terug op test_addresses
    voor vathorst (legacy)."""
    for mod_name in (f"addresses_{wijk}", "test_addresses"):
        try:
            mod = import_module(mod_name)
            return mod.TEST_ADDRESSES, mod_name
        except ModuleNotFoundError:
            continue
    raise ModuleNotFoundError(
        f"Geen adressenbestand gevonden voor wijk '{wijk}'. "
        f"Maak addresses_{wijk}.py aan (draai bv. fetch_nieuwland.py)."
    )

# Vathorst is default — geladen tijdens import zodat we geen module-scope side
# effects introduceren op de rest van de scanner. Voor andere wijken vervangt
# run() dit met load_addresses_for_wijk().
TEST_ADDRESSES = None

# ─────────────────────────────────────────────────────────────
# Config

DEFAULT_WIJK = "vathorst"
DEFAULT_SAMPLE_SIZE = 5
STEPS_PER_SIDE = 1          # 1 pano naar links + 1 naar rechts + base = 3 shots
PANO_LOAD_S = 4.0           # wachttijd na Look Around laden / pano-navigatie
DELAY_BETWEEN_ADDR_S = 8    # rate-limit friendly: 8 sec tussen adressen
OLLAMA_MODEL = "qwen2.5vl:7b"
OLLAMA_URL = "http://localhost:11434"
HEADLESS = False            # False = zie de browser werken (aanbevolen voor iteratie)

# Safari-achtige UA — Apple Maps is voor Safari geoptimaliseerd
SAFARI_UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 "
             "(KHTML, like Gecko) Version/17.5 Safari/605.1.15")

# Direct Apple Maps SPA (geen beta subdomein — redirect toch naar /frame? SPA).
# Geen t=r/t=k want dat zet satellietweergave aan; we willen normale kaart met
# blauwe Look Around coverage-stripes zichtbaar.
MAPS_URL_TMPL = "https://maps.apple.com/?ll={lat:.6f},{lng:.6f}&z=20"

# Geschatte positie van de binoculars-icoon (Look Around toggle) links-onderaan.
# In viewport 1600x1000 zit 'ie rond (250, 940). Empirisch bepaald uit debug-run.
BINOCULARS_XY = (250, 940)

# Paden — wordt door setup_paths gezet
SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = None
PHOTOS_DIR = None
DEBUG_DIR = None
CSV_PATH = None

# Referentie-foto's voor few-shot leren.
# Drop 3-6 close-ups van wallboxes/laadpalen aan gevels in deze map.
# Aanbevolen: eigen paal, verschillende kleuren (zwart, wit), verschillende gevels
# (baksteen, panelen). Deze foto's worden bij ELKE Ollama-call vooraan
# meegegeven, met uitleg in de prompt dat dit is hoe een wallbox eruitziet.
REF_DIR = SCRIPT_DIR / "reference_wallboxes"
# qwen2.5vl:7b klapt boven ~5-6 images per request. Cap refs zodat 4 refs + 3
# scans = 7 totaal. Refs worden alfabetisch geladen, dus prefix je bestand met
# 01_, 02_ etc. om te kiezen welke doorkomen.
MAX_REF_IMAGES = 4

def setup_paths(wijk, csv_suffix=""):
    global OUTPUT_DIR, PHOTOS_DIR, DEBUG_DIR, CSV_PATH
    OUTPUT_DIR = SCRIPT_DIR / "output_apple_web" / wijk
    PHOTOS_DIR = OUTPUT_DIR / "photos"
    DEBUG_DIR = OUTPUT_DIR / "debug"
    PHOTOS_DIR.mkdir(parents=True, exist_ok=True)
    DEBUG_DIR.mkdir(parents=True, exist_ok=True)
    CSV_PATH = OUTPUT_DIR / f"results{csv_suffix}.csv"

# ─────────────────────────────────────────────────────────────
# Geocoding + helpers (kopie uit browser_scanner om Playwright-import in die
# file te vermijden — ja dubbele code, we accepteren dat voor nu)

UA_NOMINATIM = "PluggoScanner/1.0 (contact: m.sloothovenier@gmail.com)"
NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

_last_nominatim = 0.0

def geocode(adres):
    """Adres → (lat, lng, display_name) via Nominatim (max 1 req/sec per TOS).

    display_name wordt teruggegeven zodat run() een sanity-check kan doen: als
    Nominatim een niet-bestaande straat fuzzy-matched naar een andere (bv.
    'Alpensalamander' → 'Vuursalamander'), zit de mismatch in display_name.
    """
    global _last_nominatim
    dt = time.time() - _last_nominatim
    if dt < 1.1:
        time.sleep(1.1 - dt)
    r = requests.get(
        NOMINATIM_URL,
        params={"q": adres, "format": "json", "limit": 1, "countrycodes": "nl"},
        headers={"User-Agent": UA_NOMINATIM},
        timeout=15,
    )
    _last_nominatim = time.time()
    r.raise_for_status()
    data = r.json()
    if not data:
        return None, None, None
    return float(data[0]["lat"]), float(data[0]["lon"]), data[0].get("display_name", "")


def _extract_street(adres):
    """'Alpensalamander 6, Amersfoort' → 'alpensalamander' (voor fuzzy match)."""
    s = adres.rsplit(",", 1)[0]
    # Strip huisnummer + eventuele letter aan het eind
    s = re.sub(r'\s+\d+[a-zA-Z]?\s*$', '', s)
    return s.strip().lower()


def _geocode_matches_street(adres, display_name):
    """True als de gezochte straatnaam voorkomt in Nominatim's display_name.

    Case-insensitive substring match. Handelt korte straten (2-3 huizen) af
    waar Nominatim graag naar een gelijkende bekendere straat snapt.
    """
    if not display_name:
        return False
    street = _extract_street(adres)
    return street in display_name.lower()

def slugify(s):
    return "".join(c if c.isalnum() else "_" for c in s).strip("_")[:60]

def _bearing_deg(lat1, lng1, lat2, lng2):
    """Kompaskoers (0-360°) van punt 1 naar punt 2. 0=N, 90=O."""
    dlng = math.radians(lng2 - lng1)
    lat1r = math.radians(lat1)
    lat2r = math.radians(lat2)
    x = math.sin(dlng) * math.cos(lat2r)
    y = math.cos(lat1r) * math.sin(lat2r) - math.sin(lat1r) * math.cos(lat2r) * math.cos(dlng)
    return (math.degrees(math.atan2(x, y)) + 360) % 360

def _offset_latlng(lat, lng, meters, bearing_deg):
    """Bereken nieuwe (lat, lng) op `meters` afstand in richting `bearing_deg`."""
    br = math.radians(bearing_deg)
    dlat = meters * math.cos(br) / 111000.0
    dlng = meters * math.sin(br) / (111000.0 * math.cos(math.radians(lat)))
    return (lat + dlat, lng + dlng)

# ─────────────────────────────────────────────────────────────
# Playwright Apple Maps driver

async def _is_pano_active(page):
    """Detecteer of Look Around actief is via specifieke Apple Maps classes.

    Uit DOM-inspectie: als Look Around open is, bestaat `.mw-look-around-view`
    in de DOM met een niet-triviale grootte. Bonus-signaal: de sluiten-knop
    `.mw-look-around-view-close` bestaat.
    """
    return await page.evaluate("""() => {
      const view = document.querySelector('.mw-look-around-view');
      if (!view) {
        return {active: false, reason: 'no .mw-look-around-view'};
      }
      const r = view.getBoundingClientRect();
      const closeBtn = document.querySelector('.mw-look-around-view-close');
      const expandBtn = document.querySelector('.mw-look-around-view-expand');
      const isFullscreen = !expandBtn ||
        (expandBtn.getBoundingClientRect().width === 0);
      return {
        active: r.width > 100 && r.height > 100,
        viewSize: {w: Math.round(r.width), h: Math.round(r.height)},
        hasCloseBtn: !!closeBtn,
        hasExpandBtn: !!expandBtn,
        isFullscreen,
      };
    }""")

async def _go_fullscreen(page):
    """Klik op de expand-knop om Look Around fullscreen te maken.

    Selector: `.mw-look-around-view-expand` (aria-label "Naar schermvullende
    weergave overschakelen"). Als 'ie er niet is → we zitten al fullscreen.
    """
    result = await page.evaluate("""() => {
      const btn = document.querySelector('.mw-look-around-view-expand');
      if (!btn) return 'no expand button';
      btn.click();
      return 'clicked';
    }""")
    await asyncio.sleep(2)
    return result

async def _get_puck_heading(page):
    """
    Lees de camera-heading uit de puck (0=N, 90=O, 180=Z, 270=W).

    De puck heeft `style="rotate: 166.391246deg;"` (CSS logical rotate).
    Waarde = kompaskoers van de camera.
    """
    return await page.evaluate("""() => {
      const puck = document.querySelector('.mw-look-around-puck');
      if (!puck) return null;
      const s = puck.getAttribute('style') || '';
      const m = s.match(/rotate:\\s*(-?\\d+(?:\\.\\d+)?)deg/);
      return m ? parseFloat(m[1]) : null;
    }""")

async def _diagnose_click_point(page, x, y):
    """Wat zit er precies op (x, y)? Voor debug."""
    return await page.evaluate(f"""() => {{
      const el = document.elementFromPoint({x}, {y});
      if (!el) return null;
      return {{
        tag: el.tagName,
        cls: (el.className || '').toString().slice(0, 100),
        id: el.id || '',
        aria: el.getAttribute('aria-label') || '',
        role: el.getAttribute('role') || '',
        text: (el.innerText || '').slice(0, 50),
        rect: (() => {{
          const r = el.getBoundingClientRect();
          return {{x: Math.round(r.left), y: Math.round(r.top),
                   w: Math.round(r.width), h: Math.round(r.height)}};
        }})(),
      }};
    }}""")

async def _find_binoculars_button(page):
    """Zoek de Look Around (binoculars) icoon in de UI.

    Apple Maps SPA gebruikt geen aria-label op de icoon-knoppen. We doen
    dus DOM-heuristic: kleine klikbare elementen (button/div[role]) in de
    linker onderhelft van de viewport, met een SVG erin. De binoculars zit
    typisch geïsoleerd links-onder, ~40-60px groot.
    """
    return await page.evaluate("""() => {
      const H = window.innerHeight, W = window.innerWidth;
      const cands = Array.from(document.querySelectorAll('button, [role=button], div'));
      const hits = [];
      for (const el of cands) {
        const r = el.getBoundingClientRect();
        // Klein knopje, links-onder kwadrant, met SVG erin
        if (r.width < 20 || r.height < 20 || r.width > 90 || r.height > 90) continue;
        if (r.top < H * 0.6 || r.top > H - 20) continue;
        if (r.left > W * 0.35) continue;
        if (!el.querySelector('svg, img')) continue;
        hits.push({
          x: Math.round(r.left + r.width/2),
          y: Math.round(r.top + r.height/2),
          w: Math.round(r.width),
          h: Math.round(r.height),
          tag: el.tagName,
          cls: (el.className || '').toString().slice(0, 60),
          aria: el.getAttribute('aria-label') || '',
        });
      }
      // Sorteer: prefereer meest links + meest onderaan
      hits.sort((a, b) => (a.x + (H - a.y)) - (b.x + (H - b.y)));
      return hits.slice(0, 5);
    }""")

async def enter_look_around(page, lat, lng, dbg_prefix=None):
    """
    Open maps.apple.com op (lat, lng) en probeer Look Around te activeren.

    Return: (bool_active, str_strategy_used).

    Strategie (in volgorde):
      1. DOM-heuristic: klein icoon-knopje links-onder met SVG (= binoculars)
      2. Klik op de geschatte positie van de binoculars (BINOCULARS_XY)
      3. Klik op de blauwe coverage-stripe midden in het viewport
         (dubbelklik forceert Look Around op dat punt)
    """
    url = MAPS_URL_TMPL.format(lat=lat, lng=lng)
    print(f"      → {url}")
    await page.goto(url, wait_until="domcontentloaded", timeout=45000)
    # Wachten tot map-tiles en JS-controls geladen zijn
    await asyncio.sleep(5)

    # Cookies wegklikken als 'ie verschijnt
    await _dismiss_cookies(page)
    await asyncio.sleep(1)

    if dbg_prefix:
        await page.screenshot(path=str(DEBUG_DIR / f"{dbg_prefix}_1_after_load.png"), full_page=True)
        print(f"      [debug] URL na load: {page.url[:200]}")

    # Focus op de map zodat keyboard shortcuts werken
    await page.mouse.move(900, 500)
    await page.mouse.click(900, 500)
    await asyncio.sleep(0.3)

    strategy = None
    last_state = None

    async def _try(name, coro):
        nonlocal strategy, last_state
        try:
            await coro()
            strategy = name
            await asyncio.sleep(PANO_LOAD_S)
            last_state = await _is_pano_active(page)
            active = bool(last_state and last_state.get("active"))
            print(f"      [debug] na {name}: {last_state}")
            return active
        except Exception as e:
            print(f"      [debug] {name} faalde: {e}")
            return False

    # === Strategy 1: keyboard shortcut Shift+K ===
    # Uit DOM: <div aria-label="Kijk rond" aria-keyshortcuts="shift+k">
    # Dit bypasst de mk-map-node-element overlay volledig.
    ok = await _try(
        "shift+k",
        lambda: page.keyboard.press("Shift+K"),
    )
    if ok:
        if dbg_prefix:
            await page.screenshot(path=str(DEBUG_DIR / f"{dbg_prefix}_2_success.png"))
        return True, strategy

    # === Strategy 2: DOM .click() op de exacte selector ===
    # aria-label="Kijk rond" (NL) — synthetic click bypasst pointer-events overlay
    ok = await _try(
        'js_click [aria-label="Kijk rond"]',
        lambda: page.evaluate("""() => {
          const el = document.querySelector('[aria-label="Kijk rond"]');
          if (!el) throw new Error('button not found');
          el.click();
        }"""),
    )
    if ok:
        if dbg_prefix:
            await page.screenshot(path=str(DEBUG_DIR / f"{dbg_prefix}_2_success.png"))
        return True, strategy

    # === Strategy 3: Playwright locator click (force=True bypasst overlays) ===
    ok = await _try(
        'locator [aria-label="Kijk rond"] force',
        lambda: page.locator('[aria-label="Kijk rond"]').click(force=True, timeout=3000),
    )
    if ok:
        if dbg_prefix:
            await page.screenshot(path=str(DEBUG_DIR / f"{dbg_prefix}_2_success.png"))
        return True, strategy

    # === Alles faalde: dump DOM voor iteratie ===
    if dbg_prefix:
        await page.screenshot(path=str(DEBUG_DIR / f"{dbg_prefix}_3_no_pano.png"), full_page=True)
        try:
            html = await page.content()
            (DEBUG_DIR / f"{dbg_prefix}_dom_after.html").write_text(html, encoding="utf-8")
            print(f"      [debug] DOM (na) gedumpt: {dbg_prefix}_dom_after.html "
                  f"({len(html)} bytes)")
        except Exception:
            pass
        print(f"      [debug] URL na alle pogingen: {page.url[:200]}")

    print(f"      ✗ Look Around niet actief (laatste: {strategy}, state={last_state})")
    return False, strategy or "none"

async def _dismiss_cookies(page):
    texts = ["Accept", "Accept All", "Alles accepteren", "Weigeren", "Reject",
             "I agree", "OK", "Continue"]
    for text in texts:
        try:
            btn = page.get_by_role("button", name=re.compile(text, re.I)).first
            if await btn.is_visible(timeout=800):
                await btn.click()
                await asyncio.sleep(1)
                return
        except Exception:
            continue

async def screenshot_pano(page):
    """Screenshot van de Look Around pano-view.

    Look Around vult ~90-95% van het viewport met een video/canvas element.
    De map-canvas eronder is óók 1600x1000 maar zit onder Look Around.
    Simpelste + betrouwbaarste: een volledige viewport-screenshot. De sidebar
    (Zoek/Gidsen/Route) is meestal weggevouwen in Look Around, dus we hebben
    ~95% pano-content in het frame.
    """
    return await page.screenshot(type="jpeg", quality=88, full_page=False)

async def rotate_camera(page, degrees):
    """
    Roteer de camera in de Look Around view via een muis-drag op de canvas.

    Apple Maps opent Look Around auto-georiënteerd op het pin-adres (camera
    kijkt richting huis). Door de canvas te draggen roteren we vanaf dat
    startpunt. Rotatie geeft ons zicht op de ZIJGEVEL — waar wallboxes in
    Vathorst vaak zitten.

    Args:
      degrees: positief = rechts draaien (camera naar rechts pannen).
               Bijv. +45 laat de rechter zijgevel zien, -45 de linker.

    Retourneert: True als hash veranderde (rotatie werkte).
    """
    coords = await page.evaluate("""() => {
      const view = document.querySelector('.mw-look-around-view');
      if (!view) return null;
      const r = view.getBoundingClientRect();
      return {
        cx: Math.round(r.left + r.width / 2),
        cy: Math.round(r.top + r.height / 2),
        w: Math.round(r.width),
        h: Math.round(r.height),
      };
    }""")
    if not coords:
        print("      [debug] rotate: geen .mw-look-around-view")
        return False

    # Pre-shot hash voor verificatie
    pre_shot = await page.screenshot(
        type="jpeg", quality=50,
        clip={"x": coords["cx"] - 200, "y": coords["cy"] - 150,
              "width": 400, "height": 300},
    )
    pre_hash = hashlib.sha1(pre_shot).hexdigest()[:12]

    # Empirische kalibratie op Apple Look Around (13" MBP, dpr=2, WebKit):
    # gemeten overshoot van ~1.8x met w/60 → dus effectieve sensitivity is w/108.
    # Feedback-loop in _open_and_face vangt eventuele restfouten op.
    px_per_degree = coords["w"] / 108.0
    dx = int(degrees * px_per_degree)
    # NB: drag naar LINKS = camera roteert naar RECHTS (positief).
    end_x = coords["cx"] - dx

    print(f"      [debug] rotate {degrees:+d}° via drag ({coords['cx']},{coords['cy']}) → ({end_x},{coords['cy']})")

    await page.mouse.move(coords["cx"], coords["cy"])
    await page.mouse.down()
    # Stapsgewijze drag voor natuurlijke pan
    steps = 15
    for i in range(1, steps + 1):
        x = coords["cx"] + (end_x - coords["cx"]) * i // steps
        await page.mouse.move(x, coords["cy"])
        await asyncio.sleep(0.02)
    await page.mouse.up()
    await asyncio.sleep(1.5)

    # Post-shot hash
    post_shot = await page.screenshot(
        type="jpeg", quality=50,
        clip={"x": coords["cx"] - 200, "y": coords["cy"] - 150,
              "width": 400, "height": 300},
    )
    post_hash = hashlib.sha1(post_shot).hexdigest()[:12]
    changed = pre_hash != post_hash
    print(f"      [debug] hash {pre_hash} → {post_hash} (changed={changed})")
    return changed

async def _open_and_face(page, pano_lat, pano_lng, target_lat, target_lng,
                         dbg_prefix=None, dbg_suffix="", max_delta_after=None):
    """
    Open Look Around bij (pano_lat, pano_lng) en roteer de camera zodat 'ie
    naar (target_lat, target_lng) kijkt.

    Args:
      max_delta_after: als niet None, verifieer dat de puck-heading NA de rotate
                       binnen `max_delta_after` graden van target_bearing zit.
                       Zo niet → return False (view skippen).

    Returns: True als 't gelukt is.
    """
    ok, _ = await enter_look_around(page, pano_lat, pano_lng, dbg_prefix=None)
    if not ok:
        return False
    await _go_fullscreen(page)

    # Lees actuele camera-heading (waar Apple 'm auto-oriënteerde)
    puck = await _get_puck_heading(page)
    if puck is None:
        print(f"      [debug] {dbg_suffix}: geen puck heading gevonden — skip rotate")
        return True

    # Bereken bearing van pano naar target
    target_bearing = _bearing_deg(pano_lat, pano_lng, target_lat, target_lng)

    # Iteratief roteren met feedback (drag-kalibratie is niet perfect)
    max_iters = 3
    tolerance = 6  # graden — binnen deze marge stoppen we
    for i in range(max_iters):
        delta = (target_bearing - puck + 540) % 360 - 180
        print(f"      [debug] {dbg_suffix} iter{i}: puck={puck:.0f}° "
              f"target={target_bearing:.0f}° delta={delta:+.0f}°")
        if abs(delta) <= tolerance:
            break
        await rotate_camera(page, int(delta))
        new_puck = await _get_puck_heading(page)
        if new_puck is None:
            break
        puck = new_puck

    # Sanity-check: klopt de eind-heading?
    final_delta = abs((target_bearing - puck + 540) % 360 - 180)
    print(f"      [debug] {dbg_suffix}: final puck={puck:.0f}° final_delta={final_delta:.0f}°")
    if max_delta_after is not None and final_delta > max_delta_after:
        print(f"      [debug] {dbg_suffix}: SKIP — camera wijst nog {final_delta:.0f}° "
              f"van target af (kalibratie faalt of wrong pano)")
        return False

    return True


async def capture_3_panos(page, lat, lng, slug, dbg=False):
    """
    3 shots met echte pano-stappen langs de straat:
      base = pano ~5m TERUG van de gevel (voor afstand/context), camera facing huis
      F1   = pano ~7m verderop langs de straat, camera terug-geroteerd naar huis
      B1   = pano ~7m de andere kant op langs de straat, camera terug-geroteerd naar huis

    Straatrichting = camera-richting (naar huis) + 90° (perpendiculair).
    Als Apple een pano opent die >45° afwijkt van de verwachte richting
    (= verkeerde pano gekozen), skippen we die view.
    """
    dbg_prefix = slug if dbg else None

    # === 1. Peil eerst house_heading vanuit de target-coord ===
    ok, _ = await enter_look_around(page, lat, lng, dbg_prefix=dbg_prefix)
    if not ok:
        return None
    await _go_fullscreen(page)
    if dbg_prefix:
        await page.screenshot(path=str(DEBUG_DIR / f"{slug}_2b_fullscreen.png"))

    # Puck heading = camera-richting (naar het huis toe)
    house_heading = await _get_puck_heading(page)
    if house_heading is None:
        # Fallback: geen straatgeometrie beschikbaar → alleen de target-pano
        print("      [debug] geen puck heading op target — alleen base-foto")
        base_photo = await screenshot_pano(page)
        (PHOTOS_DIR / f"{slug}_base.jpg").write_bytes(base_photo)
        return [("base", base_photo)]

    # Straatgeometrie
    street_bearing_f = (house_heading + 90) % 360   # "voorwaarts" langs straat
    street_bearing_b = (house_heading - 90) % 360   # "achterwaarts" langs straat
    step_m = 7        # binnen 1 huisbreedte blijven (Vathorst-huizen ~5-6m)
    facade_m = 8      # gevel-doel: 8m van straat-coord richting gevel

    # BELANGRIJK: de opgegeven (lat,lng) is meestal een straat-geocode, niet
    # de gevel zelf. Om alle 3 de camera's naar de GEVEL te laten kijken
    # (i.p.v. langs de straat), schuiven we het rotate-doel 8m in
    # house_heading richting.
    facade_lat, facade_lng = _offset_latlng(lat, lng, facade_m, house_heading)

    print(f"      [debug] house_heading={house_heading:.0f}° "
          f"street_F={street_bearing_f:.0f}° street_B={street_bearing_b:.0f}°")
    print(f"      [debug] gevel-doel: {facade_lat:.6f}, {facade_lng:.6f} "
          f"({facade_m}m van straat-coord)")

    photos = []

    # === 2. base — vanuit target-coord, terug-facing gevel ===
    # (Apple snapt vaak naar dezelfde pano bij kleine verplaatsing, dus we
    # gebruiken de target-coord zelf en laten face-rotate 't werk doen.)
    print(f"      → base pano: {lat:.6f}, {lng:.6f} (target-coord)")
    if await _open_and_face(page, lat, lng, facade_lat, facade_lng,
                            dbg_suffix="base", max_delta_after=45):
        if dbg_prefix:
            await page.screenshot(path=str(DEBUG_DIR / f"{slug}_3_base.png"))
        base_photo = await screenshot_pano(page)
        photos.append(("base", base_photo))
        (PHOTOS_DIR / f"{slug}_base.jpg").write_bytes(base_photo)

    # === 3. F1 — 7m voorwaarts langs straat, camera terug naar gevel ===
    f1_lat, f1_lng = _offset_latlng(lat, lng, step_m, street_bearing_f)
    print(f"      → F1 pano: {f1_lat:.6f}, {f1_lng:.6f}")
    if await _open_and_face(page, f1_lat, f1_lng, facade_lat, facade_lng,
                            dbg_suffix="F1", max_delta_after=45):
        if dbg_prefix:
            await page.screenshot(path=str(DEBUG_DIR / f"{slug}_4_F1.png"))
        f1_photo = await screenshot_pano(page)
        photos.append(("F1", f1_photo))
        (PHOTOS_DIR / f"{slug}_F1.jpg").write_bytes(f1_photo)

    # === 4. B1 — 7m achterwaarts langs straat, camera terug naar gevel ===
    b1_lat, b1_lng = _offset_latlng(lat, lng, step_m, street_bearing_b)
    print(f"      → B1 pano: {b1_lat:.6f}, {b1_lng:.6f}")
    if await _open_and_face(page, b1_lat, b1_lng, facade_lat, facade_lng,
                            dbg_suffix="B1", max_delta_after=45):
        if dbg_prefix:
            await page.screenshot(path=str(DEBUG_DIR / f"{slug}_5_B1.png"))
        b1_photo = await screenshot_pano(page)
        photos.append(("B1", b1_photo))
        (PHOTOS_DIR / f"{slug}_B1.jpg").write_bytes(b1_photo)

    if not photos:
        return None

    # Volgorde voor Ollama: B1, base, F1 (van links naar rechts langs straat)
    order = {"B1": 0, "base": 1, "F1": 2}
    photos.sort(key=lambda p: order[p[0]])
    return photos

# ─────────────────────────────────────────────────────────────
# Ollama vision (dezelfde prompt als apple_scanner.py)

PROMPT_MULTI = """Je bekijkt {n} Apple Look Around foto's van HETZELFDE Nederlands huis in Amersfoort.
De foto's zijn genomen vanaf 3 verschillende pano-posities langs dezelfde straat:
- B1   = camera vanuit ~7m naar de ene kant van het huis (schuine hoek)
- base = camera vlak vóór het huis (frontale gevel-view, dichtbij)
- F1   = camera vanuit ~7m naar de andere kant (schuine hoek, andere zijgevel)

Alle 3 camera's kijken naar HETZELFDE doel-huis vanuit verschillende hoeken. Het doel-huis
staat in het midden van elke foto.

Je moet TWEE dingen bepalen over het CENTRALE huis:
  (A) heeft_laadpaal — is er thuis-oplaadinfra (wallbox / laadpaal) aanwezig?
  (B) oprit_aanwezig — heeft dit huis een eigen oprit / carport / garage waar een
      auto voor de gevel geparkeerd kan worden op eigen terrein?

Deze twee vragen zijn ONAFHANKELIJK — een huis kan wel/geen oprit hebben en wel/geen
laadpaal. De doelgroep voor onze brief-mailing is: oprit=ja + laadpaal=nee.

═══════════════════════════════════════
VRAAG A — LAADINFRA: HOE JE MOET KIJKEN
═══════════════════════════════════════

1. **Scan systematisch**: loop de complete gevel af (voor+zij), oprit, carport, achterkant
   van de portico. Wallboxes zitten vaak op verrassende plekken.

2. **ZWART-OP-ZWART CAMOUFLAGE**: veel Amersfoortse huizen hebben zwarte of donkere
   gevelpanelen. Zwarte wallboxes vallen daar bijna weg. Zoek gericht naar:
   - kleine LED-puntjes (rood/groen/wit) op donkere muren
   - rechthoekige silhouetten met scherpe randen tegen de baksteen/panelen
   - verticale cilinders / paal-vormen die niet-organisch zijn
   - Type 2-plug flappen (rond, met dekseltje)

3. **KABELGOOT = STERKE HINT**: een kabelgoot langs de gevel loopt bijna altijd naar een
   wallbox of laadpaal. Als je een kabelgoot ziet én een oprit met (E)V of laadkabel,
   is heeft_laadpaal WAARSCHIJNLIJK true (confidence ≥0.6) — ook al zie je de wallbox
   zelf niet 100% duidelijk. Kabelgoten in woonwijken zijn zeldzaam behalve voor EV-lading.

   **KABELGOOT AAN BEIDE ZIJDEN = ALTIJD LADEN**: een kabelgoot heeft GEEN andere
   functie dan EV-lading (geen tuinverlichting, geen antenne). Als je op ≥2 foto's een
   kabelgoot ziet (dus aan meerdere gevelzijden), dan is heeft_laadpaal = true met
   confidence ≥0.7. Ook al zie je de wallbox zelf nergens duidelijk staan, de goot vormt
   harde infrastructurele evidentie. NIET twijfelen.

4. **VOLG DE KABEL**: als je een dikke zwarte/oranje/gele kabel ziet op de oprit,
   in de auto-stekker, of tegen de muur: FOLLOW IT. Waar 'ie eindigt zit de wallbox.

SIGNAAL-WEGING LAADINFRA:

STERK (elk voldoende voor heeft_laadpaal=true, conf ≥0.8):
- Wallbox aan gevel/schuur — rechthoekig kastje ~30cm (wit/zwart, LED/display zichtbaar)
- Freestanding laadpaal op oprit — ~1-1.5m hoog, dun, LED-strip
- Type 2 stopcontact — rond, ~10cm, vaak met flap
- Laadkabel in gebruik — dikke kabel van muur/paal naar auto

MATIG (2 samen = STERK):
- Kabelgoot langs gevel richting oprit
- EV op oprit (Tesla, ID.3/4/7, Zoe, Ioniq, Kia EV6/Niro, Polestar, Audi e-tron/Q4/Q6,
  BMW iX/i4/i5, EQ-serie, Mustang Mach-E, Volvo EX-serie, MG4/5)
- Losse laadkabel gerold/opgehangen (zonder auto eraan)

═══════════════════════════════════════
VRAAG B — OPRIT: HOE JE MOET KIJKEN
═══════════════════════════════════════

Een "oprit" = eigen verhard terrein VOOR of NAAST de gevel, waar een auto kan staan.
Vaak zit er een oprit tussen de openbare stoep en de voordeur/gevel.

STERKE OPRIT-SIGNALEN (elk voldoende voor oprit_aanwezig=true):
- **Verharding voor de gevel**: klinkers, tegels, beton of asfalt tussen stoep en huis
  waar duidelijk EEN auto op past (ongeveer 2.5m × 5m), begrensd door tuin/heg/muur
  naar de buren toe (= niet doorlopend naar buurpanden).
- **Auto op eigen terrein**: een auto die duidelijk NIET op de openbare straat maar
  op verharding vóór/naast DEZE gevel staat, met een tuin of scheiding tussen buurhuis.
- **Garagedeur** (kanteldeur / sectionaal / dubbele deur) in de voorgevel of zijgevel
  van het CENTRALE huis (niet die van de buren).
- **Carport** — open dakconstructie op palen bedoeld voor EEN auto per huishouden.
- **Inrit-verlaging in de stoep** — de stoeprand is verlaagd/afgeschuind zodat een auto
  van de weg de oprit op kan rijden. Vaak zichtbaar als lichtere klinker-strook.

═══════════════════════════════════════
KRITIEK — VERSCHIL OPRIT vs. FLAT-PARKEERPLAATS
═══════════════════════════════════════

Dit is de belangrijkste val bij vraag B. Een gedeelde parkeerplaats vóór een flat of
appartementengebouw is GEEN oprit — ook al ligt er verharding en staan er auto's.

Herken een FLAT / APPARTEMENTENGEBOUW aan:
- Gebouw is ≥3 verdiepingen hoog met horizontaal doorlopende gevel
- Veel voordeuren dicht bij elkaar in EEN gebouw (portiekflat, galerijflat)
- Balkons op elke verdieping i.p.v. individuele daken
- Gemeenschappelijke centrale entree i.p.v. individuele voordeur per huis
- Grote naam-bordjes / bellenpaneel bij één ingang
- Rijtje brievenbussen naast één ingang (i.p.v. per huis)
- Geen individuele voortuintjes maar één doorlopende strook groen of verharding

Als je een FLAT ziet + verharding met auto's ervoor: oprit_aanwezig = **false**.
Dat is een GEDEELDE parkeerplaats voor bewoners van het gebouw — niemand heeft
individueel recht op één plek en er kan geen eigen wallbox worden geplaatst.

GEDEELDE PARKEERPLAATS (oprit_aanwezig=false):
- Groot doorlopend verhard vlak vóór meerdere voordeuren / meerdere buurpanden zonder
  scheiding (heg, muur, hek) tussen de plekken.
- Wit-gemarkeerde parkeervakken op de grond (belijning met verf) — kenmerk van een
  gemeenschappelijke parkeerplaats, niet van een privé-oprit.
- ≥3 auto's naast elkaar geparkeerd vóór dezelfde gevel-strook zonder tussenmuren.
- Achteringangen van garageboxen-rij bij een flat.
- Openbare parkeervakken langs de rijbaan met betaal-paal of vergunning-bord.

GEEN OPRIT (oprit_aanwezig=false):
- Alleen een smal tuinpad naar de voordeur (te smal voor auto).
- Voortuin met gras/planten/heg direct grenzend aan de stoep — geen verharding voor auto.
- Rijtje geparkeerde auto's OP de openbare straat (aan de stoeprand) — dat is straat-
  parkeren, geen eigen oprit.
- Achtertuin met parking (niet zichtbaar vanaf de straat) — we scoren alleen wat
  zichtbaar is vanaf de camera-positie.

TWIJFEL (oprit_aanwezig=null):
- Als de gevel volledig verscholen zit achter een schutting/heg en je niet kunt zien
  wat er achter zit, geef null.
- Als de camera de voorgevel niet in beeld heeft, geef null.
- Als je twijfelt tussen "individuele oprit" en "gedeelde parkeerplaats" en er geen
  duidelijke scheiding zichtbaar is, geef null (dan loopt 't naar oprit_twijfel-bucket
  voor handmatige review).

VUISTREGEL: eenvoudig laadpaal thuis plaatsen = je hebt EIGEN terrein nodig. Als de
plek zichtbaar met de buren wordt gedeeld, is het geen oprit voor deze doelgroep.

═══════════════════════════════════════
BUURHUIS-VAL
═══════════════════════════════════════
Rijtjeshuizen staan schouder-aan-schouder. Aan de RANDEN van de foto zie je vaak al
het buurhuis. Wallbox OF oprit van buurhuis NIET toewijzen aan doel-huis.
Vuistregel: object hoort bij het CENTRALE huis als 't binnen de zichtbare voor/zij-gevel
of oprit-perimeter van dat huis zit. Voor de oprit specifiek: kijk of het verharde
terrein aansluit op de gevel van het CENTRALE huis (niet van de buren).

Negeer: straatlantaarns, verkeersborden, brievenbussen, gele nutskastjes, airco-units.

Antwoord ALLEEN in geldig JSON (geen extra tekst):
{{"heeft_laadpaal": true of false, "oprit_aanwezig": true of false of null, "confidence": getal 0.0-1.0, "oprit_confidence": getal 0.0-1.0, "signalen": [array van gedetecteerde signaal-strings met foto-naam bijv. "B1: kabelgoot rechts" of "base: klinker-oprit met auto"], "ev_merk": string of null, "notitie": "max 25 woorden NL, benoem WAAR je 't ziet én noem oprit-status"}}"""

_REF_CACHE = None

def _load_reference_images():
    """Laad wallbox-referentiefoto's uit REF_DIR.

    Cached na eerste read. Return: list[bytes] (jpg/png bytes).
    Als de map leeg is of ontbreekt, return [] en print warning.
    """
    global _REF_CACHE
    if _REF_CACHE is not None:
        return _REF_CACHE

    if not REF_DIR.exists():
        print(f"   ⚠️  {REF_DIR.name}/ ontbreekt — draai zonder referentie-foto's")
        _REF_CACHE = []
        return _REF_CACHE

    exts = {".jpg", ".jpeg", ".png", ".webp"}
    files = sorted(p for p in REF_DIR.iterdir() if p.suffix.lower() in exts)
    if not files:
        print(f"   ⚠️  {REF_DIR.name}/ is leeg — drop 3-6 wallbox-foto's daar voor few-shot")
        _REF_CACHE = []
        return _REF_CACHE

    total = len(files)
    files = files[:MAX_REF_IMAGES]
    _REF_CACHE = [p.read_bytes() for p in files]
    if total > MAX_REF_IMAGES:
        print(f"   📚 {len(_REF_CACHE)}/{total} referentiefoto's geladen (cap {MAX_REF_IMAGES}) uit {REF_DIR.name}/")
    else:
        print(f"   📚 {len(_REF_CACHE)} referentiefoto's geladen uit {REF_DIR.name}/")
    return _REF_CACHE


def _apply_heuristic_overrides(analysis):
    """Vangnet voor bekende blinde vlekken van het model + type-sanering.

    Regel 1 — Kabelgoot aan beide zijden: als ≥2 signalen 'kabelgoot' bevatten
    (dus op meerdere foto's/zijden waargenomen) én model zegt False met lage
    confidence, forceren we True. In woonwijk-nieuwbouw is een kabelgoot
    functioneel alleen voor EV-lading — geen andere use case.

    Regel 2 — Sanitize oprit-velden: qwen2.5vl:7b geeft soms strings als
    "yes"/"nee"/"unknown" terug ipv true/false/null. Normaliseer.
    """
    # ── Sanitize oprit-velden ──────────────────────────────────
    oprit_raw = analysis.get("oprit_aanwezig")
    if isinstance(oprit_raw, str):
        low = oprit_raw.strip().lower()
        if low in ("true", "ja", "yes", "y", "1"):
            analysis["oprit_aanwezig"] = True
        elif low in ("false", "nee", "no", "n", "0"):
            analysis["oprit_aanwezig"] = False
        else:
            analysis["oprit_aanwezig"] = None
    elif oprit_raw not in (True, False, None):
        analysis["oprit_aanwezig"] = None

    oprit_conf = analysis.get("oprit_confidence")
    try:
        analysis["oprit_confidence"] = float(oprit_conf) if oprit_conf is not None else None
    except (TypeError, ValueError):
        analysis["oprit_confidence"] = None

    # ── Kabelgoot-override ─────────────────────────────────────
    signalen = analysis.get("signalen") or []
    if not isinstance(signalen, list):
        return analysis

    kabelgoot_hits = sum(1 for s in signalen if isinstance(s, str) and "kabelgoot" in s.lower())
    heeft = analysis.get("heeft_laadpaal")
    conf = analysis.get("confidence") or 0.0

    if kabelgoot_hits >= 2 and not heeft and conf < 0.6:
        analysis["heeft_laadpaal"] = True
        analysis["confidence"] = 0.65
        original_note = analysis.get("notitie") or ""
        analysis["notitie"] = (
            f"{original_note} [auto-override: {kabelgoot_hits}× kabelgoot → EV-lading]"
        ).strip()

    return analysis


PROMPT_FEWSHOT_HEADER = """═══════════════════════════════════════
REFERENTIEFOTO'S — DIT IS WAAR JE NAAR ZOEKT
═══════════════════════════════════════
De EERSTE {n_ref} foto's zijn REFERENTIE. Dit zijn close-ups van BEKENDE
wallboxes / laadpalen aan Nederlandse gevels. Bestudeer ze goed:
- vorm (rechthoekige kastjes, ronde palen)
- grootte t.o.v. deur/gevel-elementen
- typische plaatsing (naast voordeur, op zijgevel, naast garage)
- kleur/afwerking (wit, zwart, grijs)
- LED-indicatoren, Type 2 stekker-uitsparing

Als je in de SCAN-foto's (foto {first_scan} t/m {last_scan}) een object ziet dat
qua vorm, plaatsing of afmeting LIJKT op één van de referentiefoto's, dan
tel je dat als STERK signaal (heeft_laadpaal=true, conf ≥0.8) — ook al
staat het gedeeltelijk in schaduw of is de resolutie lager.

═══════════════════════════════════════
"""


def ollama_analyze(photos_bytes):
    ref_bytes = _load_reference_images()
    all_images = ref_bytes + list(photos_bytes)
    images_b64 = [base64.b64encode(p).decode() for p in all_images]

    n_ref = len(ref_bytes)
    n_scan = len(photos_bytes)

    if n_ref > 0:
        prompt = PROMPT_FEWSHOT_HEADER.format(
            n_ref=n_ref,
            first_scan=n_ref + 1,
            last_scan=n_ref + n_scan,
        ) + PROMPT_MULTI.format(n=n_scan)
    else:
        prompt = PROMPT_MULTI.format(n=n_scan)

    r = requests.post(
        f"{OLLAMA_URL}/api/generate",
        json={
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "images": images_b64,
            "stream": False,
            "format": "json",
            "options": {"temperature": 0.1, "num_ctx": 16384},
        },
        timeout=600,
    )
    if not r.ok:
        # Print Ollama's error body — geeft veel meer info dan raise_for_status
        print(f"\n   ⚠️  Ollama {r.status_code}: {r.text[:500]}")
        r.raise_for_status()
    analysis = json.loads(r.json()["response"])
    return _apply_heuristic_overrides(analysis)

# ─────────────────────────────────────────────────────────────
# Main

def write_csv(results):
    with CSV_PATH.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=[
            "adres", "expected", "lat", "lng", "status",
            "heeft_laadpaal", "confidence",
            "oprit_aanwezig", "oprit_confidence",
            "signalen", "ev_merk",
            "notitie", "n_photos", "labels",
        ], extrasaction="ignore")
        w.writeheader()
        w.writerows(results)

# ─────────────────────────────────────────────────────────────
# Sorteer foto's op verdict — zodat Mattijs 's ochtends snel kan checken.
#
# Hoofdsortering (by_verdict/): laadpaal ja/misschien/nee
# ja_laadpaal/       → adres heeft (waarschijnlijk) al een paal, brief overslaan
# misschien/         → menselijke check nodig
# nee_geen_laadpaal/ → adres heeft geen paal — mogelijk doelgroep
#
# Secundaire sortering (by_doelgroep/): oprit-status voor brief-mailing
# doelgroep_oprit/   → oprit=ja + laadpaal=nee → PRIMAIR — deze mensen krijgen brief
# oprit_maar_paal/   → oprit=ja + laadpaal=ja  → skip (al voorzien)
# geen_oprit/        → oprit=nee                → straatlader-doelgroep (niet nu)
# oprit_twijfel/     → oprit=null of lage conf  → menselijke check

# Drempels: heeft=True + conf>=0.7 = zeker JA; heeft=False + conf>=0.6 = zeker NEE.
# Alles ertussen (incl. auto-overrides met conf=0.65) = MISSCHIEN.
CONF_YES = 0.70
CONF_NO = 0.60
# Oprit-drempel: hoge zekerheid voor doelgroep-selectie — bij twijfel liever
# in "twijfel"-bucket zodat handmatige check erop kijkt.
OPRIT_CONF_MIN = 0.60

def _verdict_bucket(result):
    if result["status"] != "OK" or not result["n_photos"]:
        return None
    heeft = result["heeft_laadpaal"]
    conf = result["confidence"] or 0.0
    if heeft is True and conf >= CONF_YES:
        return "ja_laadpaal"
    if heeft is False and conf >= CONF_NO:
        return "nee_geen_laadpaal"
    return "misschien"

def _doelgroep_bucket(result):
    """Combineer oprit- en laadpaal-verdict → brief-mailing-bucket.

    doelgroep_oprit  = oprit=True (conf≥OPRIT_CONF_MIN) + laadpaal=False (conf≥CONF_NO)
    oprit_maar_paal  = oprit=True (conf≥OPRIT_CONF_MIN) + laadpaal=True (conf≥CONF_YES)
    geen_oprit       = oprit=False (conf≥OPRIT_CONF_MIN)
    oprit_twijfel    = alles anders (None-verdict of lage conf op oprit)
    """
    if result["status"] != "OK" or not result["n_photos"]:
        return None
    oprit = result.get("oprit_aanwezig")
    oprit_conf = result.get("oprit_confidence") or 0.0
    heeft = result["heeft_laadpaal"]
    paal_conf = result["confidence"] or 0.0

    if oprit is None or oprit_conf < OPRIT_CONF_MIN:
        return "oprit_twijfel"
    if oprit is False:
        return "geen_oprit"
    # oprit is True + hoge oprit-conf
    if heeft is True and paal_conf >= CONF_YES:
        return "oprit_maar_paal"
    if heeft is False and paal_conf >= CONF_NO:
        return "doelgroep_oprit"
    # oprit vast, maar paal-verdict onzeker → twijfel
    return "oprit_twijfel"

def _copy_bucket(bucket_root, buckets, get_marker):
    """Helper: kopieer foto's per bucket. get_marker(r) → marker-string in filename."""
    for name, items in buckets.items():
        target = bucket_root / name
        target.mkdir(parents=True, exist_ok=True)
        for r in items:
            adres_slug = slugify(r["adres"])
            matches = sorted(PHOTOS_DIR.glob(f"*_{adres_slug}_*.jpg"))
            marker = get_marker(r)
            for src in matches:
                new_name = f"{src.stem}__{marker}.jpg"
                dst = target / new_name
                shutil.copy2(src, dst)

def sort_photos_by_verdict(results):
    """Kopieer foto's van PHOTOS_DIR naar OUTPUT_DIR/by_verdict/ en /by_doelgroep/.

    by_verdict/     — sortering op laadpaal-verdict (ja/misschien/nee)
    by_doelgroep/   — sortering op oprit×paal-combinatie → brief-mailing-doelgroep
    Bestaande buckets worden eerst leeggemaakt om oude runs niet te mengen.
    """
    # 1) Hoofd-bucket op laadpaal-verdict
    by_verdict_root = OUTPUT_DIR / "by_verdict"
    if by_verdict_root.exists():
        shutil.rmtree(by_verdict_root)
    verdict_buckets = {"ja_laadpaal": [], "misschien": [], "nee_geen_laadpaal": []}
    for r in results:
        bucket = _verdict_bucket(r)
        if bucket is None:
            continue
        verdict_buckets[bucket].append(r)

    def verdict_marker(r):
        conf = r["confidence"] or 0.0
        heeft = r["heeft_laadpaal"]
        m = "JA" if heeft is True else ("NEE" if heeft is False else "?")
        return f"{m}_conf{conf:.2f}"

    _copy_bucket(by_verdict_root, verdict_buckets, verdict_marker)

    # 2) Secundaire bucket op oprit×paal → brief-doelgroep
    by_doelgroep_root = OUTPUT_DIR / "by_doelgroep"
    if by_doelgroep_root.exists():
        shutil.rmtree(by_doelgroep_root)
    doelgroep_buckets = {
        "doelgroep_oprit": [],
        "oprit_maar_paal": [],
        "geen_oprit": [],
        "oprit_twijfel": [],
    }
    for r in results:
        bucket = _doelgroep_bucket(r)
        if bucket is None:
            continue
        doelgroep_buckets[bucket].append(r)

    def doelgroep_marker(r):
        oprit = r.get("oprit_aanwezig")
        oprit_conf = r.get("oprit_confidence") or 0.0
        paal_conf = r["confidence"] or 0.0
        heeft = r["heeft_laadpaal"]
        o = "OPRIT" if oprit is True else ("GEEN-OPRIT" if oprit is False else "OPRIT-?")
        p = "PAAL" if heeft is True else ("GEEN-PAAL" if heeft is False else "PAAL-?")
        return f"{o}{oprit_conf:.2f}_{p}{paal_conf:.2f}"

    _copy_bucket(by_doelgroep_root, doelgroep_buckets, doelgroep_marker)

    # Print samenvatting
    print(f"\n📂 Foto's gesorteerd naar {by_verdict_root.name}/:")
    for name in ("ja_laadpaal", "misschien", "nee_geen_laadpaal"):
        print(f"   • {name}: {len(verdict_buckets[name])} adres(sen)")
    print(f"\n📂 Foto's gesorteerd naar {by_doelgroep_root.name}/:")
    for name in ("doelgroep_oprit", "oprit_maar_paal", "geen_oprit", "oprit_twijfel"):
        print(f"   • {name}: {len(doelgroep_buckets[name])} adres(sen)")
    n_doelgroep = len(doelgroep_buckets["doelgroep_oprit"])
    print(f"\n🎯 brief-mailing-doelgroep: {n_doelgroep} adres(sen) → by_doelgroep/doelgroep_oprit/")
    return by_verdict_root

async def run(wijk, sample_size, offset, debug):
    global TEST_ADDRESSES
    TEST_ADDRESSES, addr_mod = load_addresses_for_wijk(wijk)
    start = offset
    if sample_size is None:
        sample = TEST_ADDRESSES[start:]
    else:
        sample = TEST_ADDRESSES[start:start + sample_size]
    total = len(sample)
    # Bij offset > 0: aparte CSV zodat vorige run niet overschreven wordt.
    csv_suffix = f"_{start + 1}-{start + total}" if offset > 0 else ""
    setup_paths(wijk, csv_suffix=csv_suffix)
    results = []

    print(f"→ Wijk: {wijk}  (adressen uit {addr_mod}.py)")
    range_str = f"adressen {start + 1}-{start + total} van {len(TEST_ADDRESSES)}"
    print(f"→ {total} adressen ({range_str}), model={OLLAMA_MODEL}, debug={debug}, headless={HEADLESS}")
    print(f"→ Output CSV: {CSV_PATH.name}")
    print(f"→ Foto's: {PHOTOS_DIR}\n")
    print("→ !! VPN check: is Mullvad/andere VPN actief? (jouw check, niet die van 't script)\n")

    async with async_playwright() as p:
        # WebKit engine (Safari-like) + fresh incognito context per run.
        # Voordelen: Apple's fingerprint checks vinden ons meer Safari-achtig,
        # incognito = geen langlopende sessie/cookies.
        browser = await p.webkit.launch(headless=HEADLESS)
        context = await browser.new_context(
            viewport={"width": 1600, "height": 1000},
            locale="nl-NL",
            user_agent=SAFARI_UA,
            timezone_id="Europe/Amsterdam",
        )
        page = await context.new_page()

        for i, entry in enumerate(sample, start=1):
            adres = entry["adres"]
            expected = entry.get("expected_has_charger")
            # Absolute index in TEST_ADDRESSES → foto-bestandsnamen conflicteren
            # niet tussen runs met verschillende offset.
            abs_i = start + i
            slug = f"{abs_i:02d}_{slugify(adres)}"
            print(f"[{i}/{total}] (#{abs_i}) {adres}")
            try:
                # Voorkeur: PDOK-coordinaten uit addresses_*.py (exacte VBO-
                # centroide via BAG). Als niet beschikbaar → Nominatim fallback.
                # Nominatim heeft in NL vaak alleen straat-middelpunten voor
                # huisnummers — Poortersdreef 12 en 69 landen dan op dezelfde
                # plek, en Apple snapt naar dezelfde pano. PDOK is per VBO exact.
                pdok_lat = entry.get("lat")
                pdok_lng = entry.get("lng")
                if pdok_lat is not None and pdok_lng is not None:
                    lat, lng = float(pdok_lat), float(pdok_lng)
                    print(f"   📍 {lat:.6f}, {lng:.6f}  (PDOK)")
                else:
                    lat, lng, display_name = geocode(adres)
                    if lat is None:
                        print("   ⚠️  geocode mislukt")
                        results.append({
                            "adres": adres, "expected": expected, "lat": None, "lng": None,
                            "status": "GEOCODE_FAILED", "heeft_laadpaal": None,
                            "confidence": None,
                            "oprit_aanwezig": None, "oprit_confidence": None,
                            "signalen": None, "ev_merk": None,
                            "notitie": None, "n_photos": 0, "labels": None,
                        })
                        write_csv(results)
                        continue
                    # Sanity-check: bij korte straten snapt Nominatim graag naar
                    # een lijkende naam (Alpensalamander → Vuursalamander). Als
                    # de gezochte straat NIET in de display_name zit, skippen we.
                    if not _geocode_matches_street(adres, display_name):
                        print(f"   ⚠️  GEOCODE_MISMATCH: gevraagd '{adres}' → gevonden '{display_name}'")
                        results.append({
                            "adres": adres, "expected": expected, "lat": lat, "lng": lng,
                            "status": "GEOCODE_MISMATCH", "heeft_laadpaal": None,
                            "confidence": None,
                            "oprit_aanwezig": None, "oprit_confidence": None,
                            "signalen": None, "ev_merk": None,
                            "notitie": f"Nominatim gaf: {display_name[:120]}",
                            "n_photos": 0, "labels": None,
                        })
                        write_csv(results)
                        await asyncio.sleep(DELAY_BETWEEN_ADDR_S)
                        continue
                    print(f"   📍 {lat:.6f}, {lng:.6f}  (Nominatim)")

                # In debug mode: alleen 1e adres krijgt uitgebreide DOM/URL dumps
                is_debug = debug and i == 1
                captured = await capture_3_panos(page, lat, lng, slug, dbg=is_debug)
                if not captured:
                    results.append({
                        "adres": adres, "expected": expected, "lat": lat, "lng": lng,
                        "status": "NO_LOOKAROUND", "heeft_laadpaal": None,
                        "confidence": None,
                        "oprit_aanwezig": None, "oprit_confidence": None,
                        "signalen": None, "ev_merk": None,
                        "notitie": None, "n_photos": 0, "labels": None,
                    })
                    write_csv(results)
                    await asyncio.sleep(DELAY_BETWEEN_ADDR_S)
                    continue

                labels = [lbl for lbl, _ in captured]
                photos = [ph for _, ph in captured]
                print(f"   📷 {len(photos)} foto's: [{','.join(labels)}]")

                print(f"   🤖 analyseren...", end=" ", flush=True)
                t0 = time.time()
                analysis = ollama_analyze(photos)
                dt = time.time() - t0
                heeft = analysis.get("heeft_laadpaal")
                conf = analysis.get("confidence")
                oprit = analysis.get("oprit_aanwezig")
                oprit_conf = analysis.get("oprit_confidence")
                print(f"({dt:.0f}s)  laadpaal={heeft} conf={conf}  oprit={oprit} conf={oprit_conf}")
                print(f"      \"{analysis.get('notitie', '')}\"")

                results.append({
                    "adres": adres, "expected": expected, "lat": lat, "lng": lng,
                    "status": "OK",
                    "heeft_laadpaal": heeft, "confidence": conf,
                    "oprit_aanwezig": oprit, "oprit_confidence": oprit_conf,
                    "signalen": ",".join(analysis.get("signalen") or []),
                    "ev_merk": analysis.get("ev_merk"),
                    "notitie": analysis.get("notitie"),
                    "n_photos": len(photos), "labels": ",".join(labels),
                })
                write_csv(results)

            except Exception as e:
                print(f"   ❌ {type(e).__name__}: {str(e)[:200]}")
                results.append({
                    "adres": adres, "expected": expected, "lat": None, "lng": None,
                    "status": f"ERROR: {type(e).__name__}", "heeft_laadpaal": None,
                    "confidence": None,
                    "oprit_aanwezig": None, "oprit_confidence": None,
                    "signalen": None, "ev_merk": None,
                    "notitie": None, "n_photos": 0, "labels": None,
                })
                write_csv(results)

            # Rate limiting tussen adressen — natuurlijk oogend
            if i < total:
                await asyncio.sleep(DELAY_BETWEEN_ADDR_S)

        await browser.close()

    write_csv(results)

    ok = [r for r in results if r["status"] == "OK"]
    tp = [r for r in ok if r["expected"] and r["heeft_laadpaal"]]
    print(f"\n{'─'*60}")
    print(f"Klaar. {len(ok)}/{total} succesvol.")
    if ok:
        print(f"True positive: {len(tp)}/{len(ok)} = {len(tp)/len(ok)*100:.0f}%")
    print(f"→ CSV:    {CSV_PATH}")
    print(f"→ Foto's: {PHOTOS_DIR}")

    # Sorteer foto's op verdict — ochtend-check ready
    if ok:
        sort_photos_by_verdict(results)
    if debug:
        print(f"→ Debug:  {DEBUG_DIR}")

def parse_args():
    p = argparse.ArgumentParser(description="Pluggo Apple Maps web scanner")
    p.add_argument("--wijk", default=DEFAULT_WIJK,
                   help="Wijk-naam. Output → output_apple_web/<wijk>/")
    p.add_argument("--limit", type=int, default=DEFAULT_SAMPLE_SIZE,
                   help="Max aantal adressen (0 = alles)")
    p.add_argument("--offset", type=int, default=0,
                   help="Skip N adressen aan begin (bv. --offset 5 slaat eerste 5 over)")
    p.add_argument("--debug", action="store_true",
                   help="Verbose logging + URL/DOM dumps voor 1e adres")
    p.add_argument("--sort-only", action="store_true",
                   help="Skip scan; lees bestaande CSV en sorteer photos/ opnieuw in by_verdict/")
    return p.parse_args()

def sort_only_from_csv(wijk):
    """Herbouw by_verdict/ vanuit bestaande CSV — handig als de nachtrun crashte."""
    setup_paths(wijk)
    if not CSV_PATH.exists():
        # Zoek results_*.csv (offset-varianten) als er geen kale results.csv is
        candidates = sorted(OUTPUT_DIR.glob("results*.csv"))
        if not candidates:
            print(f"❌ Geen CSV gevonden in {OUTPUT_DIR}/")
            return
        csv_file = candidates[-1]
        print(f"→ Kaal results.csv niet gevonden, gebruik {csv_file.name}")
    else:
        csv_file = CSV_PATH
    with csv_file.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    # Cast heeft_laadpaal/confidence/oprit_* terug naar juiste types
    def _bool_or_none(v):
        return True if v == "True" else (False if v == "False" else None)

    def _float_or_none(v):
        try:
            return float(v) if v else None
        except (ValueError, TypeError):
            return None

    for r in rows:
        r["heeft_laadpaal"] = _bool_or_none(r.get("heeft_laadpaal"))
        r["confidence"] = _float_or_none(r.get("confidence"))
        # oprit-velden zijn nieuw — oude CSV's hebben ze niet, default naar None
        r["oprit_aanwezig"] = _bool_or_none(r.get("oprit_aanwezig"))
        r["oprit_confidence"] = _float_or_none(r.get("oprit_confidence"))
        try:
            r["n_photos"] = int(r["n_photos"]) if r["n_photos"] else 0
        except (ValueError, TypeError):
            r["n_photos"] = 0
    print(f"→ {len(rows)} rijen ingelezen uit {csv_file.name}")
    sort_photos_by_verdict(rows)

if __name__ == "__main__":
    args = parse_args()
    if args.sort_only:
        sort_only_from_csv(args.wijk)
    else:
        sample_size = None if args.limit == 0 else args.limit
        try:
            asyncio.run(run(args.wijk, sample_size, args.offset, args.debug))
        except KeyboardInterrupt:
            print("\n\n⚠️  Onderbroken (Ctrl-C). CSV + foto's zijn bewaard.")
            print(f"    Sorteren op verdict kan nog met:")
            print(f"    python3 apple_web_scanner.py --wijk {args.wijk} --sort-only")
