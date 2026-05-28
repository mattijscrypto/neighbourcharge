// Pluggo — opp-onboard-merchant edge function
// ----------------------------------------------------------------------------
// Wordt aangeroepen vanuit Flutter na de BTW-vragenlijst om de paaleigenaar
// als consumer of business merchant bij OPP aan te maken. Vervolgens kan de
// Flutter app de gebruiker doorsturen naar bank-verificatie / iDIN.
//
// Flow:
//   1. Verifieert de gebruiker (Supabase JWT)
//   2. Leest profiles.business_type + vat_status (door BTW-vragenlijst gezet)
//   3. POST naar OPP /v1/merchants met juiste type (consumer/business)
//   4. Slaat opp_merchant_uid + initial compliance state op in profiles
//   5. Maakt direct een 'empty' bank_account aan voor de verificatie-redirect
//   6. Geeft de bank verification_url terug aan de Flutter app
//
// Idempotent: als profiles.opp_merchant_uid al gezet is, geef die terug zonder
// opnieuw een merchant aan te maken.
//
// Secrets / env:
//   • OPP_API_KEY            — bearer token partner-level
//   • OPP_API_BASE_URL       — sandbox of productie
//   • OPP_NOTIFY_URL_BASE    — bv. https://<project>.supabase.co/functions/v1
//   • APP_DEEP_LINK_SCHEME   — bv. "pluggo" (voor return_url na bank-verif)
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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
    const oppApiKey = Deno.env.get("OPP_API_KEY");
    const oppApiBase =
      Deno.env.get("OPP_API_BASE_URL") ??
      "https://api-sandbox.onlinebetaalplatform.nl/v1";
    const oppNotifyBase =
      Deno.env.get("OPP_NOTIFY_URL_BASE") ?? `${supabaseUrl}/functions/v1`;
    const deepLink = Deno.env.get("APP_DEEP_LINK_SCHEME") ?? "pluggo";

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey || !oppApiKey) {
      return jsonError("Server niet juist geconfigureerd", 500);
    }

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
    // 2. Profile + BTW-vragenlijst antwoorden
    // -----------------------------------------------------------------------
    const admin = createClient(supabaseUrl, supabaseServiceKey);

    const { data: profile, error: pErr } = await admin
      .from("profiles")
      .select(
        "id, full_name, email, phone, business_type, vat_status, kvk_number, vat_number, opp_merchant_uid"
      )
      .eq("id", userId)
      .maybeSingle();

    if (pErr || !profile) {
      return jsonError("Profiel niet gevonden", 404);
    }
    if (!profile.business_type) {
      return jsonError(
        "Vul eerst de BTW-vragenlijst in voordat je betalingen kunt ontvangen",
        409
      );
    }

    // -----------------------------------------------------------------------
    // 3. Idempotency: bestaande merchant? Geef gewoon bank verification_url terug
    // -----------------------------------------------------------------------
    if (profile.opp_merchant_uid) {
      // Haal bank verification_url op
      const verifUrl = await fetchBankVerificationUrl(
        profile.opp_merchant_uid,
        oppApiKey,
        oppApiBase,
        oppNotifyBase,
        deepLink,
        admin,
      );
      return jsonOk({
        opp_merchant_uid: profile.opp_merchant_uid,
        verification_url: verifUrl,
        reused: true,
      });
    }

    // -----------------------------------------------------------------------
    // 4. Merchant aanmaken bij OPP
    //
    // Voor v1 maken we alleen consumer merchants — particulier + KOR + BTW-plichtige
    // ZZP'ers kunnen allemaal als consumer onboarden. Business onboarding (level 400
    // direct vereist + UBO + KvK-uittreksel) is voor latere fase.
    // -----------------------------------------------------------------------
    const isBusinessType =
      profile.business_type === "bv" || profile.business_type === "overig";

    // Voor v1 raden we particulieren + eenmanszaken aan als consumer merchant.
    // BV's en VvE's gaan via business onboarding.
    const merchantEndpoint = isBusinessType
      ? `${oppApiBase}/merchants`  // business onboarding (zelfde endpoint, type wordt afgeleid uit body)
      : `${oppApiBase}/merchants`;

    const merchantBody: Record<string, unknown> = {
      country: "nl",
      emailaddress: profile.email ?? userEmail,
      phone: profile.phone ?? null,
      notify_url: `${oppNotifyBase}/opp-webhook`,
      type: isBusinessType ? "business" : "consumer",
    };

    if (isBusinessType && profile.kvk_number) {
      merchantBody.coc_nr = profile.kvk_number;
    }
    if (isBusinessType && profile.vat_number) {
      merchantBody.vat_nr = profile.vat_number;
    }

    const mRes = await fetch(merchantEndpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${oppApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(merchantBody),
    });

    if (!mRes.ok) {
      const errBody = await mRes.text();
      console.error("OPP merchant create faalde:", mRes.status, errBody);
      return jsonError("OPP merchant aanmaken mislukt", 502);
    }

    const merchant = await mRes.json();
    const merchantUid = merchant.uid as string | undefined;
    if (!merchantUid) {
      console.error("OPP merchant response zonder uid:", merchant);
      return jsonError("OPP gaf geen merchant uid terug", 502);
    }

    // Initial compliance level: 100 (created, no bank yet)
    const initialLevel = (merchant?.compliance?.level as number | undefined) ?? 100;
    const initialStatus = (merchant?.compliance?.status as string | undefined) ?? "unverified";

    await admin
      .from("profiles")
      .update({
        opp_merchant_uid: merchantUid,
        opp_compliance_level: initialLevel,
        opp_compliance_status: mapStatus(initialStatus),
        opp_onboarding_started_at: new Date().toISOString(),
      })
      .eq("id", userId);

    // -----------------------------------------------------------------------
    // 5. Maak direct een 'empty' bank account aan voor de verificatie-redirect
    // -----------------------------------------------------------------------
    const verifUrl = await fetchBankVerificationUrl(
      merchantUid,
      oppApiKey,
      oppApiBase,
      oppNotifyBase,
      deepLink,
      admin,
    );

    return jsonOk({
      opp_merchant_uid: merchantUid,
      verification_url: verifUrl,
      reused: false,
    });
  } catch (err) {
    console.error("opp-onboard-merchant fatal error:", err);
    return jsonError("Onbekende serverfout", 500);
  }
});

// ----------------------------------------------------------------------------
// Helper: bank_account aanmaken en verification_url teruggeven
// ----------------------------------------------------------------------------
async function fetchBankVerificationUrl(
  merchantUid: string,
  oppApiKey: string,
  oppApiBase: string,
  oppNotifyBase: string,
  deepLink: string,
  admin: any,
): Promise<string | null> {
  // Stap 1: maak een bank account aan (kan idempotent door eerst te queryen)
  const listRes = await fetch(
    `${oppApiBase}/merchants/${encodeURIComponent(merchantUid)}/bank_accounts`,
    { headers: { Authorization: `Bearer ${oppApiKey}` } },
  );
  let bankUid: string | undefined;
  if (listRes.ok) {
    const list = await listRes.json();
    const data = list?.data as any[] | undefined;
    if (data && data.length > 0) {
      bankUid = data[0].uid as string | undefined;
    }
  }

  if (!bankUid) {
    const createRes = await fetch(
      `${oppApiBase}/merchants/${encodeURIComponent(merchantUid)}/bank_accounts`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${oppApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          return_url: `${deepLink}://onboarding/bank-return`,
          notify_url: `${oppNotifyBase}/opp-webhook`,
        }),
      },
    );
    if (!createRes.ok) {
      console.error("Bank account create faalde:", await createRes.text());
      return null;
    }
    const created = await createRes.json();
    bankUid = created.uid as string | undefined;
  }

  if (!bankUid) return null;

  // Stap 2: haal de verification_url op uit de bank_account resource
  const baRes = await fetch(
    `${oppApiBase}/merchants/${encodeURIComponent(merchantUid)}/bank_accounts/${encodeURIComponent(bankUid)}`,
    { headers: { Authorization: `Bearer ${oppApiKey}` } },
  );
  if (!baRes.ok) return null;
  const ba = await baRes.json();
  await admin
    .from("profiles")
    .update({
      opp_bank_account_uid: bankUid,
      opp_bank_account_status: ba?.status ?? null,
    })
    .eq("opp_merchant_uid", merchantUid);

  return (ba?.verification_url as string | undefined) ?? null;
}

function mapStatus(s: string): string {
  switch (s) {
    case "verified":
      return "verified";
    case "rejected":
    case "disapproved":
      return "rejected";
    case "review":
    case "pending":
      return "review";
    default:
      return "unverified";
  }
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
