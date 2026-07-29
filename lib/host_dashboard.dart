// ============================================================================
// host_dashboard.dart — Host-tab body: eigen laden + verhuur-overzicht.
//
// Verantwoordelijkheden (task #339 + #340):
//   1. Statustegel bovenaan: idle / eigen sessie / gastsessie
//   2. Vier maand-tegels: eigen laden kWh, verhuur kWh + verdiend, ERE (stub)
//   3. Prominente "Start eigen laadsessie"-CTA — opent paal-picker als de host
//      meerdere palen heeft, roept dan remote-start-session aan met
//      initiated_by=owner (sessie_type='eigen_laden').
//   4. Sessie-geschiedenis (laatste 15) met eigen_laden vs gastladen marker +
//      MID-signedMeterValue-indicator.
//
// Data-bronnen:
//   - `chargers` — de eigen palen van de user (via `owner_id = auth.uid()`)
//   - `charging_sessions` — actieve + historische sessies gekoppeld aan die
//     palen. Kolom `initiated_by_owner` (bool) of `session_type` gebruikt om
//     eigen laden vs gastladen te onderscheiden.
//   - Realtime subscription op charging_sessions om statustegel live te houden.
//
// Wat deze widget NIET doet:
//   - Werkgever-declaratie-PDF (task #341) — komt via extra CTA na launch.
//   - Kalibratie-suggesties (dat doet LiveChargingCard voor booker-flow).
//   - Tag-registratie flow (task #340 fase 1 optie B) — aparte bottom-sheet.
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Kleuren spiegelen AppColors uit main.dart. We importeren die niet om circular
// dependencies te voorkomen — main.dart importeert dit bestand.
class _HostColors {
  static const primary = Color(0xFF00A87E);
  static const primaryDark = Color(0xFF00795A);
  static const primarySoft = Color(0xFFE6F7F1);
  static const surface = Colors.white;
  static const background = Color(0xFFF5F5F7);
  static const textPrimary = Color(0xFF111214);
  static const textSecondary = Color(0xFF6B6F76);
  static const divider = Color(0xFFE5E7EB);
  static const amber = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
}

List<BoxShadow> _softShadow() => [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];

// ============================================================================
// Public entry — dit widget zit als tab-body in HomeScreen. Krijgt de sticky
// tab pill via `headerContent` mee zodat de host altijd terug kan naar Boeken.
// ============================================================================

class HostDashboardBody extends StatefulWidget {
  const HostDashboardBody({
    Key? key,
    required this.topInset,
  }) : super(key: key);

  /// Ruimte die de sticky header (logo + tab-pill) boven ons inneemt.
  /// HomeScreen berekent dit en geeft het door zodat de dashboard-scroll
  /// niet onder de header valt.
  final double topInset;

  @override
  State<HostDashboardBody> createState() => _HostDashboardBodyState();
}

class _HostDashboardBodyState extends State<HostDashboardBody> {
  final _supa = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  List<_HostCharger> _chargers = [];
  _ActiveSessionSnapshot? _activeSession;
  _MonthlyTotals _monthly = _MonthlyTotals.empty();
  List<_HostSession> _recent = [];

  RealtimeChannel? _sessionsChannel;

  // ---------------------------------------------------------------------------
  // Live-laadtegel state (task #340 / #287 owner-variant)
  //
  // Voor een actieve owner-sessie tonen we een tegel met:
  //   - looptijd (verstrijkt live via _tickerTimer)
  //   - kWh geladen (uit _activeSession.meterWh, groot letterformaat)
  //   - live kW nu (rolling average over de laatste ~12 MeterValues)
  //   - progress bar 0 → charger.max_power_kw
  //
  // Onderdelen die we NIET tonen (bewuste keuze):
  //   - Kosten in €: de host laadt zichzelf op eigen stroomcontract. Dat is
  //     'ie zelf al kwijt, en het is niet de paalprijs die 'ie boekers vraagt.
  //     Kosten voor eigen laden komt evt. bij werkgever-declaratie (#341).
  //   - Target-SoC / ETA: geen boeking-context, geen batterij-info bekend.
  //     Kunnen we later toevoegen als host-profiel-EV-model gekoppeld wordt.
  //
  // _meterWindow: chronologisch (oudste eerst → nieuwste laatst) laatste 12
  //   samples. Zie live_charging_widget.dart voor waarom rolling avg belangrijk
  //   is bij OCPP MeterValue-jitter.
  // ---------------------------------------------------------------------------
  static const int _kMeterWindowSize = 12;
  List<({int wh, DateTime at})> _meterWindow = const [];
  RealtimeChannel? _meterValuesChannel;
  Timer? _tickerTimer;

  // ---------------------------------------------------------------------------
  // Dev-preview: alleen kDebugMode. Zonder OCPP-paal + auto is er geen manier
  // om de live-tegel visueel te tunen — deze knop injecteert een fake sessie
  // + realistische groeiende meter-samples zodat je de layout kunt bekijken.
  // Wordt in release builds volledig weggecompileerd via de kDebugMode-guard.
  // ---------------------------------------------------------------------------
  bool _devPreviewActive = false;
  Timer? _devPreviewTicker;

  @override
  void initState() {
    super.initState();
    _refresh();
    // 10s-ticker: laat de "loopt X min"-tekst en tijd-in-seconde-tegels
    // vloeiend verstrijken zonder op nieuwe MeterValues te wachten. Alleen
    // een setState — de child-widgets herberekenen op basis van DateTime.now().
    _tickerTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted && _activeSession != null) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _sessionsChannel?.unsubscribe();
    _meterValuesChannel?.unsubscribe();
    _tickerTimer?.cancel();
    _devPreviewTicker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dev-preview toggle — alleen beschikbaar in kDebugMode.
  // Start: injecteert een fake _activeSession + laat _meterWindow groeien via
  // een periodieke timer (elke 3s +0.2 kWh, realistisch voor 11 kW paal).
  // Stop: ruimt alles op en herlaadt de echte data.
  // ---------------------------------------------------------------------------
  void _startDevPreview() {
    if (!kDebugMode) return;
    final now = DateTime.now();
    const startWh = 2800.0;
    setState(() {
      _devPreviewActive = true;
      _activeSession = _ActiveSessionSnapshot(
        transactionId: 9999,
        chargerId: _chargers.isNotEmpty ? _chargers.first.id : 'dev-charger',
        bookingId: null,
        startedAt: now.subtract(const Duration(minutes: 14, seconds: 23)),
        initiatedByOwner: true,
        meterWh: startWh,
      );
      _meterWindow = [
        (wh: 2400, at: now.subtract(const Duration(seconds: 60))),
        (wh: 2600, at: now.subtract(const Duration(seconds: 30))),
        (wh: 2800, at: now),
      ];
    });

    _devPreviewTicker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_devPreviewActive) return;
      final latest = _meterWindow.last;
      final next = (wh: latest.wh + 91, at: DateTime.now()); // ~11 kW
      setState(() {
        _activeSession = _ActiveSessionSnapshot(
          transactionId: _activeSession!.transactionId,
          chargerId: _activeSession!.chargerId,
          bookingId: _activeSession!.bookingId,
          startedAt: _activeSession!.startedAt,
          initiatedByOwner: true,
          meterWh: next.wh.toDouble(),
        );
        _meterWindow = [
          ..._meterWindow.length >= 12
              ? _meterWindow.sublist(1)
              : _meterWindow,
          next,
        ];
      });
    });
  }

  void _stopDevPreview() {
    if (!kDebugMode) return;
    _devPreviewTicker?.cancel();
    _devPreviewTicker = null;
    setState(() {
      _devPreviewActive = false;
      _activeSession = null;
      _meterWindow = const [];
    });
    _refresh();
  }

  Future<void> _refresh() async {
    // Guard: tijdens dev-preview willen we niet dat een realtime-callback of
    // manuele refresh de gefakete _activeSession/_meterWindow overschrijft.
    if (_devPreviewActive) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supa.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _loading = false;
          _error = 'Niet ingelogd.';
        });
        return;
      }

      // 1. Eigen palen
      final chargersRaw = await _supa
          .from('chargers')
          .select('id, name, address, ocpp_charger_id, is_online, max_power_kw, has_mid_meter')
          .eq('owner_id', userId);

      final chargers = (chargersRaw as List)
          .map((r) => _HostCharger.fromMap(r as Map<String, dynamic>))
          .toList();

      // 2. Actieve sessie (indien aanwezig) op één van deze palen
      _ActiveSessionSnapshot? active;
      if (chargers.isNotEmpty) {
        final chargerIds = chargers.map((c) => c.id).toList();
        // Postgres 'in_' filter via .inFilter voor supabase_flutter 2.x.
        // Order + limit(1) vóór maybeSingle: als er per ongeluk meerdere
        // in_progress-sessies bestaan (stale test-data, orphaned CSMS-events),
        // pakken we de meest recente in plaats van te crashen op een 406.
        final activeRaw = await _supa
            .from('charging_sessions')
            .select(
                'transaction_id, charger_id, booking_id, started_at, meter_start_wh, meter_current_wh, initiated_by_owner, status')
            .inFilter('charger_id', chargerIds)
            .eq('status', 'in_progress')
            .order('started_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (activeRaw != null) {
          active = _ActiveSessionSnapshot.fromMap(
              activeRaw as Map<String, dynamic>);
        }
      }

      // 3. Maand-aggregaat: alle sessies deze maand op eigen palen
      _MonthlyTotals monthly = _MonthlyTotals.empty();
      List<_HostSession> recent = [];
      if (chargers.isNotEmpty) {
        final chargerIds = chargers.map((c) => c.id).toList();
        final firstOfMonth =
            DateTime(DateTime.now().year, DateTime.now().month, 1)
                .toIso8601String();

        final sessionsRaw = await _supa
            .from('charging_sessions')
            .select(
                'transaction_id, charger_id, started_at, stopped_at, meter_start_wh, meter_current_wh, meter_stop_wh, initiated_by_owner, status, booking_id')
            .inFilter('charger_id', chargerIds)
            .gte('started_at', firstOfMonth)
            .order('started_at', ascending: false)
            .limit(50);

        // Bouw een set van charger-IDs met MID-meter voor snelle lookup.
        final midChargerIds = chargers
            .where((c) => c.hasMidMeter)
            .map((c) => c.id)
            .toSet();

        for (final s in (sessionsRaw as List)) {
          final m = s as Map<String, dynamic>;
          final session = _HostSession.fromMap(m);
          if (session.status == 'completed') {
            if (session.initiatedByOwner) {
              monthly.eigenKwh += session.kwh;
            } else {
              monthly.verhuurKwh += session.kwh;
              // Verdiend = kWh × (paalprijs - €0,03). Zonder paalprijs
              // hier laten we het rustig — verdiend wordt server-side
              // exact berekend via de payments-tabel, ophalen post-launch.
            }
            // ERE: alle kWh op MID-gecertificeerde palen (eigen + verhuur).
            if (midChargerIds.contains(session.chargerId)) {
              monthly.ereKwh += session.kwh;
            }
          }
        }

        // Laatste 15 (van de 50 die we ophaalden) voor de UI-lijst.
        recent = (sessionsRaw as List)
            .take(15)
            .map((s) => _HostSession.fromMap(s as Map<String, dynamic>))
            .toList();
      }

      setState(() {
        _chargers = chargers;
        _activeSession = active;
        _monthly = monthly;
        _recent = recent;
        _loading = false;
      });

      _subscribeSessions();
      // Als er een lopende sessie is: rolling window met kWh-samples ophalen
      // en subscriben op nieuwe ticks voor live kW-berekening.
      if (active != null) {
        await _loadRecentMeterValues(active.transactionId);
        _subscribeMeterValues(active.transactionId);
      } else {
        _meterValuesChannel?.unsubscribe();
        _meterValuesChannel = null;
        _meterWindow = const [];
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Kon dashboard niet laden: $e';
      });
    }
  }

  void _subscribeSessions() {
    _sessionsChannel?.unsubscribe();
    if (_chargers.isEmpty) return;
    final userId = _supa.auth.currentUser?.id;
    if (userId == null) return;
    _sessionsChannel = _supa
        .channel('host_dashboard_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'charging_sessions',
          callback: (_) {
            // Debounce niet nodig — refresh is idempotent en licht.
            if (mounted) _refresh();
          },
        )
        .subscribe();
  }

  // ---------------------------------------------------------------------------
  // Meter values: rolling window ophalen + realtime subscribe
  //
  // charging_session_meter_values wordt door de CSMS-bridge gevuld (per OCPP-
  // tick, meestal elke 10-30 s). We houden de laatste 12 samples aan om een
  // stabiele kW-schatting te maken — 1 sample is te veel ruis, 2 samples pakt
  // OCPP-jitter niet weg. Zie live_charging_widget.dart voor de motivatie.
  //
  // Subscriben is bewust op INSERT (nieuwe ticks) gefilterd op transaction_id,
  // niet 'all' — we willen niet elke MeterValue van elke sessie in de app op-
  // vangen als de host tientallen palen heeft.
  // ---------------------------------------------------------------------------
  Future<void> _loadRecentMeterValues(int transactionId) async {
    try {
      final rows = await _supa
          .from('charging_session_meter_values')
          .select('meter_wh, measured_at')
          .eq('transaction_id', transactionId)
          .order('measured_at', ascending: false)
          .limit(_kMeterWindowSize);
      if (!mounted) return;
      final list = (rows as List).cast<Map<String, dynamic>>();
      // Newest→oldest omdraaien naar chronologisch (oudste → nieuwste) zodat
      // first/last logica intuïtief blijft.
      final samples = list.reversed
          .map((r) => (
                wh: (r['meter_wh'] as num).toInt(),
                at: DateTime.parse(r['measured_at'] as String).toLocal(),
              ))
          .toList(growable: false);
      setState(() => _meterWindow = samples);
    } catch (_) {
      // Silent — als de tabel er nog niet is of RLS blokkeert vallen we
      // gewoon terug op de kWh-teller uit charging_sessions zelf.
    }
  }

  void _subscribeMeterValues(int transactionId) {
    _meterValuesChannel?.unsubscribe();
    _meterValuesChannel = _supa
        .channel('host_meter_values_$transactionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'charging_session_meter_values',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'transaction_id',
            value: transactionId,
          ),
          callback: (_) => _loadRecentMeterValues(transactionId),
        )
        .subscribe();
  }

  /// Rolling-average laadvermogen (kW) over de window: (last_wh − first_wh)
  /// gedeeld door (last_at − first_at), millisecond-precisie.
  ///
  /// Null als er nog geen 2 samples zijn, of als de window verdacht is
  /// (dt ≤ 0 of dWh < 0 — kan bij out-of-order ticks).
  double? get _measuredKw {
    if (_meterWindow.length < 2) return null;
    final first = _meterWindow.first;
    final last = _meterWindow.last;
    final dtMs = last.at.difference(first.at).inMilliseconds;
    if (dtMs <= 0) return null;
    final dWh = last.wh - first.wh;
    if (dWh < 0) return null;
    // kW = dWh × 3600 / dtMs   (Wh over ms → kW)
    return dWh * 3600.0 / dtMs;
  }

  Future<void> _startEigenLadenSessie() async {
    if (_chargers.isEmpty) {
      _snack('Je hebt nog geen eigen paal om te laden.');
      return;
    }
    if (_activeSession != null) {
      _snack('Er loopt al een sessie op je paal.');
      return;
    }

    // Enkele paal → direct starten. Meerdere → picker.
    _HostCharger target;
    if (_chargers.length == 1) {
      target = _chargers.first;
    } else {
      final picked = await _pickCharger();
      if (picked == null) return;
      target = picked;
    }

    if (target.ocppChargerId == null) {
      _snack(
          '${target.name} is niet OCPP-gekoppeld. Koppel de paal eerst via Mijn Palen.');
      return;
    }
    if (!target.isOnline) {
      _snack(
          '${target.name} is offline. Check dat de paal verbinding heeft met Pluggo.');
      return;
    }

    // Loading-state via dialog
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: _HostColors.primary)),
    ));

    try {
      final res = await _supa.functions.invoke(
        'remote-start-session',
        body: {
          'charger_id': target.id,
          'initiated_by_owner': true,
        },
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close spinner

      final status = res.status ?? 0;
      final data = res.data;
      if (status >= 400) {
        _snack(_reasonFrom(data) ?? 'Start-verzoek geweigerd.');
        return;
      }
      final accepted = data is Map && data['accepted'] == true;
      _snack(accepted
          ? 'Laadopdracht verstuurd — de paal begint zo met laden.'
          : (_reasonFrom(data) ?? 'Paal wees start-verzoek af.'));
      // Realtime channel triggert refresh vanzelf.
    } on FunctionException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _snack(_reasonFrom(e.details) ?? 'Kon niet starten — probeer opnieuw.');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _snack('Onverwachte fout: $e');
    }
  }

  Future<void> _stopEigenLadenSessie() async {
    final s = _activeSession;
    if (s == null) return;
    try {
      // remote-stop-session accepteert transaction_id (owner-flow) of
      // booking_id (booker-flow). Eigen laadsessies hebben géén booking_id,
      // dus we sturen de transaction_id van de lopende sessie mee.
      final res = await _supa.functions.invoke(
        'remote-stop-session',
        body: {
          'transaction_id': s.transactionId,
          if (s.bookingId != null) 'booking_id': s.bookingId,
        },
      );
      if (!mounted) return;
      final status = res.status ?? 0;
      if (status >= 400) {
        _snack(_reasonFrom(res.data) ?? 'Stop-verzoek geweigerd.');
        return;
      }
      _snack('Stop-opdracht verstuurd — sessie sluit zo af.');
    } catch (e) {
      _snack('Kon niet stoppen: $e');
    }
  }

  Future<_HostCharger?> _pickCharger() async {
    return showModalBottomSheet<_HostCharger>(
      context: context,
      backgroundColor: _HostColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welke paal wil je starten?',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _HostColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ..._chargers.map((c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      c.isOnline
                          ? Icons.bolt_rounded
                          : Icons.power_off_rounded,
                      color: c.isOnline
                          ? _HostColors.primary
                          : _HostColors.textSecondary,
                    ),
                    title: Text(c.name),
                    subtitle: Text(c.address ?? ''),
                    trailing: c.ocppChargerId == null
                        ? Text(
                            'niet gekoppeld',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _HostColors.textSecondary,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(c),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _reasonFrom(dynamic data) {
    if (data is Map) {
      final reason = data['reason'] ?? data['error'];
      if (reason is String && reason.isNotEmpty) return reason;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.only(top: widget.topInset),
        child: const Center(
          child: CircularProgressIndicator(color: _HostColors.primary),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.only(top: widget.topInset + 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: _HostColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _HostColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _refresh,
                child: const Text('Opnieuw'),
              ),
            ],
          ),
        ),
      );
    }

    if (_chargers.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      color: _HostColors.primary,
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.only(
          top: widget.topInset + 8,
          left: 16,
          right: 16,
          bottom: 32,
        ),
        children: [
          _statusTile(),
          // Debug-only knop: preview live-tegel zonder echte auto/paal.
          // Weggecompileerd in release builds via kDebugMode.
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _devPreviewActive ? _stopDevPreview : _startDevPreview,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _devPreviewActive
                      ? const Color(0xFFFFEECC)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _devPreviewActive
                        ? const Color(0xFFE6A817)
                        : const Color(0xFFCCCCCC),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _devPreviewActive
                          ? '🐛 Preview aan — tik om te stoppen'
                          : '🐛 Preview live-tegel',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Live-tegel: alleen bij een eigen actieve sessie. Gastsessies
          // rendert de booker's app zelf via LiveChargingCard; de host hoeft
          // die niet nog eens te zien.
          if ((_activeSession != null && _activeSession!.initiatedByOwner)) ...[
            const SizedBox(height: 12),
            _liveOwnerTile(),
          ],
          const SizedBox(height: 16),
          _startCta(),
          const SizedBox(height: 24),
          _tegelsRow(),
          const SizedBox(height: 24),
          _sessionListHeader(),
          const SizedBox(height: 8),
          ..._recent.map(_sessionRow),
          if (_recent.isEmpty) _sessionListEmpty(),
          const SizedBox(height: 24),
          _mijnPalenLink(),
        ],
      ),
    );
  }

  // ---------- Building blocks ----------

  Widget _emptyState() {
    return Padding(
      padding: EdgeInsets.only(top: widget.topInset + 32, left: 24, right: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.ev_station_rounded,
              size: 56, color: _HostColors.primary),
          const SizedBox(height: 16),
          Text(
            'Nog geen eigen paal',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _HostColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Voeg een paal toe om via Pluggo te laden, te verhuren en je sessies bij te houden.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _HostColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _HostColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              // Navigatie naar Mijn Palen loopt via het profielmenu in main.dart.
              // We tonen hier een snack die de user erheen wijst — geen
              // directe navigator-push omdat we anders het profielmenu-model
              // moeten dupliceren.
              _snack('Open het profielmenu (rechtsboven) → Mijn palen.');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Voeg je paal toe'),
          ),
        ],
      ),
    );
  }

  Widget _statusTile() {
    final s = _activeSession;
    final isEigen = s?.initiatedByOwner == true;
    final label = s == null
        ? 'Paal is beschikbaar'
        : (isEigen ? 'Eigen sessie loopt' : 'Gastsessie loopt');
    final subtitle = s == null
        ? _chargers
            .map((c) => c.isOnline ? '${c.name} online' : '${c.name} offline')
            .join(' · ')
        : 'sinds ${_formatTime(s.startedAt)}';
    final color = s == null
        ? _HostColors.primaryDark
        : (isEigen ? _HostColors.primary : _HostColors.amber);
    final icon = s == null
        ? Icons.check_circle_outline_rounded
        : (isEigen ? Icons.ev_station_rounded : Icons.person_pin_circle_rounded);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _HostColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _softShadow(),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _HostColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _HostColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (s != null && isEigen)
            TextButton(
              onPressed: _stopEigenLadenSessie,
              style: TextButton.styleFrom(foregroundColor: _HostColors.danger),
              child: const Text('Stop'),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Live-laadtegel — actieve owner-sessie (task #340)
  //
  // Grote kWh-teller in het midden, tijd en kW eromheen. Progress bar toont
  // hoe vol we relatief tot de max van de paal zitten (als die bekend is).
  // Auto-updates via realtime meter values + 10s ticker.
  // ---------------------------------------------------------------------------
  Widget _liveOwnerTile() {
    final s = _activeSession!;
    // Kaart-context: de paal die 'ie op laadt. Vind 'm in _chargers om
    // max_power_kw op te halen. Als paal ondertussen verwijderd is (edge
    // case) → gebruik unknown.
    final charger = _chargers.firstWhere(
      (c) => c.id == s.chargerId,
      orElse: () => _HostCharger.unknown(),
    );
    final chargedKwh = s.meterWh / 1000.0;
    final duration = DateTime.now().difference(s.startedAt);
    final measuredKw = _measuredKw;
    final maxKw = charger.maxPowerKw;

    // Progress-fractie: gemeten kW t.o.v. paal-max. Fallback op 0 als we
    // (nog) geen samples hebben — dan blijft de balk statisch leeg i.p.v.
    // met een indeterminate spinner te ratelen.
    double progress = 0.0;
    if (measuredKw != null && maxKw != null && maxKw > 0) {
      progress = (measuredKw / maxKw).clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _HostColors.primary.withOpacity(0.10),
            _HostColors.primary.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: _HostColors.primary.withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kop: kleine bolt + "Aan het laden · paal-naam"
          Row(
            children: [
              // Kloppend bolt-icoon: heel subtiele scale-pulse via
              // TweenAnimationBuilder — trekt de aandacht zonder afleidend te
              // zijn. Loopt 1200 ms per cyclus.
              _PulsingBolt(color: _HostColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aan het laden · ${charger.name}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _HostColors.primaryDark,
                  ),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: _HostColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grote kWh in het midden — dominant visueel accent
          Center(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  color: _HostColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: chargedKwh.toStringAsFixed(2).replaceAll('.', ','),
                    style: GoogleFonts.inter(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: _HostColors.textPrimary,
                      // Tabular figures — voorkomt dat de decimaal ‘hopt’
                      // als er van 9,99 → 10,00 wordt geschakeld.
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: '  kWh',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _HostColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Progress bar 0 → max_power_kw met horizontaal label
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                // Nooit null → nooit animatie-spinner
                value: progress,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  _HostColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stats-rij: Nu (kW), Duur (min), Paal-max (kW)
          Row(
            children: [
              Expanded(
                child: _liveStat(
                  'Nu',
                  measuredKw == null
                      ? '—'
                      : '${measuredKw.toStringAsFixed(1).replaceAll('.', ',')} kW',
                ),
              ),
              Expanded(
                child: _liveStat(
                  'Duur',
                  _formatDurationShort(duration),
                ),
              ),
              Expanded(
                child: _liveStat(
                  'Paal-max',
                  maxKw == null
                      ? '—'
                      : '${maxKw.toStringAsFixed(1).replaceAll('.', ',')} kW',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _HostColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _HostColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _startCta() {
    final hasActive = _activeSession != null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor:
              hasActive ? _HostColors.textSecondary : _HostColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: hasActive ? null : _startEigenLadenSessie,
        icon: const Icon(Icons.flash_on_rounded),
        label: Text(
          hasActive ? 'Er loopt al een sessie' : 'Start eigen laadsessie',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _tegelsRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MonthTile(
                icon: Icons.ev_station_rounded,
                label: 'Eigen laden',
                value: '${_monthly.eigenKwh.toStringAsFixed(1)} kWh',
                sub: 'deze maand',
                color: _HostColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MonthTile(
                icon: Icons.savings_rounded,
                label: 'Verhuur',
                value: '${_monthly.verhuurKwh.toStringAsFixed(1)} kWh',
                sub: 'deze maand',
                color: _HostColors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ereTile()),
            const SizedBox(width: 12),
            Expanded(
              child: _MonthTile(
                icon: Icons.receipt_long_rounded,
                label: 'Sessies',
                value: '${_recent.length}',
                sub: 'laatste 15 zichtbaar',
                color: _HostColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ERE-tegel — task #338a
  //
  // Toont kWh geleverd via MID-gecertificeerde palen + schatting terugvordering.
  // Tarief €0,22/kWh is een vaste schatting (gemiddeld NL-leveringstarief 2025).
  // Eigenaar gebruikt dit als basis voor een ERE-aanvraag bij zijn energieleverancier
  // of via een inboekdienst (Joulo, EcoHandel, ere-registratie.nl).
  //
  // Geen MID-meter → slot-icoontje met uitleg.
  // ---------------------------------------------------------------------------
  static const double _kEreTarief = 0.22; // €/kWh schatting

  Widget _ereTile() {
    final hasMid = _chargers.any((c) => c.hasMidMeter);

    if (!hasMid) {
      // Slot-icoontje: geen MID-meter beschikbaar
      return _MonthTile(
        icon: Icons.lock_rounded,
        label: 'ERE',
        value: '—',
        sub: 'MID-meter vereist',
        color: _HostColors.textSecondary,
        dim: true,
      );
    }

    final kwh = _monthly.ereKwh;
    final schatting = kwh * _kEreTarief;
    final heeftData = kwh > 0;

    return _MonthTile(
      icon: Icons.eco_rounded,
      label: 'ERE',
      value: heeftData
          ? '${kwh.toStringAsFixed(1)} kWh'
          : '0,0 kWh',
      sub: heeftData
          ? '≈ €${schatting.toStringAsFixed(2)} terug te vorderen'
          : 'nog geen sessies deze maand',
      color: _HostColors.primaryDark,
    );
  }

  Widget _sessionListHeader() {
    return Row(
      children: [
        Text(
          'Sessies',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _HostColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          'Deze maand',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _HostColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _sessionListEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: _HostColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _softShadow(),
      ),
      child: Text(
        'Nog geen sessies deze maand.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: _HostColors.textSecondary,
        ),
      ),
    );
  }

  Widget _sessionRow(_HostSession s) {
    final isEigen = s.initiatedByOwner;
    final chargerName = _chargers
        .firstWhere(
          (c) => c.id == s.chargerId,
          orElse: () => _HostCharger.unknown(),
        )
        .name;
    final signedIcon = s.hasSignedMeter
        ? const Icon(Icons.verified_rounded,
            size: 14, color: _HostColors.primary)
        : Icon(Icons.help_outline_rounded,
            size: 14, color: _HostColors.textSecondary.withOpacity(0.6));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _HostColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _softShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: isEigen ? _HostColors.primary : _HostColors.amber,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isEigen ? 'Eigen laden' : 'Gastsessie',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _HostColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    signedIcon,
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$chargerName · ${_formatDateShort(s.startedAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _HostColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${s.kwh.toStringAsFixed(2)} kWh',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _HostColors.textPrimary,
                ),
              ),
              Text(
                s.statusLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _HostColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mijnPalenLink() {
    return TextButton.icon(
      onPressed: () {
        _snack('Open het profielmenu (rechtsboven) → Mijn palen.');
      },
      icon: const Icon(Icons.tune_rounded, size: 16),
      label: Text(
        'Beheer je palen (${_chargers.length})',
        style: GoogleFonts.inter(fontSize: 13),
      ),
      style: TextButton.styleFrom(foregroundColor: _HostColors.primaryDark),
    );
  }
}

// ============================================================================
// Herbruikbare maand-tegel
// ============================================================================

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.dim = false,
  }) : super(key: key);

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _HostColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16, color: dim ? color.withOpacity(0.5) : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _HostColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: dim ? _HostColors.textSecondary : _HostColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _HostColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Data-modellen — private in dit bestand.
// ============================================================================

class _HostCharger {
  final String id;
  final String name;
  final String? address;
  final String? ocppChargerId;
  final bool isOnline;
  final double? maxPowerKw;
  // MID-gecertificeerde meter: gezet via koppelwizard (migratie 0041).
  // True → kWh-standen zijn juridisch geldig voor ERE-aanvraag.
  final bool hasMidMeter;

  _HostCharger({
    required this.id,
    required this.name,
    required this.address,
    required this.ocppChargerId,
    required this.isOnline,
    required this.maxPowerKw,
    this.hasMidMeter = false,
  });

  factory _HostCharger.fromMap(Map<String, dynamic> m) {
    return _HostCharger(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? 'Naamloze paal',
      address: m['address'] as String?,
      ocppChargerId: m['ocpp_charger_id'] as String?,
      isOnline: (m['is_online'] as bool?) ?? false,
      maxPowerKw: (m['max_power_kw'] as num?)?.toDouble(),
      hasMidMeter: (m['has_mid_meter'] as bool?) ?? false,
    );
  }

  factory _HostCharger.unknown() => _HostCharger(
        id: '',
        name: 'Onbekende paal',
        address: null,
        ocppChargerId: null,
        isOnline: false,
        maxPowerKw: null,
        hasMidMeter: false,
      );
}

class _ActiveSessionSnapshot {
  final int transactionId;
  final String chargerId;
  final String? bookingId;
  final DateTime startedAt;
  final double meterWh;
  final bool initiatedByOwner;

  _ActiveSessionSnapshot({
    required this.transactionId,
    required this.chargerId,
    required this.bookingId,
    required this.startedAt,
    required this.meterWh,
    required this.initiatedByOwner,
  });

  factory _ActiveSessionSnapshot.fromMap(Map<String, dynamic> m) {
    // charging_sessions bevat aparte kolommen voor start-, current- en
    // stop-meterstand (Wh). Voor een lopende sessie is stop_wh null; we
    // rekenen dus current - start (of 0 als er nog geen MeterValue binnen is).
    final startWh = ((m['meter_start_wh'] as num?) ?? 0).toDouble();
    final currentWh = ((m['meter_current_wh'] as num?) ?? startWh).toDouble();
    final rawDelta = currentWh - startWh;
    // Negatieve delta zou fysiek onmogelijk zijn — clamp op 0 als guard tegen
    // meter-reset-glitches (bijv. na paal-reboot mid-sessie).
    final deltaWh = rawDelta < 0 ? 0.0 : rawDelta;
    return _ActiveSessionSnapshot(
      transactionId: (m['transaction_id'] as num).toInt(),
      chargerId: m['charger_id'] as String,
      bookingId: m['booking_id'] as String?,
      startedAt: DateTime.parse(m['started_at'] as String).toLocal(),
      meterWh: deltaWh,
      initiatedByOwner: (m['initiated_by_owner'] as bool?) ?? false,
    );
  }
}

class _HostSession {
  final int transactionId;
  final String chargerId;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final double kwh;
  final bool initiatedByOwner;
  final bool hasSignedMeter;
  final String status;
  final String? bookingId;

  _HostSession({
    required this.transactionId,
    required this.chargerId,
    required this.startedAt,
    required this.stoppedAt,
    required this.kwh,
    required this.initiatedByOwner,
    required this.hasSignedMeter,
    required this.status,
    required this.bookingId,
  });

  String get statusLabel {
    switch (status) {
      case 'in_progress':
        return 'loopt nu';
      case 'completed':
        return 'afgerond';
      case 'orphaned':
        return 'wees-sessie';
      case 'errored':
        return 'fout';
      default:
        return status;
    }
  }

  factory _HostSession.fromMap(Map<String, dynamic> m) {
    // kWh = (stop − start) voor afgeronde sessies; voor lopende sessies
    // (in_progress) rekenen we (current − start). Vallen alle waardes weg
    // (bijvoorbeeld orphaned sessie zonder eerste MeterValue), dan 0.
    final startWh = ((m['meter_start_wh'] as num?) ?? 0).toDouble();
    final stopWhNum = m['meter_stop_wh'] as num?;
    final currentWhNum = m['meter_current_wh'] as num?;
    final endWh = (stopWhNum ?? currentWhNum ?? (m['meter_start_wh'] as num?) ??
            0)
        .toDouble();
    final rawDelta = endWh - startWh;
    // Negatieve delta = meter-glitch of null-fallback op start; clamp op 0.
    final deltaWh = rawDelta < 0 ? 0.0 : rawDelta;
    return _HostSession(
      transactionId: (m['transaction_id'] as num).toInt(),
      chargerId: m['charger_id'] as String,
      startedAt: DateTime.parse(m['started_at'] as String).toLocal(),
      stoppedAt: m['stopped_at'] == null
          ? null
          : DateTime.parse(m['stopped_at'] as String).toLocal(),
      kwh: deltaWh / 1000.0,
      initiatedByOwner: (m['initiated_by_owner'] as bool?) ?? false,
      // MID-signed value zit op charging_session_meter_values (per-tick), niet
      // op de sessie zelf. Ophalen via aparte query volgt in taak #358 (MID-flow
      // e2e-test). Voor nu: geen indicator tonen.
      hasSignedMeter: false,
      status: (m['status'] as String?) ?? 'unknown',
      bookingId: m['booking_id'] as String?,
    );
  }
}

class _MonthlyTotals {
  double eigenKwh;
  double verhuurKwh;
  // Totaal kWh via MID-gecertificeerde palen — eigen + verhuur samen.
  // Dit is de basis voor een ERE-aanvraag bij de energieleverancier.
  double ereKwh;

  _MonthlyTotals({
    required this.eigenKwh,
    required this.verhuurKwh,
    this.ereKwh = 0,
  });

  factory _MonthlyTotals.empty() =>
      _MonthlyTotals(eigenKwh: 0, verhuurKwh: 0, ereKwh: 0);
}

// ============================================================================
// Kleine helpers
// ============================================================================

String _formatTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// hh:mm of mm:ss — kort zichtbaar. Onder een uur: mm:ss. Anders hh:mm.
String _formatDuration(Duration d) {
  if (d.isNegative) return '0:00';
  final totalSecs = d.inSeconds;
  final h = totalSecs ~/ 3600;
  final m = (totalSecs % 3600) ~/ 60;
  final s = totalSecs % 60;
  if (h == 0) {
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${h.toString()}:${m.toString().padLeft(2, '0')}';
}

/// Natuurlijker Nederlands: "23 min" / "1 u 12 min". Voor stats-tegel.
String _formatDurationShort(Duration d) {
  if (d.isNegative) return '0 min';
  final totalMin = d.inMinutes;
  if (totalMin < 60) return '$totalMin min';
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (m == 0) return '$h u';
  return '$h u $m min';
}

// ============================================================================
// _PulsingBolt — subtiele "aan het laden"-indicator
//
// Kloppend bolt-icoontje dat langzaam op-en-neer schaalt (0.85 → 1.05). Alleen
// een visuele knipoog dat er iets aan de gang is — niet zo agressief als
// blinken. Loopt continu zolang de widget in de tree zit.
// ============================================================================

class _PulsingBolt extends StatefulWidget {
  const _PulsingBolt({Key? key, required this.color}) : super(key: key);

  final Color color;

  @override
  State<_PulsingBolt> createState() => _PulsingBoltState();
}

class _PulsingBoltState extends State<_PulsingBolt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      // 0.85 ↔ 1.05 = subtiel maar merkbaar. Curves.easeInOut voelt organisch.
      scale: Tween<double>(begin: 0.85, end: 1.05).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Icon(Icons.bolt_rounded, size: 18, color: widget.color),
    );
  }
}

String _formatDateShort(DateTime dt) {
  final maanden = [
    'jan', 'feb', 'mrt', 'apr', 'mei', 'jun', //
    'jul', 'aug', 'sep', 'okt', 'nov', 'dec' //
  ];
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${maanden[dt.month - 1]} · $hh:$mm';
}
