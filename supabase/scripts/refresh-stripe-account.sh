#!/usr/bin/env bash
# Pluggo — noodrem voor stuck Stripe-status
# ----------------------------------------------------------------------------
# Vervangt handmatige SQL. Roept stripe-refresh-account edge function aan in
# admin-modus (service_role Bearer) met een user_id in de body. De function
# polt Stripe live, syncet profiles.stripe_account_status, en returnt de
# nieuwe state.
#
# Gebruik:
#   ./refresh-stripe-account.sh <user_id>
#
# user_id ophalen (SQL editor):
#   select id, email from auth.users where email = 'klant@voorbeeld.nl';
#
# Vereist deze env-vars (zet ze in .env in dezelfde map als dit script):
#   SUPABASE_URL          bv. https://vfqpijlicngnomrsasvf.supabase.co
#   SUPABASE_SERVICE_KEY  service_role JWT (Settings → API → service_role)
#
# .env voorbeeld:
#   SUPABASE_URL=https://vfqpijlicngnomrsasvf.supabase.co
#   SUPABASE_SERVICE_KEY=eyJhbGciOi...
#
# Commit .env NOOIT. Voeg 'm toe aan .gitignore.
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

URL="$SUPABASE_URL/functions/v1/stripe-refresh-account"

echo "→ POST $URL"
echo "  user_id: $USER_ID"
echo

RESPONSE=$(curl --silent --show-error --fail-with-body \
  -X POST "$URL" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER_ID\"}")

echo "Response:"
if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
