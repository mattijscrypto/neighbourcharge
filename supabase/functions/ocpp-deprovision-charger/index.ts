// Pluggo — ocpp-deprovision-charger edge function
// ----------------------------------------------------------------------------
// Wordt aangeroepen vanuit de instellingen-flow (main.dart ~r9252, "Paal
// ontkoppelen"-knop). Zet een smart paal terug naar "manueel": haalt de
// identity van de CSMS whitelist en zet public.chargers.ocpp_charger_id = null.
//
// Ontkoppelvolgorde EXPLICIET:
//   1. DELETE naar CSMS EERST
//   2. UPDATE Supabase DAARNA
//
// Waarom die volgorde? Als 't tegenovergestelde faalt (DB gelukt, CSMS niet)
// blijft de CSMS de paal accepteren maar denkt onze app dat 'ie manueel is —
// dan probeert een booker via de app te starten, mislukt, en de CSMS blijft
// gefantoom-verbonden zitten. Andersom (CSMS weg, DB nog gezet) is beter: de
// app denkt dat 'ie smart is, doet remote-start, CSMS zegt "paal niet
// verbonden", user krijgt begrijpelijke error, en de owner kan opnieuw
// ontkoppelen (idempotent).
//
// Als de CSMS-DELETE 404 geeft (identity was al weg) beschouwen we dat als
// succes — dat is 't natuurlijke idempotency-gedrag.
//
// Flow:
//   1. Verifieert de gebruiker (Supabase JWT)
//   2. Leest charger_id uit body
//   3. Haalt charger op met service-role, verifieert ownership
//   4. Als ocpp_charger_id al null is → 200 (niks te doen)
//   5. DELETE naar CSMS `/chargers/{ocpp_charger_id}`
//   6. UPDATE public.chargers SET ocpp_charger_id = null
//   7. Retourneert { ok: true }
//
// Secrets / env: identiek aan ocpp-provision-charger.
// Response-schema: { ok: true } of { ok: false, error: "..." }
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const CSMS_HTTP_TIMEOUT_MS = 12_000;

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
    const csmsBase =
      Deno.env.get("CSMS_HTTP_BASE") ?? "https://csms.pluggoapp.nl";
    const csmsApiKey = Deno.env.get("CSMS_API_KEY");

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
      return jsonError("Server niet juist geconfigureerd (Supabase env)", 500);
    }
    if (!csmsApiKey) {
      return jsonError(
        "Server niet juist geconfigureerd (CSMS_API_KEY ontbreekt)",
        500,
      );
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return jsonError("Niet ingelogd", 401);
    }
    const userId = userData.user.id;

    // -----------------------------------------------------------------------
    // 2. Body parsen
    // -----------------------------------------------------------------------
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch (_) {
      return jsonError("Ongeldige JSON body", 400);
    }

    const chargerId = typeof body.charger_id === "string"
      ? body.charger_id.trim()
      : "";
    if (!chargerId) {
      return jsonError("Veld 'charger_id' is verplicht", 400);
    }

    // -----------------------------------------------------------------------
    // 3. Charger ophalen + owner-check
    // -----------------------------------------------------------------------
    const admin = createClient(supabaseUrl, supabaseServiceKey);

    const { data: charger, error: cErr } = await admin
      .from("chargers")
      .select("id, owner_id, ocpp_charger_id, name")
      .eq("id", chargerId)
      .maybeSingle();

    if (cErr) {
      console.error(
        "ocpp-deprovision-charger: charger query faalde",
        { chargerId, error: cErr },
      );
      return jsonError(
        `Paal ophalen mislukt: ${cErr.message ?? "onbekende DB-fout"}`,
        500,
      );
    }
    if (!charger) {
      return jsonError("Paal niet gevonden", 404);
    }
    if (charger.owner_id !== userId) {
      return jsonError("Deze paal is niet van jou", 403);
    }

    // Al ontkoppeld? Idempotent teruggeven — de knop kan geen half-state
    // triggeren en de wizard verwacht ok=true bij herhaling.
    if (!charger.ocpp_charger_id) {
      return jsonOk({ ok: true, already_unlinked: true });
    }

    const identity = charger.ocpp_charger_id;

    // -----------------------------------------------------------------------
    // 4. DELETE naar CSMS
    //
    // Endpoint: DELETE {CSMS_HTTP_BASE}/chargers/{identity}
    // Response CSMS:
    //   200 / 204 → verwijderd
    //   404       → bestond niet (behandelen als succes)
    //   5xx       → CSMS down
    // -----------------------------------------------------------------------
    const csmsUrl = `${csmsBase.replace(/\/$/, "")}/chargers/${
      encodeURIComponent(identity)
    }`;

    const controller = new AbortController();
    const timeoutHandle = setTimeout(
      () => controller.abort(),
      CSMS_HTTP_TIMEOUT_MS,
    );

    let csmsRes: Response;
    try {
      csmsRes = await fetch(csmsUrl, {
        method: "DELETE",
        headers: { "X-CSMS-API-Key": csmsApiKey },
        signal: controller.signal,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(
        "ocpp-deprovision-charger: CSMS unreachable",
        { csmsUrl, error: message },
      );
      return jsonError(
        controller.signal.aborted
          ? "CSMS reageerde niet op tijd — probeer 't opnieuw"
          : `Kon CSMS niet bereiken: ${message}`,
        502,
      );
    } finally {
      clearTimeout(timeoutHandle);
    }

    const csmsRaw = await csmsRes.text();
    if (
      csmsRes.status !== 200 &&
      csmsRes.status !== 204 &&
      csmsRes.status !== 404
    ) {
      console.error(
        "ocpp-deprovision-charger: onverwachte CSMS-status",
        { status: csmsRes.status, raw: csmsRaw.slice(0, 200) },
      );
      return jsonError(
        `Onverwachte CSMS-status ${csmsRes.status}`,
        502,
      );
    }

    // -----------------------------------------------------------------------
    // 5. UPDATE public.chargers — ontkoppel
    //
    // Als DIT faalt zit de owner in de gunstige half-state (CSMS ontkoppeld,
    // DB nog niet). Zie header voor waarom die volgorde bewust is gekozen —
    // de user kan gewoon opnieuw ontkoppelen. We geven wel een duidelijke
    // error terug zodat 'ie 't doet.
    // -----------------------------------------------------------------------
    const { error: updErr } = await admin
      .from("chargers")
      .update({ ocpp_charger_id: null })
      .eq("id", chargerId);

    if (updErr) {
      console.error(
        "ocpp-deprovision-charger: DB update faalde na CSMS delete",
        { chargerId, identity, error: updErr },
      );
      return jsonError(
        "CSMS is losgekoppeld maar we konden 't in je account niet bijwerken. Probeer nogmaals op 'Ontkoppelen' te tikken.",
        500,
      );
    }

    console.log(
      `ocpp-deprovision-charger: OK user=${userId} charger=${chargerId} identity=${identity} (CSMS ${csmsRes.status})`,
    );

    return jsonOk({ ok: true });
  } catch (err) {
    console.error("ocpp-deprovision-charger fatal error:", err);
    const message = err instanceof Error ? err.message : String(err);
    return jsonError(`Serverfout: ${message}`, 500);
  }
});

function jsonError(
  message: string,
  status: number,
  extra?: Record<string, unknown>,
) {
  return new Response(
    JSON.stringify({ ok: false, error: message, ...(extra ?? {}) }),
    {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status,
    },
  );
}

function jsonOk(payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status: 200,
  });
}
