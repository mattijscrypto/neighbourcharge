#!/usr/bin/env bash
# Pluggo — Refresh Stripe-status voor Kaj + Marcel (4 juli 2026)
# ----------------------------------------------------------------------------
# Beide accounts staan in Stripe op Enabled maar in Pluggo-DB nog op pending
# (webhook v2-destination bug, task #253). Deze bash roept per user de
# refresh-stripe-account.sh aan die de state uit Stripe live pullt en
# profiles.stripe_account_status bijwerkt.
#
# Gebruik:
#   ./refresh-batch-2026-07-04.sh              # live
#   ./refresh-batch-2026-07-04.sh --dry-run    # eerst tonen
#
# Vereist .env in dezelfde map (SUPABASE_URL + SUPABASE_SERVICE_KEY).
# ----------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFRESH="$SCRIPT_DIR/refresh-stripe-account.sh"

if [[ ! -x "$REFRESH" ]]; then
  echo "Fout: $REFRESH niet gevonden of niet executable" >&2
  exit 1
fi

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

USERS=(
  "d8170b6b-06c5-46f8-beea-4d4d2dd1ab13|Kaj van der Linden <kajvdlinden@icloud.com>"
  "77b0f1b6-f21e-42c8-a1b7-65647f23f6e3|Marcel Drubbel-Klever <marcel@drubbel.nl>"
)

echo "=================================================="
echo "Batch refresh — ${#USERS[@]} users"
echo "Mode: $([[ $DRY_RUN == true ]] && echo DRY-RUN || echo LIVE)"
echo "=================================================="
echo

OK=0
FAIL=0

for entry in "${USERS[@]}"; do
  UID_="${entry%%|*}"
  LABEL="${entry#*|}"

  echo "→ $LABEL"
  echo "  user_id: $UID_"

  if [[ $DRY_RUN == true ]]; then
    echo "  [DRY-RUN] zou refresh-stripe-account.sh $UID_ aanroepen"
    echo
    continue
  fi

  if "$REFRESH" "$UID_"; then
    OK=$((OK+1))
  else
    FAIL=$((FAIL+1))
    echo "  ! refresh faalde (zie response hierboven)"
  fi

  sleep 0.5
  echo
done

echo "=================================================="
echo "Klaar. ok=$OK  failed=$FAIL  total=${#USERS[@]}"
echo "=================================================="
