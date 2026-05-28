// Pluggo — send-payment-reminders edge function
// ----------------------------------------------------------------------------
// Wordt elk uur (of dagelijks) aangeroepen door pg_cron. Stuurt een
// herinnering naar elke boeker met een openstaand betaalverzoek dat
// ouder is dan 24 uur en waarvan de vorige reminder ook >24 uur geleden is.
//
// Mag ook handmatig getriggerd worden voor testen:
//   curl -X POST https://<ref>.supabase.co/functions/v1/send-payment-reminders \
//        -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
//
// Secrets die deze functie verwacht — auto-injected door Supabase:
//   • SUPABASE_URL
//   • SUPABASE_SERVICE_ROLE_KEY
//
// JWT-verify mag UIT staan voor deze functie (cron-aanroep heeft geen user JWT).
// Wel veiligheid: de Authorization header moet de service-role key zijn.
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Betaalverzoek moet minstens N uur openstaan voordat we de eerste reminder
// sturen. Daarna een nieuwe reminder per N uur. 24h is een redelijk ritme.
const REMINDER_INTERVAL_HOURS = 24;

// Maximum aantal reminder-mails dat we per cron-run versturen, om te voorkomen
// dat een kapotte mailprovider duizenden retries veroorzaakt.
const MAX_REMINDERS_PER_RUN = 100;

const APP_NAME = "Pluggo";
const SUPPORT_EMAIL = "support@pluggoapp.nl";

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

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const cronSecret = Deno.env.get("CRON_SECRET");

    if (!supabaseUrl || !serviceKey) {
      return jsonError("Server niet juist geconfigureerd", 500);
    }

    // Veiligheid: accepteer oproepen met OFWEL de auto-injected service-role
    // key, OFWEL een handmatig gezette CRON_SECRET (voor projecten met het
    // nieuwe API-key systeem waar SUPABASE_SERVICE_ROLE_KEY een ander
    // formaat heeft dan de cron-aanroep).
    const auth = req.headers.get("Authorization") ?? "";
    const acceptable = [
      `Bearer ${serviceKey}`,
      cronSecret ? `Bearer ${cronSecret}` : null,
    ].filter(Boolean) as string[];

    if (!acceptable.includes(auth)) {
      return jsonError("Niet geautoriseerd", 401);
    }

    const admin = createClient(supabaseUrl, serviceKey);

    const cutoff = new Date(
      Date.now() - REMINDER_INTERVAL_HOURS * 60 * 60 * 1000
    ).toISOString();

    // Selecteer kandidaten: openstaand betaalverzoek + ouder dan cutoff +
    // (geen vorige reminder OF vorige reminder ook ouder dan cutoff).
    const { data: rows, error } = await admin
      .from("bookings")
      .select(
        "id, user_email, user_name, payment_requested_at, last_reminder_sent_at, total_amount_cents, kwh_consumed, charger_id, chargers(name, address)"
      )
      .not("payment_requested_at", "is", null)
      .not("payment_status", "in", "(paid,refunded)")
      .lt("payment_requested_at", cutoff)
      .or(`last_reminder_sent_at.is.null,last_reminder_sent_at.lt.${cutoff}`)
      .limit(MAX_REMINDERS_PER_RUN);

    if (error) {
      console.error("query error:", error);
      return jsonError("DB query gefaald", 500);
    }

    const candidates = (rows ?? []) as any[];
    let sent = 0;
    let failed = 0;

    for (const b of candidates) {
      const email = b.user_email as string | null;
      if (!email) {
        // geen e-mail bekend, skippen maar wel markeren zodat we niet
        // elke run opnieuw proberen
        await admin
          .from("bookings")
          .update({ last_reminder_sent_at: new Date().toISOString() })
          .eq("id", b.id);
        continue;
      }

      const charger = b.chargers ?? {};
      const chargerName = (charger.name as string | null) ?? "een laadpaal";
      const chargerAddress = (charger.address as string | null) ?? "";
      const kwh = b.kwh_consumed as number | null;
      const totalCents = b.total_amount_cents as number | null;
      const totalEuro =
        totalCents != null ? (totalCents / 100).toFixed(2).replace(".", ",") : null;

      const requestedAt = new Date(b.payment_requested_at);
      const daysOpen = Math.floor(
        (Date.now() - requestedAt.getTime()) / (1000 * 60 * 60 * 24)
      );

      const subject = `Herinnering: openstaande betaling voor ${chargerName}`;
      const html = buildReminderHtml({
        bookerName: (b.user_name as string | null) ?? "",
        chargerName,
        chargerAddress,
        kwh,
        totalEuro,
        daysOpen,
      });

      try {
        // Hergebruik de bestaande send-email edge function (Resend) zodat
        // we niet hier opnieuw Resend hoeven te configureren.
        const r = await fetch(`${supabaseUrl}/functions/v1/send-email`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${serviceKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ to: email, subject, html }),
        });

        if (!r.ok) {
          const txt = await r.text();
          console.error("send-email failed:", r.status, txt);
          failed++;
          continue;
        }

        await admin
          .from("bookings")
          .update({ last_reminder_sent_at: new Date().toISOString() })
          .eq("id", b.id);
        sent++;
      } catch (err) {
        console.error("reminder send error:", err);
        failed++;
      }
    }

    return new Response(
      JSON.stringify({
        candidates: candidates.length,
        sent,
        failed,
        cutoff,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    console.error("send-payment-reminders fatal:", err);
    return jsonError("Onbekende serverfout", 500);
  }
});

function buildReminderHtml(args: {
  bookerName: string;
  chargerName: string;
  chargerAddress: string;
  kwh: number | null;
  totalEuro: string | null;
  daysOpen: number;
}) {
  const naam = args.bookerName?.trim() ? args.bookerName : "hallo";
  const kwhLine =
    args.kwh != null && args.totalEuro != null
      ? `<p style="margin:0 0 12px 0;">Het gaat om <strong>${args.kwh} kWh</strong> ter waarde van <strong>€ ${args.totalEuro}</strong>.</p>`
      : "";

  return `<!DOCTYPE html>
<html><body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color:#1e1e1e; max-width:560px; margin:0 auto; padding:24px;">
  <h2 style="margin:0 0 16px 0;">Herinnering: openstaande betaling</h2>
  <p style="margin:0 0 12px 0;">Hi ${escapeHtml(naam)},</p>
  <p style="margin:0 0 12px 0;">
    Je betaalverzoek voor <strong>${escapeHtml(args.chargerName)}</strong>${
    args.chargerAddress ? ` (${escapeHtml(args.chargerAddress)})` : ""
  } staat al ${args.daysOpen} dag${args.daysOpen === 1 ? "" : "en"} open.
  </p>
  ${kwhLine}
  <p style="margin:0 0 12px 0;">
    Open de ${APP_NAME} app en ga naar <em>Mijn boekingen</em> om de betaling
    af te ronden. Na 7 dagen kun je tijdelijk geen nieuwe boekingen maken.
  </p>
  <p style="margin:24px 0 0 0; color:#666; font-size:13px;">
    Vragen? Mail <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>.
  </p>
</body></html>`;
}

function escapeHtml(s: string) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}
