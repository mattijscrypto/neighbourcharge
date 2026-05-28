// Pluggo — stripe-onboard-account edge function
// ----------------------------------------------------------------------------
// Wordt aangeroepen vanuit Flutter na de BTW-vragenlijst om de paaleigenaar
// als Stripe Connect connected account (Express variant, Accounts v2) aan te
// maken. Vervolgens kan de Flutter app de gebruiker doorsturen naar de
// Stripe-hosted KYC onboarding via de teruggegeven account_link URL.
//
// Flow:
//   1. Verifieert de gebruiker (Supabase JWT)
//   2. Leest profiles.business_type + email (BTW-vragenlijst moet ingevuld zijn)
//   3. Idempotency: bestaand stripe_account_id? Maak alleen nieuwe account_link
//   4. Anders: POST naar /v2/core/accounts (express dashboard, NL, recipient+merchant)
//   5. Slaat stripe_account_id + initial state op in profiles
//   6. POST naar /v2/core/account_links voor de hosted onboarding URL
//   7. Geeft onboarding_url terug aan de Flutter app
//
// Het account-object wordt geconfigureerd zodat Pluggo (de platform) zowel
// `fees_collector` als `losses_collector` is — dat betekent: Pluggo betaalt
// Stripe's processing fees uit eigen marge en absorbeert eventuele chargebacks.
// Dit is bewuste keuze: paaleigenaren krijgen voorspelbare €0,62/kWh net,
// zonder verrassingen op hun afschrift.
//
// Secrets / env:
//   • STRIPE_SECRET_KEY        — sk_test_... of sk_live_...
//   • APP_DEEP_LINK_SCHEME     — bv. "pluggo" (return_url na Stripe-hosted KYC)
//   • STRIPE_API_BASE          — optioneel, default https://api.stripe.com
//
// Reference: blueprint "Collect payments using Accounts v2 as a marketplace"
// nodes create-account-request + create-account-link-request.
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Stripe v2 (preview) endpoints VEREISEN een expliciete Stripe-Version header.
// Voor Accounts v2 + Account Links v2 (Dahlia release) gebruiken we de
// 2026-04-22.dahlia preview-versie. Update deze pin wanneer Stripe een nieuwe
// preview uitbrengt of de feature naar GA promoveert.
const STRIPE_API_VERSION = "2026-04-22.dahlia";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonError("Methode niet toegestaan", 405);
  }

  try {
    // -----------------------------------------------------------------------
    // 1. Auth + env
    // -----------------------------------------------------------------------
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Niet geautoriseerd (geen token)", 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");
    const stripeApiBase =
      Deno.env.get("STRIPE_API_BASE") ?? "https://api.stripe.com";

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
      return jsonError("Server niet juist geconfigureerd (Supabase env)", 500);
    }
    if (!stripeSecret) {
      return jsonError(
        "Server niet juist geconfigureerd (STRIPE_SECRET_KEY)",
        500,
      );
    }

    // Stripe Accounts v2 weigert custom URI schemes (pluggo://) voor return_url
    // / refresh_url — het MOET https:// zijn. We gebruiken daarom de
    // `stripe-onboarding-return` edge function als bridge: Stripe redirect
    // daar naartoe, die doet vervolgens een 302 → pluggo://onboarding/...
    // Hetzelfde Plan B-patroon als stripe-checkout-return voor de payment
    // flow. Geen HTML-landing-pagina, geen Content-Type problemen.
    //
    // Override via env mogelijk voor staging/live, anders default naar de
    // edge function op dit Supabase project (afgeleid van SUPABASE_URL).
    const bridgeBase = `${supabaseUrl}/functions/v1/stripe-onboarding-return`;
    const stripeReturnUrl =
      Deno.env.get("STRIPE_RETURN_URL") ?? `${bridgeBase}?type=return`;
    const stripeRefreshUrl =
      Deno.env.get("STRIPE_REFRESH_URL") ?? `${bridgeBase}?type=refresh`;

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return jsonError("Niet ingelogd", 401);
    }
    const userId = userData.user.id;
    const userEmail = userData.user.email;

    // -----------------------------------------------------------------------
    // 2. Profile + BTW-vragenlijst-check
    // -----------------------------------------------------------------------
    const admin = createClient(supabaseUrl, supabaseServiceKey);

    // NB: profiles heeft GEEN eigen email- of phone-kolom (auth.users is
    // de bron van waarheid voor contactgegevens). We pakken email voor
    // Stripe uit userData.user.email hieronder; telefoonnummer is voor
    // Connect Express optioneel en wordt door Stripe zelf opgevraagd in KYC.
    const { data: profile, error: pErr } = await admin
      .from("profiles")
      .select(
        "id, full_name, business_type, vat_status, kvk_number, stripe_account_id, stripe_charges_enabled",
      )
      .eq("id", userId)
      .maybeSingle();

    if (pErr) {
      console.error(
        "stripe-onboard-account: profile query faalde",
        { userId, error: pErr },
      );
      return jsonError(
        `Profiel ophalen mislukt: ${pErr.message ?? "onbekende DB-fout"}`,
        500,
      );
    }
    if (!profile) {
      console.error(
        "stripe-onboard-account: geen profiel-rij gevonden voor user",
        { userId },
      );
      return jsonError(
        `Geen profielrij voor user ${userId} — log opnieuw in of voltooi je profiel`,
        404,
      );
    }
    if (!profile.business_type) {
      return jsonError(
        "Vul eerst de BTW-vragenlijst in voordat je betalingen kunt ontvangen",
        409,
      );
    }

    const accountEmail = profile.email ?? userEmail ?? "";
    if (!accountEmail) {
      return jsonError(
        "Geen e-mailadres bekend voor dit profiel; vul eerst je profiel aan",
        409,
      );
    }

    // -----------------------------------------------------------------------
    // 3. Idempotency: bestaand account? Maak alleen nieuwe account_link.
    //
    // Stripe-hosted onboarding URLs verlopen na enkele minuten, dus iedere
    // keer dat de Flutter app een onboarding-URL nodig heeft genereren we
    // 'm opnieuw via /v2/core/account_links.
    // -----------------------------------------------------------------------
    if (profile.stripe_account_id) {
      const url = await createAccountLink(
        profile.stripe_account_id,
        stripeSecret,
        stripeApiBase,
        stripeReturnUrl,
        stripeRefreshUrl,
      );
      if (!url) {
        return jsonError("Kon onboarding-link niet aanmaken", 502);
      }
      return jsonOk({
        stripe_account_id: profile.stripe_account_id,
        onboarding_url: url,
        reused: true,
        already_verified: profile.stripe_charges_enabled === true,
      });
    }

    // -----------------------------------------------------------------------
    // 4. Connected account aanmaken — Accounts v2, Express dashboard
    //
    // Configuration choices voor Pluggo:
    //   • dashboard = "express"        → Stripe biedt minimale UI, wij doen branding
    //   • country = "NL"               → vereist voor iDEAL + EUR payouts
    //   • recipient.stripe_transfers   → mag ontvangen via destination charges
    //   • fees_collector = "application"  → Pluggo betaalt Stripe-fees uit marge
    //   • losses_collector = "application" → Pluggo absorbeert chargebacks
    //   • contact_email                → ontvangt Stripe-notificaties direct
    // -----------------------------------------------------------------------
    const accountBody = {
      dashboard: "express",
      contact_email: accountEmail,
      display_name: profile.full_name ?? "Pluggo paaleigenaar",
      identity: {
        country: "NL",
      },
      defaults: {
        responsibilities: {
          losses_collector: "application",
          fees_collector: "application",
        },
      },
      configuration: {
        recipient: {
          capabilities: {
            stripe_balance: {
              stripe_transfers: {
                requested: true,
              },
            },
          },
        },
      },
      include: [
        "configuration.merchant",
        "configuration.recipient",
        "identity",
        "defaults",
        "configuration.customer",
      ],
      metadata: {
        pluggo_profile_id: userId,
        business_type: profile.business_type,
        vat_status: profile.vat_status ?? "unknown",
      },
    };

    const accountRes = await fetch(`${stripeApiBase}/v2/core/accounts`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${stripeSecret}`,
        "Content-Type": "application/json",
        "Stripe-Version": STRIPE_API_VERSION,
      },
      body: JSON.stringify(accountBody),
    });

    if (!accountRes.ok) {
      const errBody = await accountRes.text();
      console.error(
        "Stripe v2.accounts.create faalde:",
        accountRes.status,
        errBody,
      );
      // Probeer Stripe's foutmessage uit te lezen voor een betere UI-melding
      let stripeMessage = "";
      try {
        const parsed = JSON.parse(errBody);
        stripeMessage =
          parsed?.error?.message ??
          parsed?.error?.code ??
          parsed?.message ??
          "";
      } catch (_) {
        // body is geen valide JSON, val terug op raw text (max 200 chars)
        stripeMessage = errBody.slice(0, 200);
      }
      return jsonError(
        `Stripe (${accountRes.status}): ${stripeMessage || "onbekende fout"}`,
        502,
      );
    }

    const account = await accountRes.json();
    const stripeAccountId = account.id as string | undefined;
    if (!stripeAccountId) {
      console.error("Stripe account response zonder id:", account);
      return jsonError("Stripe gaf geen account-ID terug", 502);
    }

    // -----------------------------------------------------------------------
    // 5. Initial state opslaan in profiles
    //
    // charges_enabled / payouts_enabled / details_submitted komen later via
    // de stripe-webhook (account.updated event) wanneer paaleigenaar KYC
    // afrondt. Hier zetten we alleen het account-ID en started_at.
    // -----------------------------------------------------------------------
    const { error: updErr } = await admin
      .from("profiles")
      .update({
        stripe_account_id: stripeAccountId,
        stripe_account_status: "pending",
        stripe_onboarding_started_at: new Date().toISOString(),
      })
      .eq("id", userId);

    if (updErr) {
      console.error(
        "Kon stripe_account_id niet opslaan op profile:",
        updErr,
      );
      // Niet fataal — account bestaat bij Stripe, we kunnen alsnog onboarding-link teruggeven
    }

    // -----------------------------------------------------------------------
    // 6. Account link genereren voor Stripe-hosted KYC
    // -----------------------------------------------------------------------
    const onboardingUrl = await createAccountLink(
      stripeAccountId,
      stripeSecret,
      stripeApiBase,
      stripeReturnUrl,
      stripeRefreshUrl,
    );
    if (!onboardingUrl) {
      return jsonError(
        "Account aangemaakt, maar onboarding-link genereren mislukt",
        502,
      );
    }

    return jsonOk({
      stripe_account_id: stripeAccountId,
      onboarding_url: onboardingUrl,
      reused: false,
      already_verified: false,
    });
  } catch (err) {
    console.error("stripe-onboard-account fatal error:", err);
    const message = err instanceof Error ? err.message : String(err);
    return jsonError(`Serverfout: ${message}`, 500);
  }
});

// ----------------------------------------------------------------------------
// Helper: account_link aanmaken voor Stripe-hosted onboarding
//
// De resulterende URL is kortlevend (minuten). De Flutter app moet de user er
// direct naartoe sturen (in-app browser tab). Bij refresh_url komt Stripe
// terug naar de app voor een fresh link. Bij return_url is de gebruiker klaar
// met de Stripe-flow (status onbekend tot account.updated webhook arriveert).
// ----------------------------------------------------------------------------
async function createAccountLink(
  accountId: string,
  stripeSecret: string,
  stripeApiBase: string,
  returnUrl: string,
  refreshUrl: string,
): Promise<string | null> {
  // configurations: alleen "recipient" — paaleigenaren ONTVANGEN transfers
  // via destination charges. Pluggo's platform-account is de "merchant" die
  // de iDEAL/kaart-betaling int; het connected account hoeft geen merchant
  // capability te hebben. Als we hier "merchant" zouden meegeven krijgen we
  // 400 "You must correctly specify the applied configurations" omdat het
  // account zelf alleen een recipient configuration heeft (zie /v2/core/accounts
  // body hierboven).
  //
  // refresh_url / return_url MOETEN https:// zijn — Stripe weigert custom URI
  // schemes (pluggo://). We hosten https-redirect-pagina's die via Universal
  // Links / App Links terug naar de app springen.
  const linkBody = {
    account: accountId,
    use_case: {
      type: "account_onboarding",
      account_onboarding: {
        configurations: ["recipient"],
        refresh_url: refreshUrl,
        return_url: returnUrl,
      },
    },
  };

  const linkRes = await fetch(`${stripeApiBase}/v2/core/account_links`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${stripeSecret}`,
      "Content-Type": "application/json",
      "Stripe-Version": STRIPE_API_VERSION,
    },
    body: JSON.stringify(linkBody),
  });

  if (!linkRes.ok) {
    const errBody = await linkRes.text();
    console.error(
      "Stripe v2.account_links.create faalde:",
      linkRes.status,
      errBody,
    );
    // Geef de Stripe-foutmelding door via een throw zodat de caller 'm in de
    // response kan zetten (anders zien we alleen "Kon onboarding-link niet
    // aanmaken" wat ons geen handvat geeft om Stripe-config te debuggen).
    let stripeMessage = "";
    try {
      const parsed = JSON.parse(errBody);
      stripeMessage =
        parsed?.error?.message ??
        parsed?.error?.code ??
        parsed?.message ??
        "";
    } catch (_) {
      stripeMessage = errBody.slice(0, 200);
    }
    throw new Error(
      `Stripe account_links (${linkRes.status}): ${stripeMessage || "onbekende fout"}`,
    );
  }

  const link = await linkRes.json();
  const url = link.url as string | undefined;
  return url ?? null;
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}

function jsonOk(payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status: 200,
  });
}
