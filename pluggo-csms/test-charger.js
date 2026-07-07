// Pluggo CSMS — test-client die een OCPP 1.6J charger nabootst
//
// Twee modi:
//   node test-charger.js            → happy-path (lokaal gestarte sessie)
//   node test-charger.js --wait     → wachtmodus (verbinden + heartbeat,
//                                     wacht op RemoteStartTransaction van CSMS)
//
// De wacht-modus is voor het testen van de HTTP-API in lib/http-api.js. Start
// deze in terminal-tab 2, en trigger vanuit tab 3 met bijvoorbeeld:
//
//   curl -X POST http://localhost:9001/chargers/CP-001/remote-start \
//        -H "Content-Type: application/json" \
//        -d '{"idTag":"PLUGGO-USER-1","connectorId":1}'
//
// De charger reageert dan met StartTransaction, drie MeterValues, en na
// RemoteStopTransaction of Ctrl-C sluit 'ie netjes af.

import { RPCClient } from 'ocpp-rpc';

const CSMS_URL   = process.env.CSMS_URL   ?? 'ws://localhost:9000';
const CHARGER_ID = process.env.CHARGER_ID ?? 'CP-001';
const ID_TAG     = process.env.ID_TAG     ?? 'TESTTAG123';
const WAIT_MODE  = process.argv.includes('--wait');

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

const client = new RPCClient({
  endpoint: CSMS_URL,
  identity: CHARGER_ID,
  protocols: ['ocpp1.6'],
});

// ==========================================================================
// Sessie-state — bewaard tussen calls in wachtmodus
// ==========================================================================
let currentTransactionId = null;
let meterWh = 12345;         // Start-meterstand: 12,345 kWh
let meterTickInterval = null;

/**
 * Stuur MeterValues met de huidige meterstand. Kan zowel handmatig (happy-path)
 * als vanuit een interval (wacht-modus) worden aangeroepen.
 */
async function sendMeterValues() {
  if (currentTransactionId === null) return;
  await client.call('MeterValues', {
    connectorId: 1,
    transactionId: currentTransactionId,
    meterValue: [
      {
        timestamp: new Date().toISOString(),
        sampledValue: [
          {
            value: String(meterWh),
            measurand: 'Energy.Active.Import.Register',
            unit: 'Wh',
          },
        ],
      },
    ],
  });
  console.log(`  → MeterValues tx=${currentTransactionId} meter=${meterWh}Wh (${(meterWh / 1000).toFixed(3)} kWh)`);
}

async function startSession(idTag) {
  const meterStart = meterWh;
  console.log(`→ StartTransaction (connector=1, meterStart=${meterStart}Wh, idTag=${idTag})`);
  const resp = await client.call('StartTransaction', {
    connectorId: 1,
    idTag,
    meterStart,
    timestamp: new Date().toISOString(),
  });
  currentTransactionId = resp.transactionId;
  console.log(`← transactionId=${currentTransactionId}, idTagInfo=`, resp.idTagInfo);

  await client.call('StatusNotification', {
    connectorId: 1,
    errorCode: 'NoError',
    status: 'Charging',
  });

  // In wacht-modus: elke 2 seconden 500 Wh erbij, en een MeterValues sturen.
  if (WAIT_MODE) {
    meterTickInterval = setInterval(async () => {
      meterWh += 500;
      try {
        await sendMeterValues();
      } catch (err) {
        console.error('MeterValues fout:', err.message);
      }
    }, 2000);
  }
}

async function stopSession(reason = 'Remote') {
  if (currentTransactionId === null) {
    console.warn('stopSession aangeroepen zonder actieve transactie');
    return;
  }
  if (meterTickInterval) {
    clearInterval(meterTickInterval);
    meterTickInterval = null;
  }

  const txId = currentTransactionId;
  currentTransactionId = null;

  console.log(`→ StopTransaction tx=${txId} meterStop=${meterWh}Wh reason=${reason}`);
  const resp = await client.call('StopTransaction', {
    transactionId: txId,
    idTag: ID_TAG,
    meterStop: meterWh,
    timestamp: new Date().toISOString(),
    reason,
  });
  console.log(`← Response:`, resp);

  await client.call('StatusNotification', {
    connectorId: 1,
    errorCode: 'NoError',
    status: 'Available',
  });
}

// ==========================================================================
// Handlers voor inkomende calls VANUIT de CSMS (server → charger direction)
// ==========================================================================
client.handle('RemoteStartTransaction', async ({ params }) => {
  console.log(`\n← RemoteStartTransaction ontvangen:`, params);

  if (currentTransactionId !== null) {
    // Er loopt al een sessie — reject.
    console.log('  Al een actieve transactie, weiger.');
    return { status: 'Rejected' };
  }

  // OCPP-spec: charger antwoordt eerst Accepted/Rejected, en start DAN pas
  // de daadwerkelijke StartTransaction-flow op een aparte call. Wij doen dat
  // async na een korte delay zodat de RemoteStartTransaction-response eerst
  // op de wire is.
  setImmediate(async () => {
    try {
      await wait(200);
      await startSession(params.idTag);
    } catch (err) {
      console.error('startSession (via Remote) fout:', err.message);
    }
  });

  return { status: 'Accepted' };
});

client.handle('RemoteStopTransaction', async ({ params }) => {
  console.log(`\n← RemoteStopTransaction ontvangen:`, params);

  if (params.transactionId !== currentTransactionId) {
    console.log(`  Onbekende transactionId ${params.transactionId} (huidige: ${currentTransactionId}), weiger.`);
    return { status: 'Rejected' };
  }

  setImmediate(async () => {
    try {
      await wait(200);
      await stopSession('Remote');
    } catch (err) {
      console.error('stopSession (via Remote) fout:', err.message);
    }
  });

  return { status: 'Accepted' };
});

// Fallback voor andere inkomende calls die we (nog) niet ondersteunen
client.handle(({ method }) => {
  console.warn(`← Onbekende inkomende call: ${method}`);
  throw new Error('NotImplemented');
});

// ==========================================================================
// Bootstrap
// ==========================================================================
console.log(`Test-charger "${CHARGER_ID}" verbindt met ${CSMS_URL}...`);
await client.connect();
console.log('Verbonden.\n');

console.log('→ BootNotification');
const boot = await client.call('BootNotification', {
  chargePointVendor: 'Alfen',
  chargePointModel: 'Eve Single S-line',
  chargePointSerialNumber: 'ALF-TEST-001',
  firmwareVersion: '5.7.0',
});
console.log('← Response:', boot, '\n');

await wait(500);

console.log('→ StatusNotification (Available)');
await client.call('StatusNotification', {
  connectorId: 1,
  errorCode: 'NoError',
  status: 'Available',
});
console.log('← ok\n');

// ==========================================================================
// Modus-splitsing
// ==========================================================================
if (WAIT_MODE) {
  console.log('=== WACHT-MODUS ===');
  console.log(`Charger draait door, wacht op inkomende RemoteStartTransaction.`);
  console.log(`Trigger van buitenaf met:`);
  console.log(`  curl -X POST http://localhost:9001/chargers/${CHARGER_ID}/remote-start \\`);
  console.log(`       -H "Content-Type: application/json" \\`);
  console.log(`       -d '{"idTag":"PLUGGO-USER-1","connectorId":1}'\n`);
  console.log(`En stop met:`);
  console.log(`  curl -X POST http://localhost:9001/chargers/${CHARGER_ID}/remote-stop \\`);
  console.log(`       -H "Content-Type: application/json" \\`);
  console.log(`       -d '{"transactionId":<TX_ID>}'\n`);
  console.log(`Of Ctrl-C om af te sluiten.\n`);

  // Heartbeat elke 30 sec zodat CSMS ziet dat we leven
  setInterval(async () => {
    try {
      await client.call('Heartbeat', {});
    } catch (err) {
      console.error('Heartbeat fout:', err.message);
    }
  }, 30_000);

  process.on('SIGINT', async () => {
    console.log('\nSIGINT ontvangen, afsluiten...');
    try {
      if (currentTransactionId !== null) await stopSession('PowerLoss');
      await wait(200);
      await client.close();
    } finally {
      process.exit(0);
    }
  });
} else {
  // ==========================================================================
  // Happy-path modus (originele flow)
  // ==========================================================================
  console.log('=== HAPPY-PATH MODUS ===\n');

  console.log(`→ Authorize (idTag=${ID_TAG})`);
  const auth = await client.call('Authorize', { idTag: ID_TAG });
  console.log('← Response:', auth, '\n');
  await wait(500);

  await startSession(ID_TAG);
  console.log('');

  // Drie meterticks handmatig (geen interval)
  for (let i = 1; i <= 3; i++) {
    await wait(1000);
    meterWh += 500;
    console.log(`→ MeterValues (tick ${i})`);
    await sendMeterValues();
  }
  console.log('');

  await stopSession('Local');

  await wait(500);
  await client.close();
  console.log('=== Happy-path compleet. Verbinding gesloten. ===');
  process.exit(0);
}
