// ============================================================================
// live_charging_widget.dart — LiveChargingCard voor Mijn Boekingen (task #287)
//
// Verantwoordelijkheden:
//   1. Realtime luisteren op `charging_sessions` voor de boeking
//   2. Laatste twee `charging_session_meter_values` ophalen voor tempo-schatting
//   3. Berekende waardes via charging_estimator.dart naar UI mappen
//   4. Kalibratie-suggestie tonen wanneer meting fors afwijkt van verwachting
//
// Widget-contract:
//   - Verschijnt inline in de boekingskaart op MyBookingsScreen (task #287
//     ontwerp-keuze A: inline)
//   - Toont NIETS als er geen actieve sessie is (parent moet 'm verbergen —
//     of we tonen 'm en de widget zelf detecteert "geen sessie" → SizedBox)
//   - Wanneer sessie loopt: kaart met laadbalk, %, ETA, kW, kWh + € en optie
//     kalibratie-nudge onderin
//   - Auto-hide 5 seconden nadat sessie op 'completed' gaat, zodat de user
//     nog even de eindstand ziet
//
// Ontkoppeling van dev-mode:
//   Dev "Simuleer sessie" leeft in main.dart (aparte knop op boekingskaart).
//   Deze widget weet niets van fake data — leest gewoon dezelfde tabel.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'charging_estimator.dart';

class LiveChargingCard extends StatefulWidget {
  const LiveChargingCard({
    Key? key,
    required this.bookingId,
    required this.chargerMaxKw,
    required this.vehicleBatteryKwh,
    required this.vehicleMaxAcKw,
    required this.startSocPct,
    required this.targetSocPct,
    required this.pricePerKwh,
    this.onOpenProfile,
  }) : super(key: key);

  final String bookingId;

  /// Uit `chargers.max_power_kw`. Null als paal-eigenaar 'm nog niet invulde.
  final double? chargerMaxKw;

  /// Uit `profiles.vehicle_battery_capacity_kwh`. Null als user geen auto koos.
  final double? vehicleBatteryKwh;

  /// Uit `profiles.vehicle_max_ac_kw`. Null als user geen auto koos.
  final double? vehicleMaxAcKw;

  /// Uit `bookings.start_soc_pct`. Nullable — als user 'm bij boeken niet
  /// zette hebben we geen anker om SoC absoluut te tonen.
  final int? startSocPct;

  /// Uit `bookings.target_soc_pct`. NOT NULL in DB (default 80).
  final int targetSocPct;

  /// Prijs die de boeker aan de eigenaar betaalt (€/kWh). Uit charger.
  /// Wordt gebruikt om lopende kosten te tonen tijdens de sessie.
  final double pricePerKwh;

  /// Wordt aangeroepen als user op "Vul je auto in" tapt in de calibration
  /// nudge — parent kan dan naar EditProfileScreen navigeren.
  final VoidCallback? onOpenProfile;

  @override
  State<LiveChargingCard> createState() => _LiveChargingCardState();
}

class _LiveChargingCardState extends State<LiveChargingCard> {
  // Actieve session-rij; null zolang we nog niet weten of er één is
  Map<String, dynamic>? _session;

  // Rolling buffer met de laatste N MeterValues voor kW-berekening.
  //
  // Waarom een window i.p.v. laatste 2 ticks:
  //   - Bij 5 s-cadans + jitter (timer drift + insert-latency) ligt Δt in de
  //     praktijk tussen ~4 s en ~6 s. Over 2 ticks slaat dat 1:1 op de kW-
  //     waarde (10,8 ↔ 13,5 kW bij 15 Wh delta) en dus ook op de ETA. Over
  //     12 ticks (~60 s) middelt dat weg tot ~11 kW stabiel.
  //   - Voor echte OCPP MeterValues geldt hetzelfde: palen sturen elke
  //     ~10-30 s een sample maar niet exact op de milliseconde. Rolling avg
  //     hoort er sowieso te zijn.
  //
  // Gehouden in chronologische volgorde (oudste eerst → nieuwste laatst).
  static const int _kMeterWindowSize = 12;
  List<({int wh, DateTime at})> _meterWindow = const [];

  // Realtime channel — moeten we netjes disposen bij dispose()
  RealtimeChannel? _sessionChannel;

  // Timer om de UI ~elke 10 sec te refreshen (voor ETA-countdown als er
  // geen nieuwe MeterValues binnenkomen); ook nodig om "sessie-leeftijd"
  // door te schuiven.
  Timer? _refreshTimer;

  // Auto-hide timer nadat sessie op 'completed' komt
  Timer? _hideTimer;
  bool _hidden = false;

  // Kalibratie-nudge is dismissable per sessie
  bool _calibrationDismissed = false;

  // Start-SoC prompt (task #287 revisie): als de sessie start terwijl de user
  // z'n huidige SoC nog niet aangaf, tonen we een compacte slider in de card
  // zodat 'ie 'm ter plekke kan zetten. Dit is de logische plek — bij boeking
  // (soms een week vooruit) is de huidige SoC nog niet bekend.
  //
  // _localStartSocPct overschrijft widget.startSocPct als de user 'm zojuist
  // opsloeg — voorkomt dat we op parent-refresh moeten wachten voor de UI.
  // _draftStartSoc = slider-waarde vóór opslaan.
  // _startSocPromptDismissed = user tikte "Sla over" (per sessie).
  int? _localStartSocPct;
  int _draftStartSoc = 40;
  bool _startSocPromptDismissed = false;
  bool _savingStartSoc = false;

  final _supa = Supabase.instance.client;

  /// Effectieve start-SoC: lokale override (net opgeslagen) wint van prop.
  int? get _effectiveStartSocPct => _localStartSocPct ?? widget.startSocPct;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _subscribeRealtime();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void didUpdateWidget(covariant LiveChargingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Boeking veranderde → alles resetten
    if (oldWidget.bookingId != widget.bookingId) {
      _session = null;
      _meterWindow = const [];
      _hidden = false;
      _calibrationDismissed = false;
      _localStartSocPct = null;
      _startSocPromptDismissed = false;
      _savingStartSoc = false;
      _sessionChannel?.unsubscribe();
      _loadInitial();
      _subscribeRealtime();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _hideTimer?.cancel();
    _sessionChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      // Meest recente sessie voor deze boeking (er kan er theoretisch meer
      // dan één zijn als iemand start-stop-start doet; pak de nieuwste).
      final row = await _supa
          .from('charging_sessions')
          .select()
          .eq('booking_id', widget.bookingId)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;
      if (row == null) {
        setState(() => _session = null);
        return;
      }
      setState(() => _session = row);
      _maybeStartHideTimer();
      await _loadRecentMeterValues();
    } catch (_) {
      // Silent — widget mag niet crashen op boekingslijst
    }
  }

  Future<void> _loadRecentMeterValues() async {
    final tx = _session?['transaction_id'];
    if (tx == null) return;
    try {
      final rows = await _supa
          .from('charging_session_meter_values')
          .select('meter_wh, measured_at')
          .eq('transaction_id', tx)
          .order('measured_at', ascending: false)
          .limit(_kMeterWindowSize);

      if (!mounted) return;
      final list = (rows as List).cast<Map<String, dynamic>>();
      // DB gaf newest→oldest terug; keer om zodat de window chronologisch
      // is (oudste eerst → nieuwste laatst). Handig voor first/last logica.
      final samples = list.reversed
          .map((r) => (
                wh: (r['meter_wh'] as num).toInt(),
                at: DateTime.parse(r['measured_at'] as String),
              ))
          .toList(growable: false);
      setState(() => _meterWindow = samples);
    } catch (_) {}
  }

  void _subscribeRealtime() {
    // Postgres_changes op charging_sessions gefilterd op booking_id.
    // Realtime is aangezet op deze tabel in migratie 0021.
    _sessionChannel = _supa
        .channel('live_session_${widget.bookingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'charging_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: widget.bookingId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newRow = payload.newRecord;
            setState(() => _session = newRow);
            _maybeStartHideTimer();
            // Nieuwe meter waarde? Herlaad de rolling window voor kW-avg.
            _loadRecentMeterValues();
          },
        )
        .subscribe();
  }

  void _maybeStartHideTimer() {
    if (_session?['status'] == 'completed' && _hideTimer == null) {
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _hidden = true);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Afgeleide berekeningen — allemaal via charging_estimator.dart voor
  // testbaarheid. Hier alleen glue: pluk waarden uit _session + widget.
  // ---------------------------------------------------------------------------

  double? get _chargedKwh {
    final s = _session;
    if (s == null) return null;
    final start = (s['meter_start_wh'] as num?)?.toInt();
    final current = (s['meter_current_wh'] as num?)?.toInt() ??
        (s['meter_stop_wh'] as num?)?.toInt();
    if (start == null || current == null) return 0;
    final wh = current - start;
    if (wh < 0) return 0;
    return wh / 1000.0;
  }

  Duration get _sessionAge {
    final startedStr = _session?['started_at'] as String?;
    if (startedStr == null) return Duration.zero;
    return DateTime.now().difference(DateTime.parse(startedStr).toLocal());
  }

  /// Gemeten laadvermogen (kW) over de rolling window: (last_wh − first_wh)
  /// gedeeld door (last_at − first_at). Millisecond-precisie in de deler,
  /// zodat 4,8 s en 5,2 s niet allebei op 5 s worden afgerond.
  ///
  /// Null als er nog geen 2 samples zijn, of als de window verdacht is
  /// (dt ≤ 0 of dWh < 0 — kan als een tick out-of-order binnenkomt).
  double? get _measuredKw {
    if (_meterWindow.length < 2) return null;
    final first = _meterWindow.first;
    final last = _meterWindow.last;
    final dtMs = last.at.difference(first.at).inMilliseconds;
    if (dtMs <= 0) return null;
    final dWh = last.wh - first.wh;
    if (dWh < 0) return null;
    // Wh / ms → kW.
    //   kW = (dWh Wh) / (dtMs ms) * (1000 ms/s) * (3600 s/h) / (1000 W/kW)
    //      = dWh * 3600 / dtMs
    return dWh * 3600.0 / dtMs;
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    final status = session['status'] as String?;
    // Alleen tonen tijdens 'in_progress' of net na 'completed' (auto-hide na 5s).
    if (status != 'in_progress' && status != 'completed') {
      return const SizedBox.shrink();
    }

    final charged = _chargedKwh ?? 0;
    final effectiveStartSoc = _effectiveStartSocPct;
    final currentSoc = estimateCurrentSocPct(
      startSocPct: effectiveStartSoc,
      chargedKwh: charged,
      batteryCapacityKwh: widget.vehicleBatteryKwh,
    );
    final expectedKw = expectedEffectiveKw(
      chargerMaxKw: widget.chargerMaxKw,
      vehicleMaxAcKw: widget.vehicleMaxAcKw,
    );
    final measuredKw = _measuredKw;
    final etaMin = estimateEtaMinutes(
      currentSocPct: currentSoc,
      targetSocPct: widget.targetSocPct,
      // Gebruik gemeten kW als we die hebben (accurater), anders verwacht kW
      effectiveKw: measuredKw ?? expectedKw,
      batteryCapacityKwh: widget.vehicleBatteryKwh,
    );
    final showCalibration = !_calibrationDismissed &&
        shouldSuggestCalibration(
          sessionAge: _sessionAge,
          measuredKw: measuredKw,
          expectedKw: expectedKw,
        );

    final costs = charged * widget.pricePerKwh;
    final isCompleted = status == 'completed';

    // Prompt tonen als er nog geen start-SoC bekend is, user 'm niet weggeklikt
    // heeft en de auto überhaupt bekend is (zonder batterij-info heeft SoC
    // geen zin — dan valt de kalibratie-banner al terug op de profiel-nudge).
    final showStartSocPrompt = !isCompleted &&
        effectiveStartSoc == null &&
        !_startSocPromptDismissed &&
        widget.vehicleBatteryKwh != null;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FBF4), // heel licht groen — "actief"
        border: Border.all(color: const Color(0xFF34C759).withOpacity(0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(isCompleted),
          const SizedBox(height: 10),
          if (showStartSocPrompt) ...[
            _buildStartSocPrompt(),
            const SizedBox(height: 10),
          ],
          _buildProgressBar(currentSoc),
          const SizedBox(height: 10),
          _buildStatsRow(currentSoc, etaMin, measuredKw, charged, costs),
          if (showCalibration) ...[
            const SizedBox(height: 10),
            _buildCalibrationBanner(measuredKw!, expectedKw!),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Start-SoC prompt (task #287 revisie)
  //
  // Compacte inline slider die de user aanmoedigt om nu — op het moment dat
  // 'ie aan de paal staat — z'n huidige SoC in te vullen. Dit is niet nodig
  // om te laden (widget werkt ook zonder), maar geeft de %-schaal + accurate
  // ETA. "Sla over" verbergt 'm voor de rest van deze sessie.
  //
  // Op "Opslaan" schrijven we naar bookings.start_soc_pct (RLS: booker mag
  // z'n eigen booking updaten). Local override zorgt voor directe UI-refresh
  // zonder op parent-refetch te wachten.
  // ---------------------------------------------------------------------------
  Widget _buildStartSocPrompt() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF34C759).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.battery_charging_full_rounded,
                size: 16,
                color: Color(0xFF1B5E20),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Hoe vol is je auto nu?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
              InkWell(
                onTap: _savingStartSoc
                    ? null
                    : () => setState(() => _startSocPromptDismissed = true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Sla over',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Voor een accurate laadtijd + %-schaal.',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF34C759),
                    inactiveTrackColor:
                        const Color(0xFF34C759).withOpacity(0.2),
                    thumbColor: const Color(0xFF34C759),
                    overlayColor:
                        const Color(0xFF34C759).withOpacity(0.15),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    min: 0,
                    max: 75,
                    divisions: 15, // stapjes van 5%
                    value: _draftStartSoc.toDouble().clamp(0.0, 75.0),
                    label: '$_draftStartSoc%',
                    onChanged: _savingStartSoc
                        ? null
                        : (v) =>
                            setState(() => _draftStartSoc = v.round()),
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$_draftStartSoc%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _savingStartSoc ? null : _saveStartSoc,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _savingStartSoc
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Opslaan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveStartSoc() async {
    setState(() => _savingStartSoc = true);
    final value = _draftStartSoc;
    try {
      await _supa
          .from('bookings')
          .update({'start_soc_pct': value})
          .eq('id', widget.bookingId);
      if (!mounted) return;
      setState(() {
        _localStartSocPct = value;
        _savingStartSoc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingStartSoc = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opslaan mislukt: $e')),
      );
    }
  }

  Widget _buildHeader(bool isCompleted) {
    return Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.bolt,
          color: const Color(0xFF34C759),
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          isCompleted ? 'Sessie voltooid' : 'Aan het laden',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B5E20),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(int? currentSoc) {
    // Progressbar-berekening — de balk toont altijd 0→100% van de batterij.
    // Wat we tekenen hangt af van hoeveel we weten:
    //   1. currentSoc bekend (start_soc + battery ingevuld)      → SoC-schaal
    //      Balk = currentSoc/100, label = "X%".
    //      Target-SoC = een verticaal streepje op de balk.
    //   2. Alleen vehicleBatteryKwh bekend, geen start_soc       → "gewonnen %"
    //      Balk = chargedKwh / batteryKwh (winst t.o.v. onbekend startpunt).
    //      Label = kWh geladen.
    //   3. Geen auto-data                                        → lege balk
    //      Balk = 0 (statisch, NIET indeterminate!), label wijst naar profiel.
    final start = _effectiveStartSocPct;
    final target = widget.targetSocPct;
    final batteryKwh = widget.vehicleBatteryKwh;
    final charged = _chargedKwh ?? 0;

    double fillFraction;
    String label;
    double? targetMarkerFraction; // positie 0-1 voor target-streepje
    if (currentSoc != null) {
      // Case 1: we hebben SoC — balk is 0→100% van batterij
      fillFraction = (currentSoc / 100.0).clamp(0.0, 1.0);
      label = '$currentSoc%';
      // Target-streepje op 0-100 schaal (alleen als 't zin heeft)
      if (target > (start ?? 0)) {
        targetMarkerFraction = (target / 100.0).clamp(0.0, 1.0);
      }
    } else if (batteryKwh != null && batteryKwh > 0) {
      // Case 2: geen SoC-anker, wel batterijgrootte — toon gewonnen fractie
      fillFraction = (charged / batteryKwh).clamp(0.0, 1.0);
      label = formatKwh(charged);
    } else {
      // Case 3: geen auto-data — statische lege balk, geen animatie
      fillFraction = 0.0;
      label = 'Vul auto in voor %';
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 22,
            child: LinearProgressIndicator(
              // Nooit null → nooit indeterminate animatie.
              value: fillFraction,
              minHeight: 22,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF34C759),
              ),
            ),
          ),
        ),
        // Verticaal target-streepje (alleen als we currentSoc + target hebben)
        if (targetMarkerFraction != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final x = constraints.maxWidth * targetMarkerFraction!;
                return Stack(children: [
                  Positioned(
                    left: x - 1,
                    top: 2,
                    bottom: 2,
                    child: Container(
                      width: 2,
                      color: const Color(0xFF1B5E20).withOpacity(0.55),
                    ),
                  ),
                ]);
              },
            ),
          ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B5E20),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(
    int? currentSoc,
    int? etaMin,
    double? measuredKw,
    double chargedKwh,
    double costs,
  ) {
    // 4 kleine info-blokjes op een rij: %, ETA, kW, kWh+€
    // Als een waarde ontbreekt tonen we '—' zodat de lay-out stabiel blijft.
    return Row(
      children: [
        Expanded(
          child: _statBox(
            'Tot ${widget.targetSocPct}%',
            etaMin == null ? '—' : formatEtaLabel(etaMin),
          ),
        ),
        Expanded(
          child: _statBox(
            'Nu',
            measuredKw == null ? '—' : formatKw(measuredKw),
          ),
        ),
        Expanded(
          child: _statBox(
            'Geladen',
            '${formatKwh(chargedKwh)}\n${formatEuro(costs)}',
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF4B7A55),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B3B20),
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationBanner(double measured, double expected) {
    // Nudge — niet blocking, wel opvallend. User kan wegklikken.
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        border: Border.all(color: const Color(0xFFFFA726).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laadt trager dan verwacht',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF6E4200),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gemeten ${formatKw(measured)}, verwacht ${formatKw(expected)}. '
                  'Klopt je auto-keuze en de paal-specificatie in je profiel?',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF6E4200)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (widget.onOpenProfile != null)
                      TextButton(
                        onPressed: widget.onOpenProfile,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Naar profiel'),
                      ),
                    TextButton(
                      onPressed: () => setState(() => _calibrationDismissed = true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sluit',
                        style: TextStyle(color: Color(0xFF6E4200)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
