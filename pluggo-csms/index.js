// Pluggo CSMS — OCPP 1.6J server met Supabase-persistentie + app-driven commands
//
// Twee poorten:
//   - ws://localhost:9000       — chargepoints praten hier OCPP
//   - http://localhost:9001     — Pluggo-app (via Edge Function) triggert
//                                  RemoteStart/Stop hier
//
// Sessie-events worden via lib/supabase.js gepersisteerd. Actieve connecties
// worden bijgehouden in lib/connections.js zodat de HTTP-API outbound calls
// naar de juiste paal kan routeren.

import 'dotenv/config';
import { RPCServer, createRPCError } from 'ocpp-rpc';
import {
  supabase,
  createSession,
  recordMeterValue,
  closeSession,
} from './lib/supabase.js';
import { registerConnection, unregisterConnection } from './lib/connections.js';
import { startHttpApi } from './lib/http-api.js';

const PORT = 9000;

const server = new RPCServer({
  protocols: ['ocpp1.6'],         // We beginnen bij 1.6J (breder ondersteund dan 2.0.1)
  strictMode: true,               // Alle verplichte velden moeten kloppen
});

// ==========================================================================
// AUTH & CONNECTION
// ==========================================================================
// De 'auth' handler beslist of een chargepoint mag verbinden.
// Voor nu: iedereen mag connecten. Later: Basic Auth op password + whitelist.
// ==========================================================================
server.auth((accept, reject, handshake) => {
  console.log(`[AUTH] Verbinding van chargepoint id="${handshake.identity}" pad="${handshake.request.url}"`);
  accept({
    sessionId: handshake.identity,
  });
});

// ==========================================================================
// CLIENT HANDLERS
// ==========================================================================
server.on('client', async (client) => {
  console.log(`[CONNECT] Chargepoint ${client.identity} online`);

  // Registreer in de connection-map zodat HTTP-API outbound calls kan doen
  // (RemoteStartTransaction / RemoteStopTransaction).
  registerConnection(client.identity, client);

  // Laatst bekende boot-payload per sessie bewaren zodat we hem bij StartTransaction
  // in charging_sessions.boot_payload kunnen opslaan voor debugging.
  let lastBootPayload = null;

  // ----- BootNotification -----
  client.handle('BootNotification', ({ params }) => {
    console.log(`[BOOT] ${client.identity}:`, params);
    lastBootPayload = params;
    return {
      status: 'Accepted',
      interval: 300,           // heartbeat elke 5 min
      currentTime: new Date().toISOString(),
    };
  });

  // ----- Heartbeat -----
  client.handle('Heartbeat', () => {
    console.log(`[HEARTBEAT] ${client.identity}`);
    return { currentTime: new Date().toISOString() };
  });

  // ----- Authorize -----
  // Voor nu: altijd Accepted. Later: check tegen Supabase bookings-tabel of
  // een RFID-whitelist per charger.
  client.handle('Authorize', ({ params }) => {
    console.log(`[AUTHORIZE] ${client.identity} idTag=${params.idTag}`);
    return {
      idTagInfo: { status: 'Accepted' },
    };
  });

  // ----- StartTransaction -----
  // Server kent transactionId toe (via Supabase identity column).
  // Bij DB-fout: fallback naar lokale id, paal krijgt Accepted maar sessie is
  // niet persistent (paal buffert dan lokaal en probeert later opnieuw).
  //
  // Deze handler wordt getriggerd door zowel lokale sessies (RFID-tap op de
  // paal) als door onze eigen RemoteStartTransaction (via HTTP-API). Vanuit
  // OCPP-perspectief is er geen verschil — paal stuurt in beide gevallen een
  // gewone StartTransaction.
  client.handle('StartTransaction', async ({ params }) => {
    const { transactionId, persisted } = await createSession({
      ocppChargerId: client.identity,
      connectorId: params.connectorId,
      idTag: params.idTag,
      meterStartWh: params.meterStart,
      bootPayload: lastBootPayload,
    });

    console.log(
      `[START] ${client.identity} tx=${transactionId} connectorId=${params.connectorId} meterStart=${params.meterStart}Wh idTag=${params.idTag} persisted=${persisted}`,
    );

    return {
      transactionId,
      idTagInfo: { status: 'Accepted' },
    };
  });

  // ----- MeterValues -----
  // Tussentijdse meterstanden. Schrijft naar log-tabel + updatet
  // meter_current_wh op sessie → Realtime naar Flutter-app.
  client.handle('MeterValues', async ({ params }) => {
    const meterValue = params.meterValue?.[0];
    const sampled = meterValue?.sampledValue ?? [];
    const energySample = sampled.find(
      (v) => v.measurand === 'Energy.Active.Import.Register' || !v.measurand,
    );
    const meterWh = energySample ? Number(energySample.value) : null;
    const measuredAt = meterValue?.timestamp ?? new Date().toISOString();

    console.log(
      `[METER] ${client.identity} tx=${params.transactionId} kWh=${
        meterWh !== null ? (meterWh / 1000).toFixed(3) : '?'
      }`,
    );

    if (meterWh !== null && params.transactionId) {
      await recordMeterValue({
        transactionId: params.transactionId,
        meterWh,
        measuredAt,
        rawPayload: params,
      });
    }

    return {};
  });

  // ----- StopTransaction -----
  client.handle('StopTransaction', async ({ params }) => {
    console.log(
      `[STOP]  ${client.identity} tx=${params.transactionId} meterStop=${params.meterStop}Wh reason=${params.reason ?? 'Local'}`,
    );

    await closeSession({
      transactionId: params.transactionId,
      meterStopWh: params.meterStop,
      stopReason: params.reason,
      stopPayload: params,
    });

    return {
      idTagInfo: { status: 'Accepted' },
    };
  });

  // ----- StatusNotification -----
  client.handle('StatusNotification', ({ params }) => {
    console.log(
      `[STATUS] ${client.identity} connector=${params.connectorId} status=${params.status} errorCode=${params.errorCode}`,
    );
    return {};
  });

  // ----- Fallback voor onbekende acties -----
  client.handle(({ method, params }) => {
    console.warn(`[UNKNOWN] ${client.identity} method=${method}`, params);
    throw createRPCError('NotImplemented');
  });

  client.on('close', () => {
    console.log(`[DISCONNECT] Chargepoint ${client.identity} offline`);
    unregisterConnection(client.identity, client);
  });
});

// ==========================================================================
// START — WebSocket + HTTP parallel
// ==========================================================================
await server.listen(PORT);
console.log(`\n Pluggo CSMS luistert op ws://localhost:${PORT}`);
console.log(`   Test-URL voor simulator: ws://localhost:${PORT}/CP-001`);
console.log(
  supabase
    ? `   [SUPABASE] Bridge actief — sessies worden gepersisteerd.`
    : `   [SUPABASE] Geen bridge — draai zonder DB. Vul .env om te persisteren.`,
);

// HTTP-API voor app-driven commands (RemoteStartTransaction, RemoteStopTransaction)
startHttpApi();
console.log('');
