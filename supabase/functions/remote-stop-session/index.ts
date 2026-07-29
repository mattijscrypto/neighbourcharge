// Pluggo — remote-stop-session edge function
// ----------------------------------------------------------------------------
// Spiegel van `remote-start-session`. Wordt aangeroepen wanneer een boeker
// (of de paal-eigenaar) in de app op "Stop laden" tikt. Deze functie zoekt
// de actieve OCPP-transactie op die bij deze boeking hoort, en stuurt een
// RemoteStopTransaction-command naar de CSMS.
//
// Flow:
//   1. Verifieert de gebruiker (Supabase JWT)
//   2. Leest booking_id uit body (transaction_id optioneel voor edge-cases)
//   3. Haalt met service-role de actieve charging_sessions-rij op voor deze
//      booking (status='in_progress'). Als er geen actieve sessie is: 404.
//   4. Verifieert dat de aanvrager óf de booker óf de paal-eigenaar is.
//      Beide partijen mogen stoppen — de boeker wil misschien vroeg weg,
//      de paal-eigenaar wil misschien een verwaarloosde sessie afbreken.
//   5. POST naar CSMS `/chargers/{ocpp_id}/remote-stop` met X-CSMS-API-Key
//      en body { transactionId }
//   6. Retourneert response van CSMS door naar de app
//
// Secrets / env: zelfde als remote-start-session.
//
// Response-schema:
//   200 OK    → { accepted: true,  ocppResponse: { status: "Accepted" } }
//   409       → { accepted: false, ocppResponse: { status: "Rejected" }, reason }
//   4xx / 5xx → { error: "...", details?: "..." }
//
// Beslissing: we sluiten de sessions-rij hier NIET af. De paal zal (na het
// accepteren van de RemoteStop) zelf een StopTransaction sturen; de CSMS
// zet dan meter_stop_wh, stopped_at en status='completed'. Zo blijft de
// bron-van-waarheid consistent bij de CSMS, ook als de RemoteStop wél
// accepted wordt maar de paal om een of andere reden nog even doorlaadt.
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Zelfde timeout-marge als bij remote-start: CSMS zelf wacht 10s op de paal,
// wij geven 'm 12s zodat een nette 504 van de CSMS niet ook nog aan onze kant
// timeout.
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

    // User-scoped client om auth.uid() te bepalen
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth
      .getUser();
    if (userError || !userData?.user) {
      return jsonError("Niet ingelogd", 401);
    }
    const userId = userData.user.id;

    // -----------------------------------------------------------------------
    // 2. Body parsen
    //
    // Primair pad: caller stuurt booking_id — we resolven zelf de actieve
    // transaction. Fallback pad: caller stuurt transaction_id direct (bijv.
    // paal-eigenaar in een dashboard die geen booking-context heeft).
    // -----------------------------------------------------------------------
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch (_) {
      return jsonError("Ongeldige JSON body", 400);
    }

    const bookingId = typeof body.booking_id === "string"
      ? body.booking_id.trim()
      : "";
    const rawTxId = body.transaction_id;
    const transactionIdInput = typeof rawTxId === "number" &&
        Number.isInteger(rawTxId)
      ? rawTxId
      : typeof rawTxId === "string" && /^\d+$/.test(rawTxId.trim())
      ? Number(rawTxId.trim())
      : null;

    if (!bookingId && transactionIdInput === null) {
      return jsonError(
        "Geef minstens 'booking_id' óf 'transaction_id' mee",
        400,
      );
    }

    // -----------------------------------------------------------------------
    // 3. Actieve sessie opzoeken
    // -----------------------------------------------------------------------
    const admin = createClient(supabaseUrl, supabaseServiceKey);

    type SessionRow = {
      transaction_id: number;
      ocpp_charger_id: string;
      status: string;
      booking_id: string | null;
      charger_id: string | null;
      chargers:
        | { id: string; owner_id: string; name: string | null }
        | { id: string; owner_id: string; name: string | null }[]
        | null;
      bookings:
        | { id: string; user_id: string }
        | { id: string; user_id: string }[]
        | null;
    };

    const sessionSelect =
      "transaction_id, ocpp_charger_id, status, booking_id, charger_id, " +
      "chargers:charger_id(id, owner_id, name), " +
      "bookings:booking_id(id, user_id)";

    let session: SessionRow | null = null;
    let sessionErr: { message?: string } | null = null;

    if (transactionIdInput !== null) {
      const { data, error } = await admin
        .from("charging_sessions")
        .select(sessionSelect)
        .eq("transaction_id", transactionIdInput)
        .maybeSingle();
      session = data as SessionRow | null;
      sessionErr = error;
    } else {
      // Booking-pad: er kan in theorie meer dan één in_progress-sessie per
      // booking bestaan als iemand hem stopt en direct opnieuw start binnen
      // hetzelfde tijdsvenster — pak de meest recente.
      const { data, error } = await admin
        .from("charging_sessions")
        .select(sessionSelect)
        .eq("booking_id", bookingId)
        .eq("status", "in_progress")
        .order("started_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      session = data as SessionRow | null;
      sessionErr = error;
    }

    if (sessionErr) {
      console.error(
        "remote-stop-session: sessie-query faalde",
        { bookingId, transactionIdInput, error: sessionErr },
      );
      return jsonError(
        `Sessie ophalen mislukt: ${sessionErr.message ?? "onbekende DB-fout"}`,
        500,
      );
    }
    if (!session) {
      return jsonError(
        "Geen actieve laadsessie gevonden voor deze boeking",
        404,
      );
    }
    if (session.status !== "in_progress") {
      return jsonError(
        `Sessie staat al op status '${session.status}' — niks te stoppen`,
        409,
      );
    }

    // -----------------------------------------------------------------------
    // 4. Authorization: booker OF paal-eigenaar mag stoppen
    // -----------------------------------------------------------------------
    const booking = Array.isArray(session.bookings)
      ? session.bookings[0]
      : session.bookings;
    const charger = Array.isArray(session.chargers)
      ? session.chargers[0]
      : session.chargers;

    const isBooker = booking?.user_id === userId;
    const isOwner = charger?.owner_id === userId;

    if (!isBooker && !isOwner) {
      return jsonError(
        "Je bent noch de boeker noch de eigenaar van deze paal",
        403,
      );
    }

    if (!session.ocpp_charger_id) {
      // Kan in principe niet — kolom is NOT NULL — maar defensief.
      return jsonError(
        "Sessie heeft geen OCPP-charger-id (dit hoort niet te gebeuren)",
        500,
      );
    }

    // -----------------------------------------------------------------------
    // 5. POST naar CSMS
    //
    // Endpoint: POST {CSMS_HTTP_BASE}/chargers/{ocpp_charger_id}/remote-stop
    // Body:     { transactionId }
    // Auth:     X-CSMS-API-Key header
    //
    // CSMS-response mapping (zie pluggo-csms/lib/http-api.js):
    //   202 → { accepted: true,  ocppResponse: { status: "Accepted" } }
    //   409 → { accepted: false, ocppResponse: { status: "Rejected" | ... } }
    //   404 → paal niet verbonden
    //   504 → paal antwoordde niet
    // -----------------------------------------------------------------------
    const csmsUrl = `${csmsBase.replace(/\/$/, "")}/chargers/${
      encodeURIComponent(session.ocpp_charger_id)
    }/remote-stop`;

    const controller = new AbortController();
    const timeoutHandle = setTimeout(
      () => controller.abort(),
      CSMS_HTTP_TIMEOUT_MS,
    );

    let csmsRes: Response;
    try {
      csmsRes = await fetch(csmsUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSMS-API-Key": csmsApiKey,
        },
        body: JSON.stringify({ transactionId: session.transaction_id }),
        signal: controller.signal,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(
        "remote-stop-session: CSMS unreachable",
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

    let csmsBody: Record<string, unknown> = {};
    const csmsRaw = await csmsRes.text();
    try {
      csmsBody = csmsRaw ? JSON.parse(csmsRaw) : {};
    } catch (_) {
      console.warn(
        "remote-stop-session: CSMS response was geen JSON",
        { status: csmsRes.status, raw: csmsRaw.slice(0, 200) },
      );
      csmsBody = { error: "CSMS gaf een niet-JSON response terug" };
    }

    console.log(
      `remote-stop-session: user=${userId} role=${
        isOwner ? "owner" : "booker"
      } tx=${session.transaction_id} paal=${session.ocpp_charger_id} → CSMS ${csmsRes.status}`,
    );

    // Statuscode-mapping identiek aan remote-start-session:
    if (csmsRes.status === 202) {
      return jsonOk({
        accepted: true,
        ocppResponse: csmsBody.ocppResponse ?? null,
        transaction_id: session.transaction_id,
      });
    }
    if (csmsRes.status === 404) {
      return jsonError(
        "De paal is momenteel niet verbonden — de sessie loopt door tot 'ie weer online komt",
        503,
        { csms: csmsBody },
      );
    }
    if (csmsRes.status === 409) {
      return jsonError(
        `De paal weigerde de stopopdracht${
          (csmsBody.ocppResponse as { status?: string })?.status
            ? ` (${(csmsBody.ocppResponse as { status: string }).status})`
            : ""
        }`,
        409,
        { csms: csmsBody },
      );
    }
    if (csmsRes.status === 504) {
      return jsonError(
        "De paal antwoordde niet op tijd — probeer 't zo direct opnieuw",
        504,
        { csms: csmsBody },
      );
    }
    return jsonError(
      `Onverwachte CSMS-status ${csmsRes.status}`,
      502,
      { csms: csmsBody },
    );
  } catch (err) {
    console.error("remote-stop-session fatal error:", err);
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
    JSON.stringify({ error: message, ...(extra ?? {}) }),
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
