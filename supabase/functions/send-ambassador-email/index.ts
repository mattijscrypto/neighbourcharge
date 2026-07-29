// Pluggo — send-ambassador-email edge function
// ----------------------------------------------------------------------------
// Verstuurt een ambassadeurs-mail 48 uur na email-bevestiging.
//
// Wordt aangeroepen door een pg_cron job (migratie 0043) die elk uur draait.
// De job zoekt alle gebruikers waarvan email_confirmed_at tussen 48 en 72 uur
// geleden valt én waarbij ambassador_email_sent_at nog NULL is in profiles.
//
// Interface:
//   POST {}  (geen body nodig — de functie pikt zelf kandidaten op)
//   → 200 { sent: number }
//
// Auth: alleen service-role.
// Secrets:
//   • RESEND_API_KEY
// Auto:
//   • SUPABASE_URL
//   • SUPABASE_SERVICE_ROLE_KEY
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const DEFAULT_FROM   = "Ra'ka van Pluggo <info@pluggoapp.nl>";
const DEFAULT_REPLY_TO = "info@pluggoapp.nl";
const RESEND_API_URL = "https://api.resend.com/emails";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonError("Methode niet toegestaan", 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const resendKey   = Deno.env.get("RESEND_API_KEY");

    if (!supabaseUrl || !serviceKey) return jsonError("Server niet juist geconfigureerd (Supabase env)", 500);
    if (!resendKey)                  return jsonError("Server niet juist geconfigureerd (RESEND_API_KEY)", 500);

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ") || authHeader.slice(7).trim() !== serviceKey) {
      return jsonError("Alleen service-role mag ambassador-mails triggeren", 403);
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // -----------------------------------------------------------------------
    // Kandidaten ophalen: bevestigd 48–72 uur geleden, nog geen ambassador-mail
    // -----------------------------------------------------------------------
    const { data: candidates, error } = await supabase
      .from("profiles")
      .select("id, full_name, ambassador_email_sent_at")
      .is("ambassador_email_sent_at", null)
      .lt("created_at", new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString())
      .gt("created_at", new Date(Date.now() - 72 * 60 * 60 * 1000).toISOString());

    if (error) {
      console.error("Kandidaten ophalen mislukt:", error);
      return jsonError("Database-fout bij ophalen kandidaten", 500);
    }
    if (!candidates || candidates.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Haal e-mailadressen op via auth.users (service-role)
    let sent = 0;
    for (const profile of candidates) {
      const { data: userData } = await supabase.auth.admin.getUserById(profile.id);
      const email = userData?.user?.email;
      if (!email) continue;

      const fullName  = (profile.full_name ?? "").trim();
      const firstName = fullName.length > 0 ? fullName.split(/\s+/)[0] : "";
      const salutation = firstName ? `Hoi ${escapeHtml(firstName)},` : "Hoi,";

      const r = await fetch(RESEND_API_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from:     DEFAULT_FROM,
          to:       [email],
          subject:  "Help Pluggo groeien in jouw buurt",
          html:     ambassadorHtml(salutation),
          reply_to: DEFAULT_REPLY_TO,
        }),
      });

      if (r.ok) {
        // Markeer als verzonden
        await supabase
          .from("profiles")
          .update({ ambassador_email_sent_at: new Date().toISOString() })
          .eq("id", profile.id);
        sent++;
        console.log("Ambassador-mail verzonden", { to: email, user_id: profile.id });
      } else {
        const body = await r.text();
        console.error("Resend ambassador error", { status: r.status, body, to: email });
      }
    }

    return new Response(JSON.stringify({ sent }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error("send-ambassador-email fatal:", err);
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

function ambassadorHtml(salutation: string): string {
  return `<!DOCTYPE html>
<html lang="nl">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Help Pluggo groeien</title>
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
            <td style="padding:28px 32px 8px 32px;">
              <p style="margin:0 0 16px 0;font-size:16px;line-height:24px;color:#374151;">${salutation}</p>
              <p style="margin:0 0 16px 0;font-size:16px;line-height:24px;color:#374151;">
                Je hebt nu een kijkje kunnen nemen in de app. Fijn als je erbij bent.
              </p>
              <p style="margin:0 0 16px 0;font-size:16px;line-height:24px;color:#374151;">
                Pluggo groeit door mensen zoals jij — iedereen die een paal kent, een buurman tipt of een berichtje deelt helpt het netwerk uitbreiden. Daarvoor hebben we een ambassadeurspagina gemaakt. Je vindt er kant-en-klare berichtjes, een flyer die je kunt aanvragen en een paar tips.
              </p>
              <p style="margin:0 0 4px 0;font-size:16px;line-height:24px;color:#374151;">
                Geen verplichting — maar elke paal die erbij komt maakt het voor iedereen beter.
              </p>
            </td>
          </tr>

          <!-- CTA -->
          <tr>
            <td align="center" style="padding:24px 32px 24px 32px;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center" bgcolor="#00A87E" style="border-radius:10px;">
                    <a href="https://pluggoapp.nl/ambassadeur" target="_blank" style="display:inline-block;padding:14px 28px;font-size:16px;font-weight:600;color:#FFFFFF;text-decoration:none;border-radius:10px;">Bekijk de ambassadeurspagina</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <tr>
            <td style="padding:0 32px 0 32px;">
              <div style="border-top:1px solid #E5E7EB;"></div>
            </td>
          </tr>

          <tr>
            <td style="padding:20px 32px 32px 32px;">
              <p style="margin:0;font-size:13px;line-height:20px;color:#6B7280;">
                Fijne dag,<br />
                <strong>Ra'ka</strong> — team Pluggo<br /><br />
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
