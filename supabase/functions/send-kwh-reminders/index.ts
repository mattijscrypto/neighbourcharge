// Pluggo — send-kwh-reminders edge function                               (#12)
// ----------------------------------------------------------------------------
// Wordt elke 15 minuten aangeroepen door pg_cron. Stuurt een push-notificatie
// naar de paal-eigenaar voor elke voltooide boeking waarbij:
//   • de boeking >2 uur geleden is afgelopen (end_time < now() - 2h)
//   • status = 'confirmed'
//   • kWh is nog NIET ingevoerd (kwh_consumed IS NULL)
//   • eigenaar heeft NIET "geen lading" aangeklikt (no_charge = false)
//   • payment_requested_at IS NULL (betaalverzoek nog niet verstuurd)
//   • we hebben nog geen reminder gestuurd (kwh_reminder_sent_at IS NULL)
//
// Na het versturen: kwh_reminder_sent_at = now() zetten zodat we de
// eigenaar niet elke 15 minuten blijven pushen.
//
// Handmatig testen:
//   curl -X POST https://<ref>.supabase.co/functions/v1/send-kwh-reminders \
//        -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
//
// Auto-injected secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// JWT-verify: UIT (cron-aanroep heeft geen user JWT)
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const DELAY_HOURS = 2; // reminder pas nadat de boeking >2u voorbij is
const MAX_PER_RUN = 100;

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

    // Accepteer service-role key óf CRON_SECRET in Authorization header.
    const auth = req.headers.get("Authorization") ?? "";
    const acceptable = [
      `Bearer ${serviceKey}`,
      cronSecret ? `Bearer ${cronSecret}` : null,
    ].filter(Boolean) as string[];

    if (!acceptable.includes(auth)) {
      return jsonError("Niet geautoriseerd", 401);
    }

    const admin = createClient(supabaseUrl, serviceKey);

    // Cutoff: boekingen die meer dan DELAY_HOURS geleden zijn afgelopen.
    const cutoff = new Date(
      Date.now() - DELAY_HOURS * 60 * 60 * 1000
    ).toISOString();

    // Haal kandidaat-boekingen op: joined met chargers voor owner_id + naam.
    const { data: rows, error } = await admin
      .from("bookings")
      .select("id, end_time, charger_id, chargers(id, name, owner_id)")
      .eq("status", "confirmed")
      .is("payment_requested_at", null)
      .is("kwh_consumed", null)
      .eq("no_charge", false)
      .is("kwh_reminder_sent_at", null)
      .lt("end_time", cutoff)
      .limit(MAX_PER_RUN);

    if (error) {
      console.error("[send-kwh-reminders] query error:", error);
      return jsonError("DB query gefaald", 500);
    }

    const candidates = (rows ?? []) as any[];
    let sent = 0;
    let failed = 0;

    for (const b of candidates) {
      const charger = b.chargers as {
        id: string;
        name: string;
        owner_id: string;
      } | null;

      if (!charger?.owner_id) {
        // Geen eigenaar gevonden — zet reminder toch op zodat we niet
        // elke run opnieuw proberen.
        await admin
          .from("bookings")
          .update({ kwh_reminder_sent_at: new Date().toISOString() })
          .eq("id", b.id);
        continue;
      }

      const chargerName = charger.name ?? "jouw laadpaal";

      try {
        const r = await fetch(`${supabaseUrl}/functions/v1/send-push`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${serviceKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            user_id: charger.owner_id,
            title: "kWh invullen",
            body: `De laadsessie op ${chargerName} is afgelopen — vul de verbruikte kWh in zodat de boeker kan betalen.`,
            data: {
              type: "kwh_reminder",
              booking_id: String(b.id),
              charger_id: String(charger.id),
            },
          }),
        });

        if (!r.ok) {
          const txt = await r.text();
          console.error("[send-kwh-reminders] send-push failed:", r.status, txt);
          failed++;
          continue;
        }

        // Markeer als verzonden — one-shot, we sturen maar één reminder.
        await admin
          .from("bookings")
          .update({ kwh_reminder_sent_at: new Date().toISOString() })
          .eq("id", b.id);
        sent++;
      } catch (err) {
        console.error("[send-kwh-reminders] push error:", err);
        failed++;
      }
    }

    return new Response(
      JSON.stringify({ candidates: candidates.length, sent, failed, cutoff }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    console.error("[send-kwh-reminders] fatal:", err);
    return jsonError("Onbekende serverfout", 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}
