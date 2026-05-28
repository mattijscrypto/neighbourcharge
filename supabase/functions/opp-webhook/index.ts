// Pluggo — opp-webhook edge function
// ----------------------------------------------------------------------------
// Wordt aangeroepen door Online Payment Platform (OPP) bij elke statusverandering
// op een transaction, merchant, of bank_account die wij hebben gekoppeld.
//
// OPP webhook payload (JSON body):
//   {
//     "uid": "<notification_uid>",
//     "type": "transaction.status.changed" | "merchant.compliance_status.changed"
//            | "merchant.compliance_level.changed" | "bank_account.status.changed",
//     "created": <unix_ts>,
//     "object_uid": "<resource_uid>",
//     "object_type": "transaction" | "merchant" | "bank_account",
//     "object_url": "https://api-(sandbox.)onlinebetaalplatform.nl/v1/...",
//     "verification_hash": "<hmac_or_token>"
//   }
//
// Best practice (zelfde als Mollie):
//   • Vertrouw de body niet — re-fetch het object via OPP API om de actuele
//     status te krijgen. verification_hash valideren we tegen de partner secret.
//   • Altijd 200 terug zodra verwerkt — OPP retryt anders met backoff.
//   • Webhook is publiek bereikbaar, dus verify_jwt=false in config.toml.
//
// Secrets / env:
//   • OPP_API_KEY            — bearer token partner-level
//   • OPP_API_BASE_URL       — sandbox of productie (defaults naar sandbox)
//   • OPP_WEBHOOK_SECRET     — gedeelde secret voor verification_hash validatie
//                              (te bevestigen met OPP sales — formaat HMAC-SHA256?)
//   • SUPABASE_URL           (auto)
//   • SUPABASE_SERVICE_ROLE_KEY (auto)
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface OppNotification {
  uid: string;
  type: string;
  created: number;
  object_uid: string;
  object_type: string;
  object_url: string;
  verification_hash?: string;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("ok", { status: 200 });
  }

  try {
    // -----------------------------------------------------------------------
    // 1. Parse JSON body
    // -----------------------------------------------------------------------
    let notif: OppNotification;
    try {
      notif = (await req.json()) as OppNotification;
    } catch (_) {
      console.error("OPP webhook: ongeldige JSON body");
      return new Response("bad json", { status: 400 });
    }

    if (!notif?.object_uid || !notif?.object_type || !notif?.type) {
      console.error("OPP webhook: incomplete payload", notif);
      return new Response("incomplete", { status: 400 });
    }

    // -----------------------------------------------------------------------
    // 2. Env + clients
    // -----------------------------------------------------------------------
    const oppApiKey = Deno.env.get("OPP_API_KEY");
    const oppApiBase =
      Deno.env.get("OPP_API_BASE_URL") ??
      "https://api-sandbox.onlinebetaalplatform.nl/v1";
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!oppApiKey || !supabaseUrl || !supabaseServiceKey) {
      console.error("OPP webhook env niet compleet");
      return new Response("server config", { status: 500 });
    }

    // TODO: verification_hash valideren zodra we van OPP weten welk algoritme
    // ze gebruiken (HMAC-SHA256 van partner secret? Of opvragen via API?).
    // Voor nu: re-fetch het object server-side om authenticiteit te bevestigen.

    const admin = createClient(supabaseUrl, supabaseServiceKey);

    // -----------------------------------------------------------------------
    // 3. Route naar handler op basis van object_type
    // -----------------------------------------------------------------------
    switch (notif.object_type) {
      case "transaction":
        return await handleTransactionStatus(notif, oppApiKey, oppApiBase, admin, supabaseUrl, supabaseServiceKey);
      case "merchant":
        return await handleMerchantStatus(notif, oppApiKey, oppApiBase, admin);
      case "bank_account":
        return await handleBankAccountStatus(notif, oppApiKey, oppApiBase, admin);
      default:
        console.warn("OPP webhook: onbekend object_type", notif.object_type);
        return new Response("ok (ignored)", { status: 200 });
    }
  } catch (err) {
    console.error("OPP webhook fatal error:", err);
    return new Response("error", { status: 500 });
  }
});

// ============================================================================
// Transaction status changed → update payments + bookings, trigger downstream
// ============================================================================
async function handleTransactionStatus(
  notif: OppNotification,
  oppApiKey: string,
  oppApiBase: string,
  admin: any,
  supabaseUrl: string,
  supabaseServiceKey: string,
): Promise<Response> {
  const txnUid = notif.object_uid;

  // Re-fetch transactie
  const txnRes = await fetch(`${oppApiBase}/transactions/${encodeURIComponent(txnUid)}`, {
    headers: { Authorization: `Bearer ${oppApiKey}` },
  });
  if (!txnRes.ok) {
    console.error("OPP transaction fetch faalde", txnRes.status, await txnRes.text());
    return new Response("opp error", { status: 502 });
  }
  const txn = await txnRes.json();
  const oppStatus = txn.status as string | undefined;
  const newStatus = mapOppTransactionStatus(oppStatus);
  const completedAt = oppStatus === "completed" && txn.completed
    ? new Date((txn.completed as number) * 1000).toISOString()
    : null;

  // Vind onze payment row
  const { data: paymentRow, error: pErr } = await admin
    .from("payments")
    .select("id, booking_id, status")
    .eq("opp_transaction_uid", txnUid)
    .maybeSingle();

  if (pErr) {
    console.error("DB fetch error:", pErr);
    return new Response("db error", { status: 500 });
  }
  if (!paymentRow) {
    console.warn("Payment niet gevonden voor OPP txn uid:", txnUid);
    return new Response("not found (ignored)", { status: 200 });
  }

  // Idempotent: zelfde status = geen werk
  if (paymentRow.status === newStatus && newStatus === "paid") {
    return new Response("ok (no change)", { status: 200 });
  }

  // Update payment
  const { error: updErr } = await admin
    .from("payments")
    .update({
      status: newStatus,
      opp_status: oppStatus ?? null,
      paid_at: completedAt,
      opp_completed_at: completedAt,
    })
    .eq("id", paymentRow.id);

  if (updErr) {
    console.error("Kon payment niet updaten:", updErr);
    return new Response("db error", { status: 500 });
  }

  // Was de booking vóór deze update al paid? (idempotency push-notif)
  const wasAlreadyPaidOnBooking = await (async () => {
    const { data: bRow } = await admin
      .from("bookings")
      .select("payment_status")
      .eq("id", paymentRow.booking_id)
      .maybeSingle();
    return bRow?.payment_status === "paid";
  })();

  // Update booking-status door ALLE payments te lezen (bug #71 fix)
  const { data: allPayments, error: listErr } = await admin
    .from("payments")
    .select("status")
    .eq("booking_id", paymentRow.booking_id);

  let derivedStatus = newStatus;
  if (!listErr && allPayments) {
    if (allPayments.some((p: any) => p.status === "paid")) {
      derivedStatus = "paid";
    } else if (allPayments.some((p: any) => p.status === "pending")) {
      derivedStatus = "pending";
    } else if (allPayments.length > 0) {
      derivedStatus = "failed";
    } else {
      derivedStatus = "unpaid";
    }
  }

  await admin
    .from("bookings")
    .update({ payment_status: derivedStatus })
    .eq("id", paymentRow.booking_id);

  // ---------------------------------------------------------------------
  // Side effects bij eerste-keer-paid:
  //   1. Push naar paaleigenaar
  //   2. Trigger invoice-engine (self-billing PDF)
  // ---------------------------------------------------------------------
  if (derivedStatus === "paid" && !wasAlreadyPaidOnBooking) {
    try {
      const { data: bookingRow } = await admin
        .from("bookings")
        .select(
          "id, user_name, total_amount_cents, charger_id, chargers(owner_id, name)"
        )
        .eq("id", paymentRow.booking_id)
        .maybeSingle();

      const charger = (bookingRow as any)?.chargers;
      const ownerId = charger?.owner_id as string | undefined;
      const chargerName = (charger?.name as string | undefined) ?? "je laadpaal";
      const bookerName = (bookingRow?.user_name as string | undefined) ?? "De boeker";
      const totalCents = (bookingRow?.total_amount_cents as number | undefined) ?? 0;
      const euro = (totalCents / 100).toFixed(2).replace(".", ",");

      // Push notif
      if (ownerId) {
        fetch(`${supabaseUrl}/functions/v1/send-push`, {
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
        }).catch((e) => console.error("send-push failed:", e));
      }

      // Invoice-engine (genereert self-billing factuur PDF en mailt 'm)
      // Implementatie staat in /functions/generate-self-billing-invoice (TODO)
      fetch(`${supabaseUrl}/functions/v1/generate-self-billing-invoice`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${supabaseServiceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ payment_id: paymentRow.id }),
      }).catch((e) => console.error("invoice-engine failed:", e));
    } catch (e) {
      console.error("Side effects faalden:", e);
    }
  }

  return new Response("ok", { status: 200 });
}

// ============================================================================
// Merchant compliance status / level changed → update profiles.opp_* velden
// ============================================================================
async function handleMerchantStatus(
  notif: OppNotification,
  oppApiKey: string,
  oppApiBase: string,
  admin: any,
): Promise<Response> {
  const merchantUid = notif.object_uid;

  const mRes = await fetch(`${oppApiBase}/merchants/${encodeURIComponent(merchantUid)}`, {
    headers: { Authorization: `Bearer ${oppApiKey}` },
  });
  if (!mRes.ok) {
    console.error("OPP merchant fetch faalde", mRes.status);
    return new Response("opp error", { status: 502 });
  }
  const merchant = await mRes.json();

  const complianceLevel = (merchant?.compliance?.level as number | undefined) ?? null;
  const complianceStatus = (merchant?.compliance?.status as string | undefined) ?? "unverified";
  // canReceivePayments / canReceiveSettlements derived uit compliance status
  const canReceivePayments = complianceStatus === "verified" || complianceStatus === "review";
  const canReceivePayouts = complianceStatus === "verified";

  const { error: updErr } = await admin
    .from("profiles")
    .update({
      opp_compliance_level: complianceLevel,
      opp_compliance_status: mapOppComplianceStatus(complianceStatus),
      opp_can_receive_payments: canReceivePayments,
      opp_can_receive_payouts: canReceivePayouts,
      opp_onboarding_completed_at: canReceivePayouts ? new Date().toISOString() : null,
    })
    .eq("opp_merchant_uid", merchantUid);

  if (updErr) {
    console.error("Kon profile niet updaten:", updErr);
    return new Response("db error", { status: 500 });
  }

  return new Response("ok", { status: 200 });
}

// ============================================================================
// Bank account status changed → update profiles.opp_bank_account_status
// ============================================================================
async function handleBankAccountStatus(
  notif: OppNotification,
  oppApiKey: string,
  oppApiBase: string,
  admin: any,
): Promise<Response> {
  // object_url bevat het volledige merchant + bank_account pad
  // Bv: https://api-sandbox.onlinebetaalplatform.nl/v1/merchants/{merchant_uid}/bank_accounts/{bank_uid}
  const url = notif.object_url ?? "";
  const merchantMatch = url.match(/\/merchants\/([^/]+)\//);
  const merchantUid = merchantMatch?.[1];

  if (!merchantUid) {
    console.warn("OPP bank_account notif zonder merchant in URL:", url);
    return new Response("ok (no merchant)", { status: 200 });
  }

  // Re-fetch het bank account
  const baRes = await fetch(url, {
    headers: { Authorization: `Bearer ${oppApiKey}` },
  });
  if (!baRes.ok) {
    console.error("OPP bank fetch faalde", baRes.status);
    return new Response("opp error", { status: 502 });
  }
  const ba = await baRes.json();
  const baStatus = (ba?.status as string | undefined) ?? null;
  const baUid = (ba?.uid as string | undefined) ?? notif.object_uid;

  await admin
    .from("profiles")
    .update({
      opp_bank_account_uid: baUid,
      opp_bank_account_status: baStatus,
    })
    .eq("opp_merchant_uid", merchantUid);

  return new Response("ok", { status: 200 });
}

// ============================================================================
// Mappers
// ============================================================================
function mapOppTransactionStatus(s: string | undefined): string {
  switch (s) {
    case "completed":
      return "paid";
    case "created":
    case "pending":
    case "reserved":
      return "pending";
    case "cancelled":
    case "expired":
    case "failed":
    case "refunded":
      return "failed";
    default:
      return "pending";
  }
}

function mapOppComplianceStatus(s: string): string {
  switch (s) {
    case "verified":
      return "verified";
    case "rejected":
    case "disapproved":
      return "rejected";
    case "review":
    case "pending":
      return "review";
    default:
      return "unverified";
  }
}
