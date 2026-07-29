// ============================================================================
// resync-all-stripe-accounts.ts — one-off Deno script
// ============================================================================
//
// Doel: alle connected accounts die op 'pending' of 'review' staan in de
// profiles-tabel forceren te resyncen tegen de actuele Stripe-state.
//
// Reden: de v2 webhook destination was tussen 22 juni en 2 juli 2026 verkeerd
// geconfigureerd (verkeerde subscription + verkeerd whsec). Accounts die in
// die periode succesvol de KYC-flow hebben voltooid staan in Stripe op
// "Enabled" (charges_enabled=true, payouts_enabled=true) maar in de Pluggo-DB
// nog op 'pending', waardoor ze in de app geen palen kunnen aanmaken.
//
// Deze script draait de exact same projectie-logica als handleAccountUpdatedV2
// in de webhook, maar voor alle relevante accounts in één batch — zonder van
// echte Stripe-events afhankelijk te zijn.
//
// Usage:
//   STRIPE_SECRET_KEY=sk_live_... \
//   SUPABASE_URL=https://<ref>.supabase.co \
//   SUPABASE_SERVICE_ROLE_KEY=eyJ... \
//   deno run --allow-net --allow-env \
//     supabase/scripts/resync-all-stripe-accounts.ts
//
// Flags:
//   --dry-run    Toon wat er zou gebeuren, geen writes naar Supabase
//   --account acct_xxx   Alleen dit specifieke account resyncen
//
// ============================================================================

const STRIPE_API_BASE = "https://api.stripe.com";
const STRIPE_API_VERSION = "2026-04-22.dahlia";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!STRIPE_SECRET_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    "Missing env vars. Required: STRIPE_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY",
  );
  Deno.exit(1);
}

const args = Deno.args;
const DRY_RUN = args.includes("--dry-run");
const SINGLE_ACCOUNT_IDX = args.indexOf("--account");
const SINGLE_ACCOUNT =
  SINGLE_ACCOUNT_IDX >= 0 ? args[SINGLE_ACCOUNT_IDX + 1] : null;

console.log(
  `[resync] mode=${DRY_RUN ? "DRY-RUN" : "LIVE"}  ${
    SINGLE_ACCOUNT ? `account=${SINGLE_ACCOUNT}` : "target=all pending/review"
  }`,
);

// ----------------------------------------------------------------------------
// 1. Kandidaten ophalen uit profiles
// ----------------------------------------------------------------------------
interface ProfileRow {
  id: string;
  stripe_account_id: string;
  stripe_account_status: string;
  email?: string;
  full_name?: string;
}

async function fetchCandidates(): Promise<ProfileRow[]> {
  const url = new URL(`${SUPABASE_URL}/rest/v1/profiles`);
  url.searchParams.set(
    "select",
    "id,stripe_account_id,stripe_account_status,email,full_name",
  );
  url.searchParams.set("stripe_account_id", "not.is.null");
  if (SINGLE_ACCOUNT) {
    url.searchParams.set("stripe_account_id", `eq.${SINGLE_ACCOUNT}`);
  } else {
    // Focus op wat vastzit: pending/review. verified/restricted/rejected slaan we over,
    // die zijn al gesynced (behalve als je --account gebruikt om ze te forceren).
    url.searchParams.set(
      "stripe_account_status",
      "in.(pending,review)",
    );
  }

  const res = await fetch(url.toString(), {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY!}`,
    },
  });
  if (!res.ok) {
    throw new Error(
      `fetchCandidates failed: ${res.status} ${await res.text()}`,
    );
  }
  return (await res.json()) as ProfileRow[];
}

// ----------------------------------------------------------------------------
// 2. Voor elk account: haal actuele state uit Stripe v2 API
// ----------------------------------------------------------------------------
interface AccountState {
  charges_enabled: boolean;
  payouts_enabled: boolean;
  details_submitted: boolean;
  disabled_reason: string | null;
  currently_due: string[];
}

async function fetchStripeAccountState(
  accountId: string,
): Promise<AccountState | null> {
  const includes = [
    "configuration.recipient",
    "identity",
    "requirements",
  ].map((i) => `include=${encodeURIComponent(i)}`).join("&");

  const url =
    `${STRIPE_API_BASE}/v2/core/accounts/${encodeURIComponent(accountId)}?${includes}`;

  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY!}`,
      "Stripe-Version": STRIPE_API_VERSION,
    },
  });

  if (!res.ok) {
    console.error(
      `  ! stripe GET faalde voor ${accountId}: ${res.status} ${await res
        .text()}`,
    );
    return null;
  }

  const account = await res.json();

  const recipientCaps = account?.configuration?.recipient?.capabilities ?? {};
  const stripeTransfersActive =
    recipientCaps?.stripe_balance?.stripe_transfers?.status === "active";

  const chargesEnabled = stripeTransfersActive;
  const payoutsEnabled = stripeTransfersActive;

  const detailsSubmitted =
    Array.isArray(account?.requirements?.entries) === false ||
    (account?.requirements?.entries?.length ?? 0) === 0;

  const currentlyDue =
    (account?.requirements?.entries as
      | Array<{ description?: string }>
      | undefined)
      ?.map((e) => e.description ?? "")
      .filter((s) => s.length > 0) ?? [];

  return {
    charges_enabled: chargesEnabled,
    payouts_enabled: payoutsEnabled,
    details_submitted: detailsSubmitted,
    disabled_reason: null, // v2 model — leeg tenzij Stripe expliciet disabled
    currently_due: currentlyDue,
  };
}

// ----------------------------------------------------------------------------
// 3. Projecteer state → profiles-kolommen (spiegelt syncAccountStateToProfile)
// ----------------------------------------------------------------------------
function computeStatus(state: AccountState): string {
  if (state.disabled_reason && state.disabled_reason.includes("rejected")) {
    return "rejected";
  }
  if (state.charges_enabled && state.payouts_enabled) return "verified";
  if (state.disabled_reason) return "restricted";
  if (state.details_submitted) return "review";
  return "pending";
}

async function writeProfile(
  accountId: string,
  state: AccountState,
): Promise<void> {
  const status = computeStatus(state);

  const url = new URL(`${SUPABASE_URL}/rest/v1/profiles`);
  url.searchParams.set("stripe_account_id", `eq.${accountId}`);

  const body = {
    stripe_charges_enabled: state.charges_enabled,
    stripe_payouts_enabled: state.payouts_enabled,
    stripe_details_submitted: state.details_submitted,
    stripe_disabled_reason: state.disabled_reason,
    stripe_currently_due: state.currently_due,
    stripe_account_status: status,
    stripe_last_webhook_at: new Date().toISOString(),
  };

  if (DRY_RUN) {
    console.log(`  [DRY-RUN] zou UPDATE doen:`, body);
    return;
  }

  const res = await fetch(url.toString(), {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY!,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY!}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    console.error(
      `  ! profiles PATCH faalde voor ${accountId}: ${res.status} ${await res
        .text()}`,
    );
  }
}

// ----------------------------------------------------------------------------
// MAIN
// ----------------------------------------------------------------------------
const candidates = await fetchCandidates();
console.log(`[resync] ${candidates.length} kandidaten gevonden`);

let updated = 0;
let unchanged = 0;
let failed = 0;

for (const profile of candidates) {
  const label = `${profile.stripe_account_id} (${
    profile.full_name ?? profile.email ?? profile.id
  }) [was: ${profile.stripe_account_status}]`;
  console.log(`\n[resync] ${label}`);

  const state = await fetchStripeAccountState(profile.stripe_account_id);
  if (!state) {
    failed++;
    continue;
  }

  const newStatus = computeStatus(state);
  console.log(
    `  → new_status=${newStatus}  charges=${state.charges_enabled}  payouts=${state.payouts_enabled}  details_submitted=${state.details_submitted}`,
  );
  if (state.currently_due.length > 0) {
    console.log(`  currently_due:`, state.currently_due);
  }

  if (newStatus === profile.stripe_account_status) {
    unchanged++;
    console.log(`  ↳ status ongewijzigd`);
  } else {
    console.log(
      `  ↳ status flip: ${profile.stripe_account_status} → ${newStatus}`,
    );
    updated++;
  }

  await writeProfile(profile.stripe_account_id, state);
}

console.log(
  `\n[resync] klaar. updated=${updated}  unchanged=${unchanged}  failed=${failed}  total=${candidates.length}`,
);
