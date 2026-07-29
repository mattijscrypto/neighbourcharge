// Pluggo — submit-tin edge function
// ----------------------------------------------------------------------------
// Task #263: DAC7 BSN-drempelflow.
//
// Deze functie ontvangt van een ingelogde paaleigenaar het fiscaal
// identificatienummer (TIN — BSN voor natuurlijk persoon, RSIN voor
// rechtspersoon) dat we straks bij de jaarlijkse DAC7-rapportage aan de
// Belastingdienst moeten meegeven. De rauwe waarde wordt NOOIT in klare tekst
// opgeslagen — we versleutelen met AES-256-GCM en zetten alleen ciphertext +
// nonce weg in `profiles_tin_secure` (RLS zonder select-policy voor
// authenticated → alleen service_role kan lezen).
//
// Grondslag (verplicht in prompt-UI): art. 10c AWR jo. art. 8 Uitv.reg. WIB
// jo. DAC7-richtlijn (EU) 2021/514.
//
// Interface:
//   POST { tin: string, tin_type: "bsn" | "rsin" }
//   → 200 { ok: true, tin_last4: "1234", tin_type: "bsn",
//           payouts_unblocked: boolean }
//   → 400 { error: "invalid_format" | "invalid_check_digit" |
//                  "tin_type_mismatch" | "missing_field" }
//   → 401 { error: "unauthorized" }
//   → 500 { error: "..." }
//
// Auth: user JWT verplicht (verify_jwt = default true in config.toml).
//
// Secrets — handmatig gezet via `supabase secrets set …`:
//   • DAC7_ENCRYPTION_KEY          — base64 van 32 bytes (256-bit AES-GCM key)
//   • DAC7_ENCRYPTION_KEY_VERSION  — smallint, huidige actieve versie (default 1)
//
// Genereer een nieuwe key met:
//   openssl rand -base64 32
//
// Key rotation-strategie: als een key gecompromitteerd is of ouder wordt dan
// 12 maanden, genereer nieuwe key + bump version. Aparte one-off script
// leest oude ciphertexts met v1 key, herencrypt met v2 key. Deze functie
// gebruikt altijd de HUIDIGE versie voor nieuwe writes.
//
// Threat model:
//   • Postgres-lek (SQL-injection, RLS-bypass) → aanvaller ziet ciphertext
//     maar niet de key. Zonder key = geen plaintext.
//   • Edge function env-lek → aanvaller heeft de key maar niet de DB.
//     Zonder ciphertext = geen plaintext.
//   • Beide tegelijk = plaintext lekt. Mitigatie: incidenteel key rotation
//     + monitoring op env-diffs.
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const ENCRYPTION_KEY_B64 = Deno.env.get("DAC7_ENCRYPTION_KEY") ?? "";
const ENCRYPTION_KEY_VERSION = parseInt(
  Deno.env.get("DAC7_ENCRYPTION_KEY_VERSION") ?? "1",
  10,
);

// admin client — gebruikt voor writes met RLS-bypass.
const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// ---------------------------------------------------------------------------
// TIN-validatie — 11-proef
// ---------------------------------------------------------------------------

/**
 * Normaliseer TIN-input: strip alle non-digits, pad 8→9 met leading zero.
 */
function normalizeTin(raw: string): string {
  const digits = (raw ?? "").replace(/\D/g, "");
  if (digits.length === 8) return "0" + digits;
  return digits;
}

/**
 * BSN/RSIN 11-proef. Weights [9,8,7,6,5,4,3,2,-1]. Zelfde algoritme voor
 * BSN als RSIN (historisch sofinummer).
 *
 * Retourneert true als input:
 *  - genormaliseerd 9 digits is,
 *  - niet geheel nullen is,
 *  - sum(digit × weight) mod 11 == 0.
 */
function isValidTin(normalized: string): boolean {
  if (normalized.length !== 9) return false;
  if (normalized === "000000000") return false;

  const weights = [9, 8, 7, 6, 5, 4, 3, 2, -1];
  let sum = 0;
  for (let i = 0; i < 9; i++) {
    sum += parseInt(normalized[i], 10) * weights[i];
  }
  return sum % 11 === 0;
}

// ---------------------------------------------------------------------------
// AES-256-GCM encryptie via Deno WebCrypto
// ---------------------------------------------------------------------------

/**
 * Laad de master key uit env. Base64 → 32 raw bytes → CryptoKey met
 * usage=encrypt. Idempotent te cachen zou kunnen, maar edge functions zijn
 * short-lived en de import is snel — laten we het simpel houden.
 */
async function loadEncryptionKey(): Promise<CryptoKey> {
  if (!ENCRYPTION_KEY_B64) {
    throw new Error("DAC7_ENCRYPTION_KEY env is niet gezet");
  }
  const rawKey = Uint8Array.from(atob(ENCRYPTION_KEY_B64), (c) =>
    c.charCodeAt(0),
  );
  if (rawKey.length !== 32) {
    throw new Error(
      `DAC7_ENCRYPTION_KEY moet 32 bytes zijn (256-bit), kreeg ${rawKey.length}`,
    );
  }
  return await crypto.subtle.importKey(
    "raw",
    rawKey,
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );
}

/**
 * Encrypt plaintext met AES-256-GCM. Gegenereerde 12-byte nonce wordt
 * apart teruggegeven (niet prepended in de ciphertext) zodat we in Postgres
 * ciphertext en nonce als aparte bytea kolommen kunnen opslaan — duidelijker
 * voor DB-inspectie én makkelijker key rotation.
 */
async function encryptTin(plaintext: string): Promise<{
  ciphertext: Uint8Array;
  nonce: Uint8Array;
}> {
  const key = await loadEncryptionKey();
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plaintext);
  const cipherBuf = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce },
    key,
    encoded,
  );
  return {
    ciphertext: new Uint8Array(cipherBuf),
    nonce,
  };
}

// ---------------------------------------------------------------------------
// Postgres bytea helper — Deno Uint8Array → \x-hex string
// ---------------------------------------------------------------------------
// supabase-js serialiseert Uint8Array niet naar Postgres bytea in insert()
// calls. We converteren naar het hex-notatie formaat `\xdeadbeef` dat
// Postgres accepteert bij een text→bytea implicit cast op INSERT.

function bytesToPgHex(bytes: Uint8Array): string {
  const hex: string[] = [];
  for (const b of bytes) {
    hex.push(b.toString(16).padStart(2, "0"));
  }
  return "\\x" + hex.join("");
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonError("method_not_allowed", 405);
  }

  // ---- 1. Auth: user JWT vereist -----------------------------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return jsonError("unauthorized", 401);
  }

  // User-context client — bepaalt auth.uid() via de JWT.
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return jsonError("unauthorized", 401);
  }

  const ownerId = user.id;

  // ---- 2. Body parsen -----------------------------------------------------
  let body: { tin?: string; tin_type?: string };
  try {
    body = await req.json();
  } catch (_) {
    return jsonError("invalid_json", 400);
  }

  const rawTin = (body.tin ?? "").trim();
  const tinType = (body.tin_type ?? "").trim().toLowerCase();

  if (!rawTin || !tinType) {
    return jsonError("missing_field", 400);
  }
  if (tinType !== "bsn" && tinType !== "rsin") {
    return jsonError("invalid_tin_type", 400);
  }

  const normalized = normalizeTin(rawTin);
  if (normalized.length !== 9) {
    return jsonError("invalid_format", 400);
  }
  if (!isValidTin(normalized)) {
    return jsonError("invalid_check_digit", 400);
  }

  // ---- 3. Business-type consistency-check --------------------------------
  // BV / stichting / VvE hoort een RSIN in te leveren. Particulier / eenmanszaak
  // hoort een BSN. Als het niet klopt, weigeren we — beter een duidelijke
  // fout dan een verkeerd TIN-type in de DAC7-XML.
  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("business_type")
    .eq("id", ownerId)
    .single();

  if (profileError || !profile) {
    console.error("[submit-tin] profile lookup failed:", profileError);
    return jsonError("profile_not_found", 404);
  }

  const btype = profile.business_type as string | null;
  const expectedType =
    btype === "bv" || btype === "overig" ? "rsin" : "bsn";
  if (tinType !== expectedType) {
    return jsonError("tin_type_mismatch", 400, {
      expected: expectedType,
      got: tinType,
      hint:
        expectedType === "rsin"
          ? "Rechtspersoon: gebruik RSIN (van je KvK-uittreksel)."
          : "Natuurlijk persoon: gebruik BSN.",
    });
  }

  // ---- 4. Encrypt ---------------------------------------------------------
  let ciphertext: Uint8Array;
  let nonce: Uint8Array;
  try {
    const enc = await encryptTin(normalized);
    ciphertext = enc.ciphertext;
    nonce = enc.nonce;
  } catch (err) {
    console.error("[submit-tin] encrypt failed:", err);
    return jsonError("encryption_failed", 500);
  }

  const last4 = normalized.slice(-4);
  const now = new Date().toISOString();

  // ---- 5. Persist via service_role ---------------------------------------
  // Upsert op profiles_tin_secure zodat re-submit (bijv. typo-correctie)
  // gewoon overschrijft. Idempotent.
  const upsertResult = await admin
    .from("profiles_tin_secure")
    .upsert(
      {
        owner_id: ownerId,
        ciphertext: bytesToPgHex(ciphertext),
        nonce: bytesToPgHex(nonce),
        key_version: ENCRYPTION_KEY_VERSION,
        updated_at: now,
      },
      { onConflict: "owner_id" },
    );

  if (upsertResult.error) {
    console.error("[submit-tin] upsert secure failed:", upsertResult.error);
    return jsonError("persist_secure_failed", 500);
  }

  // Update profiles metadata via service_role (bypass write-guard trigger).
  const profileUpdate = await admin
    .from("profiles")
    .update({
      tin_type: tinType,
      tin_last4: last4,
      tin_provided_at: now,
    })
    .eq("id", ownerId);

  if (profileUpdate.error) {
    console.error(
      "[submit-tin] profile metadata update failed:",
      profileUpdate.error,
    );
    // Best-effort rollback van secure-row — anders staat er ciphertext
    // zonder dat de app ooit weet dat 't gelukt is.
    await admin.from("profiles_tin_secure").delete().eq("owner_id", ownerId);
    return jsonError("persist_profile_failed", 500);
  }

  // ---- 6. Clear payouts_blocked_at op alle jaren -------------------------
  // Als de owner boven de drempel zat en payouts geblokkeerd waren, mag
  // 'ie nu weer uitbetaald worden. Clear alle payouts_blocked_at voor deze
  // owner (er kunnen theoretisch meerdere jaren zijn, bijv. bij late TIN-
  // levering over jaargrens heen).
  const unblockResult = await admin
    .from("dac7_reporting_state")
    .update({ payouts_blocked_at: null })
    .eq("owner_id", ownerId)
    .not("payouts_blocked_at", "is", null)
    .select("reporting_year");

  const payoutsUnblocked = (unblockResult.data?.length ?? 0) > 0;
  if (unblockResult.error) {
    // Niet fataal — TIN is opgeslagen. Loggen en doorgaan.
    console.error(
      "[submit-tin] unblock payouts failed (non-fatal):",
      unblockResult.error,
    );
  }

  // ---- 7. Response --------------------------------------------------------
  return json(
    {
      ok: true,
      tin_last4: last4,
      tin_type: tinType,
      payouts_unblocked: payoutsUnblocked,
      key_version: ENCRYPTION_KEY_VERSION,
    },
    200,
  );
});

// ---------------------------------------------------------------------------
// Response helpers
// ---------------------------------------------------------------------------

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(
  code: string,
  status: number,
  extra?: Record<string, unknown>,
): Response {
  return json({ error: code, ...(extra ?? {}) }, status);
}
