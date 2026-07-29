#!/usr/bin/env python3
"""
Pluggo Scanner — Reset wijk

Wist ALLE lokale data van een wijk zodra de brieven verstuurd/bezorgd zijn.
Dit is de AVG-hygiëne stap: geen persoonsgegevens langer bewaren dan nodig.

Gebruik:
    python3 reset_wijk.py hoefkwartier
    python3 reset_wijk.py hoefkwartier --yes     # skip bevestiging
    python3 reset_wijk.py --list                 # toon wijken die bestaan
"""

import argparse
import shutil
import sys
from pathlib import Path

BASE = Path(__file__).parent / "output_browser"


def list_wijken():
    if not BASE.exists():
        print("Geen output_browser/ folder — nog niks gescand.")
        return
    wijken = sorted([d for d in BASE.iterdir() if d.is_dir()])
    if not wijken:
        print("Geen wijken gevonden in output_browser/.")
        return
    print(f"Wijken in {BASE}:")
    for w in wijken:
        photos = w / "photos"
        csv = w / "results.csv"
        n_photos = len(list(photos.glob("*.jpg"))) if photos.exists() else 0
        has_csv = "✓" if csv.exists() else "✗"
        print(f"  • {w.name:<30} {n_photos:>4} foto's   CSV:{has_csv}")


def reset(wijk, skip_confirm=False):
    target = BASE / wijk
    if not target.exists():
        print(f"❌ Wijk '{wijk}' bestaat niet in {BASE}")
        sys.exit(1)

    photos = target / "photos"
    csv = target / "results.csv"
    review = target / "review_decisions.csv"

    n_photos = len(list(photos.glob("*.jpg"))) if photos.exists() else 0
    has_csv = csv.exists()
    has_review = review.exists()

    print(f"Op te wissen in {target}:")
    print(f"  • {n_photos} foto's")
    print(f"  • results.csv       {'aanwezig' if has_csv else 'niet aanwezig'}")
    print(f"  • review_decisions  {'aanwezig' if has_review else 'niet aanwezig'}")
    print()

    if not skip_confirm:
        antwoord = input(
            f"⚠️  Zeker weten dat je '{wijk}' definitief wist? "
            f"Alleen doen als brieven al de deur uit zijn.\n"
            f"Type de wijknaam '{wijk}' om te bevestigen: "
        ).strip()
        if antwoord != wijk:
            print("Afgebroken. Niks gewist.")
            sys.exit(0)

    shutil.rmtree(target)
    print(f"✅ Wijk '{wijk}' gewist. AVG-hygiëne compleet.")


def parse_args():
    p = argparse.ArgumentParser(description="Wis lokale scanner-data per wijk (AVG-hygiëne)")
    p.add_argument("wijk", nargs="?", help="Wijk-naam om te wissen")
    p.add_argument("--yes", action="store_true", help="Skip bevestigings-prompt")
    p.add_argument("--list", action="store_true", help="Toon alle bestaande wijken en stop")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    if args.list:
        list_wijken()
        sys.exit(0)
    if not args.wijk:
        print("Geef een wijk-naam of --list. Zie --help.")
        sys.exit(1)
    reset(args.wijk, skip_confirm=args.yes)
