// Pluggo — create-payment edge function (pay-after-charge model)
// ----------------------------------------------------------------------------
// Wordt aangeroepen door de Flutter app als de boeker wil afrekenen, NADAT
// de eigenaar het werkelijk afgenomen kWh heeft ingevuld. Deze functie:
//   1. Verifieert de gebruiker (Supabase JWT) en haalt de boeking op
//   2. Vereist dat kwh_consumed + payment_requested_at gezet zijn
//   3. Berekent total / fee / owner_share op basis van werkelijke kWh × prijs
//   4. Maakt een Mollie betaling aan via de Mollie Payments API
//   5. Slaat een rij op in `payments` met de Mollie ID en checkout URL
//   6. Update de boeking met payment_status = 'pending' + bedragen
//   7. Geeft de checkout_url terug aan de app
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

// Pluggo fee-model (per mei 2026): vaste €0,03/kWh aan beide kanten +
// een eenmalige €0,40 transactiefee bij mini-sessies onder 10 kWh.
//   booker betaalt = kWh × (paalprijs + €0,03) + €0,40 als kWh < 10
//   host ontvangt  = kWh × (paalprijs − €0,03)  — altijd, los van sessiegrootte
//   pluggo houdt   = kWh × €0,06 + (kWh < 10 ? €0,40 : 0)
// Bewust geen percentage: Mollie's iDEAL fixed fee (~€0,32) zou een
// procentuele fee bij kleine sessies onder kostprijs duwen. De €0,40
// small-session fee dekt expliciet de iDEAL-transactiekosten op kleine
// sessies; bij grotere sessies dekt de €0,06/kWh ze ruimschoots.
// Moet identiek blijven aan lib/main.dart.
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
    // total_amount_cents wordt door de owner vastgezet bij het betaalverzoek
    // en is daarna onveranderlijk; het is de bron van waarheid voor het
    // werkelijk te betalen bedrag (bug #69).
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

    // Pay-after-charge: owner moet eerst kWh hebben ingevuld
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
    // 4. Bereken bedragen
    //    Bron van waarheid is total_amount_cents op de boeking — dat is
    //    vastgezet door de owner op het moment van het betaalverzoek en
    //    wijzigt daarna niet meer, ook niet als de owner de paalprijs
    //    aanpast (bug #69). Alleen als total_amount_cents om wat voor
    //    reden dan ook ontbreekt vallen we terug op een live berekening.
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
    let serviceFeeCents: number;
    let ownerShareCents: number;

    if (
      typeof lockedTotalCents === "number" &&
      lockedTotalCents > 0 &&
      typeof lockedFeeCents === "number" &&
      typeof lockedOwnerShareCents === "number"
    ) {
      // Gebruik de snapshot die door de owner is vastgezet.
      totalCents = lockedTotalCents;
      serviceFeeCents = lockedFeeCents;
      ownerShareCents = lockedOwnerShareCents;
    } else {
      // Fallback: live berekenen uit kWh × current paalprijs. Zou voor
      // moderne boekingen niet voor moeten komen, maar oude rijen of
      // race-conditions kunnen het triggeren.
      const pricePerKwh = Number(charger.price);
      if (!Number.isFinite(pricePerKwh) || pricePerKwh <= 0) {
        return jsonError("Ongeldige prijs op paal", 500);
      }
      // Booker betaalt paalprijs + €0,03/kWh + €0,40 als kWh < 10.
      const smallFeeEur = smallSessionFeeFor(kwh);
      const totalEuro =
        kwh * (pricePerKwh + BOOKER_FEE_EUR_PER_KWH) + smallFeeEur;
      totalCents = Math.round(totalEuro * 100);
      // Pluggo houdt €0,06/kWh + eventuele small-session fee.
      // Host-aandeel blijft kWh × (paalprijs − €0,03), onafhankelijk van fees.
      serviceFeeCents =
        Math.round(kwh * PLUGGO_FEE_EUR_PER_KWH * 100) +
        Math.round(smallFeeEur * 100);
      ownerShareCents = totalCents - serviceFeeCents;
    }

    if (totalCents < MOLLIE_MIN_CENTS) {
      return jsonError(
        `Bedrag te laag voor betaling (minimum €${(MOLLIE_MIN_CENTS / 100).toFixed(2)})`,
        400
      );
    }

    // -----------------------------------------------------------------------
    // 4b. Voorkom dubbele Mollie payments per boeking (bug #72).
    //
    // Scenario: booker tikt op "Betalen", komt op de Mollie pagina, drukt op
    // back/sluit het tabblad zonder te betalen, en tikt later opnieuw op
    // "Betalen". Zonder deze guard maken we elke keer een verse Mollie payment
    // aan en eindigen we met meerdere `pending` rijen voor één boeking — met
    // risico op dubbele betaling en reconciliation-puzzels.
    //
    // Aanpak:
    //   1. Zoek bestaande pending payment(s) voor deze boeking
    //   2. Re-fetch de status bij Mollie (onze DB kan achterlopen op webhooks)
    //   3. Als Mollie zegt "open" of "pending": hergebruik die checkout URL
    //   4. Anders (canceled/expired/failed): markeer als zodanig en val door
    //      naar het aanmaken van een nieuwe payment
    // -----------------------------------------------------------------------
    {
      const { data: existing, error: existingErr } = await admin
        .from("payments")
        .select("id, mollie_payment_id, checkout_url, status")
        .eq("booking_id", (booking as any).id)
        .eq("status", "pending")
        .order("created_at", { ascending: false });

      if (existingErr) {
        console.error("Kon bestaande payments niet ophalen:", existingErr);
        // Niet fataal — we gaan gewoon door en maken een nieuwe aan.
      } else if (existing && existing.length > 0) {
        const candidate = existing[0];

        // Eventuele extra rijen markeren we direct als 'failed' (mogen er niet
        // staan, maar als ze er zijn willen we maar één pending rij overhouden).
        if (existing.length > 1) {
          const extraIds = existing.slice(1).map((r: any) => r.id);
          await admin
            .from("payments")
            .update({ status: "failed" })
            .in("id", extraIds);
        }

        // Recheck bij Mollie zodat we niet vertrouwen op een verouderde DB-status.
        try {
          const recheckRes = await fetch(
            `https://api.mollie.com/v2/payments/${encodeURIComponent(
              candidate.mollie_payment_id
            )}`,
            { headers: { Authorization: `Bearer ${mollieApiKey}` } }
          );

          if (recheckRes.ok) {
            const recheckPayment = await recheckRes.json();
            const live = recheckPayment.status as string | undefined;

            if (live === "open" || live === "pending") {
              // Nog actief bij Mollie — hergebruik dezelfde checkout URL.
              // checkout_url is bij Mollie iDEAL stabiel zolang de payment open is.
              const reuseUrl =
                (recheckPayment?._links?.checkout?.href as string | undefined) ??
                candidate.checkout_url;

              if (reuseUrl) {
                return new Response(
                  JSON.stringify({
                    checkout_url: reuseUrl,
                    payment_id: candidate.id,
                    amount_cents: totalCents,
                    service_fee_cents: serviceFeeCents,
                    owner_share_cents: ownerShareCents,
                    reused: true,
                  }),
                  {
                    headers: {
                      ...corsHeaders,
                      "Content-Type": "application/json",
                    },
                    status: 200,
                  }
                );
              }
            }

            // Mollie zegt afgesloten (canceled/expired/failed) — markeer onze rij
            // zodat de status klopt en val door naar het aanmaken van een nieuwe.
            const mappedStatus =
              live === "paid"
                ? "paid"
                : live === "canceled" ||
                    live === "expired" ||
                    live === "failed"
                  ? "failed"
                  : "pending";

            await admin
              .from("payments")
              .update({ status: mappedStatus })
              .eq("id", candidate.id);

            // Edge case: Mollie zegt al "paid" maar onze webhook is dat nog niet
            // voor geweest. In dat geval moeten we GEEN nieuwe payment aanmaken.
            if (live === "paid") {
              await admin
                .from("bookings")
                .update({ payment_status: "paid" })
                .eq("id", (booking as any).id);
              return jsonError(
                "Deze boeking is al betaald (Mollie meldt 'paid').",
                409
              );
            }
          } else {
            // Mollie API faalt — wees conservatief: hergebruik de bestaande
            // checkout_url als die er is, in plaats van een nieuwe aan te maken
            // (anders riskeren we dubbele payments bij een transient API issue).
            if (candidate.checkout_url) {
              return new Response(
                JSON.stringify({
                  checkout_url: candidate.checkout_url,
                  payment_id: candidate.id,
                  amount_cents: totalCents,
                  service_fee_cents: serviceFeeCents,
                  owner_share_cents: ownerShareCents,
                  reused: true,
                  note: "mollie recheck failed, reusing cached url",
                }),
                {
                  headers: {
                    ...corsHeaders,
                    "Content-Type": "application/json",
                  },
                  status: 200,
                }
              );
            }
          }
        } catch (recheckErr) {
          console.error("Mollie recheck faalde:", recheckErr);
          // Zelfde defensieve aanpak: hergebruik wat we hebben, indien mogelijk.
          if (candidate.checkout_url) {
            return new Response(
              JSON.stringify({
                checkout_url: candidate.checkout_url,
                payment_id: candidate.id,
                amount_cents: totalCents,
                service_fee_cents: serviceFeeCents,
                owner_share_cents: ownerShareCents,
                reused: true,
                note: "mollie recheck threw, reusing cached url",
              }),
              {
                headers: {
                  ...corsHeaders,
                  "Content-Type": "application/json",
                },
                status: 200,
              }
            );
          }
        }
      }
    }

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
