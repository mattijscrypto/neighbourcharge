// Pluggo — ocpp-provision-charger edge function
// ----------------------------------------------------------------------------
// Wordt aangeroepen vanuit de CouplingWizard (main.dart ~r7322) wanneer een
// paal-eigenaar zijn charger aan de Pluggo CSMS wil koppelen. Deze functie is
// de brug tussen de app en de CSMS voor het "whitelist een nieuwe charger
// identity"-scenario, én zorgt dat de public.chargers-rij de bijbehorende
// ocpp_charger_id krijgt zodat de client kant weet dat 't een smart paal is.
//
// Flow:
//   1. Verifieert de gebruiker (Supabase JWT)
//   2. Leest charger_id, ocpp_identity, ocpp_password uit body
//   3. Validatie: identity 1..20 chars (OCPP 1.6 idTag limiet + charger-id
//      is ook 20-limiet in de meeste CSMS-en), password >= 8 chars
//   4. Haalt charger op met service-role
//   5. Verifieert: charger.owner_id === auth.uid()
//                  charger.ocpp_charger_id IS NULL (nog niet gekoppeld)
//   6. PUT naar CSMS `/chargers/{identity}` met { password } — de CSMS zelf
//      bcrypt-hasht en slaat op in z'n eigen tabel. Wij houden geen plaintext
//      of hash in de Supabase DB — bewuste keuze: één plek voor auth-secrets.
//   7. UPDATE public.chargers SET ocpp_charger_id = identity
//   8. Als DB-update faalt na CSMS-whitelist, doet 'ie best-effort DELETE naar
//      CSMS om de half-state te vermijden. Als DIE ook faalt: 500 met een
//      hint aan support (staat in logs, kan handmatig opgeruimd worden).
//   9. Retourneert { ok: true, endpoint: "wss://..." } zodat de wizard 'm
//      kan tonen aan de installateur.
//
// Secrets / env:
//   • CSMS_HTTP_BASE    — zie remote-start-session
//   • CSMS_API_KEY      — zie remote-start-session
//   • CSMS_WS_ENDPOINT  — optioneel, wordt teruggegeven aan de client zodat
//                          de owner weet welke URL 'ie in z'n paal moet
//                          zetten. Default: "wss://ocpp.pluggo.eu/ocpp"
//                          (zie _internal/pluggo-csms/README.md).
//   • SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY — standaard
//
// Response-schema:
//   200 OK    → { ok: true, endpoint: "wss://...", ocpp_charger_id: "..." }
//   4xx / 5xx → { ok: false, error: "..." }
//
// IDEMPOTENT: als de owner precies dezelfde identity + password nogmaals
// submit, geeft de CSMS 200 (bij PUT met identieke body). Wij updaten dan
// nog een keer public.chargers en geven ok terug. Dit voorkomt dat een
// wizard-refresh half-state achterlaat.
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// OCPP 1.6 basic auth username == charger identity; de meeste CSMS-en (ook
// steve/citrineOS/pluggo-csms) begrenzen dit tot 20 karakters om compat te
// bewaren met de OCPP-J spec voor idTag. We spiegelen dat hier.
const OCPP_IDENTITY_MAX_LEN = 20;
const OCPP_IDENTITY_MIN_LEN = 1;

// Password kan langer, maar we forceren minimaal 8 chars aan client-kant en
// spiegelen dat hier voor defense-in-depth. CSMS zelf mag hem verder valideren.
const OCPP_PASSWORD_MIN_LEN = 8;
const OCPP_PASSWORD_MAX_LEN = 128;

// Zelfde marge als remote-start-session om timing-inconsistenties te vermijden.
const CSMS_HTTP_TIMEOUT_MS = 12_000;

// Regex voor OCPP charger identity: alfanumeriek + '-' + '_' (RFC-ish voor
// URL-safe basic-auth username). Geen spaties, geen ':' (breekt basic auth),
// geen '/' (breekt onze URL-routing).
const IDENTITY_REGEX = /^[A-Za-z0-9_-]+$/;

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
    const csmsWsEndpoint =
      Deno.env.get("CSMS_WS_ENDPOINT") ?? "wss://ocpp.pluggo.eu/ocpp";

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
    // 2. Body parsen + valideren
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
    const ocppIdentity = typeof body.ocpp_identity === "string"
      ? body.ocpp_identity.trim()
      : "";
    const ocppPassword = typeof body.ocpp_password === "string"
      ? body.ocpp_password
      : "";

    if (!chargerId) {
      return jsonError("Veld 'charger_id' is verplicht", 400);
    }
    if (
      ocppIdentity.length < OCPP_IDENTITY_MIN_LEN ||
      ocppIdentity.length > OCPP_IDENTITY_MAX_LEN
    ) {
      return jsonError(
        `Charge Point Identity moet ${OCPP_IDENTITY_MIN_LEN}-${OCPP_IDENTITY_MAX_LEN} karakters lang zijn`,
        400,
      );
    }
    if (!IDENTITY_REGEX.test(ocppIdentity)) {
      return jsonError(
        "Charge Point Identity mag alleen letters, cijfers, '-' en '_' bevatten",
        400,
      );
    }
    if (
      ocppPassword.length < OCPP_PASSWORD_MIN_LEN ||
      ocppPassword.length > OCPP_PASSWORD_MAX_LEN
    ) {
      return jsonError(
        `Password moet ${OCPP_PASSWORD_MIN_LEN}-${OCPP_PASSWORD_MAX_LEN} karakters lang zijn`,
        400,
      );
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
        "ocpp-provision-charger: charger query faalde",
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

    // Als de paal al gekoppeld is met een ANDERE identity → blokkeren, de
    // owner moet eerst ontkoppelen. Als 'ie dezelfde identity al heeft is
    // dat idempotent en gaan we door (retry-scenario na wizard-crash).
    if (
      charger.ocpp_charger_id &&
      charger.ocpp_charger_id !== ocppIdentity
    ) {
      return jsonError(
        `Deze paal is al gekoppeld als '${charger.ocpp_charger_id}'. Ontkoppel 'm eerst voordat je 'n nieuwe identity gebruikt.`,
        409,
      );
    }

    // -----------------------------------------------------------------------
    // 4. Uniqueness check: is deze identity al ergens anders in gebruik?
    //
    // De CSMS zelf voorkomt duplicates (unique constraint), maar we willen
    // een fatsoenlijke error TERUG voordat we naar de CSMS gaan — anders
    // krijgen owners een cryptische 409 uit de CSMS-response. Klein extra
    // rondje in eigen DB voorkomt dat.
    // -----------------------------------------------------------------------
    const { data: dupe, error: dupErr } = await admin
      .from("chargers")
      .select("id, owner_id")
      .eq("ocpp_charger_id", ocppIdentity)
      .neq("id", chargerId)
      .maybeSingle();
    if (dupErr) {
      console.error(
        "ocpp-provision-charger: dupe-check faalde",
        { ocppIdentity, error: dupErr },
      );
      // Non-fataal: gaan door, CSMS vangt 't dan alsnog op.
    } else if (dupe) {
      return jsonError(
        "Deze Charge Point Identity is al in gebruik. Kies iets unieks (bv. z'n serienummer met 'PLG-' prefix).",
        409,
      );
    }

    // -----------------------------------------------------------------------
    // 5. PUT naar CSMS — whitelist de charger identity + password
    //
    // Endpoint:  PUT {CSMS_HTTP_BASE}/chargers/{identity}
    // Body:      { password }        — CSMS hasht zelf (bcrypt) en slaat op
    // Auth:      X-CSMS-API-Key header
    //
    // Response CSMS (zie pluggo-csms/lib/http-api.js, admin-routes):
    //   201 → aangemaakt
    //   200 → bijgewerkt (identity bestond al met andere password)
    //   409 → identity in gebruik door andere account (safety net)
    //   400 → validation error, body doorreiken
    //   5xx → CSMS down
    // -----------------------------------------------------------------------
    const csmsUrl = `${csmsBase.replace(/\/$/, "")}/chargers/${
      encodeURIComponent(ocppIdentity)
    }`;

    const controller = new AbortController();
    const timeoutHandle = setTimeout(
      () => controller.abort(),
      CSMS_HTTP_TIMEOUT_MS,
    );

    let csmsRes: Response;
    try {
      csmsRes = await fetch(csmsUrl, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-CSMS-API-Key": csmsApiKey,
        },
        body: JSON.stringify({ password: ocppPassword }),
        signal: controller.signal,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(
        "ocpp-provision-charger: CSMS unreachable",
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
        "ocpp-provision-charger: CSMS response was geen JSON",
        { status: csmsRes.status, raw: csmsRaw.slice(0, 200) },
      );
    }

    if (csmsRes.status === 409) {
      return jsonError(
        "Deze Charge Point Identity is al in gebruik op de CSMS. Kies iets unieks.",
        409,
        { csms: csmsBody },
      );
    }
    if (csmsRes.status === 400) {
      const detail = typeof csmsBody.error === "string"
        ? csmsBody.error
        : "onbekende validation-fout";
      return jsonError(
        `CSMS wees de provisioning af: ${detail}`,
        400,
        { csms: csmsBody },
      );
    }
    if (csmsRes.status !== 200 && csmsRes.status !== 201) {
      console.error(
        "ocpp-provision-charger: onverwachte CSMS-status",
        { status: csmsRes.status, body: csmsBody },
      );
      return jsonError(
        `Onverwachte CSMS-status ${csmsRes.status}`,
        502,
        { csms: csmsBody },
      );
    }

    // -----------------------------------------------------------------------
    // 6. UPDATE public.chargers — koppel de identity aan onze paal
    //
    // Als deze faalt na een succesvolle CSMS-whitelist, doen we best-effort
    // rollback (DELETE op CSMS). Anders zit de owner met een half-state:
    // CSMS accepteert wel connecties met deze identity, maar wij weten er
    // niets van en de app kan 'r niets mee.
    // -----------------------------------------------------------------------
    const { error: updErr } = await admin
      .from("chargers")
      .update({ ocpp_charger_id: ocppIdentity })
      .eq("id", chargerId);

    if (updErr) {
      console.error(
        "ocpp-provision-charger: DB update faalde na CSMS whitelist — rollback CSMS",
        { chargerId, ocppIdentity, error: updErr },
      );

      // Best-effort rollback. Als DIT ook faalt, laten we 'n loud log achter
      // zodat support 'm handmatig kan opruimen — niet blockend voor de user
      // want de CSMS-kant is dan tenminste consistent met wat wij hem later
      // opnieuw kunnen sturen.
      try {
        const rbController = new AbortController();
        const rbTimeout = setTimeout(
          () => rbController.abort(),
          CSMS_HTTP_TIMEOUT_MS,
        );
        const rbRes = await fetch(csmsUrl, {
          method: "DELETE",
          headers: { "X-CSMS-API-Key": csmsApiKey },
          signal: rbController.signal,
        });
        clearTimeout(rbTimeout);
        if (rbRes.status !== 200 && rbRes.status !== 204) {
          console.error(
            "ocpp-provision-charger: ROLLBACK CSMS DELETE faalde — HANDMATIG OPRUIMEN VEREIST",
            { csmsUrl, rollbackStatus: rbRes.status, chargerId, ocppIdentity },
          );
        }
      } catch (rbErr) {
        console.error(
          "ocpp-provision-charger: ROLLBACK CSMS onbereikbaar — HANDMATIG OPRUIMEN VEREIST",
          { csmsUrl, error: String(rbErr), chargerId, ocppIdentity },
        );
      }

      return jsonError(
        "Kon paal niet aan je account koppelen. Probeer 't opnieuw — als 't blijft mislukken, neem contact op met support.",
        500,
      );
    }

    console.log(
      `ocpp-provision-charger: OK user=${userId} charger=${chargerId} identity=${ocppIdentity} (CSMS ${csmsRes.status})`,
    );

    return jsonOk({
      ok: true,
      ocpp_charger_id: ocppIdentity,
      endpoint: csmsWsEndpoint,
    });
  } catch (err) {
    console.error("ocpp-provision-charger fatal error:", err);
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
