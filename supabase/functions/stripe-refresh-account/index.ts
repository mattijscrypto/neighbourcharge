// Pluggo — stripe-refresh-account edge function
// ----------------------------------------------------------------------------
// On-demand pull-based sync van Stripe Connect account state naar
// profiles-row. Bestaansreden: onze push-based webhook (`stripe-webhook`
// destination `pluggo-backend-v2-accounts-live`) ontvangt in productie alleen
// pings, geen real v2 account events, ondanks aantoonbaar juiste
// destination-configuratie (Connected accounts + Thin + 8 subscribed events
// inclusief bracket-varianten). Zonder deze fallback zou de app-status
// `stripe_account_status` eeuwig op 'pending' blijven staan tot iemand
// handmatig SQL draait.
//
// Deze functie wordt aangeroepen vanuit de Flutter app op strategische
// momenten waarop we willen dat de status vers is:
//   • bij openen van het profielscherm
//   • na terugkeer uit Stripe hosted onboarding (custom URL scheme handler)
//   • bij aanmaken van een nieuwe paal (voorkomt dat pending users door
//     de flow heen glippen)
//
// Flow:
//   1. Verifieert Supabase JWT
//   2. Leest profiles.stripe_account_id
//   3. Als aanwezig: GET /v2/core/accounts/{id} met dezelfde includes als
//      handleAccountUpdatedV2 in stripe-webhook
//   4. Projecteert dezelfde velden naar profiles (charges_enabled,
//      payouts_enabled, details_submitted, disabled_reason, currently_due,
//      stripe_account_status)
//   5. Returned de verse state naar de app
//
// Idempotent — kan zonder bijwerkingen zo vaak worden aangeroepen als de
// app wil.
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Zelfde Stripe API-versie als stripe-onboard-account en stripe-webhook —
// wanneer je die daar bumpt, bump ook hier.
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

    const admin = createClient(supabaseUrl, supabaseServiceKey);

    // -----------------------------------------------------------------------
    // Auth-modus 1: gebruikersaanroep vanuit Flutter (normaal geval).
    // Gebruiker stuurt z'n eigen JWT mee; we lezen z'n user_id uit auth.
    //
    // Auth-modus 2: admin/noodrem (curl vanaf laptop).
    // Aanroeper stuurt de SERVICE_ROLE_KEY als Bearer, en geeft een
    // expliciet user_id mee in de request body. Dit is de vervanger voor
    // handmatige SQL: wanneer een klant "stuck" is en de Flutter-refresh
    // (nog) niet werkt, kan Mattijs met één curl de sync forceren.
    //
    // De keuze tussen beide modi maken we op basis van de meegestuurde
    // token: is dit de service-role key? Dan admin-modus. Anders normale
    // user-flow via auth.getUser().
    // -----------------------------------------------------------------------
    let userId: string | null = null;

    // Extract raw token (zonder "Bearer " prefix).
    const rawToken = authHeader.replace(/^Bearer\s+/i, "");
    const isServiceRole = rawToken === supabaseServiceKey;

    if (isServiceRole) {
      // Admin/noodrem-modus — vereist expliciet user_id in body.
      let body: Record<string, unknown> = {};
      try {
        const text = await req.text();
        if (text) body = JSON.parse(text);
      } catch (_) {
        return jsonError(
          "Admin-modus vereist JSON body met { \"user_id\": \"...\" }",
          400,
        );
      }
      const bodyUserId = body["user_id"];
      if (typeof bodyUserId !== "string" || bodyUserId.length === 0) {
        return jsonError(
          "Admin-modus vereist expliciet user_id in body",
          400,
        );
      }
      userId = bodyUserId;
      console.log("stripe-refresh-account: admin-modus voor user", userId);
    } else {
      // Normale flow — user JWT.
      const userClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData, error: userError } = await userClient.auth
        .getUser();
      if (userError || !userData?.user) {
        return jsonError("Niet ingelogd", 401);
      }
      userId = userData.user.id;
    }

    // -----------------------------------------------------------------------
    // 2. Profile lookup
    // -----------------------------------------------------------------------

    const { data: profile, error: pErr } = await admin
      .from("profiles")
      .select(
        "id, stripe_account_id, stripe_account_status, stripe_charges_enabled, stripe_payouts_enabled",
      )
      .eq("id", userId)
      .maybeSingle();

    if (pErr) {
      console.error("stripe-refresh-account: profile query faalde", {
        userId,
        error: pErr,
      });
      return jsonError("Profiel ophalen mislukt", 500);
    }
    if (!profile) {
      return jsonError("Geen profielrij gevonden voor deze gebruiker", 404);
    }
    if (!profile.stripe_account_id) {
      // Nog geen Stripe account — niets te syncen, geen fout.
      return jsonOk({
        synced: false,
        reason: "no_stripe_account",
        stripe_account_status: profile.stripe_account_status ?? null,
      });
    }

    // -----------------------------------------------------------------------
    // 3. Poll Stripe → v2 account snapshot
    //
    // Identieke includes als handleAccountUpdatedV2 in stripe-webhook. NIET
    // configuration.merchant of .customer requesten — die bestaan niet op
    // recipient-only accounts en veroorzaken 400 invalid_fields.
    // -----------------------------------------------------------------------
    const includes = [
      "configuration.recipient",
      "identity",
      "requirements",
    ].map((i) => `include=${encodeURIComponent(i)}`).join("&");

    const accountUrl = `${stripeApiBase}/v2/core/accounts/${
      encodeURIComponent(profile.stripe_account_id)
    }?${includes}`;

    const res = await fetch(accountUrl, {
      headers: {
        Authorization: `Bearer ${stripeSecret}`,
        "Stripe-Version": STRIPE_API_VERSION,
      },
    });

    if (!res.ok) {
      const errBody = await res.text();
      console.error("stripe-refresh-account: Stripe GET faalde", {
        accountId: profile.stripe_account_id,
        status: res.status,
        body: errBody,
      });
      return jsonError(
        `Stripe ophalen mislukt (${res.status})`,
        502,
      );
    }

    const account = await res.json();

    // -----------------------------------------------------------------------
    // 4. Project naar profile-velden — 1-op-1 dezelfde logica als
    //    handleAccountUpdatedV2 in stripe-webhook. Bij toekomstige mapping-
    //    wijzigingen: sync beide plekken.
    // -----------------------------------------------------------------------
    const recipientCaps = account?.configuration?.recipient?.capabilities ?? {};
    const stripeTransfersActive =
      recipientCaps?.stripe_balance?.stripe_transfers?.status === "active";

    const chargesEnabled = stripeTransfersActive;
    const payoutsEnabled = stripeTransfersActive;

    const detailsSubmitted =
      Array.isArray(account?.requirements?.entries) === false ||
      (account?.requirements?.entries?.length ?? 0) === 0;

    const currentlyDue =
      (account?.requirements?.entries as
        | Array<{ description?: string }>
        | undefined)
        ?.map((e) => e.description ?? "")
        .filter((s) => s.length > 0) ?? [];

    const disabledReason: string | null = null; // v2 model — geen expliciete flag

    // Enum-mapping identiek aan syncAccountStateToProfile.
    let status: "pending" | "review" | "verified" | "restricted" | "rejected" =
      "pending";
    if (disabledReason && disabledReason.includes("rejected")) {
      status = "rejected";
    } else if (chargesEnabled && payoutsEnabled) {
      status = "verified";
    } else if (disabledReason) {
      status = "restricted";
    } else if (detailsSubmitted) {
      status = "review";
    } else {
      status = "pending";
    }

    const { error: updErr } = await admin
      .from("profiles")
      .update({
        stripe_charges_enabled: chargesEnabled,
        stripe_payouts_enabled: payoutsEnabled,
        stripe_details_submitted: detailsSubmitted,
        stripe_disabled_reason: disabledReason,
        stripe_currently_due: currentlyDue,
        stripe_account_status: status,
        stripe_last_webhook_at: new Date().toISOString(),
      })
      .eq("stripe_account_id", profile.stripe_account_id);

    if (updErr) {
      console.error("stripe-refresh-account: profile update faalde", {
        accountId: profile.stripe_account_id,
        error: updErr,
      });
      return jsonError("Profile update mislukt", 500);
    }

    console.log("stripe-refresh-account: gesynced", {
      accountId: profile.stripe_account_id,
      newStatus: status,
      chargesEnabled,
      payoutsEnabled,
      detailsSubmitted,
      currentlyDueCount: currentlyDue.length,
    });

    return jsonOk({
      synced: true,
      stripe_account_id: profile.stripe_account_id,
      stripe_account_status: status,
      stripe_charges_enabled: chargesEnabled,
      stripe_payouts_enabled: payoutsEnabled,
      stripe_details_submitted: detailsSubmitted,
      stripe_currently_due: currentlyDue,
    });
  } catch (err) {
    console.error("stripe-refresh-account: onverwachte fout", err);
    return jsonError("Interne fout", 500);
  }
});

function jsonOk(body: unknown) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
