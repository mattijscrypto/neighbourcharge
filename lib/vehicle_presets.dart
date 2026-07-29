// ============================================================================
// vehicle_presets.dart — preset-lijst van populairste EV's in Nederland
//
// Gebruikt door het profielscherm (EditProfileScreen) om de gebruiker in één
// tap zijn/haar voertuig-eigenschappen (capaciteit + max AC-vermogen) te
// laten invullen. Deze waarden gaan naar de profiles-tabel en zijn nodig voor:
//   - Live ETA-berekening tijdens een laadsessie (task #287)
//   - Auto-stop bij target-SoC (task #289)
//   - "Verwacht laadvermogen" tonen in de boekingsflow
//
// De preset-lijst is bewust ~30 items — genoeg om de meeste NL EV-rijders
// te dekken, kort genoeg om scrollbaar te zijn zonder search-veld.
//
// KEUZES per model:
//   - batteryCapacityKwh — USABLE capacity (niet gross). Bron: fabrikant
//     of ev-database.org. Voor modellen met meerdere accu-varianten kiezen
//     we de meest verkochte in NL.
//   - maxAcKw           — max AC on-board charger vermogen. De grote
//     meerderheid van moderne NL EV's zit op 11 kW. Uitzonderingen:
//     Renault Zoe/Megane E-Tech en Smart #1 (22 kW), Nissan Leaf (6.6 kW).
//
// User mag na kiezen van preset de waarden alsnog overrulen — sommige
// modellen hebben trim-varianten met andere accu. Er is ook een sentinel
// preset "Anders / handmatig" die de velden leegt zodat de user zelf typt.
//
// NB: whole-number kWh/kW waarden staan als int-literals (bijv. `77`) i.p.v.
// double-literals (`77.0`) — Dart promoot int-literals automatisch naar
// double in double-parameter-context, en de lint-rule `prefer_int_literals`
// vraagt dit. Alleen fractionele waarden (Nissan Leaf 6.6 kW) blijven double.
// ============================================================================

class VehiclePreset {
  const VehiclePreset({
    required this.model,
    required this.batteryCapacityKwh,
    required this.maxAcKw,
  });

  final String model;
  final double batteryCapacityKwh;
  final double maxAcKw;
}

/// Populairste EV's in Nederland — top ~30 op basis van RVO/BOVAG
/// registratiecijfers 2024-2025. Gealfabetiseerd per merk zodat de user
/// snel kan scannen.
const List<VehiclePreset> kVehiclePresets = [
  // Audi
  VehiclePreset(model: 'Audi Q4 e-tron',           batteryCapacityKwh: 77, maxAcKw: 11),

  // BMW
  VehiclePreset(model: 'BMW i4',                    batteryCapacityKwh: 81, maxAcKw: 11),
  VehiclePreset(model: 'BMW iX1',                   batteryCapacityKwh: 65, maxAcKw: 11),
  VehiclePreset(model: 'BMW iX3',                   batteryCapacityKwh: 74, maxAcKw: 11),

  // BYD
  VehiclePreset(model: 'BYD Atto 3',                batteryCapacityKwh: 60, maxAcKw: 7),

  // Cupra
  VehiclePreset(model: 'Cupra Born',                batteryCapacityKwh: 58, maxAcKw: 11),

  // Fiat
  VehiclePreset(model: 'Fiat 500e',                 batteryCapacityKwh: 42, maxAcKw: 11),

  // Ford
  VehiclePreset(model: 'Ford Mustang Mach-E',       batteryCapacityKwh: 75, maxAcKw: 11),

  // Hyundai
  VehiclePreset(model: 'Hyundai Ioniq 5',           batteryCapacityKwh: 77, maxAcKw: 11),
  VehiclePreset(model: 'Hyundai Ioniq 6',           batteryCapacityKwh: 77, maxAcKw: 11),
  VehiclePreset(model: 'Hyundai Kona Electric',     batteryCapacityKwh: 64, maxAcKw: 11),

  // Kia
  VehiclePreset(model: 'Kia EV6',                   batteryCapacityKwh: 77, maxAcKw: 11),
  VehiclePreset(model: 'Kia Niro EV',               batteryCapacityKwh: 64, maxAcKw: 11),

  // Mercedes
  VehiclePreset(model: 'Mercedes EQA',              batteryCapacityKwh: 66, maxAcKw: 11),

  // MG
  VehiclePreset(model: 'MG4 Electric',              batteryCapacityKwh: 64, maxAcKw: 11),
  VehiclePreset(model: 'MG ZS EV',                  batteryCapacityKwh: 72, maxAcKw: 11),

  // Nissan (oudere Leaf zit op 6.6 kW — belangrijk om apart te zetten)
  VehiclePreset(model: 'Nissan Leaf',               batteryCapacityKwh: 39, maxAcKw: 6.6),

  // Peugeot
  VehiclePreset(model: 'Peugeot e-208',             batteryCapacityKwh: 50, maxAcKw: 11),
  VehiclePreset(model: 'Peugeot e-2008',            batteryCapacityKwh: 50, maxAcKw: 11),
  VehiclePreset(model: 'Peugeot e-308',             batteryCapacityKwh: 54, maxAcKw: 11),

  // Polestar
  VehiclePreset(model: 'Polestar 2',                batteryCapacityKwh: 78, maxAcKw: 11),

  // Renault (22 kW AC — bijzonder)
  VehiclePreset(model: 'Renault Megane E-Tech',     batteryCapacityKwh: 60, maxAcKw: 22),
  VehiclePreset(model: 'Renault Zoe',               batteryCapacityKwh: 52, maxAcKw: 22),

  // Škoda
  VehiclePreset(model: 'Škoda Enyaq',               batteryCapacityKwh: 77, maxAcKw: 11),

  // Tesla — Model 3 en Y zijn de best-verkopende EV's in NL
  VehiclePreset(model: 'Tesla Model 3',             batteryCapacityKwh: 75, maxAcKw: 11),
  VehiclePreset(model: 'Tesla Model Y',             batteryCapacityKwh: 75, maxAcKw: 11),

  // Toyota
  VehiclePreset(model: 'Toyota bZ4X',               batteryCapacityKwh: 71, maxAcKw: 11),

  // Volkswagen — grote familie, allemaal ~77 kWh / 11 kW behalve ID.3
  VehiclePreset(model: 'Volkswagen ID.3',           batteryCapacityKwh: 58, maxAcKw: 11),
  VehiclePreset(model: 'Volkswagen ID.4',           batteryCapacityKwh: 77, maxAcKw: 11),
  VehiclePreset(model: 'Volkswagen ID.5',           batteryCapacityKwh: 77, maxAcKw: 11),
  VehiclePreset(model: 'Volkswagen ID.7',           batteryCapacityKwh: 77, maxAcKw: 11),
  VehiclePreset(model: 'Volkswagen ID. Buzz',       batteryCapacityKwh: 77, maxAcKw: 11),

  // Volvo
  VehiclePreset(model: 'Volvo EX30',                batteryCapacityKwh: 64, maxAcKw: 11),
  VehiclePreset(model: 'Volvo XC40 Recharge',       batteryCapacityKwh: 67, maxAcKw: 11),
];

/// Kijkt op basis van modelnaam of er een preset bekend is.
/// Wordt gebruikt bij initiële load (auto-selecteert bijbehorende preset in
/// de dropdown als de user 'm eerder heeft gekozen).
///
/// Normalisatie is tolerant voor whitespace-variaties: "Volkswagen ID.Buzz"
/// en "Volkswagen ID. Buzz" matchen allebei op dezelfde preset. Dit
/// voorkomt dat oudere save's die spellingsvariant hebben opgeslagen bij
/// herladen niet terug-mappen naar de preset.
VehiclePreset? findPresetByModel(String? model) {
  if (model == null || model.isEmpty) return null;
  final normalized = _normalizeModelName(model);
  for (final p in kVehiclePresets) {
    if (_normalizeModelName(p.model) == normalized) return p;
  }
  return null;
}

/// Verwijdert alle whitespace en lowercased — zodat spelling-variaties
/// (spatie na punt, dubbele spatie, hoofdletters) toch matchen.
String _normalizeModelName(String s) =>
    s.replaceAll(RegExp(r'\s+'), '').toLowerCase();
