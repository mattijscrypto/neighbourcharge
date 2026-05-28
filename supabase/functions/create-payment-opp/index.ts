// Pluggo — create-payment-opp edge function (OPP payment route)
// ----------------------------------------------------------------------------
// Vervangt create-payment (Mollie) zodra OPP cutover op 26 juni 2026 actief is.
// Tijdens parallelle run periode (12-26 juni) bestaan beide endpoints naast
// elkaar. De Flutter app kiest welk endpoint via een feature flag
// `usePppForPayments` of door te kijken of de paaleigenaar al een
// opp_merchant_uid heeft.
//
// Flow:
//   1. Verifieert de gebruiker (Supabase JWT) en haalt de boeking + paal op
//   2. Vereist dat kwh_consumed + payment_requested_at gezet zijn
//   3. Vereist dat de paaleigenaar opp_can_receive_payments=true heeft
//   4. Berekent total / fee / owner_share op basis van werkelijke kWh × prijs
//   5. Idempotency: check op bestaande pending OPP transactie + recheck status
//   6. POST naar OPP /v1/transactions met merchant_uid van paaleigenaar
//   7. Slaat een rij op in `payments` met opp_transaction_uid + psp_provider='opp'
//   8. Update boeking met payment_status='pending' + bedragen
//   9. Geeft redirect_url terug aan de app
//
// Secrets die deze functie verwacht (via supabase secrets set ...):
//   • OPP_API_KEY          — bearer token, partner-level
//   • OPP_API_BASE_URL     — bv. https://api-sandbox.onlinebetaalplatform.nl/v1
//                              of https://api.onlinebetaalplatform.nl/v1
//   • OPP_NOTIFY_URL_BASE  — bv. https://<project>.supabase.co/functions/v1
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Pluggo fee-model — MOET identiek blijven aan lib/main.dart en create-payment.
// ---------------------------------------------------------------------------
const BOOKER_FEE_EUR_PER_KWH = 0.03;
const HOST_FEE_EUR_PER_KWH = 0.03;
const PLUGGO_FEE_EUR_PER_KWH =
  BOOKER_FEE_EUR_PER_KWH + HOST_FEE_EUR_PER_KWH;
const SMALL_SESSION_THRESHOLD_KWH = 10.0;
const SMALL_SESSION_FEE_EUR = 0.40;

function smallSessionFeeFor(kwh: number): number {
  if (!Number.isFinite(kwh) || kwh <= 0) return 0;
  return kwh < SMALL_SESSION_THRESHOLD_KWH ? SMALL_SESSION_FEE_EUR : 0;
}

// Minimum bedrag voor iDEAL via OPP — net als bij Mollie €1,00.
const OPP_MIN_CENTS = 100;

// Deep link waar OPP de gebruiker naartoe stuurt na betalen.
const APP_RETURN_SCHEME = "pluggo";

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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonError("Methode niet toegestaan", 405);
  }

  try {
    // -----------------------------------------------------------------------
    // 1. Auth + env
    // -----------------------------------------------------------------------
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Niet geautoriseerd (geen token)", 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const oppApiKey = Deno.env.get("OPP_API_KEY");
    const oppApiBase =
      Deno.env.get("OPP_API_BASE_URL") ??
      "https://api-sandbox.onlinebetaalplatform.nl/v1";
    const oppNotifyBase =
      Deno.env.get("OPP_NOTIFY_URL_BASE") ?? `${supabaseUrl}/functions/v1`;

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
      return jsonError("Server niet juist geconfigureerd (Supabase env)", 500);
    }
    if (!oppApiKey) {
      return jsonError("Server niet juist geconfigureerd (OPP_API_KEY)", 500);
    }

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
    // 3. DB-werk met service role
    // -----------------------------------------------------------------------
    const admin = createClient(supabaseUrl, supabaseServiceKey);

    const { data: booking, error: bookingError } = await admin
      .from("bookings")
      .select(
        "id, user_id, status, payment_status, start_time, end_time, charger_id, kwh_consumed, payment_requested_at, total_amount_cents, service_fee_cents, owner_share_cents, chargers(id, name, address, price, owner_id)"
      )
      .eq("id", body.booking_id)
      .single();

    if (bookingError || !booking) {
      return jsonError("Boeking niet gevonden", 404);
    }

    if ((booking as any).user_id !== userId) {
      return jsonError("Geen toegang tot deze boeking", 403);
    }
    if ((booking as any).status !== "confirmed") {
      return jsonError(
        "Boeking is nog niet goedgekeurd door de eigenaar",
        409
      );
    }
    if ((booking as any).payment_status === "paid") {
      return jsonError("Deze boeking is al betaald", 409);
    }

    const kwhRaw = (booking as any).kwh_consumed;
    if (kwhRaw === null || kwhRaw === undefined) {
      return jsonError(
        "Eigenaar heeft nog niet ingevuld hoeveel kWh je hebt afgenomen",
        409
      );
    }
    const kwh = Number(kwhRaw);
    if (!Number.isFinite(kwh) || kwh <= 0) {
      return jsonError("Ongeldig aantal kWh op de boeking", 500);
    }
    if (!(booking as any).payment_requested_at) {
      return jsonError(
        "Eigenaar heeft nog geen betaalverzoek gestuurd",
        409
      );
    }

    const charger = (booking as any).chargers;
    if (!charger || charger.price === null || charger.price === undefined) {
      return jsonError("Paalgegevens onvolledig", 500);
    }

    // -----------------------------------------------------------------------
    // 3b. OPP-specifiek: paaleigenaar moet onboarded zijn
    // -----------------------------------------------------------------------
    const ownerId = charger.owner_id;
    if (!ownerId) {
      return jsonError("Paal heeft geen eigenaar geregistreerd", 500);
    }

    const { data: ownerProfile, error: ownerErr } = await admin
      .from("profiles")
      .select(
        "id, opp_merchant_uid, opp_can_receive_payments, opp_compliance_status, vat_status, full_name"
      )
      .eq("id", ownerId)
      .single();

    if (ownerErr || !ownerProfile) {
      return jsonError("Eigenaarsgegevens niet vindbaar", 500);
    }

    if (
      !ownerProfile.opp_merchant_uid ||
      !ownerProfile.opp_can_receive_payments
    ) {
      // Paaleigenaar moet zijn OPP-onboarding afronden voordat boekingen
      // betaald kunnen worden. In de Flutter app moet dit eigenlijk al
      // voorkomen worden door publicatie te blokkeren — dit is een
      // server-side safety net.
      return jsonError(
        "Deze paaleigenaar heeft zijn betaal-setup nog niet voltooid. Probeer het later opnieuw.",
        409
      );
    }

    // -----------------------------------------------------------------------
    // 4. Bereken bedragen — zelfde logica als create-payment (Mollie)
    // -----------------------------------------------------------------------
    const lockedTotalCents = (booking as any).total_amount_cents as
      | number
      | null
      | undefined;
    const lockedFeeCents = (booking as any).service_fee_cents as
      | number
      | null
      | undefined;
    const lockedOwnerShareCents = (booking as any).owner_share_cents as
      | number
      | null
      | undefined;

    let totalCents: number;
    let serviceFeeCents: number;  // = platform_fee_cents in OPP terminologie
    let ownerShareCents: number;

    if (
      typeof lockedTotalCents === "number" &&
      lockedTotalCents > 0 &&
      typeof lockedFeeCents === "number" &&
      typeof lockedOwnerShareCents === "number"
    ) {
      totalCents = lockedTotalCents;
      serviceFeeCents = lockedFeeCents;
      ownerShareCents = lockedOwnerShareCents;
    } else {
      const pricePerKwh = Number(charger.price);
      if (!Number.isFinite(pricePerKwh) || pricePerKwh <= 0) {
        return jsonError("Ongeldige prijs op paal", 500);
      }
      const smallFeeEur = smallSessionFeeFor(kwh);
      const totalEuro =
        kwh * (pricePerKwh + BOOKER_FEE_EUR_PER_KWH) + smallFeeEur;
      totalCents = Math.round(totalEuro * 100);
      serviceFeeCents =
        Math.round(kwh * PLUGGO_FEE_EUR_PER_KWH * 100) +
        Math.round(smallFeeEur * 100);
      ownerShareCents = totalCents - serviceFeeCents;
    }

    if (totalCents < OPP_MIN_CENTS) {
      return jsonError(
        `Bedrag te laag voor betaling (minimum €${(OPP_MIN_CENTS / 100).toFixed(2)})`,
        400
      );
    }

    // -----------------------------------------------------------------------
    // 4b. Idempotency guard — hergebruik bestaande pending OPP transactie
    //
    // Zelfde scenario als bug #72 maar dan voor OPP. Als er al een pending
    // payment is voor deze boeking met psp_provider='opp', hercheck bij OPP:
    //   - Als status nog 'created' of 'pending': hergebruik redirect_url
    //   - Als 'completed': markeer betaald, blokkeer dubbele betaling
    //   - Als 'expired'/'failed'/'cancelled': markeer rij, val door naar nieuw
    // -----------------------------------------------------------------------
    {
      const { data: existing, error: existingErr } = await admin
        .from("payments")
        .select("id, opp_transaction_uid, checkout_url, status, opp_status")
        .eq("booking_id", (booking as any).id)
        .eq("status", "pending")
        .eq("psp_provider", "opp")
        .order("created_at", { ascending: false });

      if (existingErr) {
        console.error("Kon bestaande payments niet ophalen:", existingErr);
      } else if (existing && existing.length > 0) {
        const candidate = existing[0];

        if (existing.length > 1) {
          const extraIds = existing.slice(1).map((r: any) => r.id);
          await admin
            .from("payments")
            .update({ status: "failed" })
            .in("id", extraIds);
        }

        if (candidate.opp_transaction_uid) {
          try {
            const recheckRes = await fetch(
              `${oppApiBase}/transactions/${encodeURIComponent(
                candidate.opp_transaction_uid
              )}`,
              { headers: { Authorization: `Bearer ${oppApiKey}` } }
            );

            if (recheckRes.ok) {
              const txn = await recheckRes.json();
              const live = txn.status as string | undefined;

              if (live === "created" || live === "pending") {
                const reuseUrl = (txn.redirect_url as string | undefined) ??
                  candidate.checkout_url;
                if (reuseUrl) {
                  return jsonOk({
                    checkout_url: reuseUrl,
                    payment_id: candidate.id,
                    amount_cents: totalCents,
                    service_fee_cents: serviceFeeCents,
                    owner_share_cents: ownerShareCents,
                    psp: "opp",
                    reused: true,
                  });
                }
              }

              if (live === "completed") {
                await admin
                  .from("payments")
                  .update({ status: "paid", opp_status: "completed" })
                  .eq("id", candidate.id);
                await admin
                  .from("bookings")
                  .update({ payment_status: "paid" })
                  .eq("id", (booking as any).id);
                return jsonError(
                  "Deze boeking is al betaald (OPP meldt 'completed').",
                  409
                );
              }

              // afgesloten zonder succes: markeer en val door naar nieuwe txn
              const mapped =
                live === "cancelled" || live === "expired" || live === "failed"
                  ? "failed"
                  : "pending";
              await admin
                .from("payments")
                .update({ status: mapped, opp_status: live ?? null })
                .eq("id", candidate.id);
            } else if (candidate.checkout_url) {
              // OPP API faalt — conservatief: hergebruik cached url
              return jsonOk({
                checkout_url: candidate.checkout_url,
                payment_id: candidate.id,
                amount_cents: totalCents,
                service_fee_cents: serviceFeeCents,
                owner_share_cents: ownerShareCents,
                psp: "opp",
                reused: true,
                note: "opp recheck failed, reusing cached url",
              });
            }
          } catch (recheckErr) {
            console.error("OPP recheck faalde:", recheckErr);
            if (candidate.checkout_url) {
              return jsonOk({
                checkout_url: candidate.checkout_url,
                payment_id: candidate.id,
                amount_cents: totalCents,
                service_fee_cents: serviceFeeCents,
                owner_share_cents: ownerShareCents,
                psp: "opp",
                reused: true,
                note: "opp recheck threw, reusing cached url",
              });
            }
          }
        }
      }
    }

    // -----------------------------------------------------------------------
    // 5. OPP transactie aanmaken
    // -----------------------------------------------------------------------
    const description = `Pluggo boeking — ${charger.name}`;
    const notifyUrl = `${oppNotifyBase}/opp-webhook`;
    const returnUrl = `${APP_RETURN_SCHEME}://payment-return?booking_id=${(booking as any).id}`;

    // OPP verwacht prijzen in cents (price: integer).
    // Voor v1 gebruiken we de "betalen via OPP screen"-flow (geen
    // payment_method specificeren). Als we straks seamless willen, voegen we
    // payment_method: 'ideal' + issuer toe vanuit de Flutter app.
    const oppPayload = {
      merchant_uid: ownerProfile.opp_merchant_uid,
      products: [
        {
          name: description,
          price: totalCents,
          quantity: 1,
        },
      ],
      total_price: totalCents,
      return_url: returnUrl,
      notify_url: notifyUrl,
      metadata: {
        booking_id: (booking as any).id,
        user_id: userId,
        charger_id: charger.id,
        // platform_fee_cents en owner_share_cents voor reconciliation.
        // De daadwerkelijke fee-afdracht configureren we via OPP partner
        // settings (te bevestigen met OPP sales).
        platform_fee_cents: serviceFeeCents,
        owner_share_cents: ownerShareCents,
      },
    };

    const oppRes = await fetch(`${oppApiBase}/transactions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${oppApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(oppPayload),
    });

    if (!oppRes.ok) {
      const errBody = await oppRes.text();
      console.error("OPP API error:", oppRes.status, errBody);
      return jsonError("OPP betaling kon niet aangemaakt worden", 502);
    }

    const oppTxn = await oppRes.json();
    const redirectUrl = oppTxn.redirect_url as string | undefined;
    const oppTxnUid = oppTxn.uid as string | undefined;
    if (!redirectUrl || !oppTxnUid) {
      console.error("OPP response zonder redirect_url of uid:", oppTxn);
      return jsonError("OPP gaf geen redirect-URL terug", 502);
    }

    // -----------------------------------------------------------------------
    // 6. Sla op in DB
    // -----------------------------------------------------------------------
    const { data: paymentRow, error: insertError } = await admin
      .from("payments")
      .insert({
        booking_id: (booking as any).id,
        amount_cents: totalCents,
        service_fee_cents: serviceFeeCents,
        owner_share_cents: ownerShareCents,
        currency: "EUR",
        status: "pending",
        checkout_url: redirectUrl,
        // OPP-specifiek
        opp_transaction_uid: oppTxnUid,
        opp_merchant_uid: ownerProfile.opp_merchant_uid,
        platform_fee_cents: serviceFeeCents,
        owner_payout_cents: ownerShareCents,
        opp_status: (oppTxn.status as string | undefined) ?? "created",
        psp_provider: "opp",
      })
      .select()
      .single();

    if (insertError || !paymentRow) {
      console.error("Failed to insert payment row:", insertError);
      return jsonError("Kon betaling niet opslaan in database", 500);
    }

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
      console.error(
        "Booking update faalde (payment toch aangemaakt):",
        bookingUpdateError
      );
    }

    // -----------------------------------------------------------------------
    // 7. Klaar — geef redirect_url terug
    // -----------------------------------------------------------------------
    return jsonOk({
      checkout_url: redirectUrl,
      payment_id: paymentRow.id,
      amount_cents: totalCents,
      service_fee_cents: serviceFeeCents,
      owner_share_cents: ownerShareCents,
      psp: "opp",
    });
  } catch (err) {
    console.error("create-payment-opp fatal error:", err);
    return jsonError("Onbekende serverfout", 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}

function jsonOk(payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status: 200,
  });
}
