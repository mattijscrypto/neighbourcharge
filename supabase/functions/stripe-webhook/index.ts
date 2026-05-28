// Pluggo — stripe-webhook edge function
// ----------------------------------------------------------------------------
// Eindpunt voor Stripe webhooks. Verwerkt twee event-families:
//
//   1. v1 events (payments)
//      • payment_intent.succeeded       → markeer boeking als betaald
//      • payment_intent.payment_failed  → markeer payment als failed
//      • payment_intent.canceled        → markeer payment als failed
//      • charge.refunded                → markeer boeking als refunded
//
//   2. v2 thin events (Accounts v2 / Connect)
//      • v2.core.account.updated                              → sync charges/payouts state
//      • v2.core.account[configuration.recipient].capability_status_updated
//                                                              → sync recipient capability
//      • v2.core.account[configuration.merchant].capability_status_updated
//                                                              → sync merchant capability
//
// Voor v2 thin events bevat de payload alleen een `related_object.url` —
// de volledige account-snapshot moet apart worden opgehaald via die URL
// met `Stripe-Context: ${account_id}` header (of zonder, voor platform-level).
//
// Signature-verificatie gebruikt HMAC-SHA256 met STRIPE_WEBHOOK_SECRET en
// het Stripe-Signature header (`t=...,v1=...`). De verificatie is hand-rolled
// (Web Crypto) om externe dependencies te vermijden.
//
// Idempotency: elke event.id wordt opgeslagen in stripe_webhook_events.
// Conflict op primary key = duplicate retry van Stripe → return 200 zonder
// nogmaals verwerken.
//
// Deze function MOET verify_jwt=false hebben in supabase/config.toml
// (zie OPP/Mollie webhook precedent in #73), omdat Stripe geen Supabase JWT
// meestuurt. De Stripe-Signature is onze authenticatie.
//
// Secrets / env:
//   • STRIPE_SECRET_KEY        — voor het ophalen van v2 account snapshots
//   • STRIPE_WEBHOOK_SECRET    — whsec_... voor de Snapshot-destination (v1 events:
//                                 payment_intent.*, charge.refunded, account.updated)
//   • STRIPE_WEBHOOK_SECRET_V2 — whsec_... voor de Thin-destination (v2 events:
//                                 v2.core.account.*, v2.core.account_link.*).
//                                 Optioneel — als 'ie ontbreekt verwerken we alleen v1.
//   • STRIPE_API_BASE          — optioneel, default https://api.stripe.com
//
// Waarom twee secrets? Stripe sta(a)t niet toe v1 (Snapshot) en v2 (Thin) events
// op één destination te mixen. We hebben dus twee destinations met elk hun eigen
// signing secret. De handler probeert eerst v1, dan v2.
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "stripe-signature, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Stripe accepteert webhook handlers tot 5s response time voordat 'ie
// retried. Houd de handler dus kort: alleen DB-werk, geen e-mails (die
// triggeren we asynchroon via een aparte job of vanuit Flutter).
const HANDLER_TIMEOUT_MS = 4000;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");
  const webhookSecretV1 = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  const webhookSecretV2 = Deno.env.get("STRIPE_WEBHOOK_SECRET_V2");
  const stripeApiBase =
    Deno.env.get("STRIPE_API_BASE") ?? "https://api.stripe.com";

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error("stripe-webhook: missing supabase env");
    return new Response("Server misconfigured", { status: 500 });
  }
  if (!webhookSecretV1 && !webhookSecretV2) {
    console.error(
      "stripe-webhook: missing webhook secret (need STRIPE_WEBHOOK_SECRET and/or STRIPE_WEBHOOK_SECRET_V2)",
    );
    return new Response("Server misconfigured", { status: 500 });
  }

  // -------------------------------------------------------------------------
  // 1. Lees raw body + Stripe-Signature header
  //    Body MOET als raw text gelezen worden (geen json()), anders mismatcht
  //    de HMAC. Verifieer signature BEFORE we de body parsen.
  // -------------------------------------------------------------------------
  const sigHeader = req.headers.get("stripe-signature");
  if (!sigHeader) {
    return new Response("Missing Stripe-Signature", { status: 400 });
  }

  const rawBody = await req.text();

  // Probeer alle geconfigureerde secrets — v1 én v2 events landen op dezelfde
  // endpoint maar hebben elk hun eigen signing secret (afkomstig van twee
  // verschillende destinations in het Stripe Dashboard).
  const candidates = [webhookSecretV1, webhookSecretV2].filter(
    (s): s is string => !!s,
  );
  let verified = false;
  for (const secret of candidates) {
    if (await verifyStripeSignature(rawBody, sigHeader, secret)) {
      verified = true;
      break;
    }
  }
  if (!verified) {
    console.warn(
      "stripe-webhook: signature verification failed against all configured secrets",
    );
    return new Response("Invalid signature", { status: 400 });
  }

  // -------------------------------------------------------------------------
  // 2. Parse event + idempotency check
  // -------------------------------------------------------------------------
  let event: any;
  try {
    event = JSON.parse(rawBody);
  } catch (_) {
    return new Response("Invalid JSON", { status: 400 });
  }

  const eventId = event.id as string | undefined;
  const eventType = event.type as string | undefined;
  if (!eventId || !eventType) {
    return new Response("Missing id/type", { status: 400 });
  }

  const admin = createClient(supabaseUrl, supabaseServiceKey);

  // Insert in stripe_webhook_events. Conflict op id = duplicate retry.
  const { error: insertErr } = await admin
    .from("stripe_webhook_events")
    .insert({
      id: eventId,
      type: eventType,
      api_version: (event.api_version as string | undefined) ?? null,
      payload: event,
    });

  if (insertErr) {
    // 23505 = unique_violation = duplicate Stripe retry
    if ((insertErr as any).code === "23505") {
      return new Response("Already processed", { status: 200 });
    }
    console.error("stripe-webhook: insert event failed", insertErr);
    // Toch doorgaan — beter dubbel verwerken dan event missen
  }

  // -------------------------------------------------------------------------
  // 3. Dispatch op event type
  // -------------------------------------------------------------------------
  let errorMessage: string | null = null;

  try {
    const handler = dispatch(eventType);
    if (handler) {
      await Promise.race([
        handler(admin, event, stripeSecret, stripeApiBase),
        timeoutPromise(HANDLER_TIMEOUT_MS),
      ]);
    } else {
      // Onbekend event-type: gewoon loggen, niet falen.
      // Stripe stuurt sowieso veel events die we niet abonneren maar
      // toch in onze webhook landen als we 'select all events' aanstaan.
      console.log("stripe-webhook: ignoring event type", eventType);
    }
  } catch (handlerErr) {
    errorMessage = String(handlerErr);
    console.error(
      "stripe-webhook: handler error for",
      eventType,
      handlerErr,
    );
  }

  // -------------------------------------------------------------------------
  // 4. Markeer event als processed (of error)
  // -------------------------------------------------------------------------
  await admin
    .from("stripe_webhook_events")
    .update({
      processed_at: new Date().toISOString(),
      error_message: errorMessage,
    })
    .eq("id", eventId);

  // Stripe verwacht ALTIJD 200 OK voor verwerkte events, ook bij interne
  // fout — anders blijft Stripe retryen. Onze error_message kolom helpt
  // bij debugging zonder retry-storm te veroorzaken.
  return new Response("OK", { status: 200 });
});

// ============================================================================
// DISPATCH TABLE
// ============================================================================

type Handler = (
  admin: any,
  event: any,
  stripeSecret: string,
  stripeApiBase: string,
) => Promise<void>;

function dispatch(eventType: string): Handler | null {
  switch (eventType) {
    // ---- Payments ----------------------------------------------------------
    case "payment_intent.succeeded":
      return handlePaymentIntentSucceeded;
    case "payment_intent.payment_failed":
    case "payment_intent.canceled":
      return handlePaymentIntentFailed;
    case "charge.refunded":
      return handleChargeRefunded;

    // ---- Checkout Sessions (Pad 2 — browser-redirect flow) ----------------
    // Bij Checkout Sessions hebben onze payment-rijen initieel
    // stripe_payment_intent_id = NULL — de PI ontstaat pas zodra de
    // gebruiker een methode kiest op checkout.stripe.com. We koppelen 'm
    // hier achteraf zodat downstream payment_intent.succeeded events
    // wél een match vinden op stripe_payment_intent_id.
    //
    // Voor sync methoden (card, Apple Pay) kan checkout.session.completed
    // óók al een 'paid' payment_status meedragen — in dat geval markeren
    // we de booking direct, en is payment_intent.succeeded een no-op.
    case "checkout.session.completed":
    case "checkout.session.async_payment_succeeded":
    case "checkout.session.async_payment_failed":
      return handleCheckoutSessionEvent;
    case "checkout.session.expired":
      return handleCheckoutSessionExpired;

    // ---- Connect / Accounts (v1 style — for legacy accounts) --------------
    case "account.updated":
      return handleAccountUpdatedV1;

    // ---- Connect / Accounts v2 (thin events) ------------------------------
    // Alle account-mutaties (configuration/identity/requirements/defaults) en
    // capability-status updates routen we naar dezelfde handler: die haalt
    // de actuele snapshot op via GET /v2/core/accounts/{id} en projecteert
    // 'm naar onze profiles-kolommen. Idempotent.
    case "v2.core.account.updated":
    case "v2.core.account[configuration.recipient].capability_status_updated":
    case "v2.core.account[configuration.merchant].capability_status_updated":
    case "v2.core.account[requirements].updated":
    case "v2.core.account[identity].updated":
    case "v2.core.account[defaults].updated":
    case "v2.core.account[configuration.recipient].updated":
    case "v2.core.account[configuration.merchant].updated":
    case "v2.core.account[configuration.customer].updated":
      return handleAccountUpdatedV2;

    // Account link returned = gebruiker is teruggekeerd uit Stripe-hosted
    // KYC flow. We doen niets speciaals — de echte state-changes komen via
    // de account.* events hierboven. Loggen voor zichtbaarheid.
    case "v2.core.account_link.returned":
      return handleAccountLinkReturned;

    default:
      return null;
  }
}

// ============================================================================
// PAYMENT HANDLERS
// ============================================================================

async function handlePaymentIntentSucceeded(
  admin: any,
  event: any,
  _stripeSecret: string,
  _stripeApiBase: string,
) {
  const pi = event?.data?.object;
  if (!pi?.id) {
    console.warn("payment_intent.succeeded zonder pi.id");
    return;
  }

  const piId = pi.id as string;
  const chargeId = (pi.latest_charge as string | undefined) ?? null;
  const transferId = (pi?.transfer_data?.destination as string | undefined)
    ? (pi?.charges?.data?.[0]?.transfer as string | undefined) ?? null
    : null;
  const applicationFeeId =
    (pi?.application_fee as string | undefined) ?? null;

  // Zoek payment row — eerst op PI-id (snelle pad), anders op metadata.booking_id
  // (fallback voor Checkout-flow waar PI-id nog niet gebackfilled is door
  // checkout.session.completed; events kunnen out-of-order arriveren).
  let { data: payment, error: pErr } = await admin
    .from("payments")
    .select("id, booking_id, status")
    .eq("stripe_payment_intent_id", piId)
    .maybeSingle();

  if (!payment) {
    const bookingId = pi?.metadata?.booking_id as string | undefined;
    if (bookingId) {
      const { data: byBooking } = await admin
        .from("payments")
        .select("id, booking_id, status")
        .eq("booking_id", bookingId)
        .eq("psp_provider", "stripe")
        .in("status", ["pending", "failed"])
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (byBooking) {
        payment = byBooking;
        // Backfill PI-id zodat eventuele toekomstige events (refund, etc.)
        // direct via stripe_payment_intent_id matchen.
        await admin
          .from("payments")
          .update({ stripe_payment_intent_id: piId })
          .eq("id", byBooking.id);
      }
    }
  }

  if (pErr || !payment) {
    console.warn(
      "payment_intent.succeeded: geen payment row voor",
      piId,
      pErr,
    );
    return;
  }

  if (payment.status === "paid") {
    // Al verwerkt — niets te doen
    return;
  }

  // Update payment
  await admin
    .from("payments")
    .update({
      status: "paid",
      stripe_status: "succeeded",
      stripe_charge_id: chargeId,
      stripe_transfer_id: transferId,
      stripe_application_fee_id: applicationFeeId,
    })
    .eq("id", payment.id);

  // Update booking
  await admin
    .from("bookings")
    .update({
      payment_status: "paid",
    })
    .eq("id", payment.booking_id);
}

async function handlePaymentIntentFailed(
  admin: any,
  event: any,
  _stripeSecret: string,
  _stripeApiBase: string,
) {
  const pi = event?.data?.object;
  if (!pi?.id) return;

  const piId = pi.id as string;
  const status = pi.status as string | undefined;

  const { data: payment } = await admin
    .from("payments")
    .select("id, booking_id, status")
    .eq("stripe_payment_intent_id", piId)
    .maybeSingle();

  if (!payment) return;
  if (payment.status === "paid") return; // niet downgraden

  await admin
    .from("payments")
    .update({
      status: "failed",
      stripe_status: status ?? "failed",
    })
    .eq("id", payment.id);

  // Booking blijft op payment_status='pending' zodat de afnemer opnieuw kan
  // proberen via create-payment-stripe (die maakt dan een nieuwe PI aan).
}

async function handleChargeRefunded(
  admin: any,
  event: any,
  _stripeSecret: string,
  _stripeApiBase: string,
) {
  const charge = event?.data?.object;
  if (!charge?.payment_intent) return;

  const piId = charge.payment_intent as string;

  const { data: payment } = await admin
    .from("payments")
    .select("id, booking_id")
    .eq("stripe_payment_intent_id", piId)
    .maybeSingle();

  if (!payment) return;

  await admin
    .from("payments")
    .update({
      status: "refunded",
      stripe_status: "refunded",
    })
    .eq("id", payment.id);

  await admin
    .from("bookings")
    .update({ payment_status: "refunded" })
    .eq("id", payment.booking_id);
}

// ============================================================================
// CHECKOUT SESSION HANDLERS (Pad 2 — browser-redirect flow)
// ============================================================================
//
// Bij Checkout Sessions doorlopen we een 2-fase webhook flow:
//
//   1. checkout.session.completed — gebruiker heeft checkout doorlopen en
//      een betaalmethode gekozen. De PaymentIntent bestaat nu. Voor sync
//      methoden (card, Apple Pay) is payment_status meteen 'paid'. Voor
//      async (iDEAL bank-redirect, Bancontact) is 'ie 'unpaid' totdat de
//      bank-redirect succesvol terugkomt.
//   2. payment_intent.succeeded — finale bevestiging dat het geld
//      daadwerkelijk gereserveerd is bij Stripe.
//
// In stap 1 koppelen we de stripe_payment_intent_id aan onze payment row
// zodat stap 2 hem direct kan vinden via dat veld.

async function handleCheckoutSessionEvent(
  admin: any,
  event: any,
  _stripeSecret: string,
  _stripeApiBase: string,
) {
  const session = event?.data?.object;
  if (!session?.id) {
    console.warn(
      `${event.type} zonder session.id`,
    );
    return;
  }

  const sessionId = session.id as string;
  const piId = (session.payment_intent as string | undefined) ?? null;
  const sessionStatus = (session.status as string | undefined) ?? null;
  const paymentStatus = (session.payment_status as string | undefined) ?? null;

  // Vind onze payment row via de session-id (uniek, ingevuld bij creatie).
  const { data: payment, error: pErr } = await admin
    .from("payments")
    .select("id, booking_id, status, stripe_payment_intent_id")
    .eq("stripe_checkout_session_id", sessionId)
    .maybeSingle();

  if (pErr || !payment) {
    console.warn(
      `${event.type}: geen payment row voor session`,
      sessionId,
      pErr,
    );
    return;
  }

  // Backfill PI-id als die er nog niet stond. Idempotent — overschrijven
  // met dezelfde waarde is harmloos.
  if (piId && payment.stripe_payment_intent_id !== piId) {
    await admin
      .from("payments")
      .update({ stripe_payment_intent_id: piId })
      .eq("id", payment.id);
  }

  // Voor sync betaalmethoden (card / Apple Pay) is payment_status meteen
  // 'paid'. Dan markeren we de booking nu al — anders wachten we op
  // payment_intent.succeeded voor de finale state.
  if (paymentStatus === "paid" && payment.status !== "paid") {
    await admin
      .from("payments")
      .update({
        status: "paid",
        stripe_status: "succeeded",
      })
      .eq("id", payment.id);

    await admin
      .from("bookings")
      .update({ payment_status: "paid" })
      .eq("id", payment.booking_id);
  } else if (paymentStatus === "unpaid" && event.type === "checkout.session.async_payment_failed") {
    // Async methode geweigerd door bank (iDEAL annulering, Bancontact timeout)
    await admin
      .from("payments")
      .update({
        status: "failed",
        stripe_status: "failed",
      })
      .eq("id", payment.id);
  } else {
    // Async pending — wacht op payment_intent.succeeded. Update alleen
    // stripe_status voor debugging-zichtbaarheid.
    await admin
      .from("payments")
      .update({
        stripe_status: sessionStatus ?? "open",
      })
      .eq("id", payment.id);
  }
}

async function handleCheckoutSessionExpired(
  admin: any,
  event: any,
  _stripeSecret: string,
  _stripeApiBase: string,
) {
  const session = event?.data?.object;
  if (!session?.id) return;

  const sessionId = session.id as string;

  const { data: payment } = await admin
    .from("payments")
    .select("id, status")
    .eq("stripe_checkout_session_id", sessionId)
    .maybeSingle();

  if (!payment) return;
  if (payment.status === "paid") return; // niet downgraden

  await admin
    .from("payments")
    .update({
      status: "failed",
      stripe_status: "expired",
    })
    .eq("id", payment.id);

  // Booking blijft op payment_status='pending' — afnemer kan opnieuw
  // proberen via create-payment-stripe (maakt dan een nieuwe Session).
}

// ============================================================================
// ACCOUNT HANDLERS — v1
// ============================================================================
// Voor v1 connected accounts (oude Connect-flow). De v2 versie hieronder
// haalt het account opnieuw op via /v2/core/accounts. Deze v1-handler werkt
// direct met de payload omdat 'account.updated' (v1) de volledige Account-
// resource meestuurt.
async function handleAccountUpdatedV1(
  admin: any,
  event: any,
  _stripeSecret: string,
  _stripeApiBase: string,
) {
  const account = event?.data?.object;
  if (!account?.id) return;

  await syncAccountStateToProfile(admin, account.id, {
    charges_enabled: Boolean(account.charges_enabled),
    payouts_enabled: Boolean(account.payouts_enabled),
    details_submitted: Boolean(account.details_submitted),
    disabled_reason: account?.requirements?.disabled_reason ?? null,
    currently_due: (account?.requirements?.currently_due as string[]) ?? [],
  });
}

// ============================================================================
// ACCOUNT HANDLERS — v2 thin events
// ============================================================================
// V2 thin events bevatten alleen een related_object met de URL waar het
// volledige account-object opgehaald kan worden. We doen dus een extra
// GET om de actuele state te krijgen, en projecteren die naar onze
// profiles-kolommen.
async function handleAccountUpdatedV2(
  admin: any,
  event: any,
  stripeSecret: string,
  stripeApiBase: string,
) {
  const related = event?.related_object;
  const accountId = (related?.id as string | undefined) ??
    (event?.data?.object?.id as string | undefined);
  if (!accountId) {
    console.warn("v2.core.account.updated zonder account id");
    return;
  }

  // Haal volledige account op. Voor v2 GET endpoints is de include-syntax
  // ?include=field1&include=field2 (repeating query param) — GEEN include[]=
  // brackets-syntax. Die geeft 400 invalid_fields ("Some fields in the request
  // were invalid: 'include'"); brackets-vorm wordt alleen voor POST-bodies
  // gebruikt waar include een JSON-array is.
  //
  // We includen alleen wat we daadwerkelijk nodig hebben:
  //   • configuration.recipient → capabilities.stripe_balance.stripe_transfers
  //   • identity                → entries-array voor details_submitted-projectie
  //   • requirements            → currently_due voor UI feedback
  //
  // configuration.merchant en .customer NIET requesten — die zijn er voor
  // onze paaleigenaar-accounts (recipient-only) niet, en includen kan een
  // 400 triggeren als de configuratie ontbreekt op het account.
  const includes = [
    "configuration.recipient",
    "identity",
    "requirements",
  ].map((i) => `include=${encodeURIComponent(i)}`).join("&");

  const accountUrl =
    `${stripeApiBase}/v2/core/accounts/${encodeURIComponent(accountId)}?${includes}`;

  const res = await fetch(accountUrl, {
    headers: {
      Authorization: `Bearer ${stripeSecret}`,
      // Stripe v2 (preview) endpoints VEREISEN deze header — zonder krijg je
      // 400 "You did not provide an API version".
      "Stripe-Version": "2026-04-22.dahlia",
    },
  });

  if (!res.ok) {
    const errBody = await res.text();
    console.error(
      "v2.core.account get faalde:",
      res.status,
      errBody,
    );
    return;
  }

  const account = await res.json();

  // V2 account-shape: capabilities zitten onder configuration.recipient.capabilities.
  // Status per capability is 'active' / 'inactive' / 'pending' / 'unrequested'.
  //
  // BELANGRIJK voor Pluggo's destination-charges model:
  //   • Pluggo's platform is de "merchant" (int iDEAL/kaart via Checkout)
  //   • Paaleigenaren zijn pure "recipients" — ze ontvangen alleen transfers
  //   • In stripe-onboard-account requesten we ALLEEN recipient.stripe_transfers,
  //     NOOIT een merchant configuratie op het connected account.
  //
  // Daarom mappen we onze domein-velden 1-op-1 op de recipient-capability:
  //   • stripe_charges_enabled  → "kan betaald worden door Pluggo" → stripe_transfers active
  //   • stripe_payouts_enabled  → "Stripe betaalt automatisch uit naar bank" → idem
  //
  // (Vroeger checkte deze code merchant.card_payments / merchant.ideal_payments —
  // maar die capabilities zijn voor ons connected account nooit aangevraagd, dus
  // bleef chargesEnabled altijd false en flipte de profiel-status nooit naar
  // 'verified' ondanks succesvolle KYC.)
  const recipientCaps = account?.configuration?.recipient?.capabilities ?? {};

  const stripeTransfersActive =
    recipientCaps?.stripe_balance?.stripe_transfers?.status === "active";

  const chargesEnabled = stripeTransfersActive;
  const payoutsEnabled = stripeTransfersActive;

  // details_submitted = identity is volledig aangeleverd
  const detailsSubmitted =
    Array.isArray(account?.requirements?.entries) === false ||
    (account?.requirements?.entries?.length ?? 0) === 0;

  const currentlyDue =
    (account?.requirements?.entries as Array<{ description?: string }> | undefined)
      ?.map((e) => e.description ?? "")
      .filter((s) => s.length > 0) ?? [];

  await syncAccountStateToProfile(admin, accountId, {
    charges_enabled: chargesEnabled,
    payouts_enabled: payoutsEnabled,
    details_submitted: detailsSubmitted,
    disabled_reason: null, // v2 model is anders; we laten 'm leeg tenzij Stripe expliciet disabled
    currently_due: currentlyDue,
  });
}

// ----------------------------------------------------------------------------
// v2.core.account_link.returned — informatief event: gebruiker heeft de Stripe
// hosted KYC-pagina afgesloten en is teruggekeerd naar de return_url. Dit zegt
// NIETS over of de account daadwerkelijk is goedgekeurd — daarvoor moeten we
// op v2.core.account[configuration.recipient].capability_status_updated wachten.
// We loggen 'm puur voor observability en als trigger om de DB te resyncen
// (defensief — in geval Stripe geen capability-update stuurt om wat voor reden).
// ----------------------------------------------------------------------------
async function handleAccountLinkReturned(
  admin: any,
  event: any,
  stripeSecret: string,
  stripeApiBase: string,
) {
  const accountId = (event?.related_object?.id as string | undefined) ??
    (event?.data?.account as string | undefined) ??
    null;

  console.log(
    "v2.core.account_link.returned for account",
    accountId ?? "(unknown)",
  );

  if (!accountId) return;

  // Defensief: trigger ook een resync zodat we niet afhankelijk zijn van een
  // separate capability-update voor de eerste sync na onboarding-afronding.
  await handleAccountUpdatedV2(
    admin,
    { related_object: { id: accountId } },
    stripeSecret,
    stripeApiBase,
  );
}

// ============================================================================
// SHARED: project account-state naar profiles
// ============================================================================
interface AccountState {
  charges_enabled: boolean;
  payouts_enabled: boolean;
  details_submitted: boolean;
  disabled_reason: string | null;
  currently_due: string[];
}

async function syncAccountStateToProfile(
  admin: any,
  accountId: string,
  state: AccountState,
) {
  // Map ruwe Stripe-flags naar onze stripe_account_status enum
  let status: "pending" | "review" | "verified" | "restricted" | "rejected" =
    "pending";

  if (state.disabled_reason && state.disabled_reason.includes("rejected")) {
    status = "rejected";
  } else if (state.charges_enabled && state.payouts_enabled) {
    // Stripe is bron van waarheid: capability_status = active op stripe_transfers
    // betekent dat KYC voldoende voltooid is om transfers te ontvangen. We
    // checken NIET expliciet details_submitted, want v2 accounts kunnen ook
    // 'verified' zijn terwijl er nog future_requirements / eventually_due
    // entries open staan (geen blockers). Anders blijft het profiel ten
    // onrechte op 'pending' hangen terwijl het Stripe Dashboard 'Enabled' toont.
    status = "verified";
  } else if (state.disabled_reason) {
    status = "restricted";
  } else if (state.details_submitted) {
    status = "review";
  } else {
    status = "pending";
  }

  const { error: updErr } = await admin
    .from("profiles")
    .update({
      stripe_charges_enabled: state.charges_enabled,
      stripe_payouts_enabled: state.payouts_enabled,
      stripe_details_submitted: state.details_submitted,
      stripe_disabled_reason: state.disabled_reason,
      stripe_currently_due: state.currently_due,
      stripe_account_status: status,
      stripe_last_webhook_at: new Date().toISOString(),
    })
    .eq("stripe_account_id", accountId);

  if (updErr) {
    console.error(
      "syncAccountStateToProfile faalde voor",
      accountId,
      updErr,
    );
  }
}

// ============================================================================
// SIGNATURE VERIFICATION
// ============================================================================
//
// Stripe-Signature header format:
//   t=1492774577,v1=5257a869e7ecebeda32affa62cdca3fa51cad7e77a0e56ff536d0ce8e108d8bd,v0=...
//
// We computen HMAC-SHA256(`${t}.${payload}`, webhookSecret) en vergelijken
// met de v1-waarde. Constante-tijd vergelijking om timing-attacks te voorkomen.
//
// Tolerantie: events ouder dan 5 minuten weigeren (Stripe-conventie).
// ----------------------------------------------------------------------------

const TOLERANCE_SECONDS = 300;

async function verifyStripeSignature(
  payload: string,
  header: string,
  secret: string,
): Promise<boolean> {
  const parts = header.split(",").map((p) => p.trim());
  let timestamp: string | null = null;
  const sigs: string[] = [];

  for (const part of parts) {
    const [k, v] = part.split("=", 2);
    if (k === "t") timestamp = v;
    if (k === "v1") sigs.push(v);
  }

  if (!timestamp || sigs.length === 0) return false;

  // Tolerantie check
  const ts = Number(timestamp);
  if (!Number.isFinite(ts)) return false;
  const nowSec = Math.floor(Date.now() / 1000);
  if (Math.abs(nowSec - ts) > TOLERANCE_SECONDS) {
    console.warn("stripe-webhook: timestamp outside tolerance", ts, nowSec);
    return false;
  }

  const signedPayload = `${timestamp}.${payload}`;

  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuffer = await crypto.subtle.sign(
    "HMAC",
    key,
    enc.encode(signedPayload),
  );
  const expected = bufToHex(sigBuffer);

  for (const candidate of sigs) {
    if (constantTimeEqual(expected, candidate)) return true;
  }
  return false;
}

function bufToHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

// ============================================================================
// UTIL
// ============================================================================

function timeoutPromise(ms: number): Promise<never> {
  return new Promise((_, reject) =>
    setTimeout(() => reject(new Error(`Handler timeout after ${ms}ms`)), ms)
  );
}
