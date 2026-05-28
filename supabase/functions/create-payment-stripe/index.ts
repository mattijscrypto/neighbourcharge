// Pluggo — create-payment-stripe edge function (Stripe Checkout route)
// ----------------------------------------------------------------------------
// **Pad 2: Stripe Checkout via browser-redirect** — vervanger van de
// PaymentIntent + PaymentSheet variant nadat we 3 dagen vastliepen op een
// silent hang in flutter_stripe 11.5.0 op iOS 26.3.1 (PaymentSheet rendert
// technisch maar onzichtbaar — Stripe SDK kan presenting view controller
// niet vinden in FlutterSceneDelegate-architectuur).
//
// In plaats van native PaymentSheet maken we hier een Stripe-hosted
// Checkout Session aan. De Flutter app opent de checkout URL in Safari
// via url_launcher externalApplication. Stripe handelt alles af (kaart,
// iDEAL bank-redirect, Apple Pay, etc.) en redirect bij success/cancel
// naar onze stripe-checkout-return edge function — die op zijn beurt
// een pluggo:// deep link opent om de gebruiker terug te brengen.
//
// Source-of-truth voor betaalstatus blijft de stripe-webhook function
// (payment_intent.succeeded + checkout.session.completed). De Flutter app
// pollt na terugkeer de booking.payment_status — robuust en simpel.
//
// Flow:
//   1. Verifieert de gebruiker (Supabase JWT) en haalt de boeking + paal op
//   2. Vereist dat kwh_consumed + payment_requested_at gezet zijn
//   3. Vereist dat de paaleigenaar stripe_charges_enabled=true heeft
//   4. Berekent total / fee / owner_share op basis van werkelijke kWh × prijs
//   5. Idempotency: hergebruik bestaande open Checkout Session als die er is
//   6. POST naar Stripe /v1/checkout/sessions met:
//        - mode=payment
//        - payment_intent_data[application_fee_amount] + transfer_data[destination]
//        - success_url / cancel_url naar stripe-checkout-return
//   7. Slaat een rij op in `payments` met stripe_checkout_session_id + psp='stripe'
//   8. Geeft checkout_url terug aan de Flutter app
//
// Stripe-vs-PaymentIntent verschillen voor Checkout Sessions:
//   • payment_method_types[] werkt hetzelfde (card + iDEAL pinnen)
//   • application_fee_amount / transfer_data zitten genest in payment_intent_data
//   • success_url / cancel_url zijn verplicht en moeten https zijn
//   • client_secret is irrelevant — gebruiker betaalt op checkout.stripe.com
//
// Secrets die deze functie verwacht (via supabase secrets set ...):
//   • STRIPE_SECRET_KEY    — sk_test_... of sk_live_...
//   • STRIPE_API_BASE      — optioneel, default https://api.stripe.com
//   • SUPABASE_URL         — gebruikt voor het bouwen van success/cancel URLs
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Pluggo fee-model — MOET identiek blijven aan lib/main.dart, create-payment
// en create-payment-opp. Single source of truth in productie wordt nog DRY
// gemaakt via een shared `_pricing.ts` (cutover task).
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

// Stripe EUR minimum is €0,50 — lager dan OPP's €1,00. We houden Pluggo's
// minimum gelijk aan OPP zodat fee-structuur onder 10 kWh consistent blijft.
const PLUGGO_MIN_CENTS = 100;

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
    const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");
    const stripeApiBase =
      Deno.env.get("STRIPE_API_BASE") ?? "https://api.stripe.com";

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
      return jsonError("Server niet juist geconfigureerd (Supabase env)", 500);
    }
    if (!stripeSecret) {
      return jsonError(
        "Server niet juist geconfigureerd (STRIPE_SECRET_KEY)",
        500,
      );
    }

    // Bouw success/cancel URLs richting de stripe-checkout-return edge
    // function. Die staat in dezelfde Supabase project, dus we kunnen
    // SUPABASE_URL hergebruiken. Stripe vereist https en plaintext URL —
    // geen template literals zoals `{CHECKOUT_SESSION_ID}` mogen tussen
    // backticks; Stripe vervangt {CHECKOUT_SESSION_ID} automatisch.
    const returnBase = `${supabaseUrl}/functions/v1/stripe-checkout-return`;
    const successUrl = `${returnBase}?status=success&session_id={CHECKOUT_SESSION_ID}`;
    const cancelUrl = `${returnBase}?status=cancel&session_id={CHECKOUT_SESSION_ID}`;

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
        "id, user_id, status, payment_status, start_time, end_time, charger_id, kwh_consumed, payment_requested_at, total_amount_cents, service_fee_cents, owner_share_cents, chargers(id, name, address, price, owner_id)",
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
        409,
      );
    }
    if ((booking as any).payment_status === "paid") {
      return jsonError("Deze boeking is al betaald", 409);
    }

    const kwhRaw = (booking as any).kwh_consumed;
    if (kwhRaw === null || kwhRaw === undefined) {
      return jsonError(
        "Eigenaar heeft nog niet ingevuld hoeveel kWh je hebt afgenomen",
        409,
      );
    }
    const kwh = Number(kwhRaw);
    if (!Number.isFinite(kwh) || kwh <= 0) {
      return jsonError("Ongeldig aantal kWh op de boeking", 500);
    }
    if (!(booking as any).payment_requested_at) {
      return jsonError(
        "Eigenaar heeft nog geen betaalverzoek gestuurd",
        409,
      );
    }

    const charger = (booking as any).chargers;
    if (!charger || charger.price === null || charger.price === undefined) {
      return jsonError("Paalgegevens onvolledig", 500);
    }

    // -----------------------------------------------------------------------
    // 3b. Stripe-specifiek: paaleigenaar moet onboarded zijn
    // -----------------------------------------------------------------------
    const ownerId = charger.owner_id;
    if (!ownerId) {
      return jsonError("Paal heeft geen eigenaar geregistreerd", 500);
    }

    const { data: ownerProfile, error: ownerErr } = await admin
      .from("profiles")
      .select(
        "id, stripe_account_id, stripe_charges_enabled, stripe_account_status, vat_status, full_name",
      )
      .eq("id", ownerId)
      .single();

    if (ownerErr || !ownerProfile) {
      return jsonError("Eigenaarsgegevens niet vindbaar", 500);
    }

    if (
      !ownerProfile.stripe_account_id ||
      !ownerProfile.stripe_charges_enabled
    ) {
      // Paaleigenaar moet zijn Stripe Connect onboarding afronden voordat
      // boekingen betaald kunnen worden. In de Flutter app moet publicatie
      // van een paal al worden geblokkeerd; dit is een server-side safety net.
      return jsonError(
        "Deze paaleigenaar heeft zijn betaal-setup nog niet voltooid. Probeer het later opnieuw.",
        409,
      );
    }

    // -----------------------------------------------------------------------
    // 4. Bereken bedragen — zelfde logica als create-payment-opp / PaymentIntent
    //
    // De boeking kan al gelocked bedragen hebben uit een eerdere betaalpoging.
    // Als die er staan: hergebruiken. Anders: opnieuw berekenen op basis van
    // paal-prijs + kWh + small-session fee.
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
    let serviceFeeCents: number;  // = application_fee_amount in Stripe-terminologie
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

    if (totalCents < PLUGGO_MIN_CENTS) {
      return jsonError(
        `Bedrag te laag voor betaling (minimum €${(PLUGGO_MIN_CENTS / 100).toFixed(2)})`,
        400,
      );
    }

    // -----------------------------------------------------------------------
    // 4b. Idempotency guard — hergebruik bestaande open Checkout Session
    //
    // Stripe Checkout Sessions blijven 24 uur geldig. Als de gebruiker
    // tussendoor de browser sluit en terugkeert in de app, willen we
    // dezelfde URL kunnen hergebruiken zonder dubbele session te maken.
    //
    // We checken de Session-status:
    //   - 'open'      → URL hergebruiken
    //   - 'complete'  → boeking is al betaald, blokkeer (defensief)
    //   - 'expired'   → nieuwe Session maken
    // -----------------------------------------------------------------------
    {
      const { data: existing, error: existingErr } = await admin
        .from("payments")
        .select(
          "id, stripe_checkout_session_id, stripe_payment_intent_id, status, stripe_status",
        )
        .eq("booking_id", (booking as any).id)
        .eq("status", "pending")
        .eq("psp_provider", "stripe")
        .order("created_at", { ascending: false });

      if (existingErr) {
        console.error("Kon bestaande payments niet ophalen:", existingErr);
      } else if (existing && existing.length > 0) {
        const candidate = existing[0];

        // Mark older duplicates as failed to keep tabel clean
        if (existing.length > 1) {
          const extraIds = existing.slice(1).map((r: any) => r.id);
          await admin
            .from("payments")
            .update({ status: "failed" })
            .in("id", extraIds);
        }

        if (candidate.stripe_checkout_session_id) {
          try {
            const recheckRes = await fetch(
              `${stripeApiBase}/v1/checkout/sessions/${encodeURIComponent(
                candidate.stripe_checkout_session_id,
              )}`,
              {
                headers: {
                  Authorization: `Bearer ${stripeSecret}`,
                  // Pin op stabiele versie i.p.v. account default (Dahlia preview).
                  "Stripe-Version": "2024-06-20",
                },
              },
            );

            if (recheckRes.ok) {
              const session = await recheckRes.json();
              const sessionStatus = session.status as string | undefined;
              const paymentStatus = session.payment_status as string | undefined;
              const sessionUrl = session.url as string | undefined;

              // Already paid? Defensive: block second checkout.
              if (paymentStatus === "paid") {
                await admin
                  .from("payments")
                  .update({
                    status: "paid",
                    stripe_status: "succeeded",
                    stripe_payment_intent_id:
                      (session.payment_intent as string | undefined) ?? null,
                  })
                  .eq("id", candidate.id);
                await admin
                  .from("bookings")
                  .update({ payment_status: "paid" })
                  .eq("id", (booking as any).id);
                return jsonError(
                  "Deze boeking is al betaald (Stripe meldt 'paid').",
                  409,
                );
              }

              // Session still usable → reuse it
              if (sessionStatus === "open" && sessionUrl) {
                return jsonOk({
                  checkout_url: sessionUrl,
                  checkout_session_id: candidate.stripe_checkout_session_id,
                  payment_id: candidate.id,
                  amount_cents: totalCents,
                  service_fee_cents: serviceFeeCents,
                  owner_share_cents: ownerShareCents,
                  psp: "stripe",
                  reused: true,
                });
              }

              // Expired / complete-zonder-betaling: markeer en val door naar
              // nieuwe Session
              await admin
                .from("payments")
                .update({
                  status: sessionStatus === "expired" ? "failed" : "pending",
                  stripe_status: sessionStatus ?? null,
                })
                .eq("id", candidate.id);
            }
          } catch (recheckErr) {
            console.error("Stripe recheck faalde:", recheckErr);
            // Val door naar nieuwe Session — veiliger dan een fout teruggeven
          }
        }
      }
    }

    // -----------------------------------------------------------------------
    // 5. Checkout Session aanmaken
    //
    // Marketplace destination charge — application_fee_amount + transfer_data
    // worden via payment_intent_data[...] doorgegeven (Stripe vouwt deze
    // op naar de onderliggende PaymentIntent zodra een betaalmethode gekozen
    // is).
    //
    // payment_method_types pinnen we expliciet op card + ideal. Dezelfde
    // reden als bij de PaymentIntent variant: het Dahlia preview account
    // levert anders methoden op die de iOS SDK / browser flow stuk maken.
    // Voor NL launch is card + iDEAL ruim voldoende (>95% dekking).
    //
    // line_items: één regel met de booking-prijs. Stripe Checkout vereist
    // line_items voor `mode: payment` — we geven een korte productnaam
    // zodat de checkout-pagina er netjes uitziet.
    // -----------------------------------------------------------------------
    const description = `Pluggo boeking — ${charger.name}`;
    // v3-suffix toegevoegd bij pivot van PaymentIntent → Checkout Session.
    // Voorkomt dat Stripe een oude PaymentIntent uit de idempotency cache
    // teruggeeft die niet past bij de nieuwe checkout-session flow.
    const idempotencyKey = `pluggo-cs-${(booking as any).id}-${kwh}-v3`;

    // Stripe v1 verwacht form-encoded body. Nested keys met [bracket]-notatie.
    const sessionParams: Record<string, string> = {
      mode: "payment",
      "payment_method_types[0]": "card",
      "payment_method_types[1]": "ideal",
      success_url: successUrl,
      cancel_url: cancelUrl,

      // Line item — de gebruiker ziet dit op checkout.stripe.com.
      "line_items[0][quantity]": "1",
      "line_items[0][price_data][currency]": "eur",
      "line_items[0][price_data][unit_amount]": totalCents.toString(),
      "line_items[0][price_data][product_data][name]": description,
      "line_items[0][price_data][product_data][description]":
        `${kwh.toFixed(2).replace(".", ",")} kWh — incl. servicefee`,

      // Marketplace destination charge via payment_intent_data
      "payment_intent_data[application_fee_amount]":
        serviceFeeCents.toString(),
      "payment_intent_data[transfer_data][destination]":
        ownerProfile.stripe_account_id,
      "payment_intent_data[description]": description,
      "payment_intent_data[metadata][booking_id]": (booking as any).id,
      "payment_intent_data[metadata][user_id]": userId,
      "payment_intent_data[metadata][charger_id]": charger.id,
      "payment_intent_data[metadata][kwh]": kwh.toString(),
      "payment_intent_data[metadata][platform_fee_cents]":
        serviceFeeCents.toString(),
      "payment_intent_data[metadata][owner_share_cents]":
        ownerShareCents.toString(),

      // Session metadata (apart van PI metadata zodat checkout.session.*
      // events ook deze info dragen).
      "metadata[booking_id]": (booking as any).id,
      "metadata[user_id]": userId,
      "metadata[charger_id]": charger.id,

      // NL-only flow; voorkomt dat Checkout meertalige prompts toont.
      locale: "nl",
    };

    // BELANGRIJK: pin Stripe-Version expliciet aan een stabiele release.
    // Zonder deze header gebruikt Stripe de pinned default van het account,
    // en onze account staat op de Dahlia preview (2026-04-22.dahlia) voor
    // de Connect v2 API. 2024-06-20 (Acacia) is stabiel + compatible met
    // standaard Checkout Sessions.
    const sessionRes = await fetch(`${stripeApiBase}/v1/checkout/sessions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${stripeSecret}`,
        "Content-Type": "application/x-www-form-urlencoded",
        "Idempotency-Key": idempotencyKey,
        "Stripe-Version": "2024-06-20",
      },
      body: new URLSearchParams(sessionParams).toString(),
    });

    if (!sessionRes.ok) {
      const errBody = await sessionRes.text();
      console.error(
        "Stripe Checkout Session error:",
        sessionRes.status,
        errBody,
      );
      return jsonError("Stripe betaling kon niet aangemaakt worden", 502);
    }

    const session = await sessionRes.json();
    const sessionId = session.id as string | undefined;
    const checkoutUrl = session.url as string | undefined;
    const sessionStatus = session.status as string | undefined;

    if (!sessionId || !checkoutUrl) {
      console.error("Stripe response zonder id/url:", session);
      return jsonError("Stripe gaf geen checkout-URL terug", 502);
    }

    // -----------------------------------------------------------------------
    // 6. Sla op in DB
    //
    // PaymentIntent ID is op dit moment nog NULL — Stripe maakt 'm pas aan
    // zodra de gebruiker een betaalmethode kiest. De stripe-webhook vult
    // 'm in bij checkout.session.completed.
    //
    // 23505 unique_violation handling: idempotency-key zorgt dat we dezelfde
    // session terugkrijgen bij retries. Als de payments-rij al bestaat
    // (bv. doordat admin SQL 'm op 'failed' zette), switchen we naar UPDATE.
    // -----------------------------------------------------------------------
    const paymentRowData = {
      booking_id: (booking as any).id,
      amount_cents: totalCents,
      service_fee_cents: serviceFeeCents,
      owner_share_cents: ownerShareCents,
      currency: "EUR",
      status: "pending",
      // Stripe-specifiek
      stripe_checkout_session_id: sessionId,
      stripe_payment_intent_id: null, // pas bekend na checkout
      stripe_account_id: ownerProfile.stripe_account_id,
      stripe_status: sessionStatus ?? "open",
      platform_fee_cents: serviceFeeCents,
      owner_payout_cents: ownerShareCents,
      psp_provider: "stripe",
    };

    let paymentRow: any = null;
    const { data: insertedRow, error: insertError } = await admin
      .from("payments")
      .insert(paymentRowData)
      .select()
      .single();

    if (insertError) {
      if ((insertError as any).code === "23505") {
        console.warn(
          `Payment row voor session ${sessionId} bestaat al — switch naar UPDATE`,
        );
        const { data: updatedRow, error: updateError } = await admin
          .from("payments")
          .update({
            status: "pending",
            stripe_status: sessionStatus ?? "open",
            amount_cents: totalCents,
            service_fee_cents: serviceFeeCents,
            owner_share_cents: ownerShareCents,
            platform_fee_cents: serviceFeeCents,
            owner_payout_cents: ownerShareCents,
            stripe_account_id: ownerProfile.stripe_account_id,
          })
          .eq("stripe_checkout_session_id", sessionId)
          .select()
          .single();
        if (updateError || !updatedRow) {
          console.error(
            "Failed to update existing payment row:",
            updateError,
          );
          return jsonError(
            "Kon bestaande betaling niet bijwerken in database",
            500,
          );
        }
        paymentRow = updatedRow;
      } else {
        console.error("Failed to insert payment row:", insertError);
        return jsonError("Kon betaling niet opslaan in database", 500);
      }
    } else {
      if (!insertedRow) {
        console.error("Insert returned no row and no error");
        return jsonError("Kon betaling niet opslaan in database", 500);
      }
      paymentRow = insertedRow;
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
        bookingUpdateError,
      );
    }

    // -----------------------------------------------------------------------
    // 7. Klaar — geef checkout_url terug aan Flutter
    //
    // Flutter opent deze URL via url_launcher externalApplication (Safari).
    // Na betaling redirect Stripe naar stripe-checkout-return → pluggo://
    // deep link. App pollt ondertussen booking.payment_status om bij paid
    // de UI te refreshen — webhook blijft source-of-truth.
    // -----------------------------------------------------------------------
    return jsonOk({
      checkout_url: checkoutUrl,
      checkout_session_id: sessionId,
      payment_id: paymentRow.id,
      amount_cents: totalCents,
      service_fee_cents: serviceFeeCents,
      owner_share_cents: ownerShareCents,
      psp: "stripe",
    });
  } catch (err) {
    console.error("create-payment-stripe fatal error:", err);
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
