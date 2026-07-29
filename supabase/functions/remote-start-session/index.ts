// Pluggo — remote-start-session edge function
// ----------------------------------------------------------------------------
// Wordt aangeroepen vanuit de Flutter-app in twee scenario's:
//
//   A) Boeker-flow (booking_id-mode) — een boeker met een bevestigde boeking
//      tikt op "Start laden" in de live-charging-widget. We verifiëren de
//      boeking-context (juiste user, confirmed, binnen tijdsvenster).
//
//   B) Host-eigen-laden-flow (owner-mode, task #340) — de paal-eigenaar wil
//      zonder boeking zelf zijn eigen EV laden aan zijn eigen paal. Body
//      bevat dan `initiated_by_owner: true` + `charger_id`. Geen boeking-
//      window check (dit is JOUW paal buiten verhuur), maar wel:
//        - user_id === charger.owner_id
//        - charger.ocpp_charger_id != null
//        - er loopt op dit moment geen andere sessie op deze paal
//
// Beide paden delen dezelfde stap 5–7:
//   5. Genereert een korte, deterministische idTag uit user_id
//   6. POST naar CSMS `/chargers/{ocpp_id}/remote-start` met X-CSMS-API-Key
//   7. Retourneert response van CSMS door naar de app
//
// Secrets / env:
//   • CSMS_HTTP_BASE    — bv. "https://csms.pluggoapp.nl" (default)
//   • CSMS_API_KEY      — shared secret die de CSMS in .env heeft. Beide
//                          moeten identiek zijn. Zie _internal/pluggo-csms/
//                          CREDENTIALS.md.
//   • SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY — standaard
//
// Response-schema:
//   200 OK    → { accepted: true,  ocppResponse: { status: "Accepted" } }
//   409       → { accepted: false, ocppResponse: { status: "Rejected" }, reason }
//   4xx / 5xx → { error: "...", details?: "..." }
//
// Beslissing: we openen géén sessions-rij hier. De CSMS ontvangt van de paal
// een StartTransaction (na het accepteren van de RemoteStart) en maakt DAAR
// de row aan. Zo blijft de bron-van-waarheid consistent bij de CSMS en zit
// er geen race tussen "we boekten een sessie maar de paal accepteerde 'm niet".
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Tolerantie: iemand die 2 min te vroeg tikt of 5 min uitloopt mag ook nog
// starten. Dit voorkomt frustratie bij kleine klok-verschillen en geeft de
// booker een reële buffer. Grenzen zijn bewust asymmetrisch (meer tolerantie
// aan de late kant dan aan de vroege kant).
const EARLY_START_TOLERANCE_MIN = 2;
const LATE_START_TOLERANCE_MIN = 5;

// OCPP 1.6 limiet: idTag is een string van max 20 karakters.
const OCPP_ID_TAG_MAX_LEN = 20;

// Hoe lang wachten we op de CSMS voordat we opgeven. De CSMS zelf wacht 10s
// op de paal; wij geven 'm 12s marge zodat een netjes-getimeoutde 504 van
// de CSMS ons niet nogmaals doet timeouten aan onze kant.
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

    const initiatedByOwner = body.initiated_by_owner === true;
    const bookingId = typeof body.booking_id === "string"
      ? body.booking_id.trim()
      : "";
    const chargerIdParam = typeof body.charger_id === "string"
      ? body.charger_id.trim()
      : "";

    // Exact één van beide moet gezet zijn — anders weten we niet welke flow.
    if (!initiatedByOwner && !bookingId) {
      return jsonError(
        "Veld 'booking_id' is verplicht (of stuur initiated_by_owner=true + charger_id)",
        400,
      );
    }
    if (initiatedByOwner && !chargerIdParam) {
      return jsonError(
        "Bij initiated_by_owner=true is 'charger_id' verplicht",
        400,
      );
    }

    // -----------------------------------------------------------------------
    // 3. Charger (+ evt. booking) ophalen met service-role
    //
    // We gebruiken service-role zodat we niet afhankelijk zijn van RLS voor
    // de authorization-check — we doen die zelf expliciet hieronder, en
    // hebben zo één plek waar de logica staat i.p.v. verspreid tussen RLS
    // policies en app-code. Wel: nooit meer data teruggeven dan nodig.
    // -----------------------------------------------------------------------
    const admin = createClient(supabaseUrl, supabaseServiceKey);

    type CharSlim = {
      id: string;
      ocpp_charger_id: string | null;
      owner_id: string;
      name: string;
    };
    let charger: CharSlim | null = null;

    if (initiatedByOwner) {
      // Owner-mode: haal de paal direct op via charger_id.
      const { data: chg, error: cErr } = await admin
        .from("chargers")
        .select("id, ocpp_charger_id, owner_id, name")
        .eq("id", chargerIdParam)
        .maybeSingle();

      if (cErr) {
        console.error(
          "remote-start-session: charger query faalde",
          { chargerIdParam, error: cErr },
        );
        return jsonError(
          `Paal ophalen mislukt: ${cErr.message ?? "onbekende DB-fout"}`,
          500,
        );
      }
      if (!chg) {
        return jsonError("Paal niet gevonden", 404);
      }

      // -----------------------------------------------------------------------
      // 4a. Owner-mode authorization + state checks
      //
      // Owner-mode = eigen paal, eigen EV, geen boeking. Twee checks:
      //   - user_id === charger.owner_id (dus jij bent daadwerkelijk eigenaar)
      //   - geen actieve sessie op deze paal (voorkomt dat een owner per
      //     ongeluk een gast-sessie doorkruist)
      // -----------------------------------------------------------------------
      if (chg.owner_id !== userId) {
        return jsonError(
          "Deze paal is niet van jou — eigen-laden werkt alleen op je eigen paal",
          403,
        );
      }

      // Actieve sessie-check: geen open charging_sessions op deze paal.
      // Status-enum ('in_progress'|'completed'|'orphaned'|'errored') is de
      // bron-van-waarheid; `stopped_at` kan bij een orphaned sessie ook null
      // zijn terwijl 'ie niet meer draait, dus filter op status.
      const { data: openSessions, error: sErr } = await admin
        .from("charging_sessions")
        .select("transaction_id")
        .eq("charger_id", chg.id)
        .eq("status", "in_progress")
        .limit(1);

      if (sErr) {
        console.error(
          "remote-start-session: active-session query faalde",
          { chargerId: chg.id, error: sErr },
        );
        // Non-fatal: als de check crasht willen we niet permanent starten
        // blokkeren. Log en ga door.
      } else if (openSessions && openSessions.length > 0) {
        return jsonError(
          "Er loopt al een sessie op deze paal — stop die eerst",
          409,
        );
      }

      charger = chg as CharSlim;
    } else {
      // Booker-flow: verifieer boeking + tijdsvenster.
      const { data: booking, error: bErr } = await admin
        .from("bookings")
        .select(
          "id, user_id, charger_id, status, start_time, end_time, chargers:charger_id(id, ocpp_charger_id, owner_id, name)",
        )
        .eq("id", bookingId)
        .maybeSingle();

      if (bErr) {
        console.error(
          "remote-start-session: booking query faalde",
          { bookingId, error: bErr },
        );
        return jsonError(
          `Boeking ophalen mislukt: ${bErr.message ?? "onbekende DB-fout"}`,
          500,
        );
      }
      if (!booking) {
        return jsonError("Boeking niet gevonden", 404);
      }

      // -----------------------------------------------------------------------
      // 4b. Booker-flow authorization + state checks
      // -----------------------------------------------------------------------
      if (booking.user_id !== userId) {
        return jsonError("Deze boeking is niet van jou", 403);
      }
      if (booking.status !== "confirmed") {
        return jsonError(
          `Boeking staat op status '${booking.status}' — alleen bevestigde boekingen kunnen laden starten`,
          409,
        );
      }

      const now = Date.now();
      const startAt = new Date(booking.start_time as string).getTime();
      const endAt = new Date(booking.end_time as string).getTime();
      if (Number.isNaN(startAt) || Number.isNaN(endAt)) {
        return jsonError("Boeking heeft ongeldige tijden", 500);
      }

      const startTolerated = startAt - EARLY_START_TOLERANCE_MIN * 60_000;
      const endTolerated = endAt + LATE_START_TOLERANCE_MIN * 60_000;
      if (now < startTolerated) {
        const minsUntil = Math.ceil((startAt - now) / 60_000);
        return jsonError(
          `Je boeking begint pas over ${minsUntil} min — probeer 't dan opnieuw`,
          409,
        );
      }
      if (now > endTolerated) {
        return jsonError(
          "Je boeking is verlopen — maak eerst een nieuwe boeking",
          409,
        );
      }

      // Supabase geeft de embedded relatie terug als object OF array afhankelijk
      // van of 'ie de FK herkent als many-to-one. We handelen beide gevallen af.
      charger = Array.isArray(booking.chargers)
        ? (booking.chargers[0] as CharSlim)
        : (booking.chargers as CharSlim | null);
    }

    if (!charger) {
      return jsonError(
        "Bijhorende paal niet gevonden — heeft de eigenaar 'm verwijderd?",
        404,
      );
    }
    if (!charger.ocpp_charger_id) {
      return jsonError(
        "Deze paal is nog niet OCPP-gekoppeld — vraag de eigenaar 'm te activeren, of gebruik de handmatige laadflow",
        409,
      );
    }

    // -----------------------------------------------------------------------
    // 5. idTag genereren
    //
    // OCPP 1.6 limiteert idTag tot 20 karakters. We hebben nodig:
    //   - Uniek per user (voor traceerbaarheid in sessions)
    //   - Deterministic (zodat retry hetzelfde geeft)
    //   - Niet-enumerable (liever geen strak "user-1", "user-2")
    //
    // Voor MVP knippen we de user_id UUID zonder streepjes af tot 20 chars.
    // Dat is 20 hex = 80 bits entropie, ruim voldoende om collisions te
    // vermijden binnen onze user-base. In fase 2 vervangen we dit door
    // HMAC-SHA256(user_id, server_secret)[:20] om enumeration onmogelijk te
    // maken (task voor later).
    // -----------------------------------------------------------------------
    const idTag = userId.replace(/-/g, "").slice(0, OCPP_ID_TAG_MAX_LEN);

    // -----------------------------------------------------------------------
    // 6. POST naar CSMS
    //
    // Endpoint: POST {CSMS_HTTP_BASE}/chargers/{ocpp_charger_id}/remote-start
    // Body:     { idTag, connectorId? }
    // Auth:     X-CSMS-API-Key header
    //
    // Responses die de CSMS geeft (zie pluggo-csms/lib/http-api.js):
    //   202 → { accepted: true,  ocppResponse: { status: "Accepted" } }
    //   409 → { accepted: false, ocppResponse: { status: "Rejected" | ... } }
    //   404 → { error: "Charger niet verbonden" }
    //   504 → { error: "Paal heeft niet (op tijd) geantwoord" }
    // -----------------------------------------------------------------------
    const csmsUrl =
      `${csmsBase.replace(/\/$/, "")}/chargers/${
        encodeURIComponent(charger.ocpp_charger_id)
      }/remote-start`;

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
        body: JSON.stringify({ idTag, connectorId: 1 }),
        signal: controller.signal,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(
        "remote-start-session: CSMS unreachable",
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

    // Response van CSMS parsen — als 't geen JSON is, val terug op text.
    let csmsBody: Record<string, unknown> = {};
    const csmsRaw = await csmsRes.text();
    try {
      csmsBody = csmsRaw ? JSON.parse(csmsRaw) : {};
    } catch (_) {
      console.warn(
        "remote-start-session: CSMS response was geen JSON",
        { status: csmsRes.status, raw: csmsRaw.slice(0, 200) },
      );
      csmsBody = { error: "CSMS gaf een niet-JSON response terug" };
    }

    console.log(
      `remote-start-session: user=${userId} booking=${bookingId} paal=${charger.ocpp_charger_id} → CSMS ${csmsRes.status}`,
    );

    // Doorzetten naar de app met betekenisvolle status codes.
    // - 202 (accepted door paal) → 200 met accepted=true
    // - 404 (paal niet verbonden) → 503 (dienst tijdelijk niet beschikbaar)
    // - 409 (paal weigerde)       → 409 met accepted=false
    // - 504 (paal antwoordde niet) → 504
    // - anders                    → 502
    if (csmsRes.status === 202) {
      return jsonOk({
        accepted: true,
        ocppResponse: csmsBody.ocppResponse ?? null,
        charger: { name: charger.name },
      });
    }
    if (csmsRes.status === 404) {
      // Owner-mode: de user IS de eigenaar, dus de "vraag de eigenaar"-copy
      // klopt niet. Booker-mode: user is een gast en moet weten dat 't aan de
      // paal-kant ligt, niet aan hun app.
      return jsonError(
        initiatedByOwner
          ? "Je paal is momenteel niet verbonden met Pluggo. Check dat 'ie stroom en internet heeft."
          : "De paal is momenteel niet verbonden — vraag de eigenaar te controleren of 'ie online is",
        503,
        { csms: csmsBody },
      );
    }
    if (csmsRes.status === 409) {
      return jsonError(
        `De paal weigerde de startopdracht${
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
        "De paal antwoordde niet op tijd — mogelijk offline of bezig",
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
    console.error("remote-start-session fatal error:", err);
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
