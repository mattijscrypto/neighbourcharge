// Pluggo — send-welcome-email edge function
// ----------------------------------------------------------------------------
// Verstuurt een Pluggo-gebrande welkomstmail naar een nieuwe gebruiker.
//
// Wordt aangeroepen door de Postgres-trigger `send_welcome_email_on_confirm`
// (zie migratie 0020_welcome_email_trigger.sql) zodra `email_confirmed_at`
// van NULL naar een timestamp gaat op auth.users.
//
// Interface:
//   POST { user_id: string, email: string }
//   → 200 { sent: true, id: string }
//   → 4xx/5xx { error: string }
//
// Auth: alleen service-role. De trigger stuurt het service-role JWT mee in
// Authorization header. verify_jwt=true is fine — Supabase gateway checkt de
// JWT, wij checken daarna nog service_role-rechten via getUser().
//
// Secrets:
//   • RESEND_API_KEY  (handmatig gezet)
// Auto:
//   • SUPABASE_URL
//   • SUPABASE_SERVICE_ROLE_KEY
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const DEFAULT_FROM = "Pluggo <info@pluggoapp.nl>";
const DEFAULT_REPLY_TO = "info@pluggoapp.nl";
const RESEND_API_URL = "https://api.resend.com/emails";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface WelcomeRequest {
  user_id: string;
  email: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonError("Methode niet toegestaan", 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const resendKey = Deno.env.get("RESEND_API_KEY");

    if (!supabaseUrl || !serviceKey) {
      return jsonError("Server niet juist geconfigureerd (Supabase env)", 500);
    }
    if (!resendKey) {
      return jsonError("Server niet juist geconfigureerd (RESEND_API_KEY)", 500);
    }

    // -----------------------------------------------------------------------
    // Auth-check — accepteer alleen service-role.
    // Supabase gateway heeft de JWT al gevalideerd (verify_jwt=true), maar
    // we willen zeker weten dat 't de service-role is en niet een gewone user.
    // -----------------------------------------------------------------------
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return jsonError("Niet geautoriseerd", 401);
    }
    const token = authHeader.slice("Bearer ".length).trim();
    if (token !== serviceKey) {
      return jsonError("Alleen service-role mag welkomstmails triggeren", 403);
    }

    // -----------------------------------------------------------------------
    // Body parsen
    // -----------------------------------------------------------------------
    let body: WelcomeRequest;
    try {
      body = (await req.json()) as WelcomeRequest;
    } catch {
      return jsonError("Body moet geldige JSON zijn", 400);
    }
    const userId = (body.user_id ?? "").trim();
    const email = (body.email ?? "").trim();
    if (!userId || !email) {
      return jsonError("'user_id' en 'email' zijn verplicht", 400);
    }

    // -----------------------------------------------------------------------
    // Voornaam ophalen uit profiles.full_name (optioneel — kan NULL zijn vlak
    // na signup). We halen 'em op via de service-role client zodat RLS niet
    // in de weg zit.
    // -----------------------------------------------------------------------
    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    let firstName = "";
    try {
      const { data } = await supabase
        .from("profiles")
        .select("full_name")
        .eq("id", userId)
        .maybeSingle();
      const fullName = (data?.full_name ?? "").trim();
      if (fullName.length > 0) {
        firstName = fullName.split(/\s+/)[0];
      }
    } catch (err) {
      console.warn("profiles lookup faalde, val terug op naamloos:", err);
    }

    // -----------------------------------------------------------------------
    // HTML samenstellen
    // -----------------------------------------------------------------------
    const salutation = firstName ? `Hoi ${escapeHtml(firstName)},` : "Hoi,";
    const subject = "Welkom bij Pluggo — leuk dat je meedoet";
    const html = welcomeHtml(salutation);

    // -----------------------------------------------------------------------
    // POST naar Resend
    // -----------------------------------------------------------------------
    const r = await fetch(RESEND_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: DEFAULT_FROM,
        to: [email],
        subject,
        html,
        reply_to: DEFAULT_REPLY_TO,
      }),
    });

    const responseText = await r.text();
    if (!r.ok) {
      console.error("Resend welcome error", {
        status: r.status,
        body: responseText,
        to: email,
      });
      return jsonError(
        `Email-provider weigerde welkomstmail (${r.status}): ${responseText}`,
        502
      );
    }

    let resendJson: { id?: string } = {};
    try {
      resendJson = JSON.parse(responseText);
    } catch {
      // no-op
    }

    console.log("Welkomstmail verzonden", {
      id: resendJson.id,
      to: email,
      user_id: userId,
    });

    return new Response(
      JSON.stringify({ sent: true, id: resendJson.id ?? null }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    console.error("send-welcome-email fatal:", err);
    return jsonError("Onbekende serverfout", 500);
  }
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function welcomeHtml(salutation: string): string {
  return `<!DOCTYPE html>
<html lang="nl">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Welkom bij Pluggo</title>
</head>
<body style="margin:0;padding:0;background-color:#F5F7F5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1F2937;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F5F7F5;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;background-color:#FFFFFF;border-radius:16px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.04);">

          <tr>
            <td align="center" style="padding:36px 24px 8px 24px;">
              <div style="display:inline-block;width:56px;height:56px;background-color:#00A87E;border-radius:14px;line-height:56px;font-size:28px;font-weight:700;color:#FFFFFF;letter-spacing:-0.5px;">P</div>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:4px 24px 0 24px;">
              <div style="font-size:14px;font-weight:600;color:#00A87E;letter-spacing:1px;text-transform:uppercase;">Pluggo</div>
            </td>
          </tr>

          <tr>
            <td align="center" style="padding:24px 32px 8px 32px;">
              <h1 style="margin:0;font-size:26px;line-height:34px;font-weight:700;color:#111827;">Welkom bij Pluggo 👋</h1>
            </td>
          </tr>

          <tr>
            <td style="padding:16px 32px 8px 32px;">
              <p style="margin:0 0 16px 0;font-size:16px;line-height:24px;color:#374151;">${salutation}</p>
              <p style="margin:0 0 16px 0;font-size:16px;line-height:24px;color:#374151;">
                Fijn dat je erbij bent. Je account is aangemaakt en klaar voor gebruik. Pluggo is een buurt-laadnetwerk: paaleigenaren delen hun privépaal met de omgeving, rijders vinden goedkoop laden om de hoek.
              </p>
              <p style="margin:0 0 16px 0;font-size:16px;line-height:24px;color:#374151;">
                Wat je nu kunt doen:
              </p>
            </td>
          </tr>

          <!-- Twee kaartjes: paaleigenaar / rijder -->
          <tr>
            <td style="padding:0 32px 8px 32px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="padding:16px;background-color:#F0FAF6;border-radius:12px;border:1px solid #D5EEE3;">
                    <p style="margin:0 0 6px 0;font-size:15px;font-weight:600;color:#065F46;">🔌 Heb je zelf een laadpaal?</p>
                    <p style="margin:0;font-size:14px;line-height:22px;color:#374151;">
                      Voeg de paal toe in de app en stel je prijs per kWh in. Rijders kunnen nu direct bij je boeken — als pionier krijg je postcode-voorrang in de zoekresultaten.
                    </p>
                  </td>
                </tr>
                <tr><td style="height:12px;font-size:0;line-height:0;">&nbsp;</td></tr>
                <tr>
                  <td style="padding:16px;background-color:#F0FAF6;border-radius:12px;border:1px solid #D5EEE3;">
                    <p style="margin:0 0 6px 0;font-size:15px;font-weight:600;color:#065F46;">🚗 Rij je elektrisch?</p>
                    <p style="margin:0;font-size:14px;line-height:22px;color:#374151;">
                      Kijk rond op de kaart en zie welke buurtpalen er in je omgeving staan. Boeken kan nu direct — je laadt goedkoper dan bij de publieke paal.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- CTA -->
          <tr>
            <td align="center" style="padding:24px 32px 8px 32px;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center" bgcolor="#00A87E" style="border-radius:10px;">
                    <a href="https://pluggoapp.nl" target="_blank" style="display:inline-block;padding:14px 28px;font-size:16px;font-weight:600;color:#FFFFFF;text-decoration:none;border-radius:10px;">Open Pluggo</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <tr>
            <td style="padding:16px 32px 8px 32px;">
              <p style="margin:0;font-size:14px;line-height:22px;color:#6B7280;text-align:center;">
                Vragen, feedback of loop je ergens tegenaan? We lezen elke mail zelf.
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding:24px 32px 0 32px;">
              <div style="border-top:1px solid #E5E7EB;"></div>
            </td>
          </tr>

          <tr>
            <td style="padding:20px 32px 32px 32px;">
              <p style="margin:0 0 8px 0;font-size:13px;line-height:20px;color:#6B7280;">
                Fijne dag,<br />
                <strong>Ra'ka &amp; Mattijs</strong> — team Pluggo
              </p>
              <p style="margin:0;font-size:13px;line-height:20px;color:#6B7280;">
                Reageren kan direct op deze mail of via <a href="mailto:info@pluggoapp.nl" style="color:#00A87E;text-decoration:none;">info@pluggoapp.nl</a>.
              </p>
            </td>
          </tr>

        </table>

        <table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;">
          <tr>
            <td align="center" style="padding:20px 16px 0 16px;">
              <p style="margin:0;font-size:12px;line-height:18px;color:#9CA3AF;">
                Pluggo — het peer-to-peer laadnetwerk van Nederland<br />
                <a href="https://pluggoapp.nl" style="color:#9CA3AF;text-decoration:underline;">pluggoapp.nl</a>
              </p>
            </td>
          </tr>
        </table>

      </td>
    </tr>
  </table>
</body>
</html>`;
}
