// Pluggo — send-push edge function
// ----------------------------------------------------------------------------
// Centrale push-verzender via Firebase Cloud Messaging (FCM HTTP v1 API).
// Wordt aangeroepen door:
//   • De Flutter app op events zoals nieuwe boeking, accept/reject,
//     payment-request, kWh-actie, chat-bericht, etc.
//   • Eventueel later vanuit een cron of trigger.
//
// Interface:
//   POST {
//     user_id: string,        // ontvanger (uuid)
//     title:   string,
//     body:    string,
//     data?:   Record<string, string>   // optionele payload (alle waarden moeten string zijn)
//   }
//   → 200 { sent: number, removed: number }
//   → 4xx/5xx { error: string }
//
// Auth: accepteert geldige user JWT óf service-role key. Beide werken zodat
// de Flutter app kan pingen én cron-functies hier ook naartoe kunnen.
//
// Mechanica:
//   1. Haal alle FCM-tokens van de target user op uit user_devices.
//   2. Voor elk token: roep FCM HTTP v1 send aan met OAuth2 access token
//      gegenereerd uit de service account JSON.
//   3. Bij UNREGISTERED of INVALID_ARGUMENT: verwijder dat token uit
//      user_devices (anders blijven we dood-tokens bombarderen).
//
// Secrets — handmatig zetten via:
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='<inhoud van firebase-service-account.json>'
// Auto-injected door Supabase:
//   • SUPABASE_URL
//   • SUPABASE_SERVICE_ROLE_KEY
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// ---------------------------------------------------------------------------
// CORS
// ---------------------------------------------------------------------------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ---------------------------------------------------------------------------
// Service account & OAuth2 access token
//
// Google's FCM HTTP v1 vereist een OAuth2 access token. We genereren die
// zelf met een JWT die we ondertekenen met de service account private key.
// Tokens zijn 1 uur geldig — we cachen 'm in module scope.
// ---------------------------------------------------------------------------

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

function getServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON secret ontbreekt");
  }
  const sa = JSON.parse(raw) as ServiceAccount;
  if (!sa.project_id || !sa.client_email || !sa.private_key) {
    throw new Error("Service account JSON mist project_id/client_email/private_key");
  }
  return sa;
}

// Importeer een PEM-encoded RSA private key voor RSA-SHA256 signing.
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // Pem komt soms met \n als escape — Postgres/JSON kan dat doen.
  const cleaned = pem
    .replace(/\\n/g, "\n")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64UrlEncode(buf: ArrayBuffer | Uint8Array | string): string {
  let bytes: Uint8Array;
  if (typeof buf === "string") {
    bytes = new TextEncoder().encode(buf);
  } else if (buf instanceof ArrayBuffer) {
    bytes = new Uint8Array(buf);
  } else {
    bytes = buf;
  }
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/=+$/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token;
  }

  const sa = getServiceAccount();
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };
  const headerB64 = base64UrlEncode(JSON.stringify(header));
  const claimB64 = base64UrlEncode(JSON.stringify(claim));
  const unsigned = `${headerB64}.${claimB64}`;

  const key = await importPrivateKey(sa.private_key);
  const sig = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64UrlEncode(sig)}`;

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`OAuth2 token exchange faalde: ${resp.status} ${txt}`);
  }
  const json = await resp.json();
  cachedAccessToken = {
    token: json.access_token,
    expiresAt: now + (json.expires_in ?? 3600),
  };
  return cachedAccessToken.token;
}

// ---------------------------------------------------------------------------
// FCM send naar één token
// Returnt { ok: true } of { ok: false, removeToken: boolean, error: string }
// ---------------------------------------------------------------------------

interface SendResult {
  ok: boolean;
  removeToken: boolean;
  error?: string;
}

async function sendToToken(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<SendResult> {
  const message: Record<string, unknown> = {
    token: fcmToken,
    notification: { title, body },
  };
  if (data && Object.keys(data).length > 0) {
    // FCM data values MOETEN strings zijn — converteren defensief.
    const stringData: Record<string, string> = {};
    for (const [k, v] of Object.entries(data)) {
      stringData[k] = String(v);
    }
    message.data = stringData;
  }
  // iOS-specifiek: zet category/sound voor nette presentatie.
  message.apns = {
    payload: {
      aps: {
        sound: "default",
        "mutable-content": 1,
      },
    },
  };

  const url =
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });

  if (resp.ok) return { ok: true, removeToken: false };

  const txt = await resp.text();
  // Dood-token detectie: FCM v1 geeft 404 of 400 met UNREGISTERED /
  // INVALID_ARGUMENT terug als token niet meer geldig is.
  const isDead =
    resp.status === 404 ||
    /UNREGISTERED|NOT_FOUND|INVALID_ARGUMENT/i.test(txt);
  return {
    ok: false,
    removeToken: isDead,
    error: `${resp.status} ${txt.slice(0, 200)}`,
  };
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST required" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const { user_id, title, body, data } = await req.json();
    if (!user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: "user_id, title, body verplicht" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Service-role client voor RLS-bypass — we lezen alle devices van een user
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: rows, error: selErr } = await supabase
      .from("user_devices")
      .select("id, fcm_token")
      .eq("user_id", user_id);

    if (selErr) {
      return new Response(JSON.stringify({ error: selErr.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!rows || rows.length === 0) {
      // Geen devices — geen fout, gewoon niets te doen
      return new Response(
        JSON.stringify({ sent: 0, removed: 0, note: "no devices" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const sa = getServiceAccount();
    const accessToken = await getAccessToken();

    let sent = 0;
    const deadIds: string[] = [];

    // Sequentieel — de meeste users hebben 1-2 devices, dus paralleliseren
    // voegt complexiteit toe zonder veel winst.
    for (const row of rows) {
      const result = await sendToToken(
        accessToken,
        sa.project_id,
        row.fcm_token,
        title,
        body,
        data,
      );
      if (result.ok) {
        sent++;
      } else if (result.removeToken) {
        deadIds.push(row.id);
      }
      // Andere fouten: laten zitten, kunnen tijdelijk zijn (rate limit etc).
    }

    if (deadIds.length > 0) {
      await supabase.from("user_devices").delete().in("id", deadIds);
    }

    return new Response(
      JSON.stringify({ sent, removed: deadIds.length }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("[send-push]", msg);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
