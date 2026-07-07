// Pluggo CSMS — Supabase-bridge
// Wraps @supabase/supabase-js met CSMS-specifieke helpers voor sessie-lifecycle.
//
// Ontwerp-principe: DB is "best-effort". De OCPP-response naar de paal moet
// ALTIJD binnen ~1 seconde vertrekken, ongeacht of Supabase up is, traag is,
// of een fout gooit. Anders timeout de paal en dumpt-ie z'n backlog opnieuw.
//
// Daarom:
//   1. Elke DB-call wordt gewrapped in try/catch (geen unhandled rejections).
//   2. Elke DB-call heeft een harde timeout van DB_TIMEOUT_MS.
//   3. Bij fout/timeout: logging + graceful fallback (lokale tx-id), server draait door.

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Harde upper-bound op elke DB-call. OCPP-paal timeout is doorgaans 30s;
// wij mikken op sub-seconde om zeker binnen die bound te blijven.
const DB_TIMEOUT_MS = 3000;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.warn('[SUPABASE] WAARSCHUWING: SUPABASE_URL of SUPABASE_SERVICE_ROLE_KEY ontbreekt in .env.');
  console.warn('[SUPABASE] Server draait door zonder DB-persistentie. Sessies alleen in console-log.');
}

export const supabase = (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY)
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    })
  : null;

// ==========================================================================
// Helpers
// ==========================================================================

/**
 * Wrap een Supabase-thenable met een timeout. Als de call niet binnen
 * timeoutMs voltooit, wordt de promise gerejected met een Error.
 * De Supabase-call zelf loopt op de achtergrond nog even door — dat is prima,
 * we negeren het resultaat.
 */
function withTimeout(thenable, label, timeoutMs = DB_TIMEOUT_MS) {
  return Promise.race([
    thenable,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`[SUPABASE] ${label} timed out after ${timeoutMs}ms`)), timeoutMs),
    ),
  ]);
}

/**
 * Voer een async DB-actie uit, vang alle fouten op, log ze,
 * en return een fallback-waarde. NOOIT throwen.
 */
async function safeCall(label, fn, fallback) {
  try {
    return await fn();
  } catch (err) {
    console.error(`[SUPABASE] ${label} failed:`, err?.message ?? err);
    return fallback;
  }
}

// ==========================================================================
// Session lifecycle helpers
// ==========================================================================

/**
 * Zoekt Pluggo-charger uuid op basis van OCPP identity.
 * Return null als paal (nog) niet gemapped is in chargers.ocpp_charger_id.
 */
export async function findChargerByOcppId(ocppChargerId) {
  if (!supabase) return null;
  return safeCall('findChargerByOcppId', async () => {
    const { data, error } = await withTimeout(
      supabase
        .from('chargers')
        .select('id, owner_id')
        .eq('ocpp_charger_id', ocppChargerId)
        .maybeSingle(),
      'findChargerByOcppId',
    );
    if (error) {
      console.error('[SUPABASE] findChargerByOcppId error:', error.message);
      return null;
    }
    return data;
  }, null);
}

/**
 * StartTransaction: INSERT + return transaction_id.
 * Return de bigint transaction_id die aan de paal teruggegeven moet worden.
 * Bij DB-fout of timeout: return een lokale fallback-id (niet gepersisteerd),
 * zodat de OCPP-response niet blokkeert.
 */
let localFallbackTxId = 1_000_000_000; // hoge start zodat lokaal ≠ echte tx-ids

export async function createSession({ ocppChargerId, connectorId, idTag, meterStartWh, bootPayload }) {
  if (!supabase) {
    return { transactionId: localFallbackTxId++, persisted: false };
  }

  return safeCall('createSession', async () => {
    const charger = await findChargerByOcppId(ocppChargerId);

    const { data, error } = await withTimeout(
      supabase
        .from('charging_sessions')
        .insert({
          ocpp_charger_id: ocppChargerId,
          connector_id: connectorId,
          id_tag: idTag,
          charger_id: charger?.id ?? null,
          meter_start_wh: meterStartWh,
          meter_current_wh: meterStartWh,
          status: 'in_progress',
          boot_payload: bootPayload ?? null,
        })
        .select('transaction_id')
        .single(),
      'createSession.insert',
    );

    if (error) {
      console.error('[SUPABASE] createSession error:', error.message);
      return { transactionId: localFallbackTxId++, persisted: false };
    }
    return { transactionId: data.transaction_id, persisted: true };
  }, { transactionId: localFallbackTxId++, persisted: false });
}

/**
 * MeterValues: append log + update current meter op sessie (triggert Realtime).
 * Idempotent — dubbele meter values met dezelfde timestamp worden genegeerd.
 * Bij DB-fout of timeout: alleen loggen, geen crash.
 */
export async function recordMeterValue({ transactionId, meterWh, measuredAt, rawPayload }) {
  if (!supabase) return;

  await safeCall('recordMeterValue.log', async () => {
    const { error } = await withTimeout(
      supabase
        .from('charging_session_meter_values')
        .insert({
          transaction_id: transactionId,
          meter_wh: meterWh,
          measured_at: measuredAt,
          raw_payload: rawPayload ?? null,
        }),
      'recordMeterValue.log',
    );
    if (error && !error.message?.includes('duplicate key')) {
      console.error('[SUPABASE] recordMeterValue log-insert error:', error.message);
    }
  }, undefined);

  await safeCall('recordMeterValue.update', async () => {
    const { error } = await withTimeout(
      supabase
        .from('charging_sessions')
        .update({
          meter_current_wh: meterWh,
          last_meter_at: measuredAt,
        })
        .eq('transaction_id', transactionId),
      'recordMeterValue.update',
    );
    if (error) {
      console.error('[SUPABASE] recordMeterValue session-update error:', error.message);
    }
  }, undefined);
}

/**
 * StopTransaction: sluit sessie af.
 * Bij DB-fout of timeout: alleen loggen, geen crash.
 */
export async function closeSession({ transactionId, meterStopWh, stopReason, stopPayload }) {
  if (!supabase) return;

  await safeCall('closeSession', async () => {
    const { error } = await withTimeout(
      supabase
        .from('charging_sessions')
        .update({
          meter_stop_wh: meterStopWh,
          meter_current_wh: meterStopWh,
          status: 'completed',
          stop_reason: stopReason ?? 'Local',
          stopped_at: new Date().toISOString(),
          stop_payload: stopPayload ?? null,
        })
        .eq('transaction_id', transactionId),
      'closeSession',
    );

    if (error) {
      console.error('[SUPABASE] closeSession error:', error.message);
    }
  }, undefined);
}

// ==========================================================================
// Globale safety-net: unhandled promise rejections mogen NOOIT de server killen
// ==========================================================================
process.on('unhandledRejection', (reason) => {
  console.error('[UNHANDLED REJECTION]', reason);
});
process.on('uncaughtException', (err) => {
  console.error('[UNCAUGHT EXCEPTION]', err);
});
