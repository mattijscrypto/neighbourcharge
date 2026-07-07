// Pluggo CSMS — HTTP-API voor app-driven commands
//
// Naast de WebSocket-server (poort 9000) draaien we een kleine HTTP-server
// (poort 9001) waar de Pluggo-app (via een Supabase Edge Function) requests
// naartoe stuurt om laadsessies te starten of stoppen.
//
// Ontwerp-principes:
//   1. Gebruikt alleen Node's ingebouwde `http`-module. Geen Express nodig.
//   2. Auth via shared secret in X-CSMS-API-Key header. De Edge Function
//      is de enige die de secret kent — user-auth zit in Supabase, niet hier.
//   3. Endpoints zijn dun. Ze routeren naar `connections.js` en calleren
//      RemoteStart/Stop op de ocpp-rpc client. Business-logica hoort NIET hier.
//   4. Alle responses zijn JSON. Errors bevatten `error` string + optionele
//      `details`. Nooit stack traces lekken.

import http from 'node:http';
import { getConnection, listConnections, connectionCount } from './connections.js';

const HTTP_PORT = Number(process.env.CSMS_HTTP_PORT ?? 9001);
const API_KEY = process.env.CSMS_API_KEY ?? null;

// ==========================================================================
// Utilities
// ==========================================================================

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function sendError(res, status, error, details) {
  sendJson(res, status, { error, ...(details ? { details } : {}) });
}

/**
 * Lees de request body volledig in geheugen en parse als JSON.
 * Max 64 KB — RemoteStart payloads zijn tientallen bytes, dus dit is
 * ruim genoeg en beschermt tegen memory-exhaustion aanvallen.
 */
function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    const MAX_BYTES = 64 * 1024;
    let received = 0;
    const chunks = [];

    req.on('data', (chunk) => {
      received += chunk.length;
      if (received > MAX_BYTES) {
        reject(new Error('Request body te groot (>64KB)'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (received === 0) return resolve({});
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch (err) {
        reject(new Error(`Kon body niet parsen als JSON: ${err.message}`));
      }
    });
    req.on('error', reject);
  });
}

function checkAuth(req, res) {
  if (!API_KEY) {
    // Geen API_KEY geconfigureerd — dev-modus, iedereen mag.
    // In productie MOET deze env var gezet zijn.
    return true;
  }
  const provided = req.headers['x-csms-api-key'];
  if (!provided || provided !== API_KEY) {
    sendError(res, 401, 'Ongeldige of ontbrekende X-CSMS-API-Key header');
    return false;
  }
  return true;
}

/**
 * Wrap een OCPP-call met timeout — als paal niet binnen `timeoutMs`
 * antwoordt gaan we ervan uit dat 'ie stuck is en falen we netjes.
 * De HTTP-client (Edge Function) krijgt dan een 504 in plaats van een hang.
 */
function callWithTimeout(client, action, params, timeoutMs = 10000) {
  return Promise.race([
    client.call(action, params),
    new Promise((_, reject) =>
      setTimeout(
        () => reject(new Error(`OCPP call ${action} timeout na ${timeoutMs}ms`)),
        timeoutMs,
      ),
    ),
  ]);
}

// ==========================================================================
// Route handlers
// ==========================================================================

/**
 * GET /health
 * Publieke endpoint — geen auth. Handig voor load balancer health checks
 * en om te verifiëren dat de server draait vanaf de VPS zelf.
 */
function handleHealth(req, res) {
  sendJson(res, 200, {
    ok: true,
    connections: connectionCount(),
    uptime_s: Math.round(process.uptime()),
  });
}

/**
 * GET /chargers
 * Debug endpoint — lijst van actieve WebSocket-verbindingen.
 */
function handleListChargers(req, res) {
  if (!checkAuth(req, res)) return;
  sendJson(res, 200, { chargers: listConnections() });
}

/**
 * POST /chargers/:ocppChargerId/remote-start
 * Body: { idTag: string, connectorId?: number, chargingProfile?: object }
 *
 * Stuurt een OCPP RemoteStartTransaction naar de gespecificeerde paal.
 * Paal antwoordt Accepted / Rejected. Als Accepted volgt automatisch
 * een normale StartTransaction-flow (die door de bestaande handler in
 * index.js opgepikt wordt en een charging_sessions-rij aanmaakt).
 */
async function handleRemoteStart(req, res, ocppChargerId) {
  if (!checkAuth(req, res)) return;

  let body;
  try {
    body = await readJsonBody(req);
  } catch (err) {
    return sendError(res, 400, 'Body parse fout', err.message);
  }

  const { idTag, connectorId, chargingProfile } = body;
  if (!idTag || typeof idTag !== 'string') {
    return sendError(res, 400, 'Veld "idTag" is verplicht en moet een string zijn');
  }

  const entry = getConnection(ocppChargerId);
  if (!entry) {
    return sendError(res, 404, `Charger "${ocppChargerId}" is niet verbonden met CSMS`);
  }

  const params = { idTag };
  if (Number.isInteger(connectorId)) params.connectorId = connectorId;
  if (chargingProfile) params.chargingProfile = chargingProfile;

  console.log(`[HTTP] RemoteStart → ${ocppChargerId} idTag=${idTag} connector=${connectorId ?? 'any'}`);

  try {
    const result = await callWithTimeout(entry.client, 'RemoteStartTransaction', params);
    console.log(`[HTTP] RemoteStart ← ${ocppChargerId}:`, result);

    // OCPP paal antwoordt met { status: 'Accepted' | 'Rejected' }
    if (result?.status === 'Accepted') {
      return sendJson(res, 202, { accepted: true, ocppResponse: result });
    }
    return sendJson(res, 409, { accepted: false, ocppResponse: result });
  } catch (err) {
    console.error(`[HTTP] RemoteStart ${ocppChargerId} failed:`, err.message);
    return sendError(res, 504, 'Paal heeft niet (op tijd) geantwoord', err.message);
  }
}

/**
 * POST /chargers/:ocppChargerId/remote-stop
 * Body: { transactionId: number }
 *
 * Stuurt een OCPP RemoteStopTransaction naar de gespecificeerde paal om een
 * lopende sessie af te breken. Paal antwoordt Accepted/Rejected, en stuurt bij
 * Accepted zelf de StopTransaction (die door de bestaande handler in index.js
 * de charging_sessions-rij afsluit).
 */
async function handleRemoteStop(req, res, ocppChargerId) {
  if (!checkAuth(req, res)) return;

  let body;
  try {
    body = await readJsonBody(req);
  } catch (err) {
    return sendError(res, 400, 'Body parse fout', err.message);
  }

  const { transactionId } = body;
  if (!Number.isInteger(transactionId)) {
    return sendError(res, 400, 'Veld "transactionId" is verplicht en moet een integer zijn');
  }

  const entry = getConnection(ocppChargerId);
  if (!entry) {
    return sendError(res, 404, `Charger "${ocppChargerId}" is niet verbonden met CSMS`);
  }

  console.log(`[HTTP] RemoteStop → ${ocppChargerId} tx=${transactionId}`);

  try {
    const result = await callWithTimeout(entry.client, 'RemoteStopTransaction', { transactionId });
    console.log(`[HTTP] RemoteStop ← ${ocppChargerId}:`, result);
    if (result?.status === 'Accepted') {
      return sendJson(res, 202, { accepted: true, ocppResponse: result });
    }
    return sendJson(res, 409, { accepted: false, ocppResponse: result });
  } catch (err) {
    console.error(`[HTTP] RemoteStop ${ocppChargerId} failed:`, err.message);
    return sendError(res, 504, 'Paal heeft niet (op tijd) geantwoord', err.message);
  }
}

// ==========================================================================
// Router
// ==========================================================================

const REMOTE_START_RE = /^\/chargers\/([^/]+)\/remote-start\/?$/;
const REMOTE_STOP_RE  = /^\/chargers\/([^/]+)\/remote-stop\/?$/;

function router(req, res) {
  const url = req.url ?? '/';
  const method = req.method ?? 'GET';

  if (method === 'GET' && url === '/health') return handleHealth(req, res);
  if (method === 'GET' && url === '/chargers') return handleListChargers(req, res);

  const startMatch = url.match(REMOTE_START_RE);
  if (startMatch && method === 'POST') {
    return handleRemoteStart(req, res, decodeURIComponent(startMatch[1]));
  }

  const stopMatch = url.match(REMOTE_STOP_RE);
  if (stopMatch && method === 'POST') {
    return handleRemoteStop(req, res, decodeURIComponent(stopMatch[1]));
  }

  sendError(res, 404, `Onbekende route: ${method} ${url}`);
}

// ==========================================================================
// Start
// ==========================================================================

export function startHttpApi() {
  const server = http.createServer((req, res) => {
    // Wrap router zodat een sync throw geen crash veroorzaakt.
    try {
      router(req, res);
    } catch (err) {
      console.error('[HTTP] Onverwachte fout:', err);
      if (!res.headersSent) sendError(res, 500, 'Interne serverfout');
    }
  });

  server.on('error', (err) => {
    console.error('[HTTP] Server error:', err);
  });

  server.listen(HTTP_PORT, () => {
    console.log(` Pluggo CSMS HTTP-API luistert op http://localhost:${HTTP_PORT}`);
    console.log(
      API_KEY
        ? `   [AUTH] X-CSMS-API-Key verplicht op /chargers/*`
        : `   [AUTH] GEEN API_KEY — dev-modus, alle requests welkom. Zet CSMS_API_KEY in .env vóór productie!`,
    );
  });

  return server;
}
