// Pluggo — stripe-checkout-return edge function
// ----------------------------------------------------------------------------
// HTTPS-bridge tussen Stripe Checkout (verplicht https success/cancel URL)
// en de Pluggo iOS-app (`pluggo://` custom URL scheme).
//
// === Plan B: pure 302 redirect ===
// Vorige versie returnde een HTML-landing-page met meta-refresh + JS-redirect,
// maar Safari op iOS renderde de response consistent als platte tekst — de
// Content-Type header werd ergens onderweg (Supabase edge proxy?) gestript
// of niet correct doorgegeven. Resultaat: gebruiker zag de raw HTML source
// in plaats van een mooie bevestigingspagina, en geen redirect terug naar
// de app.
//
// Plan B vermijdt het hele probleem: in plaats van HTML te returnen, doen
// we een 302 redirect met `Location: pluggo://stripe-return?...` Safari
// volgt die header direct en iOS triggert het URL scheme handler → Pluggo
// app komt naar voren. Geen pagina-render, geen Content-Type issue, geen
// 1-seconde flits met "Betaling gelukt" tekst.
//
// Trade-off: gebruikers zien een korte witte flits in Safari (i.p.v. een
// groene success-card). Acceptabel — de app komt binnen ~300ms terug en
// toont daar de bevestiging. UX-glue zit voortaan in de app, niet hier.
//
// URL parameters die we ondersteunen:
//   ?status=success   — doorgegeven aan app als ?status=success
//   ?status=cancel    — doorgegeven aan app als ?status=cancel
//   ?session_id=...   — Checkout Session ID voor logging in de app
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const APP_SCHEME = "pluggo";

serve((req) => {
  const url = new URL(req.url);
  const status = url.searchParams.get("status") ?? "success";
  const sessionId = url.searchParams.get("session_id") ?? "";

  // Bouw de app-deeplink. Pluggo's lib/main.dart polling vangt de status
  // ook op zonder deeplink (via de bookings tabel), maar de redirect zorgt
  // ervoor dat de gebruiker actief terug naar de app gestuurd wordt.
  const appUrl = new URL(`${APP_SCHEME}://stripe-return`);
  appUrl.searchParams.set("status", status);
  if (sessionId) appUrl.searchParams.set("session_id", sessionId);

  return new Response(null, {
    status: 302,
    headers: {
      Location: appUrl.toString(),
      "Cache-Control": "no-store",
    },
  });
});
