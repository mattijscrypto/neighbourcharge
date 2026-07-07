// Pluggo CSMS — connection registry
//
// In-memory Map van actieve chargepoint-connecties, gekoppeld op OCPP identity.
// Wordt gebruikt door de HTTP-API om outbound OCPP-calls (RemoteStartTransaction,
// RemoteStopTransaction) naar de juiste paal te routeren.
//
// Belangrijk: dit is bewust NIET gepersisteerd. Als de CSMS-server herstart,
// bouwen palen automatisch hun WebSocket-verbinding opnieuw op via reconnect-
// logica en registreren zich opnieuw. Persistent zou hier alleen maar false
// state kunnen creëren (paal denkt "verbonden", server is dood).

/** @type {Map<string, { client: import('ocpp-rpc').RPCServerClient, connectedAt: Date }>} */
const connections = new Map();

/**
 * Registreer een verbinding zodra een client succesvol het 'client' event
 * heeft doorlopen. Overschrijft eventuele stale entry met dezelfde identity
 * (kan gebeuren als paal reconnect voordat de vorige TCP-close is doorgekomen).
 */
export function registerConnection(ocppChargerId, client) {
  const existing = connections.get(ocppChargerId);
  if (existing && existing.client !== client) {
    console.warn(
      `[CONN] ${ocppChargerId}: nieuwe verbinding vervangt stale entry (connect-race)`,
    );
    try {
      existing.client.close();
    } catch (_) {
      // Best effort — als 'ie al dicht is prima
    }
  }
  connections.set(ocppChargerId, { client, connectedAt: new Date() });
  console.log(`[CONN] ${ocppChargerId}: geregistreerd (${connections.size} actief)`);
}

export function unregisterConnection(ocppChargerId, client) {
  const entry = connections.get(ocppChargerId);
  // Alleen deregistreren als het echt dezelfde client-instance is.
  // Voorkomt dat een oude close-event de nieuwe verbinding uit-de-map gooit.
  if (entry?.client === client) {
    connections.delete(ocppChargerId);
    console.log(`[CONN] ${ocppChargerId}: verwijderd (${connections.size} actief)`);
  }
}

export function getConnection(ocppChargerId) {
  return connections.get(ocppChargerId) ?? null;
}

export function listConnections() {
  return Array.from(connections.entries()).map(([id, { connectedAt }]) => ({
    ocppChargerId: id,
    connectedAt: connectedAt.toISOString(),
  }));
}

export function connectionCount() {
  return connections.size;
}
