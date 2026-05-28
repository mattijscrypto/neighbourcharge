// Pluggo — send-email edge function
// ----------------------------------------------------------------------------
// Centrale email-verzender. Wordt aangeroepen door:
//   • De Flutter app (8 plekken: nieuwe boeking, kWh-betaalverzoek,
//     accept/reject, cancel, problem report, chat-notificatie, etc.)
//   • De `send-payment-reminders` cron edge function (24-uurs herinneringen)
//   • Een Postgres trigger zou hier ook naartoe kunnen migreren — voor nu
//     blijft `notify_owner_new_booking()` direct Resend aanroepen, maar als
//     deze functie stabiel draait kan die trigger gedropt worden.
//
// Interface:
//   POST { to: string | string[], subject: string, html: string,
//          from?: string, replyTo?: string }
//   → 200 { id: string, to: string[] }   (Resend message id)
//   → 4xx/5xx { error: string }
//
// Auth: accepteert ÓF een geldige user JWT (Supabase ANON_KEY check) ÓF de
// service-role key (voor cron + backend calls). Beide werken — zo kan een
// ingelogde booker mailen via de app, en kan de cron 's nachts mailen.
//
// Secrets — handmatig gezet via `supabase secrets set RESEND_API_KEY=re_...`:
//   • RESEND_API_KEY        — Resend API key (begint met re_)
// Auto-injected door Supabase:
//   • SUPABASE_URL
//   • SUPABASE_ANON_KEY
//   • SUPABASE_SERVICE_ROLE_KEY
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

// Default afzender. Overschrijfbaar per call via `from` param.
// Domein moet verified zijn in Resend dashboard, anders weigert Resend.
//
// We gebruiken info@ als enige adres (zowel from als reply-to) zodat
// alles via die ene gratis-doorgestuurde mailbox loopt naar rakawakka@.
// Eventuele upgrades later: noreply@ voor pure transactional, support@
// voor reply-to. Voor nu = simpel.
const DEFAULT_FROM = "Pluggo <info@pluggoapp.nl>";
const DEFAULT_REPLY_TO = "info@pluggoapp.nl";

// Resend API endpoint
const RESEND_API_URL = "https://api.resend.com/emails";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface SendEmailRequest {
  to: string | string[];
  subject: string;
  html: string;
  from?: string;
  replyTo?: string;
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonError("Methode niet toegestaan", 405);
  }

  try {
    // -----------------------------------------------------------------------
    // 1. Auth — accepteert JWT óf service-role key
    // -----------------------------------------------------------------------
    const authHeader = req.headers.get("Authorization") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const resendKey = Deno.env.get("RESEND_API_KEY");

    if (!resendKey) {
      console.error("RESEND_API_KEY niet gezet");
      return jsonError("Server niet juist geconfigureerd (RESEND_API_KEY)", 500);
    }

    if (!authHeader.startsWith("Bearer ")) {
      return jsonError("Niet geautoriseerd (geen token)", 401);
    }

    const token = authHeader.slice("Bearer ".length).trim();

    // Service-role mag altijd. JWT moet door Supabase verified zijn — dat
    // gebeurt automatisch door de gateway als JWT-verify aanstaat in de
    // function settings (default: aan). Dus als we hier komen met een
    // geldige `Authorization: Bearer <jwt>` is 'ie al gevalideerd.
    // Extra check: weiger als token leeg of duidelijk een rare string is.
    if (!token || token.length < 20) {
      return jsonError("Niet geautoriseerd (token ongeldig)", 401);
    }

    // -----------------------------------------------------------------------
    // 2. Body parsen + valideren
    // -----------------------------------------------------------------------
    let body: SendEmailRequest;
    try {
      body = (await req.json()) as SendEmailRequest;
    } catch {
      return jsonError("Body moet geldige JSON zijn", 400);
    }

    const toRaw = body.to;
    const subject = (body.subject ?? "").trim();
    const html = body.html ?? "";
    const from = (body.from ?? DEFAULT_FROM).trim();
    const replyTo = (body.replyTo ?? DEFAULT_REPLY_TO).trim();

    if (!toRaw || (Array.isArray(toRaw) && toRaw.length === 0)) {
      return jsonError("'to' is verplicht (string of array)", 400);
    }
    if (!subject) {
      return jsonError("'subject' is verplicht", 400);
    }
    if (!html.trim()) {
      return jsonError("'html' is verplicht en mag niet leeg zijn", 400);
    }

    // Normaliseer naar array. Resend accepteert max 50 ontvangers per call.
    const toList: string[] = (Array.isArray(toRaw) ? toRaw : [toRaw])
      .map((s) => String(s).trim())
      .filter((s) => s.length > 0);

    if (toList.length === 0) {
      return jsonError("'to' bevat geen geldig adres", 400);
    }
    if (toList.length > 50) {
      return jsonError("Max 50 ontvangers per email", 400);
    }

    // Hele globbsale email-validatie. Resend valideert zelf ook nog, maar
    // we filteren in elk geval evidente onzin eruit zodat we minder 4xx's
    // van Resend krijgen.
    const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const invalid = toList.filter((e) => !emailRe.test(e));
    if (invalid.length > 0) {
      return jsonError(`Ongeldig email-adres: ${invalid.join(", ")}`, 400);
    }

    // -----------------------------------------------------------------------
    // 3. POST naar Resend
    // -----------------------------------------------------------------------
    const resendBody = {
      from,
      to: toList,
      subject,
      html,
      reply_to: replyTo,
    };

    const r = await fetch(RESEND_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(resendBody),
    });

    const responseText = await r.text();

    if (!r.ok) {
      // Resend geeft handige errors terug — log ze voor debugging in
      // Supabase Logs, en geef een nette 502 terug aan de caller.
      console.error("Resend API error", {
        status: r.status,
        body: responseText,
        to: toList,
        subject,
      });
      return jsonError(
        `Email-provider weigerde de verzending (${r.status}): ${responseText}`,
        502
      );
    }

    let resendJson: { id?: string } = {};
    try {
      resendJson = JSON.parse(responseText);
    } catch {
      // Resend gaf 200 maar geen JSON — ongebruikelijk maar niet fataal
    }

    console.log("Email verzonden", {
      id: resendJson.id,
      to: toList,
      subject,
    });

    return new Response(
      JSON.stringify({
        id: resendJson.id ?? null,
        to: toList,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    console.error("send-email fatal:", err);
    return jsonError("Onbekende serverfout", 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}
