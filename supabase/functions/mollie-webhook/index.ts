// Pluggo — mollie-webhook edge function
// ----------------------------------------------------------------------------
// Wordt aangeroepen door Mollie wanneer een betaalstatus verandert.
// Mollie POST't een x-www-form-urlencoded body met "id={mollie_payment_id}".
//
// Mollie best practice:
//   • Vertrouw de body niet — re-fetch de payment via de Mollie API om de
//     actuele status te krijgen (de body bevat alleen het id).
//   • Geef altijd 200 OK terug zodra je 'm hebt verwerkt, anders blijft
//     Mollie met exponential backoff retryen.
//   • De endpoint moet publiek bereikbaar zijn, dus zet de Supabase setting
//     "Verify JWT" op UIT voor deze function. Webhook authenticiteit hoeven
//     we niet te checken — een rogue caller kan alleen een refresh forceren
//     op een payment id die zij sowieso al kennen via Mollie.
//
// Secrets / env:
//   • MOLLIE_API_KEY        — bv. test_xxx of live_xxx
//   • SUPABASE_URL          (auto)
//   • SUPABASE_SERVICE_ROLE_KEY (auto)
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  // GET / HEAD requests komen wel eens van bots / health checks — gewoon 200.
  if (req.method !== "POST") {
    return new Response("ok", { status: 200 });
  }

  try {
    // -----------------------------------------------------------------------
    // 1. Parse form body — Mollie stuurt application/x-www-form-urlencoded
    // -----------------------------------------------------------------------
    const text = await req.text();
    const params = new URLSearchParams(text);
    const molliePaymentId = params.get("id");
    if (!molliePaymentId) {
      console.error("Webhook ontvangen zonder id");
      return new Response("missing id", { status: 400 });
    }

    // -----------------------------------------------------------------------
    // 2. Re-fetch de payment status uit Mollie
    // -----------------------------------------------------------------------
    const mollieApiKey = Deno.env.get("MOLLIE_API_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!mollieApiKey || !supabaseUrl || !supabaseServiceKey) {
      console.error("Webhook env niet compleet");
      return new Response("server config", { status: 500 });
    }

    const mollieRes = await fetch(
      `https://api.mollie.com/v2/payments/${encodeURIComponent(molliePaymentId)}`,
      {
        headers: { Authorization: `Bearer ${mollieApiKey}` },
      }
    );
    if (!mollieRes.ok) {
      console.error(
        "Mollie fetch faalde",
        mollieRes.status,
        await mollieRes.text()
      );
      // 200 terug zodat Mollie 'm later opnieuw stuurt? Nee — gebruik 502
      // zodat Mollie wél retryt. Logs zien we in Supabase.
      return new Response("mollie error", { status: 502 });
    }
    const molliePayment = await mollieRes.json();

    const newStatus = mapMollieStatus(molliePayment.status);
    const paidAt =
      molliePayment.status === "paid" && molliePayment.paidAt
        ? molliePayment.paidAt
        : null;

    // -----------------------------------------------------------------------
    // 3. Vind onze payment row + update
    // -----------------------------------------------------------------------
    const admin = createClient(supabaseUrl, supabaseServiceKey);

    const { data: paymentRow, error: pErr } = await admin
      .from("payments")
      .select("id, booking_id, status")
      .eq("mollie_payment_id", molliePaymentId)
      .maybeSingle();

    if (pErr) {
      console.error("DB fetch error:", pErr);
      return new Response("db error", { status: 500 });
    }
    if (!paymentRow) {
      // Webhook voor een betaling die we niet kennen? Kan gebeuren bij
      // testen / handmatige betalingen via Mollie Dashboard.
      // 200 terug zodat Mollie niet eindeloos blijft retryen.
      console.warn("Payment niet gevonden voor mollie id:", molliePaymentId);
      return new Response("not found (ignored)", { status: 200 });
    }

    // Idempotent: als de status al definitief is en gelijk, doe niets extra
    if (paymentRow.status === newStatus && newStatus === "paid") {
      return new Response("ok (no change)", { status: 200 });
    }

    // -----------------------------------------------------------------------
    // 4. Update payments rij
    // -----------------------------------------------------------------------
    const { error: updErr } = await admin
      .from("payments")
      .update({
        status: newStatus,
        paid_at: paidAt,
      })
      .eq("id", paymentRow.id);

    if (updErr) {
      console.error("Kon payment niet updaten:", updErr);
      return new Response("db error", { status: 500 });
    }

    // -----------------------------------------------------------------------
    // 5. Update boeking met nieuwe payment_status
    // -----------------------------------------------------------------------
    const { error: bUpdErr } = await admin
      .from("bookings")
      .update({ payment_status: newStatus })
      .eq("id", paymentRow.booking_id);

    if (bUpdErr) {
      console.error("Kon booking niet updaten:", bUpdErr);
      // Niet retryen — payment is correct gelogd, dit is consistency-issue
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error("Webhook fatal error:", err);
    return new Response("error", { status: 500 });
  }
});

/**
 * Mappt de Mollie payment status string naar onze public.payment_status enum.
 * Mollie statussen: open, canceled, pending, authorized, expired, failed, paid
 */
function mapMollieStatus(s: string): string {
  switch (s) {
    case "paid":
      return "paid";
    case "open":
    case "pending":
    case "authorized":
      return "pending";
    case "canceled":
    case "expired":
    case "failed":
      return "failed";
    default:
      // Onbekende status — laat 'm op pending staan, dan kunnen we 'm
      // later via Mollie Dashboard inspecteren.
      return "pending";
  }
}
