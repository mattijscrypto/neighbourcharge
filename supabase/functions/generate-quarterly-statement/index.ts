// Pluggo — generate-quarterly-statement edge function
// ----------------------------------------------------------------------------
// Task #163: kwartaaloverzicht-engine voor BTW-plichtige paaleigenaren.
//
// FLOW
// ----------------------------------------------------------------------------
// 1. Aangeroepen door pg_cron (5e van jan/apr/jul/okt, 07:00 UTC — zie
//    migratie 0031). Kan ook handmatig met explicit {year, quarter} voor
//    backfill of testing.
// 2. Query `quarterly_statement_targets(year, quarter)` — geeft alle
//    BTW-plichtige owners met >0 paid bookings in het kwartaal.
// 3. Per owner:
//      a. Detail-regels via `quarterly_statement_bookings(...)`
//      b. YTD-aggregaten via `quarterly_statement_ytd(...)`
//      c. Kwartaal-aggregaten uit de detail-regels
//      d. PDF renderen (pdf-lib) — A4, sessie-tabel met paginering + totalen
//         + YTD-blok
//      e. PDF uploaden naar Storage bucket `quarterly-statements`
//         onder `{year}/Q{quarter}/{owner_id}.pdf`
//      f. Row inserten in public.quarterly_statements (idempotency: unique
//         (owner_id, year, quarter) — 23505 = already generated, skip)
//      g. Signed URL (7 dagen) genereren
//      h. Email versturen via send-email edge function met download-link
//      i. sent_at / send_error updaten
// 4. Return: samenvatting {targets_found, generated, sent, errors[]}.
//
// INTERFACE
// ----------------------------------------------------------------------------
//   POST { year?: number, quarter?: 1|2|3|4, dry_run?: boolean,
//          target_owner_id?: string }
//     → 200 { year, quarter, targets_found, generated, sent, errors[] }
//     → 4xx/5xx { error: string }
//
//   Defaults: year+quarter = vorige kwartaal op basis van "vandaag"
//   (jan-mrt → Q4 van vorig jaar, apr-jun → Q1, jul-sep → Q2, okt-dec → Q3).
//
// AUTH
// ----------------------------------------------------------------------------
//   Alleen service-role (auto-injected key OF handmatig gezette CRON_SECRET).
//   Zelfde patroon als send-payment-reminders.
//
// SECRETS
// ----------------------------------------------------------------------------
//   Handmatig gezet:
//     • RESEND_API_KEY  — Resend API key (via send-email edge function)
//     • CRON_SECRET     — optioneel; alternative bearer voor cron met
//                         nieuwe-API-key-projecten
//   Auto-injected:
//     • SUPABASE_URL
//     • SUPABASE_SERVICE_ROLE_KEY
//     • SUPABASE_ANON_KEY (voor call naar send-email)
// ----------------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import {
  PDFDocument,
  StandardFonts,
  rgb,
  PDFFont,
  PDFPage,
} from "https://esm.sh/pdf-lib@1.17.1";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const STORAGE_BUCKET = "quarterly-statements";
const SIGNED_URL_EXPIRES_SECONDS = 60 * 60 * 24 * 30; // 30 dagen — de eigenaar
// heeft t/m maandeinde na kwartaal voor aangifte, plus buffer.

const PDF_MARGIN = 40;                    // pt
const PDF_LINE_HEIGHT = 14;               // pt
const PDF_TABLE_ROW_HEIGHT = 16;          // pt
const PDF_PAGE_WIDTH = 595.28;            // A4
const PDF_PAGE_HEIGHT = 841.89;           // A4
const PDF_MAX_ROWS_FIRST_PAGE = 22;       // ruimte over voor header + totalen
const PDF_MAX_ROWS_NEXT_PAGE = 40;        // gewone tabelpagina's

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
interface RequestBody {
  year?: number;
  quarter?: 1 | 2 | 3 | 4;
  dry_run?: boolean;
  target_owner_id?: string;
}

interface Target {
  owner_id: string;
  email: string | null;
  full_name: string | null;
  kvk_number: string | null;
  vat_number: string | null;
  vat_status: string;
  q_from: string;
  q_to: string;
}

interface BookingRow {
  booking_id: string;
  session_date: string;
  charger_name: string | null;
  charger_address: string | null;
  kwh_consumed: number | null;
  owner_share_cents: number | null;
  owner_vat_amount_cents: number | null;
  booker_email: string | null;
}

interface YtdRow {
  session_count: number;
  total_kwh: number;
  subtotal_cents: number;
  vat_cents: number;
  total_cents: number;
}

interface StatementError {
  owner_id: string;
  stage: string;
  message: string;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonError("Methode niet toegestaan", 405);
  }

  try {
    // --- 1. Env + auth ---------------------------------------------------
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const cronSecret = Deno.env.get("CRON_SECRET");

    if (!supabaseUrl || !serviceKey) {
      return jsonError("Server niet juist geconfigureerd", 500);
    }

    const auth = req.headers.get("Authorization") ?? "";
    const acceptable = [
      `Bearer ${serviceKey}`,
      cronSecret ? `Bearer ${cronSecret}` : null,
    ].filter(Boolean) as string[];

    if (!acceptable.includes(auth)) {
      return jsonError("Niet geautoriseerd", 401);
    }

    // --- 2. Body + kwartaal-defaults ------------------------------------
    let body: RequestBody = {};
    if (req.headers.get("content-length") !== "0") {
      try {
        body = (await req.json()) as RequestBody;
      } catch {
        // Empty of ongeldige body → gebruik defaults.
        body = {};
      }
    }

    const { year, quarter } = resolveQuarter(body.year, body.quarter);
    const dryRun = body.dry_run === true;

    console.log("generate-quarterly-statement start", {
      year,
      quarter,
      dryRun,
      target_owner_id: body.target_owner_id ?? null,
    });

    // --- 3. Supabase client ---------------------------------------------
    const admin = createClient(supabaseUrl, serviceKey);

    // --- 4. Targets ophalen ---------------------------------------------
    const { data: targetsRaw, error: targetsError } = await admin.rpc(
      "quarterly_statement_targets",
      { p_year: year, p_quarter: quarter }
    );
    if (targetsError) {
      console.error("targets rpc failed", targetsError);
      return jsonError(
        `quarterly_statement_targets faalde: ${targetsError.message}`,
        500
      );
    }

    let targets: Target[] = (targetsRaw ?? []) as Target[];

    // Optioneel filter voor handmatige test/backfill van één owner.
    if (body.target_owner_id) {
      targets = targets.filter((t) => t.owner_id === body.target_owner_id);
    }

    if (targets.length === 0) {
      console.log("Geen BTW-plichtige owners met paid bookings in periode.");
      return okJson({
        year,
        quarter,
        targets_found: 0,
        generated: 0,
        sent: 0,
        errors: [],
      });
    }

    if (dryRun) {
      return okJson({
        year,
        quarter,
        targets_found: targets.length,
        generated: 0,
        sent: 0,
        dry_run: true,
        targets: targets.map((t) => ({
          owner_id: t.owner_id,
          email: t.email,
          full_name: t.full_name,
        })),
        errors: [],
      });
    }

    // --- 5. Per target verwerken ----------------------------------------
    let generated = 0;
    let sent = 0;
    const errors: StatementError[] = [];

    for (const target of targets) {
      try {
        const result = await processTarget(admin, target, year, quarter);
        if (result === "generated") generated++;
        else if (result === "generated_and_sent") {
          generated++;
          sent++;
        } else if (result === "sent_only") {
          sent++;
        }
        // "already_sent" telt niet meer als generated/sent.
      } catch (err) {
        console.error("Owner-processing failed", target.owner_id, err);
        errors.push({
          owner_id: target.owner_id,
          stage: "processTarget",
          message: err instanceof Error ? err.message : String(err),
        });
      }
    }

    return okJson({
      year,
      quarter,
      targets_found: targets.length,
      generated,
      sent,
      errors,
    });
  } catch (err) {
    console.error("generate-quarterly-statement fatal:", err);
    return jsonError(
      "Onbekende serverfout: " +
        (err instanceof Error ? err.message : String(err)),
      500
    );
  }
});

// ---------------------------------------------------------------------------
// Kwartaal-berekening
// ---------------------------------------------------------------------------
function resolveQuarter(
  explicitYear?: number,
  explicitQuarter?: 1 | 2 | 3 | 4
): { year: number; quarter: 1 | 2 | 3 | 4 } {
  if (explicitYear && explicitQuarter) {
    if (explicitQuarter < 1 || explicitQuarter > 4) {
      throw new Error("quarter moet 1-4 zijn");
    }
    return { year: explicitYear, quarter: explicitQuarter };
  }

  // Default = vorig kwartaal (op basis van UTC-nu; scheelt geen dag rond
  // 1 jan / 1 apr / 1 jul / 1 okt aangezien de cron pas op de 5e draait).
  const now = new Date();
  const y = now.getUTCFullYear();
  const currentQuarter = Math.floor(now.getUTCMonth() / 3) + 1; // 1..4

  if (currentQuarter === 1) {
    return { year: y - 1, quarter: 4 };
  }
  return { year: y, quarter: (currentQuarter - 1) as 1 | 2 | 3 | 4 };
}

// ---------------------------------------------------------------------------
// processTarget — één owner: data ophalen, PDF, opslaan, insert, email.
// ---------------------------------------------------------------------------
type ProcessOutcome =
  | "generated"
  | "generated_and_sent"
  | "sent_only"
  | "already_sent";

async function processTarget(
  admin: ReturnType<typeof createClient>,
  target: Target,
  year: number,
  quarter: 1 | 2 | 3 | 4
): Promise<ProcessOutcome> {
  // Idempotency-check: bestaat er al een statement voor dit (owner, y, q)?
  // Zo ja én sent_at is niet null → skip volledig. Zo ja én sent_at is null
  // (dus PDF eerder gegenereerd, mail eerder gefaald) → hergebruik row en
  // probeer alleen de mail opnieuw.
  const { data: existing, error: existingError } = await admin
    .from("quarterly_statements")
    .select("id, pdf_storage_path, sent_at")
    .eq("owner_id", target.owner_id)
    .eq("year", year)
    .eq("quarter", quarter)
    .maybeSingle();

  if (existingError) {
    throw new Error(`existing lookup: ${existingError.message}`);
  }

  if (existing?.sent_at) {
    console.log("Statement al verzonden — skip", {
      owner_id: target.owner_id,
      year,
      quarter,
    });
    return "already_sent";
  }

  // Data ophalen
  const { data: bookingsRaw, error: bookingsError } = await admin.rpc(
    "quarterly_statement_bookings",
    { p_owner_id: target.owner_id, p_year: year, p_quarter: quarter }
  );
  if (bookingsError) {
    throw new Error(`bookings rpc: ${bookingsError.message}`);
  }
  const bookings: BookingRow[] = (bookingsRaw ?? []) as BookingRow[];

  if (bookings.length === 0) {
    // Kan gebeuren als de detail-query een edge case heeft die targets niet
    // heeft (bijv. een booking waarvan payment_completed_at op grens ligt).
    // Return silent: geen PDF, geen mail.
    console.log("Bookings-query gaf 0 rijen — skip", target.owner_id);
    return "already_sent";
  }

  const { data: ytdRaw, error: ytdError } = await admin.rpc(
    "quarterly_statement_ytd",
    {
      p_owner_id: target.owner_id,
      p_year: year,
      p_up_to_quarter: quarter,
    }
  );
  if (ytdError) {
    throw new Error(`ytd rpc: ${ytdError.message}`);
  }
  const ytd: YtdRow = (ytdRaw ?? [])[0] as YtdRow;

  // Kwartaal-aggregaten
  const q = aggregateQuarter(bookings);

  let statementId: string;
  let pdfStoragePath: string;

  if (existing?.pdf_storage_path) {
    // PDF bestaat al — hergebruik.
    statementId = existing.id;
    pdfStoragePath = existing.pdf_storage_path;
    console.log("PDF hergebruiken", { statementId, pdfStoragePath });
  } else {
    // --- PDF renderen -------------------------------------------------
    const pdfBytes = await renderStatementPdf({
      target,
      year,
      quarter,
      bookings,
      quarterAgg: q,
      ytd,
    });

    // --- Upload ------------------------------------------------------
    pdfStoragePath = `${year}/Q${quarter}/${target.owner_id}.pdf`;
    const { error: uploadError } = await admin.storage
      .from(STORAGE_BUCKET)
      .upload(pdfStoragePath, pdfBytes, {
        contentType: "application/pdf",
        upsert: true,
      });
    if (uploadError) {
      throw new Error(`storage upload: ${uploadError.message}`);
    }

    // --- Insert/upsert row -------------------------------------------
    const insertPayload = {
      owner_id: target.owner_id,
      year,
      quarter,
      full_name: target.full_name,
      kvk_number: target.kvk_number,
      vat_number: target.vat_number,
      session_count: q.session_count,
      total_kwh: q.total_kwh,
      subtotal_cents: q.subtotal_cents,
      vat_cents: q.vat_cents,
      total_cents: q.total_cents,
      ytd_session_count: ytd?.session_count ?? 0,
      ytd_total_kwh: ytd?.total_kwh ?? 0,
      ytd_subtotal_cents: ytd?.subtotal_cents ?? 0,
      ytd_vat_cents: ytd?.vat_cents ?? 0,
      ytd_total_cents: ytd?.total_cents ?? 0,
      pdf_storage_path: pdfStoragePath,
      email_to: target.email,
    };

    if (existing) {
      const { error: updateError } = await admin
        .from("quarterly_statements")
        .update(insertPayload)
        .eq("id", existing.id);
      if (updateError) {
        throw new Error(`row update: ${updateError.message}`);
      }
      statementId = existing.id;
    } else {
      const { data: inserted, error: insertError } = await admin
        .from("quarterly_statements")
        .insert(insertPayload)
        .select("id")
        .single();
      if (insertError) {
        // 23505 = unique violation → concurrent run, ander proces was ons
        // voor. Fetch existing en ga verder met mail.
        if (insertError.code === "23505") {
          const { data: raced } = await admin
            .from("quarterly_statements")
            .select("id, sent_at")
            .eq("owner_id", target.owner_id)
            .eq("year", year)
            .eq("quarter", quarter)
            .single();
          if (raced?.sent_at) return "already_sent";
          statementId = raced!.id;
        } else {
          throw new Error(`row insert: ${insertError.message}`);
        }
      } else {
        statementId = inserted!.id;
      }
    }
  }

  // --- Mail versturen ------------------------------------------------
  if (!target.email) {
    console.warn("Geen email voor owner", target.owner_id);
    await admin
      .from("quarterly_statements")
      .update({
        send_error: "geen email adres op profiel",
      })
      .eq("id", statementId);
    return "generated";
  }

  // Signed URL (30 dagen) voor de download-link.
  const { data: signed, error: signedError } = await admin.storage
    .from(STORAGE_BUCKET)
    .createSignedUrl(pdfStoragePath, SIGNED_URL_EXPIRES_SECONDS);
  if (signedError || !signed?.signedUrl) {
    throw new Error(
      `signed url: ${signedError?.message ?? "geen URL teruggekregen"}`
    );
  }

  const html = renderStatementEmailHtml({
    target,
    year,
    quarter,
    quarterAgg: q,
    downloadUrl: signed.signedUrl,
  });

  const subject = `Pluggo kwartaaloverzicht Q${quarter} ${year}`;

  try {
    await callSendEmail(admin, target.email, subject, html);
  } catch (mailErr) {
    const msg = mailErr instanceof Error ? mailErr.message : String(mailErr);
    await admin
      .from("quarterly_statements")
      .update({ send_error: msg })
      .eq("id", statementId);
    throw new Error(`send-email: ${msg}`);
  }

  await admin
    .from("quarterly_statements")
    .update({ sent_at: new Date().toISOString(), send_error: null })
    .eq("id", statementId);

  return existing?.pdf_storage_path ? "sent_only" : "generated_and_sent";
}

// ---------------------------------------------------------------------------
// aggregateQuarter — som kwartaal-cijfers uit detail-rijen
// ---------------------------------------------------------------------------
function aggregateQuarter(bookings: BookingRow[]) {
  let session_count = 0;
  let total_kwh = 0;
  let subtotal_cents = 0;
  let vat_cents = 0;
  for (const b of bookings) {
    session_count++;
    total_kwh += Number(b.kwh_consumed ?? 0);
    subtotal_cents += Number(b.owner_share_cents ?? 0);
    vat_cents += Number(b.owner_vat_amount_cents ?? 0);
  }
  return {
    session_count,
    total_kwh: Math.round(total_kwh * 100) / 100,
    subtotal_cents,
    vat_cents,
    total_cents: subtotal_cents + vat_cents,
  };
}

// ---------------------------------------------------------------------------
// PDF rendering — pdf-lib, A4, sessie-tabel met paginering + totalen + YTD
// ---------------------------------------------------------------------------
interface RenderInput {
  target: Target;
  year: number;
  quarter: 1 | 2 | 3 | 4;
  bookings: BookingRow[];
  quarterAgg: ReturnType<typeof aggregateQuarter>;
  ytd: YtdRow;
}

async function renderStatementPdf(input: RenderInput): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);

  doc.setTitle(
    `Pluggo Kwartaaloverzicht Q${input.quarter} ${input.year} — ${input.target.full_name ?? ""}`
  );
  doc.setAuthor("Pluggo");
  doc.setCreator("Pluggo generate-quarterly-statement");

  // Chunk de bookings over pagina's heen.
  const pages: BookingRow[][] = [];
  let cursor = 0;
  pages.push(input.bookings.slice(cursor, cursor + PDF_MAX_ROWS_FIRST_PAGE));
  cursor += PDF_MAX_ROWS_FIRST_PAGE;
  while (cursor < input.bookings.length) {
    pages.push(input.bookings.slice(cursor, cursor + PDF_MAX_ROWS_NEXT_PAGE));
    cursor += PDF_MAX_ROWS_NEXT_PAGE;
  }

  for (let i = 0; i < pages.length; i++) {
    const page = doc.addPage([PDF_PAGE_WIDTH, PDF_PAGE_HEIGHT]);
    if (i === 0) {
      drawFirstPageHeader(page, font, bold, input);
    } else {
      drawContinuationHeader(page, bold, input, i + 1);
    }

    const tableTop = i === 0 ? 620 : 780;
    drawTableRows(
      page,
      font,
      bold,
      pages[i],
      tableTop,
      /* showHeader */ true,
      i === 0
        ? 0
        : pages.slice(0, i).reduce((acc, p) => acc + p.length, 0)
    );

    // Alleen op de laatste pagina de totalen + YTD-blok.
    if (i === pages.length - 1) {
      const belowTable =
        tableTop - PDF_TABLE_ROW_HEIGHT * (pages[i].length + 2) - 20;
      drawTotals(page, font, bold, input, belowTable);
    }

    drawFooter(page, font, i + 1, pages.length);
  }

  return doc.save();
}

function drawFirstPageHeader(
  page: PDFPage,
  font: PDFFont,
  bold: PDFFont,
  input: RenderInput
) {
  const { width, height } = page.getSize();
  const left = PDF_MARGIN;
  let y = height - PDF_MARGIN;

  // Titel
  page.drawText("Pluggo", {
    x: left,
    y: y - 22,
    size: 24,
    font: bold,
    color: rgb(0.15, 0.55, 0.35),
  });
  page.drawText("Kwartaaloverzicht", {
    x: left,
    y: y - 46,
    size: 16,
    font: bold,
  });
  page.drawText(`Q${input.quarter} ${input.year}`, {
    x: left,
    y: y - 64,
    size: 14,
    font,
  });

  // Meta-blok rechtsboven
  const metaX = width - PDF_MARGIN - 220;
  let metaY = y - 22;
  page.drawText("Pluggo B.V.", { x: metaX, y: metaY, size: 10, font: bold });
  metaY -= PDF_LINE_HEIGHT;
  page.drawText("info@pluggoapp.nl", { x: metaX, y: metaY, size: 9, font });
  metaY -= PDF_LINE_HEIGHT;
  page.drawText(
    `Gegenereerd: ${formatDateNL(new Date().toISOString())}`,
    { x: metaX, y: metaY, size: 9, font }
  );

  // Owner-blok
  const ownerY = y - 110;
  page.drawText("Overzicht voor:", { x: left, y: ownerY, size: 10, font });
  page.drawText(sanitizeWinAnsi(input.target.full_name ?? "(naam onbekend)"), {
    x: left,
    y: ownerY - PDF_LINE_HEIGHT,
    size: 12,
    font: bold,
  });

  let detailY = ownerY - PDF_LINE_HEIGHT * 2 - 4;
  if (input.target.kvk_number) {
    page.drawText(`KvK: ${sanitizeWinAnsi(input.target.kvk_number)}`, {
      x: left,
      y: detailY,
      size: 10,
      font,
    });
    detailY -= PDF_LINE_HEIGHT;
  }
  if (input.target.vat_number) {
    page.drawText(`BTW-nummer: ${sanitizeWinAnsi(input.target.vat_number)}`, {
      x: left,
      y: detailY,
      size: 10,
      font,
    });
    detailY -= PDF_LINE_HEIGHT;
  }
  if (input.target.email) {
    page.drawText(sanitizeWinAnsi(input.target.email), {
      x: left,
      y: detailY,
      size: 10,
      font,
    });
    detailY -= PDF_LINE_HEIGHT;
  }

  // Periode-blok
  const periodStart = quarterStartDate(input.year, input.quarter);
  const periodEnd = quarterEndDate(input.year, input.quarter);
  page.drawText(
    `Periode: ${formatDateNL(periodStart)} t/m ${formatDateNL(periodEnd)}`,
    { x: left, y: detailY - 8, size: 10, font: bold }
  );

  // Toelichting
  const toelichting =
    "Dit overzicht toont alle betaalde laadsessies op uw palen in het genoemde kwartaal.\n" +
    "U bent BTW-plichtig en dient de vermelde BTW zelf af te dragen aan de Belastingdienst.\n" +
    "Pluggo hanteert een self-billing constructie conform art. 35e Wet OB.";
  drawMultiline(page, font, toelichting, left, detailY - 32, 9, 11);
}

function drawContinuationHeader(
  page: PDFPage,
  bold: PDFFont,
  input: RenderInput,
  pageNum: number
) {
  const { height } = page.getSize();
  page.drawText(
    `Pluggo Kwartaaloverzicht Q${input.quarter} ${input.year} (vervolg, blad ${pageNum})`,
    {
      x: PDF_MARGIN,
      y: height - PDF_MARGIN,
      size: 10,
      font: bold,
    }
  );
}

// Tabel-kolommen: Datum | Paal | kWh | Excl. BTW | BTW | Totaal
const COL_X = {
  date: 40,
  charger: 130,
  kwh: 340,
  excl: 400,
  vat: 460,
  total: 520,
};

function drawTableRows(
  page: PDFPage,
  font: PDFFont,
  bold: PDFFont,
  rows: BookingRow[],
  topY: number,
  showHeader: boolean,
  startIndex: number,
) {
  let y = topY;
  if (showHeader) {
    page.drawText("Datum", { x: COL_X.date, y, size: 9, font: bold });
    page.drawText("Paal", { x: COL_X.charger, y, size: 9, font: bold });
    page.drawText("kWh", { x: COL_X.kwh, y, size: 9, font: bold });
    page.drawText("Excl. BTW", { x: COL_X.excl, y, size: 9, font: bold });
    page.drawText("BTW", { x: COL_X.vat, y, size: 9, font: bold });
    page.drawText("Totaal", { x: COL_X.total, y, size: 9, font: bold });
    // horizontale lijn onder header
    page.drawLine({
      start: { x: PDF_MARGIN, y: y - 3 },
      end: { x: PDF_PAGE_WIDTH - PDF_MARGIN, y: y - 3 },
      thickness: 0.5,
      color: rgb(0.6, 0.6, 0.6),
    });
    y -= PDF_TABLE_ROW_HEIGHT;
  }

  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const subtotal = Number(r.owner_share_cents ?? 0);
    const vat = Number(r.owner_vat_amount_cents ?? 0);
    const total = subtotal + vat;

    page.drawText(formatDateNL(r.session_date), {
      x: COL_X.date,
      y,
      size: 8,
      font,
    });
    page.drawText(truncateText(r.charger_name ?? "(paal)", 32), {
      x: COL_X.charger,
      y,
      size: 8,
      font,
    });
    page.drawText(formatKwh(r.kwh_consumed), {
      x: COL_X.kwh,
      y,
      size: 8,
      font,
    });
    page.drawText(formatEuroCents(subtotal), {
      x: COL_X.excl,
      y,
      size: 8,
      font,
    });
    page.drawText(formatEuroCents(vat), {
      x: COL_X.vat,
      y,
      size: 8,
      font,
    });
    page.drawText(formatEuroCents(total), {
      x: COL_X.total,
      y,
      size: 8,
      font,
    });

    y -= PDF_TABLE_ROW_HEIGHT;
  }
}

function drawTotals(
  page: PDFPage,
  font: PDFFont,
  bold: PDFFont,
  input: RenderInput,
  topY: number
) {
  const left = PDF_MARGIN;
  let y = topY;

  // Divider
  page.drawLine({
    start: { x: left, y: y + 6 },
    end: { x: PDF_PAGE_WIDTH - PDF_MARGIN, y: y + 6 },
    thickness: 0.8,
  });

  // Kwartaal-totalen
  page.drawText(`Totaal Q${input.quarter} ${input.year}`, {
    x: left,
    y,
    size: 11,
    font: bold,
  });
  y -= PDF_LINE_HEIGHT + 4;

  const rows: [string, string][] = [
    ["Aantal sessies", `${input.quarterAgg.session_count}`],
    ["Totaal kWh", formatKwh(input.quarterAgg.total_kwh)],
    ["Omzet excl. BTW", formatEuroCents(input.quarterAgg.subtotal_cents)],
    ["BTW (21%)", formatEuroCents(input.quarterAgg.vat_cents)],
    ["Totaal incl. BTW", formatEuroCents(input.quarterAgg.total_cents)],
  ];
  for (const [label, val] of rows) {
    page.drawText(label, { x: left, y, size: 10, font });
    page.drawText(val, {
      x: PDF_PAGE_WIDTH - PDF_MARGIN - 100,
      y,
      size: 10,
      font,
    });
    y -= PDF_LINE_HEIGHT;
  }

  // YTD-blok
  y -= 12;
  page.drawLine({
    start: { x: left, y: y + 6 },
    end: { x: PDF_PAGE_WIDTH - PDF_MARGIN, y: y + 6 },
    thickness: 0.4,
    color: rgb(0.6, 0.6, 0.6),
  });
  page.drawText(
    `Cumulatief tot en met Q${input.quarter} ${input.year} (YTD)`,
    { x: left, y, size: 11, font: bold }
  );
  y -= PDF_LINE_HEIGHT + 4;

  const ytdRows: [string, string][] = [
    ["Aantal sessies", `${input.ytd?.session_count ?? 0}`],
    ["Totaal kWh", formatKwh(input.ytd?.total_kwh ?? 0)],
    ["Omzet excl. BTW", formatEuroCents(input.ytd?.subtotal_cents ?? 0)],
    ["BTW (21%)", formatEuroCents(input.ytd?.vat_cents ?? 0)],
    ["Totaal incl. BTW", formatEuroCents(input.ytd?.total_cents ?? 0)],
  ];
  for (const [label, val] of ytdRows) {
    page.drawText(label, { x: left, y, size: 10, font });
    page.drawText(val, {
      x: PDF_PAGE_WIDTH - PDF_MARGIN - 100,
      y,
      size: 10,
      font,
    });
    y -= PDF_LINE_HEIGHT;
  }
}

function drawFooter(
  page: PDFPage,
  font: PDFFont,
  pageNum: number,
  totalPages: number,
) {
  page.drawText(
    `Pluggo — kwartaaloverzicht — pagina ${pageNum} van ${totalPages}`,
    {
      x: PDF_MARGIN,
      y: 20,
      size: 8,
      font,
      color: rgb(0.5, 0.5, 0.5),
    }
  );
}

function drawMultiline(
  page: PDFPage,
  font: PDFFont,
  text: string,
  x: number,
  y: number,
  size: number,
  lineHeight: number,
) {
  const lines = text.split("\n");
  let cursor = y;
  for (const line of lines) {
    page.drawText(line, { x, y: cursor, size, font });
    cursor -= lineHeight;
  }
}

// ---------------------------------------------------------------------------
// Email HTML
// ---------------------------------------------------------------------------
interface EmailInput {
  target: Target;
  year: number;
  quarter: 1 | 2 | 3 | 4;
  quarterAgg: ReturnType<typeof aggregateQuarter>;
  downloadUrl: string;
}

function renderStatementEmailHtml(input: EmailInput): string {
  const naam =
    input.target.full_name?.split(" ")[0] ?? "paaleigenaar";
  const subtotal = formatEuroCents(input.quarterAgg.subtotal_cents);
  const vat = formatEuroCents(input.quarterAgg.vat_cents);
  const total = formatEuroCents(input.quarterAgg.total_cents);
  const kwh = formatKwh(input.quarterAgg.total_kwh);

  return `
<!doctype html>
<html lang="nl">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width" />
  <title>Pluggo kwartaaloverzicht Q${input.quarter} ${input.year}</title>
</head>
<body style="margin:0;padding:0;background:#f4f6f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#1c1c1c;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f5;padding:24px 0;">
    <tr><td align="center">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.05);">
        <tr>
          <td style="background:#268c58;padding:24px 28px;">
            <div style="color:#fff;font-size:20px;font-weight:700;letter-spacing:-0.2px;">Pluggo</div>
            <div style="color:#d5efe1;font-size:14px;margin-top:2px;">Kwartaaloverzicht Q${input.quarter} ${input.year}</div>
          </td>
        </tr>
        <tr>
          <td style="padding:28px;">
            <p style="margin:0 0 12px 0;font-size:16px;">Hoi ${escapeHtml(naam)},</p>
            <p style="margin:0 0 18px 0;font-size:14px;line-height:1.55;">
              Hier is je kwartaaloverzicht voor <strong>Q${input.quarter} ${input.year}</strong>.
              Je bent aangemeld als BTW-plichtige paaleigenaar bij Pluggo, dus we sturen elk
              kwartaal een overzicht dat je kunt gebruiken voor je BTW-aangifte.
            </p>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                   style="border-collapse:collapse;margin:8px 0 18px 0;background:#f8faf9;border-radius:8px;">
              <tr>
                <td style="padding:14px 18px;">
                  <div style="display:flex;justify-content:space-between;font-size:13px;color:#4a5a52;margin-bottom:6px;">
                    <span>Aantal sessies</span><span style="color:#1c1c1c;font-weight:600;">${input.quarterAgg.session_count}</span>
                  </div>
                  <div style="display:flex;justify-content:space-between;font-size:13px;color:#4a5a52;margin-bottom:6px;">
                    <span>Totaal kWh</span><span style="color:#1c1c1c;font-weight:600;">${kwh}</span>
                  </div>
                  <div style="display:flex;justify-content:space-between;font-size:13px;color:#4a5a52;margin-bottom:6px;">
                    <span>Omzet excl. BTW</span><span style="color:#1c1c1c;font-weight:600;">${subtotal}</span>
                  </div>
                  <div style="display:flex;justify-content:space-between;font-size:13px;color:#4a5a52;margin-bottom:6px;">
                    <span>BTW (21%)</span><span style="color:#1c1c1c;font-weight:600;">${vat}</span>
                  </div>
                  <div style="display:flex;justify-content:space-between;font-size:14px;color:#1c1c1c;font-weight:700;border-top:1px solid #dfe6e2;margin-top:8px;padding-top:8px;">
                    <span>Totaal incl. BTW</span><span>${total}</span>
                  </div>
                </td>
              </tr>
            </table>
            <p style="margin:0 0 18px 0;font-size:14px;line-height:1.55;">
              De volledige sessie-tabel + cumulatieve YTD-cijfers vind je in de PDF hieronder.
              De downloadlink is 30 dagen geldig — bewaar de PDF in je administratie.
            </p>
            <div style="text-align:center;margin:20px 0 8px 0;">
              <a href="${input.downloadUrl}" style="display:inline-block;padding:12px 24px;background:#268c58;color:#fff;text-decoration:none;border-radius:8px;font-size:15px;font-weight:600;">
                Download PDF-overzicht
              </a>
            </div>
            <p style="margin:16px 0 0 0;font-size:12px;color:#748078;line-height:1.5;">
              Pluggo hanteert een self-billing constructie conform art. 35e Wet OB. Vragen over
              dit overzicht? Antwoord op deze mail — dan helpt Ra'ka of Mattijs je verder.
            </p>
          </td>
        </tr>
        <tr>
          <td style="padding:16px 28px;background:#f4f6f5;color:#748078;font-size:11px;text-align:center;">
            Pluggo B.V. · info@pluggoapp.nl · pluggoapp.nl
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`.trim();
}

// ---------------------------------------------------------------------------
// send-email helper — hergebruikt de bestaande edge function.
// ---------------------------------------------------------------------------
async function callSendEmail(
  admin: ReturnType<typeof createClient>,
  to: string,
  subject: string,
  html: string,
) {
  const { data, error } = await admin.functions.invoke("send-email", {
    body: { to, subject, html },
  });
  if (error) {
    throw new Error(error.message || "onbekende send-email fout");
  }
  if (data && typeof data === "object" && "error" in data) {
    throw new Error(String((data as { error: unknown }).error));
  }
}

// ---------------------------------------------------------------------------
// Utils
// ---------------------------------------------------------------------------
function quarterStartDate(year: number, quarter: 1 | 2 | 3 | 4): string {
  const month = (quarter - 1) * 3 + 1;
  return `${year}-${String(month).padStart(2, "0")}-01`;
}

function quarterEndDate(year: number, quarter: 1 | 2 | 3 | 4): string {
  const endMonth = quarter * 3; // 3,6,9,12
  const endDay = [3, 6, 9].includes(endMonth)
    ? new Date(Date.UTC(year, endMonth, 0)).getUTCDate()
    : 31;
  return `${year}-${String(endMonth).padStart(2, "0")}-${String(endDay).padStart(2, "0")}`;
}

function formatDateNL(iso: string): string {
  try {
    const d = new Date(iso);
    if (isNaN(d.getTime())) return iso;
    const dd = String(d.getUTCDate()).padStart(2, "0");
    const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
    const yyyy = d.getUTCFullYear();
    return `${dd}-${mm}-${yyyy}`;
  } catch {
    return iso;
  }
}

function formatKwh(n: number | null | undefined): string {
  const val = Number(n ?? 0);
  return `${val.toFixed(2).replace(".", ",")} kWh`;
}

function formatEuroCents(cents: number | null | undefined): string {
  const c = Number(cents ?? 0);
  const euros = c / 100;
  return `\u20ac ${euros.toFixed(2).replace(".", ",")}`;
}

function truncateText(s: string, max: number): string {
  const clean = sanitizeWinAnsi(s);
  return clean.length > max ? clean.slice(0, max - 1) + "\u2026" : clean;
}

// pdf-lib's StandardFonts.Helvetica gebruikt WinAnsi encoding. Karakters
// buiten dat bereik (bijv. emoji in paal-namen) crashen drawText. Voor
// robuustheid vervangen we alles wat niet in WinAnsi zit met '?'. Nederlandse
// tekens (é, ë, ï, ç, etc.) + € zitten allemaal in WinAnsi, dus dit raakt
// alleen echt exotisch materiaal.
function sanitizeWinAnsi(s: string): string {
  if (!s) return "";
  // WinAnsi = Latin-1 + euro (0x80) + typografische quotes/dashes in 0x91-0x9D
  // range. Simpel: alles > 0xFF → '?', plus enkele bekende problematische
  // control-chars in 0x00-0x1F range (behalve tab/nieuwe regel).
  let out = "";
  for (const ch of s) {
    const code = ch.codePointAt(0) ?? 0;
    if (code > 0xff) {
      // Buiten Latin-1: probeer een paar veelvoorkomende Unicode → ASCII/Latin-1
      // replacements, val terug op '?'.
      if (ch === "\u2013" || ch === "\u2014") out += "-";      // en/em dash
      else if (ch === "\u2018" || ch === "\u2019") out += "'";  // curly quotes
      else if (ch === "\u201C" || ch === "\u201D") out += '"';  // curly dquotes
      else if (ch === "\u2026") out += "...";                    // ellipsis
      else if (ch === "\u20AC") out += "\u20AC";                 // euro (safe)
      else out += "?";
    } else if (code < 0x20 && ch !== "\t" && ch !== "\n") {
      out += " ";
    } else {
      out += ch;
    }
  }
  return out;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function okJson(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status: 200,
  });
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}
