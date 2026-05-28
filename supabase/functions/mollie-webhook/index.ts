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
    // 5. Update boeking — leid status af uit ÁLLE payments voor deze boeking,
    //    niet alleen deze webhook. Voorkomt dat een late "failed" webhook van
    //    een eerdere afgebroken poging een succesvolle "paid" overschrijft
    //    (bug #71: last-write-wins race condition).
    //
    //    Regel:
    //      - Eén of meer payments paid     → booking paid
    //      - Geen paid maar wel pending    → booking pending
    //      - Alleen failed/canceled        → booking failed
    //      - Geen payments                 → unpaid (zou hier niet voorkomen)
    // -----------------------------------------------------------------------
    // Was de booking vóór deze update al paid? Zo ja, dan is dit een dubbele
    // webhook en moeten we GEEN push sturen (anders krijgt de owner 2x ping).
    const wasAlreadyPaidOnBooking = await (async () => {
      const { data: bRow } = await admin
        .from("bookings")
        .select("payment_status")
        .eq("id", paymentRow.booking_id)
        .maybeSingle();
      return bRow?.payment_status === "paid";
    })();

    const { data: allPayments, error: listErr } = await admin
      .from("payments")
      .select("status")
      .eq("booking_id", paymentRow.booking_id);

    if (listErr) {
      console.error("Kon payments niet ophalen voor status-derivatie:", listErr);
      // Fallback: oude logic — beter iets dan niets
      await admin
        .from("bookings")
        .update({ payment_status: newStatus })
        .eq("id", paymentRow.booking_id);
    } else {
      let derivedStatus: string;
      if (allPayments?.some((p: any) => p.status === "paid")) {
        derivedStatus = "paid";
      } else if (allPayments?.some((p: any) => p.status === "pending")) {
        derivedStatus = "pending";
      } else if (allPayments && allPayments.length > 0) {
        derivedStatus = "failed";
      } else {
        derivedStatus = "unpaid";
      }

      const { error: bUpdErr } = await admin
        .from("bookings")
        .update({ payment_status: derivedStatus })
        .eq("id", paymentRow.booking_id);

      if (bUpdErr) {
        console.error("Kon booking niet updaten:", bUpdErr);
        // Niet retryen — payment is correct gelogd, dit is consistency-issue
      }

      // ---------------------------------------------------------------------
      // 6. Push naar eigenaar bij eerste-keer-paid. Best effort:
      //    - alleen als de booking NU op "paid" staat
      //    - alleen als de booking dit nog niet was (idempotent)
      //    - faalt stil; payment-status moet altijd correct gelogd zijn
      // ---------------------------------------------------------------------
      if (derivedStatus === "paid" && !wasAlreadyPaidOnBooking) {
        try {
          const { data: bookingRow } = await admin
            .from("bookings")
            .select(
              "id, user_name, total_amount_cents, charger_id, " +
                "chargers(owner_id, name)"
            )
            .eq("id", paymentRow.booking_id)
            .maybeSingle();

          // chargers join komt als object terug (single FK), niet als array
          const charger = (bookingRow as any)?.chargers;
          const ownerId = charger?.owner_id as string | undefined;
          const chargerName = (charger?.name as string | undefined) ?? "je laadpaal";
          const bookerName =
            (bookingRow?.user_name as string | undefined) ?? "De boeker";
          const totalCents =
            (bookingRow?.total_amount_cents as number | undefined) ?? 0;
          const euro = (totalCents / 100).toFixed(2).replace(".", ",");

          if (ownerId) {
            // Roep onze eigen send-push function aan met service-role auth.
            await fetch(`${supabaseUrl}/functions/v1/send-push`, {
              method: "POST",
              headers: {
                Authorization: `Bearer ${supabaseServiceKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                user_id: ownerId,
                title: "Betaling ontvangen",
                body: `${bookerName} heeft € ${euro} betaald voor ${chargerName}.`,
                data: {
                  type: "payment_paid",
                  booking_id: String(paymentRow.booking_id),
                },
              }),
            });
          }
        } catch (pushErr) {
          // Niet fataal — webhook moet altijd 200 teruggeven
          console.error("send-push naar owner faalde:", pushErr);
        }
      }
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
