// Pluggo — create-payment edge function
// ----------------------------------------------------------------------------
// Wordt aangeroepen door de Flutter app op het moment dat een boeker zijn
// goedgekeurde boeking wil afrekenen. Deze functie:
//   1. Verifieert de gebruiker (Supabase JWT) en haalt de boeking op
//   2. Berekent total / fee / owner_share op basis van duur × geschat kWh × prijs
//   3. Maakt een Mollie betaling aan via de Mollie Payments API
//   4. Slaat een rij op in `payments` met de Mollie ID en checkout URL
//   5. Update de boeking met payment_status = 'pending' + bedragen
//   6. Geeft de checkout_url terug aan de app
//
// Secrets die deze functie verwacht (via supabase secrets set ...):
//   • MOLLIE_API_KEY        — bv. test_xxx of live_xxx
// Auto-injected door Supabase:
//   • SUPABASE_URL
//   • SUPABASE_ANON_KEY
//   • SUPABASE_SERVICE_ROLE_KEY
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Config — pas hier aan als je het product aanpast.
// ---------------------------------------------------------------------------

// Geschatte laadsnelheid voor kWh→tijd conversie. De meeste home chargers
// in NL leveren 7,4 kW (eenfase 32A) of 11 kW (driefase). 7,4 kW is een
// conservatieve middenwaarde — owners ontvangen iets minder dan ze in
// theorie hadden kunnen leveren, wat veiliger is dan de andere kant op.
const ESTIMATED_KW = 7.4;

// Service fee percentage voor Pluggo. Staat ook in T&Cs en FAQ.
const SERVICE_FEE_RATE = 0.05;

// Minimum bedrag voor Mollie iDEAL is meestal €1,00. Daaronder weigert
// de Mollie API en geven we een nette error terug.
const MOLLIE_MIN_CENTS = 100;

// Deep link waar Mollie de gebruiker naartoe stuurt na betalen.
// `pluggo://` moet ook in iOS Info.plist en Android intent-filter geregistreerd zijn.
const APP_RETURN_SCHEME = "pluggo";

// CORS — staat alle origins toe omdat de Flutter app via verschillende
// origins kan komen (web, native via custom header). Authentication via JWT.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface CreatePaymentRequest {
  booking_id: string;
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
    // 1. Authenticatie — wie roept dit aan?
    // -----------------------------------------------------------------------
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Niet geautoriseerd (geen token)", 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const mollieApiKey = Deno.env.get("MOLLIE_API_KEY");

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
      return jsonError("Server niet juist geconfigureerd (Supabase env)", 500);
    }
    if (!mollieApiKey) {
      return jsonError("Server niet juist geconfigureerd (MOLLIE_API_KEY)", 500);
    }

    // userClient gebruikt de meegegeven JWT om te valideren wie er belt.
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return jsonError("Niet ingelogd", 401);
    }
    const userId = userData.user.id;

    // -----------------------------------------------------------------------
    // 2. Parse body
    // -----------------------------------------------------------------------
    let body: CreatePaymentRequest;
    try {
      body = (await req.json()) as CreatePaymentRequest;
    } catch (_) {
      return jsonError("Ongeldige JSON body", 400);
    }
    if (!body.booking_id) {
      return jsonError("booking_id ontbreekt in body", 400);
    }

    // -----------------------------------------------------------------------
    // 3. DB-werk doen we met service-role om RLS te bypassen.
    //    De checks hieronder garanderen dat alleen de juiste user dit kan.
    // -----------------------------------------------------------------------
    const admin = createClient(supabaseUrl, supabaseServiceKey);

    // Haal boeking op — joinen we de paal mee voor naam en prijs.
    const { data: booking, error: bookingError } = await admin
      .from("bookings")
      .select(
        "id, user_id, status, payment_status, start_time, end_time, charger_id, chargers(id, name, address, price, owner_id)"
      )
      .eq("id", body.booking_id)
      .single();

    if (bookingError || !booking) {
      return jsonError("Boeking niet gevonden", 404);
    }

    // Veiligheid: alleen de boeker mag betalen
    if ((booking as any).user_id !== userId) {
      return jsonError("Geen toegang tot deze boeking", 403);
    }

    // De eigenaar moet de boeking eerst goedkeuren
    if ((booking as any).status !== "confirmed") {
      return jsonError(
        "Boeking is nog niet goedgekeurd door de eigenaar",
        409
      );
    }

    // Niet dubbel betalen
    if ((booking as any).payment_status === "paid") {
      return jsonError("Deze boeking is al betaald", 409);
    }

    const charger = (booking as any).chargers;
    if (!charger || charger.price === null || charger.price === undefined) {
      return jsonError("Paalgegevens onvolledig", 500);
    }

    // -----------------------------------------------------------------------
    // 4. Bereken bedragen
    //    Pricing model: total_amount = wat de boeker betaalt = duur × kWh × prijs.
    //    Daarvan gaat 95% naar de eigenaar, 5% is Pluggo's servicefee.
    // -----------------------------------------------------------------------
    const startMs = new Date((booking as any).start_time).getTime();
    const endMs = new Date((booking as any).end_time).getTime();
    const hours = (endMs - startMs) / (1000 * 60 * 60);
    if (!Number.isFinite(hours) || hours <= 0) {
      return jsonError("Ongeldige boekingsduur", 400);
    }

    const pricePerKwh = Number(charger.price);
    if (!Number.isFinite(pricePerKwh) || pricePerKwh <= 0) {
      return jsonError("Ongeldige prijs op paal", 500);
    }

    const estimatedKwh = hours * ESTIMATED_KW;
    const totalEuro = estimatedKwh * pricePerKwh;
    const totalCents = Math.round(totalEuro * 100);

    if (totalCents < MOLLIE_MIN_CENTS) {
      return jsonError(
        `Bedrag te laag voor betaling (minimum €${(MOLLIE_MIN_CENTS / 100).toFixed(2)})`,
        400
      );
    }

    const serviceFeeCents = Math.round(totalCents * SERVICE_FEE_RATE);
    const ownerShareCents = totalCents - serviceFeeCents;

    // -----------------------------------------------------------------------
    // 5. Mollie payment aanmaken
    // -----------------------------------------------------------------------
    const description = `Pluggo boeking — ${charger.name}`;
    const mollieAmount = (totalCents / 100).toFixed(2);

    const webhookUrl = `${supabaseUrl}/functions/v1/mollie-webhook`;
    const redirectUrl = `${APP_RETURN_SCHEME}://payment-return?booking_id=${(booking as any).id}`;

    const molliePayload = {
      amount: { currency: "EUR", value: mollieAmount },
      description,
      redirectUrl,
      webhookUrl,
      metadata: {
        booking_id: (booking as any).id,
        user_id: userId,
        charger_id: charger.id,
      },
    };

    const mollieRes = await fetch("https://api.mollie.com/v2/payments", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${mollieApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(molliePayload),
    });

    if (!mollieRes.ok) {
      const errBody = await mollieRes.text();
      console.error("Mollie API error:", mollieRes.status, errBody);
      return jsonError("Mollie betaling kon niet aangemaakt worden", 502);
    }

    const molliePayment = await mollieRes.json();
    const checkoutUrl = molliePayment?._links?.checkout?.href as
      | string
      | undefined;
    if (!checkoutUrl) {
      console.error("Mollie response zonder checkout URL:", molliePayment);
      return jsonError("Mollie gaf geen checkout URL terug", 502);
    }

    // -----------------------------------------------------------------------
    // 6. Sla op in DB
    // -----------------------------------------------------------------------
    const { data: paymentRow, error: insertError } = await admin
      .from("payments")
      .insert({
        booking_id: (booking as any).id,
        mollie_payment_id: molliePayment.id,
        amount_cents: totalCents,
        service_fee_cents: serviceFeeCents,
        owner_share_cents: ownerShareCents,
        currency: "EUR",
        status: "pending",
        checkout_url: checkoutUrl,
      })
      .select()
      .single();

    if (insertError || !paymentRow) {
      console.error("Failed to insert payment row:", insertError);
      return jsonError("Kon betaling niet opslaan in database", 500);
    }

    // Update boeking met payment_status + bedragen
    const { error: bookingUpdateError } = await admin
      .from("bookings")
      .update({
        payment_status: "pending",
        total_amount_cents: totalCents,
        service_fee_cents: serviceFeeCents,
        owner_share_cents: ownerShareCents,
      })
      .eq("id", (booking as any).id);

    if (bookingUpdateError) {
      // Niet fataal — payment row is al opgeslagen, webhook kan alsnog
      // de status updaten. Wel loggen voor monitoring.
      console.error(
        "Booking update faalde (payment toch aangemaakt):",
        bookingUpdateError
      );
    }

    // -----------------------------------------------------------------------
    // 7. Klaar — geef checkout_url terug
    // -----------------------------------------------------------------------
    return new Response(
      JSON.stringify({
        checkout_url: checkoutUrl,
        payment_id: paymentRow.id,
        amount_cents: totalCents,
        service_fee_cents: serviceFeeCents,
        owner_share_cents: ownerShareCents,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err) {
    console.error("create-payment fatal error:", err);
    return jsonError("Onbekende serverfout", 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}
