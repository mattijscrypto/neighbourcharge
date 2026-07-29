#!/usr/bin/env bash
# Pluggo — Pionier-vlag handmatig zetten voor een gebruiker
# ----------------------------------------------------------------------------
# Zet profiles.is_pioneer = true + pioneer_since = now() voor een user.
# Gebruikt PostgREST + service_role, dus bypasst de guard-trigger (die alleen
# blokkeert als auth.uid() niet null is; bij service_role is 'ie null).
#
# Wanneer gebruiken:
#   Iemand hebben we manueel willen belonen (warm lead, snelle onboarder,
#   community-connector) maar heeft nog geen paal — dus de auto-flag trigger
#   uit 0019 heeft nog niet gevuurd. Voor mensen die wél een paal aanmaken
#   gaat 't automatisch (tot cap van 100).
#
# Gebruik:
#   ./flag-pioneer.sh <user_id>
#
# user_id ophalen: Supabase Dashboard → Authentication → Users → klik op de
# gebruiker → User UID kopiëren (of via SQL: select id, email from auth.users)
#
# Vereist deze env-vars (staan al in .env voor de andere scripts):
#   SUPABASE_URL          bv. https://vfqpijlicngnomrsasvf.supabase.co
#   SUPABASE_SERVICE_KEY  service_role JWT (Settings → API → service_role)
# ----------------------------------------------------------------------------

set -euo pipefail

USER_ID="${1:-}"
if [[ -z "$USER_ID" ]]; then
  echo "Gebruik: $0 <user_id>" >&2
  echo "  user_id: Supabase auth.users.id (UUID)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$SCRIPT_DIR/.env"; set +a
fi

: "${SUPABASE_URL:?SUPABASE_URL env-var ontbreekt}"
: "${SUPABASE_SERVICE_KEY:?SUPABASE_SERVICE_KEY env-var ontbreekt}"

URL="$SUPABASE_URL/rest/v1/profiles?id=eq.$USER_ID"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo "→ PATCH $URL"
echo "  is_pioneer:    true"
echo "  pioneer_since: $NOW"
echo

RESPONSE=$(curl --silent --show-error --fail-with-body \
  -X PATCH "$URL" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{\"is_pioneer\":true,\"pioneer_since\":\"$NOW\"}")

echo "Response:"
if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
