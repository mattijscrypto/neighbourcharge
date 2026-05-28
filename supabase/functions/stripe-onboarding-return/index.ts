// Pluggo — stripe-onboarding-return edge function
// ----------------------------------------------------------------------------
// HTTPS-bridge tussen Stripe Connect-hosted KYC (verplicht https return/refresh
// URL) en de Pluggo iOS-app (`pluggo://` custom URL scheme).
//
// Stripe Accounts v2 account_links accepteren GEEN custom URI schemes
// (`pluggo://`) als return_url of refresh_url — beide moeten https zijn. We
// hosten daarom deze edge function als bridge: Stripe redirect hier naartoe,
// wij doen vervolgens een 302 → `pluggo://onboarding/stripe-complete` (of
// `…/stripe-refresh`), iOS Safari volgt die header, het URL scheme handler
// triggert en de Pluggo app komt naar voren.
//
// Dezelfde Plan B-aanpak als `stripe-checkout-return`: geen HTML-landing-page,
// geen Content-Type discussie, geen mojibake. Pure 302 redirect.
//
// Query parameters:
//   ?type=return      — KYC voltooid (of overgeslagen), terug naar app
//   ?type=refresh     — link is verlopen, app moet nieuwe link opvragen
//   ?account_id=...   — optioneel, doorgegeven aan app voor logging
//
// Default (geen ?type=) → behandeld als "return".
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const APP_SCHEME = "pluggo";

serve((req) => {
  const url = new URL(req.url);
  const type = url.searchParams.get("type") ?? "return";
  const accountId = url.searchParams.get("account_id") ?? "";

  // type=refresh → app moet nieuwe onboarding-link opvragen via
  //                stripe-onboard-account (oude link verlopen)
  // type=return  → KYC-flow afgerond (status onbekend tot account.updated
  //                webhook arriveert; app pollt profiles.stripe_charges_enabled)
  const host = type === "refresh" ? "stripe-refresh" : "stripe-complete";
  const appUrl = new URL(`${APP_SCHEME}://onboarding/${host}`);
  if (accountId) appUrl.searchParams.set("account_id", accountId);

  return new Response(null, {
    status: 302,
    headers: {
      Location: appUrl.toString(),
      "Cache-Control": "no-store",
    },
  });
});
