// ============================================================================
// charging_estimator.dart — pure berekeningen voor live laadschatting (task #287)
//
// Alle rekenlogica los van UI/Supabase gehouden zodat 'ie:
//   1. Trivial te unit-testen is
//   2. Herbruikbaar is (bijv. later voor push #288: milestone-80%, ETA-10min)
//   3. Geen side-effects heeft — puur input → output
//
// De widget (live_charging_widget.dart) voedt deze functies met wat 'ie
// heeft: MeterValues-history uit charging_session_meter_values + profile
// velden uit profiles + max_power_kw uit chargers.
//
// FILOSOFIE — DEFENSIEF SCHATTEN:
//   - Als data ontbreekt (start_soc null, batterij null, etc.) → return null
//     ipv gokken. UI verbergt dan dat veld ipv nep-cijfer tonen.
//   - Onder- ipv overschat. "Nog 30 min" is beter dan "nog 20" en 40 blijken.
//   - Sanity-caps: SoC klemt op 0-100, ETA op max 24 uur (>1 dag = onzin).
// ============================================================================

import 'dart:math' as math;

/// Snapshot van een lopende sessie op één moment. Wordt door de widget
/// gebouwd uit de laatste `charging_sessions` row + optioneel de laatste N
/// meter-value ticks uit `charging_session_meter_values`.
class SessionSnapshot {
  const SessionSnapshot({
    required this.chargedKwh,
    required this.sessionAge,
    required this.recentKw,
  });

  /// Cumulatief geladen in kWh sinds start (meter_current_wh - meter_start_wh).
  final double chargedKwh;

  /// Hoe lang de sessie al draait — bepaalt of we genoeg data hebben voor
  /// tempo-schatting en kalibratie-suggesties.
  final Duration sessionAge;

  /// Gemeten laadvermogen over de meest recente window (~1 minuut). Berekend
  /// door de widget uit (Δwh / Δt) van de laatste twee ticks. Null als er
  /// nog geen 2 ticks zijn.
  final double? recentKw;
}

/// Schat huidige SoC-percentage op basis van geladen kWh en batterij-capaciteit.
///
/// Vereist start_soc_pct — zonder die anker-waarde kunnen we geen absoluut
/// percentage tonen (wel kWh en ETA-tot-vol).
///
/// Klemt op 100% om te voorkomen dat we "112%" tonen bij overschatting.
int? estimateCurrentSocPct({
  required int? startSocPct,
  required double chargedKwh,
  required double? batteryCapacityKwh,
}) {
  if (startSocPct == null) return null;
  if (batteryCapacityKwh == null || batteryCapacityKwh <= 0) return null;
  final gainedPct = (chargedKwh / batteryCapacityKwh) * 100.0;
  final soc = startSocPct + gainedPct;
  return soc.clamp(0, 100).round();
}

/// Verwacht effectief laadvermogen: bottleneck van paal en auto.
///
/// Beide velden zijn nullable — als er maar één bekend is nemen we die.
/// Als beide null → return null (widget toont dan "onbekend").
double? expectedEffectiveKw({
  required double? chargerMaxKw,
  required double? vehicleMaxAcKw,
}) {
  if (chargerMaxKw == null && vehicleMaxAcKw == null) return null;
  if (chargerMaxKw == null) return vehicleMaxAcKw;
  if (vehicleMaxAcKw == null) return chargerMaxKw;
  return math.min(chargerMaxKw, vehicleMaxAcKw);
}

/// Schat ETA (minuten) tot doel-SoC bereikt is.
///
/// Formule: (target_soc - current_soc) / 100 * batterij_kwh / effectief_kw * 60
///
/// Retourneert null als:
///   - current al ≥ target (klaar, geen ETA nodig)
///   - één van de inputs ontbreekt (kan niet rekenen)
///   - effectief_kw ≤ 0 (paal levert niks — oneindig lang)
///
/// Cap op 24u — als 't langer duurt is er iets fundamenteel mis met de
/// meting; toon dan liever "onbekend" dan een absurd getal.
int? estimateEtaMinutes({
  required int? currentSocPct,
  required int targetSocPct,
  required double? effectiveKw,
  required double? batteryCapacityKwh,
}) {
  if (currentSocPct == null) return null;
  if (effectiveKw == null || effectiveKw <= 0) return null;
  if (batteryCapacityKwh == null || batteryCapacityKwh <= 0) return null;
  if (currentSocPct >= targetSocPct) return 0;

  final remainingPct = targetSocPct - currentSocPct;
  final remainingKwh = (remainingPct / 100.0) * batteryCapacityKwh;
  final hours = remainingKwh / effectiveKw;
  final minutes = (hours * 60).round();

  if (minutes < 0) return null;
  if (minutes > 24 * 60) return null; // sanity cap
  return minutes;
}

/// Formatteer ETA-minuten naar Nederlandse UI-tekst.
///
/// Voorbeelden: 0→"minder dan 1 min", 5→"5 min", 65→"1 u 5 min", 60→"1 u".
String formatEtaLabel(int minutes) {
  if (minutes <= 0) return 'bijna klaar';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (mins == 0) return '$hours u';
  return '$hours u $mins min';
}

/// Kalibratie-signaal: wijkt de gemeten laadsnelheid significant af van de
/// verwachting? Dat betekent dat óf de paal-specs, óf de auto-preset, óf
/// de auto zelf iets anders doet dan gedacht (BMS-cap, koude batterij).
///
/// Trigger-regels (bewust conservatief — nudge, geen alarm):
///   - Minstens `minSessionAge` verstreken (default 2 min) zodat het niet
///     op het startvermogen-rampje ("preconditioning") triggert.
///   - Gemeten laadvermogen is `deviationRatio` × lager dan verwacht
///     (default 0.7 = 30% onder).
///   - Beide vermogens bekend (anders geen vergelijking mogelijk).
bool shouldSuggestCalibration({
  required Duration sessionAge,
  required double? measuredKw,
  required double? expectedKw,
  Duration minSessionAge = const Duration(minutes: 2),
  double deviationRatio = 0.7,
}) {
  if (sessionAge < minSessionAge) return false;
  if (measuredKw == null || expectedKw == null) return false;
  if (expectedKw <= 0) return false;
  return measuredKw < expectedKw * deviationRatio;
}

/// Format kW-waarde voor UI. Nederlands: komma-decimaal, 1 decimaal genoeg.
/// Voorbeelden: 10.8 → "10,8 kW", 3.7 → "3,7 kW", 11.0 → "11,0 kW".
String formatKw(double kw) => '${kw.toStringAsFixed(1).replaceAll('.', ',')} kW';

/// Format kWh voor UI. 2 decimalen om aan te sluiten bij Pluggo-facturatie.
String formatKwh(double kwh) =>
    '${kwh.toStringAsFixed(2).replaceAll('.', ',')} kWh';

/// Format euro-bedrag zonder currency-lib overkill.
/// Voorbeelden: 0.87 → "€0,87", 1.5 → "€1,50", 12.345 → "€12,35".
String formatEuro(double amount) =>
    '€${amount.toStringAsFixed(2).replaceAll('.', ',')}';
