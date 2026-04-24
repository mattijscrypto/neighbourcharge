import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Supabase configuratie
// Voor een echt product horen deze in environment variables,
// maar voor een MVP is dit prima. De publishable key is veilig om te delen.
const String supabaseUrl = 'https://vfqpijlicngnomrsasvf.supabase.co';
const String supabaseAnonKey = 'sb_publishable_6LYdmmkM6efPz5WJzi5tiQ_0qiXqML1';

// Google Maps API key - dezelfde als in AppDelegate.swift en web/index.html
const String googleMapsApiKey = 'AIzaSyCLt4pD18cnyedvZnLD6f7XEfRkIy4Dtio';

// Publieke URL's (GitHub Pages) — pas deze aan nadat je Pages hebt aangezet.
// Voorbeeld-URL: https://<jouw-github-username>.github.io/neighbourcharge/
const String privacyPolicyUrl =
    'https://m-sloothovenier.github.io/neighbourcharge/privacy.html';
const String termsOfServiceUrl =
    'https://m-sloothovenier.github.io/neighbourcharge/terms.html';

// ============================================
// Design tokens - centrale plek voor kleuren/styling
// ============================================
class AppColors {
  static const primary = Color(0xFF00A87E); // Verdiept, premium groen
  static const primaryDark = Color(0xFF00795A);
  static const primarySoft = Color(0xFFE6F7F1);
  static const solar = Color(0xFFF9A825); // Zonne-energie accent
  static const solarSoft = Color(0xFFFFF7D6);
  static const surface = Colors.white;
  static const background = Color(0xFFF5F5F7); // iOS-achtig neutraal
  static const textPrimary = Color(0xFF111214);
  static const textSecondary = Color(0xFF6B6F76);
  static const divider = Color(0xFFE5E7EB);
  static const danger = Color(0xFFE53935);
}

// Zachte schaduw die we overal gebruiken voor een "lifted card" look
List<BoxShadow> get softShadow => [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];

// Opent een externe URL in de browser (of in-app WebView bij fallback).
// Gebruikt bij de privacy policy / terms-links.
Future<void> _openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    // Fallback: laat het OS zelf kiezen
    await launchUrl(uri);
  }
}

// Zoek coördinaten op bij een adres via Google Geocoding API.
// Retourneert een LatLng bij succes, of gooit een foutmelding.
Future<LatLng> geocodeAddress(String address) async {
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/geocode/json'
    '?address=${Uri.encodeComponent(address)}'
    '&key=$googleMapsApiKey'
    '&region=nl',
  );

  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('Netwerkfout bij het opzoeken van het adres');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final status = data['status'] as String;

  if (status == 'ZERO_RESULTS') {
    throw Exception('Adres niet gevonden. Controleer de spelling.');
  }
  if (status != 'OK') {
    final message = data['error_message'] as String? ?? status;
    throw Exception('Google: $message');
  }

  final results = data['results'] as List;
  if (results.isEmpty) {
    throw Exception('Adres niet gevonden');
  }

  final location = (results.first as Map)['geometry']['location'] as Map;
  return LatLng(
    (location['lat'] as num).toDouble(),
    (location['lng'] as num).toDouble(),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const NeighbourChargeApp());
}

// Handige shortcut om bij de Supabase-client te komen
final supabase = Supabase.instance.client;

// Data model voor een laadpaal
class Charger {
  final String id;
  final String name;
  final String address;
  final String price;
  final String type;
  final bool available;
  final bool solar;
  final LatLng position;
  final String description;
  final String instructions;
  final String? ownerId;
  final List<String> photoUrls;

  const Charger({
    required this.id,
    required this.name,
    required this.address,
    required this.price,
    required this.type,
    required this.available,
    required this.solar,
    required this.position,
    required this.description,
    this.instructions = '',
    this.ownerId,
    this.photoUrls = const [],
  });

  // Van een database-rij (Map) naar een Charger-object
  factory Charger.fromMap(Map<String, dynamic> map) {
    final photosRaw = map['photo_urls'];
    final photos = photosRaw is List
        ? photosRaw.whereType<String>().toList()
        : <String>[];
    return Charger(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      price: (map['price'] as num).toStringAsFixed(2),
      type: map['type'] as String,
      available: map['available'] as bool? ?? true,
      solar: map['solar'] as bool? ?? false,
      position: LatLng(
        (map['lat'] as num).toDouble(),
        (map['lng'] as num).toDouble(),
      ),
      description: map['description'] as String? ?? '',
      instructions: map['instructions'] as String? ?? '',
      ownerId: map['owner_id'] as String?,
      photoUrls: photos,
    );
  }
}

// Data model voor een beschikbaarheidsblok (wekelijks terugkerend)
class AvailabilitySlot {
  final int dayOfWeek; // 1 = Maandag, 7 = Zondag (DateTime.weekday)
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const AvailabilitySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory AvailabilitySlot.fromMap(Map<String, dynamic> map) {
    return AvailabilitySlot(
      dayOfWeek: (map['day_of_week'] as num).toInt(),
      startTime: _parseDbTime(map['start_time'] as String),
      endTime: _parseDbTime(map['end_time'] as String),
    );
  }
}

// Supabase geeft TIME terug als "HH:MM:SS"
TimeOfDay _parseDbTime(String time) {
  final parts = time.split(':');
  return TimeOfDay(
    hour: int.parse(parts[0]),
    minute: int.parse(parts[1]),
  );
}

// Voor opslag in Supabase: "HH:MM:SS"
String _formatTimeForDb(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m:00';
}

// Voor weergave in de UI: "HH:MM"
String _formatTimeForDisplay(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

const List<String> _weekdayNames = [
  '', // index 0 - niet gebruikt
  'Maandag',
  'Dinsdag',
  'Woensdag',
  'Donderdag',
  'Vrijdag',
  'Zaterdag',
  'Zondag',
];

// Data model voor een boeking
class Booking {
  final String id;
  final String chargerId;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String? message;
  final String? userName;
  final bool viewedByOwner;
  // Optioneel: charger-info uit een joined query
  final Charger? charger;

  const Booking({
    required this.id,
    required this.chargerId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.message,
    this.userName,
    this.viewedByOwner = false,
    this.charger,
  });

  factory Booking.fromMap(Map<String, dynamic> map) {
    // Als we een joined charger meekregen, parsen we 'm ook
    Charger? charger;
    final chargerMap = map['chargers'];
    if (chargerMap is Map<String, dynamic>) {
      charger = Charger.fromMap(chargerMap);
    }
    return Booking(
      id: map['id'] as String,
      chargerId: map['charger_id'] as String,
      userId: map['user_id'] as String,
      startTime: DateTime.parse(map['start_time'] as String).toLocal(),
      endTime: DateTime.parse(map['end_time'] as String).toLocal(),
      status: map['status'] as String,
      message: map['message'] as String?,
      userName: map['user_name'] as String?,
      viewedByOwner: (map['viewed_by_owner'] as bool?) ?? false,
      charger: charger,
    );
  }

  Duration get duration => endTime.difference(startTime);
}

// Helper om een DateTime en TimeOfDay te combineren
DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

// Rond een TimeOfDay naar de dichtstbijzijnde 30 minuten
TimeOfDay _roundTo30Min(TimeOfDay t) {
  final totalMinutes = t.hour * 60 + t.minute;
  final rounded = ((totalMinutes + 15) ~/ 30) * 30;
  final h = (rounded ~/ 60) % 24;
  final m = rounded % 60;
  return TimeOfDay(hour: h, minute: m);
}

const List<String> _shortWeekdayNames = [
  '', 'Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo',
];
const List<String> _monthNames = [
  '',
  'januari', 'februari', 'maart', 'april', 'mei', 'juni',
  'juli', 'augustus', 'september', 'oktober', 'november', 'december',
];

class NeighbourChargeApp extends StatelessWidget {
  const NeighbourChargeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = Typography.blackMountainView;
    final interTextTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return MaterialApp(
      title: 'Pluggo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
          background: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: interTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            elevation: 0,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================
// AuthGate: bepaalt of gebruiker naar Home of Login gaat
// ============================================
class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    // Luister naar auth state changes zodat UI direct reageert op login/logout
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Check de initiële session (direct na app-start)
        final session = supabase.auth.currentSession;
        if (session != null) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
  static const LatLng _center = LatLng(52.1561, 5.3878);

  List<Charger> _chargers = [];
  Set<Marker> _markers = {};
  bool _loading = true;
  String? _error;

  // Aantal ongelezen binnenkomende boekingen (voor rode badge op profielicoon)
  int _unreadIncoming = 0;

  // Wordt true zodra de user permissie heeft gegeven; dan tonen we de blauwe dot
  bool _showMyLocation = false;
  // Voorkomt dat we meerdere keren tegelijk locatie proberen op te halen
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _loadChargers();
    _loadUnreadIncoming();
  }

  // Vraagt (indien nodig) toestemming voor locatie en animeert de camera
  // naar de huidige positie. Toont nette foutberichten als het niet lukt.
  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      // Stap 1: check of location services überhaupt aan staan op het toestel
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Zet locatievoorzieningen aan in je instellingen om deze functie te gebruiken.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Stap 2: vraag permissie als die nog niet gegeven is
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Zonder locatietoestemming kunnen we je niet op de kaart zetten.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Stap 3: haal de huidige positie op (medium accuracy is snel zat)
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;

      setState(() => _showMyLocation = true);

      // Stap 4: animeer de camera naar de locatie
      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 15,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon locatie niet ophalen: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _loadUnreadIncoming() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await supabase
          .from('bookings')
          .select('id, chargers!inner(owner_id)')
          .eq('chargers.owner_id', userId)
          .eq('viewed_by_owner', false);
      if (!mounted) return;
      setState(() {
        _unreadIncoming = (data as List).length;
      });
    } catch (_) {
      // Stil falen: badge blijft op vorige waarde
    }
  }

  Future<void> _loadChargers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await supabase
          .from('chargers')
          .select()
          .order('created_at', ascending: false);

      final chargers = (data as List)
          .map((row) => Charger.fromMap(row as Map<String, dynamic>))
          .toList();

      setState(() {
        _chargers = chargers;
        _markers = chargers.map((charger) {
          // Kleur van de marker hangt af van beschikbaarheid en zonnepanelen
          double hue;
          if (!charger.available) {
            hue = BitmapDescriptor.hueRed; // Bezet
          } else if (charger.solar) {
            hue = BitmapDescriptor.hueYellow; // Zonne-energie
          } else {
            hue = 160; // Custom groen die past bij AppColors.primary
          }
          return Marker(
            markerId: MarkerId(charger.id),
            position: charger.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(
              title: charger.name,
              snippet: '€${charger.price}/kWh · ${charger.type}',
            ),
            onTap: () => _openDetail(charger),
          );
        }).toSet();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Kon laadpalen niet laden: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(Charger charger) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(charger: charger),
      ),
    );
    // Als de paal bewerkt of verwijderd is, ververs de home-lijst
    if (changed == true) {
      _loadChargers();
    }
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddChargerScreen(),
      ),
    );
    if (added == true) {
      _loadChargers();
    }
  }

  // Toont een bottom sheet met gebruikersinfo + uitlog-knop
  void _showProfileSheet() {
    final user = supabase.auth.currentUser;
    final fullName =
        user?.userMetadata?['full_name'] as String? ?? 'Gebruiker';
    final email = user?.email ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IncomingBookingsScreen(),
                      ),
                    );
                    // Badge opnieuw ophalen zodra je terug bent
                    _loadUnreadIncoming();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inbox_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Inkomende boekingen',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_unreadIncoming > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_unreadIncoming',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyBookingsScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_note_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Mijn boekingen',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _openExternalUrl(privacyPolicyUrl);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Privacybeleid',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.open_in_new_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _openExternalUrl(termsOfServiceUrl);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Algemene voorwaarden',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.open_in_new_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await supabase.auth.signOut();
                    // AuthGate regelt de navigatie terug naar login
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          color: AppColors.danger,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Uitloggen',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteAccount();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_forever_rounded,
                          color: AppColors.danger,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Verwijder account',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Account verwijderen?',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Je account, al je laadpalen, foto\'s en boekingen worden permanent '
          'verwijderd. Deze actie kan niet ongedaan worden gemaakt.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuleren',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Verwijder',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Laat de gebruiker zien dat er iets gebeurt
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw 'Niet ingelogd';

      // 1) Verzamel alle foto-paden van de palen van deze gebruiker
      final chargers = await supabase
          .from('chargers')
          .select('photo_urls')
          .eq('owner_id', uid);

      final paths = <String>[];
      const marker = '/object/public/charger-photos/';
      for (final row in (chargers as List)) {
        final urls = row['photo_urls'];
        if (urls is List) {
          for (final u in urls) {
            if (u is String) {
              final idx = u.indexOf(marker);
              if (idx >= 0) paths.add(u.substring(idx + marker.length));
            }
          }
        }
      }

      // 2) Verwijder de foto's uit storage (best-effort — negeer fouten)
      if (paths.isNotEmpty) {
        try {
          await supabase.storage.from('charger-photos').remove(paths);
        } catch (_) {
          // Niet fataal: account wordt alsnog verwijderd
        }
      }

      // 3) Server-side cascade: bookings, slots, chargers, profile, auth.users
      await supabase.rpc('delete_my_account');

      // 4) Loader weg VÓÓR signOut — anders blijft 'ie hangen boven
      //    het loginscherm omdat AuthGate de widget-tree omwisselt.
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 5) Sign out — AuthGate stuurt terug naar login
      await supabase.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // loader weg
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verwijderen mislukt: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Body gebruikt Stack zodat kaart full-screen is en overlays erboven liggen
      body: Stack(
        children: [
          // === Kaart vult het volledige scherm ===
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 13,
            ),
            markers: _markers,
            // Blauwe dot wordt pas getoond nadat user op de locate-knop tikt
            // en toestemming geeft. Voorkomt dat iOS de permission-popup
            // meteen bij app-start laat zien.
            myLocationEnabled: _showMyLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(bottom: 240), // Ruimte voor bottom sheet
          ),

          // === Floating header: logo + zoekbalk + user avatar ===
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  // Logo-rij bovenaan
                  Row(
                    children: [
                      _brandBadge(),
                      const SizedBox(width: 10),
                      Text(
                        'Pluggo',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      _roundIconButton(
                        icon: Icons.refresh_rounded,
                        onTap: () {
                          _loadChargers();
                          _loadUnreadIncoming();
                        },
                      ),
                      const SizedBox(width: 8),
                      _roundIconButton(
                        icon: Icons.person_outline_rounded,
                        onTap: _showProfileSheet,
                        badgeCount: _unreadIncoming,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Zoekbalk met pil-vorm en zachte schaduw
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: softShadow,
                    ),
                    child: TextField(
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Zoek laadpalen in jouw buurt…',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // === Sleepbare bottom sheet met lijst van laadpunten ===
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.18,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.18, 0.32, 0.85],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Sleep-handvat (horizontale bar bovenin)
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Header met titel + teller
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            'Laadpunten in de buurt',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (!_loading && _error == null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_chargers.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _buildChargerList(scrollController),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      // === Floating actions: locate-me + toevoegen, beide boven de bottom sheet ===
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Kleine ronde locate-me knop
            FloatingActionButton(
              heroTag: 'locate-me',
              onPressed: _locating ? null : _goToMyLocation,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 2,
              mini: true,
              shape: const CircleBorder(),
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded, size: 22),
            ),
            const SizedBox(height: 10),
            // Grote uitgebreide "Toevoegen" knop
            FloatingActionButton.extended(
              heroTag: 'add-charger',
              onPressed: _openAdd,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Toevoegen',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Kleine helper: het Pluggo-logo badge
  Widget _brandBadge() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
    );
  }

  // Kleine helper: witte ronde icon-knop voor de header
  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: softShadow,
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 20),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Center(
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChargerList(ScrollController scrollController) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 44),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadChargers,
                child: const Text('Opnieuw proberen'),
              ),
            ],
          ),
        ),
      );
    }
    if (_chargers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nog geen laadpunten',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Voeg de eerste toe en laat je buren\nbij je laden.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final currentUserId = supabase.auth.currentUser?.id;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _chargers.length,
      itemBuilder: (context, index) {
        final charger = _chargers[index];
        final isOwner =
            charger.ownerId != null && charger.ownerId == currentUserId;
        return _ChargerCard(
          charger: charger,
          onTap: () => _openDetail(charger),
          isOwner: isOwner,
          onChanged: _loadChargers,
        );
      },
    );
  }
}

class AddChargerScreen extends StatefulWidget {
  const AddChargerScreen({Key? key}) : super(key: key);

  @override
  State<AddChargerScreen> createState() => _AddChargerScreenState();
}

class _AddChargerScreenState extends State<AddChargerScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _selectedType = 'Type 2';
  bool _isSolar = false;
  bool _saving = false;

  // Foto-upload state
  final List<XFile> _pickedPhotos = [];
  static const int _maxPhotos = 4;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  // Laat een bottom sheet zien waarin je kunt kiezen tussen camera of galerij
  Future<void> _addPhoto() async {
    if (_pickedPhotos.length >= _maxPhotos) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    'Foto maken',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    'Kies uit galerij',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _pickedPhotos.add(picked));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon foto niet openen: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() => _pickedPhotos.removeAt(index));
  }

  // Upload één foto naar Supabase Storage en geef de publieke URL terug
  Future<String> _uploadSinglePhoto(XFile file, String chargerId) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    // Unieke bestandsnaam binnen de folder van de paal
    final path =
        '$chargerId/${DateTime.now().millisecondsSinceEpoch}_${_pickedPhotos.indexOf(file)}.$ext';

    await supabase.storage.from('charger-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: false,
          ),
        );

    return supabase.storage.from('charger-photos').getPublicUrl(path);
  }

  Future<void> _saveCharger() async {
    // Simpele validatie
    if (_nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vul naam, adres en prijs in'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prijs is geen geldig getal (bijv. 0.21)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Stap 1: zoek coördinaten op via Google Geocoding
      final coords = await geocodeAddress(_addressController.text.trim());

      // Stap 2: sla op in Supabase (owner_id is vereist door RLS)
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Je bent niet ingelogd');
      }

      // Insert met .select().single() geeft de nieuwe row terug inclusief id
      final inserted = await supabase
          .from('chargers')
          .insert({
            'name': _nameController.text.trim(),
            'address': _addressController.text.trim(),
            'price': price,
            'type': _selectedType,
            'available': true,
            'solar': _isSolar,
            'lat': coords.latitude,
            'lng': coords.longitude,
            'description': _descriptionController.text.trim(),
            'instructions': _instructionsController.text.trim(),
            'owner_id': userId,
          })
          .select()
          .single();

      final chargerId = inserted['id'] as String;

      // Stap 3: upload foto's (indien aanwezig) en koppel de URL's aan de paal
      if (_pickedPhotos.isNotEmpty) {
        final urls = <String>[];
        for (final photo in _pickedPhotos) {
          final url = await _uploadSinglePhoto(photo, chargerId);
          urls.add(url);
        }
        await supabase
            .from('chargers')
            .update({'photo_urls': urls})
            .eq('id', chargerId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laadpaal toegevoegd! 🎉'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context, true); // true = nieuw item toegevoegd
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Haal "Exception: " weg uit de boodschap voor een nettere weergave
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Laadpaal toevoegen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verdien geld met je laadpaal en help je buren goedkoper laden!',
                      style: TextStyle(fontSize: 13, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _label('Jouw naam'),
            _textField(
              controller: _nameController,
              hint: 'bijv. Jan de Vries',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),
            _label('Adres'),
            _textField(
              controller: _addressController,
              hint: 'bijv. Zonnelaan 12, Amersfoort',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 20),
            _label('Prijs per kWh'),
            _textField(
              controller: _priceController,
              hint: 'bijv. 0.21',
              icon: Icons.euro,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'We zoeken de coördinaten automatisch op bij je adres.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _label('Type aansluiting'),
            Row(
              children: ['Type 2', 'CCS', 'CHAdeMO'].map((type) {
                final selected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: SwitchListTile(
                value: _isSolar,
                onChanged: (val) => setState(() => _isSolar = val),
                activeColor: AppColors.primary,
                title: const Text(
                  '☀️ Stroom van zonnepanelen',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                subtitle: const Text(
                  'Goedkoper laden tijdens zonnepiek',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Omschrijving'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Beschrijf je laadpaal, beschikbaarheid, etc.',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Instructies voor de boeker'),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Zichtbaar voor mensen die je paal geboekt hebben. '
                'Bijv. waar de paal precies hangt, of de kabel aan jouw of hun kant zit, '
                'of je gewoon aankomt en laadt, of dat er iets aan staat.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: TextField(
                controller: _instructionsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'bijv. "Paal hangt links naast de schuur. Gratis laden staat aan, dus stekker erin en het werkt. Oprit is open tussen 8-18."',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Foto\'s van je paal en oprit'),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Laat zien waar je paal staat en hoe boekers op de oprit komen. Max 4 foto\'s.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            _photoPickerRow(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveCharger,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Laadpaal toevoegen',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _photoPickerRow() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pickedPhotos.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          // Laatste tegel is altijd de "+ toevoegen"-knop (tenzij max bereikt)
          if (index == _pickedPhotos.length) {
            if (_pickedPhotos.length >= _maxPhotos) {
              return const SizedBox.shrink();
            }
            return GestureDetector(
              onTap: _saving ? null : _addPhoto,
              child: Container(
                width: 110,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_rounded,
                      size: 28,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Foto toevoegen',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final photo = _pickedPhotos[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: kIsWeb
                    ? Image.network(
                        photo.path,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(photo.path),
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _saving ? null : () => _removePhoto(index),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// EditChargerScreen — eigenaar kan paal bewerken of verwijderen
// ============================================================================
class EditChargerScreen extends StatefulWidget {
  final Charger charger;
  const EditChargerScreen({Key? key, required this.charger}) : super(key: key);

  @override
  State<EditChargerScreen> createState() => _EditChargerScreenState();
}

class _EditChargerScreenState extends State<EditChargerScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instructionsController;
  late String _selectedType;
  late bool _isSolar;
  late bool _isAvailable;

  // Bestaande foto-URLs uit de database (die we kunnen verwijderen)
  late List<String> _existingPhotoUrls;
  // Nieuw gekozen foto's die nog geupload moeten worden
  final List<XFile> _newPhotos = [];
  // URL's die de user heeft weggehaald — bij Save verwijderen we ze uit storage
  final List<String> _removedPhotoUrls = [];

  bool _saving = false;
  bool _deleting = false;
  // We onthouden het originele adres zodat we alleen opnieuw geocoden als het gewijzigd is
  late final String _originalAddress;

  static const int _maxPhotos = 4;

  @override
  void initState() {
    super.initState();
    final c = widget.charger;
    _nameController = TextEditingController(text: c.name);
    _addressController = TextEditingController(text: c.address);
    _priceController = TextEditingController(text: c.price);
    _descriptionController = TextEditingController(text: c.description);
    _instructionsController = TextEditingController(text: c.instructions);
    _selectedType = c.type;
    _isSolar = c.solar;
    _isAvailable = c.available;
    _existingPhotoUrls = List.of(c.photoUrls);
    _originalAddress = c.address;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  int get _totalPhotoCount => _existingPhotoUrls.length + _newPhotos.length;

  Future<void> _addPhoto() async {
    if (_totalPhotoCount >= _maxPhotos) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded,
                      color: AppColors.primary),
                  title: Text('Foto maken',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary),
                  title: Text('Kies uit galerij',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _newPhotos.add(picked));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon foto niet openen: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      _removedPhotoUrls.add(_existingPhotoUrls[index]);
      _existingPhotoUrls.removeAt(index);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() => _newPhotos.removeAt(index));
  }

  // Haal het Supabase-Storage-pad uit een publieke URL
  // (alles na /object/public/charger-photos/)
  String? _storagePathFromUrl(String url) {
    const marker = '/object/public/charger-photos/';
    final idx = url.indexOf(marker);
    if (idx < 0) return null;
    return url.substring(idx + marker.length);
  }

  Future<String> _uploadSinglePhoto(XFile file, String chargerId, int idx) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final path =
        '$chargerId/${DateTime.now().millisecondsSinceEpoch}_$idx.$ext';
    await supabase.storage.from('charger-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
        );
    return supabase.storage.from('charger-photos').getPublicUrl(path);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vul naam, adres en prijs in'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final price =
        double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prijs is geen geldig getal (bijv. 0.21)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final chargerId = widget.charger.id;
      final newAddress = _addressController.text.trim();

      // Stap 1: als adres gewijzigd is, opnieuw geocoden
      LatLng? newCoords;
      if (newAddress != _originalAddress) {
        newCoords = await geocodeAddress(newAddress);
      }

      // Stap 2: upload eventuele nieuwe foto's
      final newUploadedUrls = <String>[];
      for (var i = 0; i < _newPhotos.length; i++) {
        final url = await _uploadSinglePhoto(_newPhotos[i], chargerId, i);
        newUploadedUrls.add(url);
      }

      // Stap 3: verwijderde foto's weghalen uit storage
      if (_removedPhotoUrls.isNotEmpty) {
        final paths = _removedPhotoUrls
            .map(_storagePathFromUrl)
            .whereType<String>()
            .toList();
        if (paths.isNotEmpty) {
          try {
            await supabase.storage.from('charger-photos').remove(paths);
          } catch (_) {
            // Niet fataal; de DB-update gaat door
          }
        }
      }

      // Stap 4: de charger-row bijwerken
      final finalPhotoUrls = [..._existingPhotoUrls, ...newUploadedUrls];
      final update = <String, dynamic>{
        'name': _nameController.text.trim(),
        'address': newAddress,
        'price': price,
        'type': _selectedType,
        'available': _isAvailable,
        'solar': _isSolar,
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'photo_urls': finalPhotoUrls,
      };
      if (newCoords != null) {
        update['lat'] = newCoords.latitude;
        update['lng'] = newCoords.longitude;
      }

      await supabase.from('chargers').update(update).eq('id', chargerId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wijzigingen opgeslagen'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context, {'updated': true});
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opslaan mislukt: $msg'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Paal verwijderen?',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Weet je zeker dat je deze paal wilt verwijderen? '
            'Alle bijbehorende boekingen en beschikbaarheid gaan ook weg. '
            'Dit kan niet ongedaan worden gemaakt.',
            style: GoogleFonts.inter(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Annuleren',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Verwijderen'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _deleteCharger();
  }

  Future<void> _deleteCharger() async {
    setState(() => _deleting = true);
    final chargerId = widget.charger.id;
    try {
      // Stap 1: gerelateerde bookings en availability_slots weghalen
      // (indien foreign keys geen CASCADE hebben)
      await supabase.from('bookings').delete().eq('charger_id', chargerId);
      await supabase
          .from('availability_slots')
          .delete()
          .eq('charger_id', chargerId);

      // Stap 2: alle foto's uit storage weghalen
      final allUrls = [..._existingPhotoUrls];
      final paths =
          allUrls.map(_storagePathFromUrl).whereType<String>().toList();
      if (paths.isNotEmpty) {
        try {
          await supabase.storage.from('charger-photos').remove(paths);
        } catch (_) {
          // Niet fataal
        }
      }

      // Stap 3: de charger-rij zelf weghalen
      await supabase.from('chargers').delete().eq('id', chargerId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paal verwijderd'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context, {'deleted': true});
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verwijderen mislukt: $msg'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Paal bewerken',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Jouw naam'),
            _textField(
              controller: _nameController,
              hint: 'bijv. Jan de Vries',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),
            _label('Adres'),
            _textField(
              controller: _addressController,
              hint: 'bijv. Zonnelaan 12, Amersfoort',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 20),
            _label('Prijs per kWh'),
            _textField(
              controller: _priceController,
              hint: 'bijv. 0.21',
              icon: Icons.euro,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _label('Type aansluiting'),
            Row(
              children: ['Type 2', 'CCS', 'CHAdeMO'].map((type) {
                final selected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10),
                        ],
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _isAvailable,
                    onChanged: (v) => setState(() => _isAvailable = v),
                    activeColor: AppColors.primary,
                    title: const Text('Beschikbaar voor boekingen',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15)),
                    subtitle: const Text(
                      'Zet uit als je tijdelijk niet wil verhuren',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  SwitchListTile(
                    value: _isSolar,
                    onChanged: (v) => setState(() => _isSolar = v),
                    activeColor: AppColors.primary,
                    title: const Text(
                      '☀️ Stroom van zonnepanelen',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'Goedkoper laden tijdens zonnepiek',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _label('Omschrijving'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10),
                ],
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Beschrijf je laadpaal, beschikbaarheid, etc.',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Instructies voor de boeker'),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Zichtbaar voor mensen die je paal geboekt hebben. '
                'Handig als je niet thuis bent.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10),
                ],
              ),
              child: TextField(
                controller: _instructionsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'bijv. "Paal hangt links naast de schuur. Gratis laden staat aan — stekker erin en het werkt."',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Foto\'s'),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Max 4 foto\'s. Tik op een foto om \'m weg te halen.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            _photoRow(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Wijzigingen opslaan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _confirmDelete,
                icon: _deleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: AppColors.danger,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: const Text('Paal verwijderen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _photoRow() {
    final tiles = <Widget>[];
    // Eerst bestaande foto's
    for (var i = 0; i < _existingPhotoUrls.length; i++) {
      final url = _existingPhotoUrls[i];
      tiles.add(_tile(
        child: Image.network(
          url,
          width: 110,
          height: 110,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 110,
            height: 110,
            color: AppColors.divider,
            child: const Icon(Icons.broken_image_rounded,
                color: AppColors.textSecondary),
          ),
        ),
        onRemove: () => _removeExistingPhoto(i),
      ));
    }
    // Dan nieuw-toegevoegde
    for (var i = 0; i < _newPhotos.length; i++) {
      final p = _newPhotos[i];
      tiles.add(_tile(
        child: kIsWeb
            ? Image.network(p.path, width: 110, height: 110, fit: BoxFit.cover)
            : Image.file(File(p.path),
                width: 110, height: 110, fit: BoxFit.cover),
        onRemove: () => _removeNewPhoto(i),
      ));
    }
    // Plus de "+"-knop als er nog ruimte is
    if (_totalPhotoCount < _maxPhotos) {
      tiles.add(GestureDetector(
        onTap: _saving ? null : _addPhoto,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_rounded,
                  size: 28, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(
                'Toevoegen',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ));
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }

  Widget _tile({required Widget child, required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: child,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _saving ? null : onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class DetailScreen extends StatefulWidget {
  final Charger charger;

  const DetailScreen({Key? key, required this.charger}) : super(key: key);

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  List<AvailabilitySlot> _slots = [];
  bool _loadingSlots = true;

  // De charger wordt lokaal bijgehouden zodat we 'm kunnen updaten na bewerken
  late Charger charger;

  // Heeft de huidige gebruiker (niet de eigenaar) een niet-geannuleerde boeking
  // voor deze paal? Zo ja: instructies zijn zichtbaar.
  bool _hasActiveBooking = false;

  @override
  void initState() {
    super.initState();
    charger = widget.charger;
    _loadSlots();
    _checkBooking();
  }

  Future<void> _checkBooking() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await supabase
          .from('bookings')
          .select('id')
          .eq('charger_id', charger.id)
          .eq('user_id', userId)
          .neq('status', 'cancelled')
          .limit(1);
      if (!mounted) return;
      setState(() {
        _hasActiveBooking = (data as List).isNotEmpty;
      });
    } catch (_) {
      // Bij fout houden we 'm gewoon op false
    }
  }

  Future<void> _refreshCharger() async {
    try {
      final data = await supabase
          .from('chargers')
          .select()
          .eq('id', charger.id)
          .maybeSingle();
      if (data == null || !mounted) return;
      setState(() {
        charger = Charger.fromMap(data);
      });
    } catch (_) {
      // Stil falen; we gebruiken de cached versie
    }
  }

  Future<void> _openEdit() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditChargerScreen(charger: charger),
      ),
    );
    if (!mounted || result == null) return;
    if (result['deleted'] == true) {
      // De paal is verwijderd — terug naar home met signaal om te refreshen
      Navigator.pop(context, true);
      return;
    }
    // Wijzigingen doorgevoerd: laadpaal-data opnieuw ophalen
    await _refreshCharger();
    await _loadSlots();
  }

  Future<void> _loadSlots() async {
    try {
      final data = await supabase
          .from('availability_slots')
          .select()
          .eq('charger_id', charger.id)
          .order('day_of_week');

      if (!mounted) return;
      setState(() {
        _slots = (data as List)
            .map((row) => AvailabilitySlot.fromMap(row as Map<String, dynamic>))
            .toList();
        _loadingSlots = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  bool get _isOwner {
    final userId = supabase.auth.currentUser?.id;
    return userId != null && userId == charger.ownerId;
  }

  // Laat een bottom sheet zien met Apple Maps en Google Maps,
  // opent de gekozen app met de coördinaten van deze paal als bestemming.
  Future<void> _openInMaps() async {
    final lat = charger.position.latitude;
    final lng = charger.position.longitude;
    final label = Uri.encodeComponent(charger.name);

    // URLs die per platform werken
    final appleMapsUrl = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&q=$label');
    final googleMapsApp = Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving');
    final googleMapsWeb = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    // Check welke apps daadwerkelijk geïnstalleerd zijn (alleen relevant op iOS)
    final hasGoogleMapsApp = Platform.isIOS
        ? await canLaunchUrl(googleMapsApp)
        : false;

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Navigeer naar ${charger.name}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (Platform.isIOS)
                  ListTile(
                    leading: const Icon(Icons.map_rounded, color: AppColors.primary),
                    title: Text('Apple Maps',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await launchUrl(appleMapsUrl,
                          mode: LaunchMode.externalApplication);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.directions_rounded,
                      color: AppColors.primary),
                  title: Text('Google Maps',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                  subtitle: Platform.isIOS && !hasGoogleMapsApp
                      ? const Text('Opent in je browser')
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (hasGoogleMapsApp) {
                      await launchUrl(googleMapsApp,
                          mode: LaunchMode.externalApplication);
                    } else {
                      await launchUrl(googleMapsWeb,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.content_copy_rounded,
                      color: AppColors.textSecondary),
                  title: Text('Kopieer adres',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Clipboard.setData(
                        ClipboardData(text: charger.address));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Adres gekopieerd'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openManageAvailability() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvailabilityScreen(charger: charger),
      ),
    );
    // Na terugkomst: refresh de getoonde slots
    _loadSlots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Laadpaal details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (charger.photoUrls.isNotEmpty) ...[
              _PhotoCarousel(photoUrls: charger.photoUrls),
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: charger.available ? AppColors.primarySoft : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.ev_station,
                          color: charger.available ? AppColors.primary : Colors.grey,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              charger.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              charger.address,
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      // Compacte "Route"-knop rechts van het adres.
                      // Opent een bottom sheet met Apple Maps / Google Maps / kopiëren.
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _openInMaps,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.navigation_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Route',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (charger.solar)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.solarSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '☀️ Stroom van zonnepanelen',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFF9A825),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.bolt,
                    label: 'Prijs',
                    value: '€${charger.price}/kWh',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.cable,
                    label: 'Aansluiting',
                    value: charger.type,
                    color: const Color(0xFF5C6BC0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: charger.available ? Icons.check_circle : Icons.cancel,
                    label: 'Status',
                    value: charger.available ? 'Vrij' : 'Bezet',
                    color: charger.available ? AppColors.primary : Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Over deze laadpaal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    charger.description.isEmpty
                        ? 'Geen omschrijving beschikbaar.'
                        : charger.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // === Instructies-kaart (alleen zichtbaar voor eigenaar of bevestigde boeker) ===
            if (charger.instructions.isNotEmpty &&
                (_isOwner || _hasActiveBooking)) ...[
              _instructionsCard(),
              const SizedBox(height: 16),
            ],
            // === Hint voor mensen die nog niet geboekt hebben ===
            if (charger.instructions.isNotEmpty &&
                !_isOwner &&
                !_hasActiveBooking) ...[
              _lockedInstructionsHint(),
              const SizedBox(height: 16),
            ],
            // === Beschikbaarheid-sectie ===
            _availabilityCard(),
            const SizedBox(height: 24),
            // === Actie-knop onderaan (verschilt voor eigenaar vs bezoeker) ===
            SizedBox(
              width: double.infinity,
              child: _isOwner
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openManageAvailability,
                            icon: const Icon(Icons.edit_calendar_rounded),
                            label: const Text('Beschikbaarheid beheren'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openEdit,
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('Paal bewerken'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                color: AppColors.divider,
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: charger.available
                          ? () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BookingScreen(charger: charger),
                                ),
                              );
                              // Als er een boeking gemaakt is, worden de
                              // instructies nu zichtbaar.
                              if (mounted) _checkBooking();
                            }
                          : null,
                      child: Text(
                        charger.available ? 'Reserveer nu' : 'Momenteel bezet',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Kaart met de instructies van de eigenaar voor de boeker
  // (bijv. "paal hangt links naast schuur, gratis laden staat aan").
  Widget _instructionsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tips_and_updates_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _isOwner ? 'Instructies (zichtbaar voor boekers)' : 'Instructies van de eigenaar',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            charger.instructions,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Kleine hint voor mensen die de paal nog niet geboekt hebben
  Widget _lockedInstructionsHint() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Na je boeking zie je hier de instructies van de eigenaar (bijv. waar de paal hangt en hoe je laadt).',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Kaart met het wekelijks schema. Toont alle 7 dagen en welke tijden er zijn ingesteld.
  Widget _availabilityCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Beschikbaarheid',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingSlots)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (_slots.isEmpty)
            Text(
              _isOwner
                  ? 'Je hebt nog geen tijden ingesteld.'
                  : 'Nog geen tijden bekend — neem contact op met de eigenaar.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else
            // Lijst met 7 dagen — elke dag toont tijden of "Gesloten"
            Column(
              children: List.generate(7, (i) {
                final day = i + 1;
                final slot = _slots.where((s) => s.dayOfWeek == day).firstOrNull;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          _weekdayNames[day],
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        slot == null
                            ? 'Gesloten'
                            : '${_formatTimeForDisplay(slot.startTime)} – ${_formatTimeForDisplay(slot.endTime)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: slot == null
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontWeight: slot == null ? FontWeight.w400 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

// ============================================
// Foto-carousel voor de detail-pagina (fullscreen bij tikken)
// ============================================
class _PhotoCarousel extends StatefulWidget {
  final List<String> photoUrls;
  const _PhotoCarousel({Key? key, required this.photoUrls}) : super(key: key);

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullScreen(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenPhotoView(
          photoUrls: widget.photoUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.photoUrls.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _openFullScreen(index),
                  child: Image.network(
                    widget.photoUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.divider,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.textSecondary,
                          size: 40,
                        ),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.divider,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        // Paginatie-indicator alleen tonen bij meerdere foto's
        if (widget.photoUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.photoUrls.length, (i) {
                final active = i == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _FullscreenPhotoView extends StatelessWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _FullscreenPhotoView({
    Key? key,
    required this.photoUrls,
    required this.initialIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photoUrls.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                photoUrls[index],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================
// AvailabilityScreen - wekelijks schema beheren per laadpaal
// ============================================
class AvailabilityScreen extends StatefulWidget {
  final Charger charger;
  const AvailabilityScreen({Key? key, required this.charger}) : super(key: key);

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  // Voor elke dag (1-7): of hij aanstaat + start + eindtijd
  final Map<int, bool> _enabled = {for (var i = 1; i <= 7; i++) i: false};
  final Map<int, TimeOfDay> _start = {
    for (var i = 1; i <= 7; i++) i: const TimeOfDay(hour: 8, minute: 0),
  };
  final Map<int, TimeOfDay> _end = {
    for (var i = 1; i <= 7; i++) i: const TimeOfDay(hour: 22, minute: 0),
  };

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    try {
      final data = await supabase
          .from('availability_slots')
          .select()
          .eq('charger_id', widget.charger.id);

      for (final row in (data as List)) {
        final slot = AvailabilitySlot.fromMap(row as Map<String, dynamic>);
        _enabled[slot.dayOfWeek] = true;
        _start[slot.dayOfWeek] = slot.startTime;
        _end[slot.dayOfWeek] = slot.endTime;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showError('Kon beschikbaarheid niet laden');
    }
  }

  Future<void> _save() async {
    // Valideer: eindtijd moet na starttijd zijn
    for (var day = 1; day <= 7; day++) {
      if (_enabled[day] == true) {
        final s = _start[day]!;
        final e = _end[day]!;
        final startMins = s.hour * 60 + s.minute;
        final endMins = e.hour * 60 + e.minute;
        if (endMins <= startMins) {
          _showError('${_weekdayNames[day]}: eindtijd moet na starttijd zijn');
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      // Strategie: verwijder alle bestaande slots voor deze charger, insert nieuwe
      await supabase
          .from('availability_slots')
          .delete()
          .eq('charger_id', widget.charger.id);

      final rows = <Map<String, dynamic>>[];
      for (var day = 1; day <= 7; day++) {
        if (_enabled[day] == true) {
          rows.add({
            'charger_id': widget.charger.id,
            'day_of_week': day,
            'start_time': _formatTimeForDb(_start[day]!),
            'end_time': _formatTimeForDb(_end[day]!),
          });
        }
      }

      if (rows.isNotEmpty) {
        await supabase.from('availability_slots').insert(rows);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beschikbaarheid opgeslagen!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Opslaan mislukt. Probeer het opnieuw.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickTime(int day, {required bool isStart}) async {
    final initial = isStart ? _start[day]! : _end[day]!;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                    primary: AppColors.primary,
                  ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start[day] = picked;
        } else {
          _end[day] = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Beschikbaarheid'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : Column(
              children: [
                // Uitleg-banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Stel in op welke dagen en tijden buren mogen laden.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      return _dayCard(day);
                    },
                  ),
                ),
                // Save-knop onderaan met veilige afstand
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Opslaan'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _dayCard(int day) {
    final enabled = _enabled[day] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            // Header-rij met dagnaam + toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _weekdayNames[day],
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: enabled,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _enabled[day] = v),
                  ),
                ],
              ),
            ),
            // Tijdvelden alleen tonen als de dag aanstaat
            if (enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _timeChip(
                        label: 'Van',
                        time: _start[day]!,
                        onTap: () => _pickTime(day, isStart: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _timeChip(
                        label: 'Tot',
                        time: _end[day]!,
                        onTap: () => _pickTime(day, isStart: false),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _timeChip({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatTimeForDisplay(time),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.access_time_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// BookingScreen - laadpaal reserveren
// ============================================
class BookingScreen extends StatefulWidget {
  final Charger charger;
  const BookingScreen({Key? key, required this.charger}) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _messageController = TextEditingController();

  AvailabilitySlot? _slotForSelectedDay;
  bool _loadingSlot = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSlotForSelectedDay();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadSlotForSelectedDay() async {
    setState(() => _loadingSlot = true);
    try {
      final data = await supabase
          .from('availability_slots')
          .select()
          .eq('charger_id', widget.charger.id)
          .eq('day_of_week', _selectedDate.weekday);

      if (!mounted) return;
      if ((data as List).isNotEmpty) {
        final slot = AvailabilitySlot.fromMap(data.first as Map<String, dynamic>);
        setState(() {
          _slotForSelectedDay = slot;
          // Standaard de start/eind gelijk zetten aan de beschikbare window
          _startTime = slot.startTime;
          _endTime = slot.endTime;
          _loadingSlot = false;
        });
      } else {
        setState(() {
          _slotForSelectedDay = null;
          _startTime = null;
          _endTime = null;
          _loadingSlot = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSlot = false);
    }
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadSlotForSelectedDay();
  }

  Future<void> _pickStartTime() async {
    final slot = _slotForSelectedDay;
    if (slot == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? slot.startTime,
      builder: _timePickerBuilder,
    );
    if (picked != null) {
      setState(() => _startTime = _roundTo30Min(picked));
    }
  }

  Future<void> _pickEndTime() async {
    final slot = _slotForSelectedDay;
    if (slot == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? slot.endTime,
      builder: _timePickerBuilder,
    );
    if (picked != null) {
      setState(() => _endTime = _roundTo30Min(picked));
    }
  }

  Widget _timePickerBuilder(BuildContext ctx, Widget? child) {
    return MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _submit() async {
    final slot = _slotForSelectedDay;
    if (slot == null) {
      _showError('Op ${_weekdayNames[_selectedDate.weekday]} is er geen beschikbaarheid');
      return;
    }
    if (_startTime == null || _endTime == null) {
      _showError('Kies een start- en eindtijd');
      return;
    }

    // Vergelijk in minuten sinds middernacht
    final startMin = _startTime!.hour * 60 + _startTime!.minute;
    final endMin = _endTime!.hour * 60 + _endTime!.minute;
    final slotStartMin = slot.startTime.hour * 60 + slot.startTime.minute;
    final slotEndMin = slot.endTime.hour * 60 + slot.endTime.minute;

    if (endMin <= startMin) {
      _showError('Eindtijd moet na starttijd zijn');
      return;
    }
    if (startMin < slotStartMin || endMin > slotEndMin) {
      _showError(
        'Kies een tijd binnen ${_formatTimeForDisplay(slot.startTime)}–${_formatTimeForDisplay(slot.endTime)}',
      );
      return;
    }
    if (endMin - startMin > 12 * 60) {
      _showError('Boekingen kunnen maximaal 12 uur duren');
      return;
    }

    final startDT = _combineDateAndTime(_selectedDate, _startTime!);
    final endDT = _combineDateAndTime(_selectedDate, _endTime!);

    setState(() => _submitting = true);
    try {
      // Conflict-check: zoek bestaande boekingen die overlappen met dit tijdvak
      // Overlap = existing.start < new.end AND existing.end > new.start
      final overlapping = await supabase
          .from('bookings')
          .select('id')
          .eq('charger_id', widget.charger.id)
          .neq('status', 'cancelled')
          .lt('start_time', endDT.toUtc().toIso8601String())
          .gt('end_time', startDT.toUtc().toIso8601String());

      if ((overlapping as List).isNotEmpty) {
        if (!mounted) return;
        setState(() => _submitting = false);
        _showError('Dit tijdvak is al geboekt. Kies een ander tijdstip.');
        return;
      }

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Niet ingelogd');
      }
      final userId = user.id;
      final userName =
          (user.userMetadata?['full_name'] as String?)?.trim().isNotEmpty ==
                  true
              ? user.userMetadata!['full_name'] as String
              : (user.email ?? 'Onbekend');

      await supabase.from('bookings').insert({
        'charger_id': widget.charger.id,
        'user_id': userId,
        'user_name': userName,
        'start_time': startDT.toUtc().toIso8601String(),
        'end_time': endDT.toUtc().toIso8601String(),
        'status': 'confirmed',
        'message': _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      });

      if (!mounted) return;
      // Succes-scherm tonen
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _BookingSuccessDialog(
          date: _selectedDate,
          start: _startTime!,
          end: _endTime!,
          charger: widget.charger,
          onClose: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop(true); // terug naar detail
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Reservering mislukt. Probeer het opnieuw.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reserveer laadpaal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chargerSummaryCard(),
            const SizedBox(height: 22),
            Text(
              'Kies een dag',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _dayPickerStrip(),
            const SizedBox(height: 22),
            Text(
              'Kies een tijd',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _timePickers(),
            const SizedBox(height: 22),
            Text(
              'Bericht aan de eigenaar (optioneel)',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Bijv. Hallo! Ik kom rond 18:30 langs.',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting || _loadingSlot ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Bevestig reservering'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chargerSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.ev_station_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.charger.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.charger.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '€${widget.charger.price}',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayPickerStrip() {
    // 14 dagen strip — vandaag + 13 dagen
    final today = DateTime.now();
    final days = List.generate(14, (i) {
      return DateTime(today.year, today.month, today.day).add(Duration(days: i));
    });

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = _selectedDate.year == day.year &&
              _selectedDate.month == day.month &&
              _selectedDate.day == day.day;
          return GestureDetector(
            onTap: () => _selectDate(day),
            child: Container(
              width: 58,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _shortWeekdayNames[day.weekday],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? Colors.white.withOpacity(0.85)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.day.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _timePickers() {
    if (_loadingSlot) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ),
        ),
      );
    }

    final slot = _slotForSelectedDay;
    if (slot == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.do_not_disturb_rounded,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Op ${_weekdayNames[_selectedDate.weekday]} is de laadpaal niet beschikbaar.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Window-info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Beschikbaar: ${_formatTimeForDisplay(slot.startTime)} – ${_formatTimeForDisplay(slot.endTime)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bigTimeField(
                label: 'Van',
                time: _startTime,
                onTap: _pickStartTime,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bigTimeField(
                label: 'Tot',
                time: _endTime,
                onTap: _pickEndTime,
              ),
            ),
          ],
        ),
        if (_startTime != null && _endTime != null) ...[
          const SizedBox(height: 10),
          _durationSummary(),
        ],
      ],
    );
  }

  Widget _bigTimeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time == null ? '--:--' : _formatTimeForDisplay(time),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: time == null ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationSummary() {
    final start = _combineDateAndTime(_selectedDate, _startTime!);
    final end = _combineDateAndTime(_selectedDate, _endTime!);
    if (!end.isAfter(start)) {
      return const SizedBox.shrink();
    }
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final text = hours == 0
        ? '$minutes minuten'
        : minutes == 0
            ? '$hours uur'
            : '$hours u $minutes min';
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        'Duur: $text',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// Succes-dialog nadat een boeking is gemaakt
class _BookingSuccessDialog extends StatelessWidget {
  final DateTime date;
  final TimeOfDay start;
  final TimeOfDay end;
  final Charger charger;
  final VoidCallback onClose;

  const _BookingSuccessDialog({
    required this.date,
    required this.start,
    required this.end,
    required this.charger,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Gereserveerd!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${charger.name}\n${date.day} ${_monthNames[date.month]} · ${_formatTimeForDisplay(start)}–${_formatTimeForDisplay(end)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                child: const Text('Oké'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// MyBookingsScreen - lijst met boekingen van de ingelogde gebruiker
// ============================================
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<Booking> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('bookings')
          .select('*, chargers(*)')
          .eq('user_id', userId)
          .order('start_time', ascending: true);

      if (!mounted) return;
      setState(() {
        _bookings = (data as List)
            .map((row) => Booking.fromMap(row as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Boeking annuleren?'),
        content: const Text('Weet je zeker dat je deze reservering wilt annuleren?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nee'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja, annuleer',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', booking.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kon niet annuleren'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mijn boekingen'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : _bookings.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      return _bookingTile(_bookings[index]);
                    },
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nog geen boekingen',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Reserveer een laadpaal in de buurt\nvia de kaart.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingTile(Booking booking) {
    final now = DateTime.now();
    final isPast = booking.endTime.isBefore(now);
    final isCancelled = booking.status == 'cancelled';
    final isUpcoming = !isPast && !isCancelled;

    Color accent;
    String label;
    if (isCancelled) {
      accent = AppColors.danger;
      label = 'Geannuleerd';
    } else if (isPast) {
      accent = AppColors.textSecondary;
      label = 'Afgelopen';
    } else {
      accent = AppColors.primary;
      label = 'Bevestigd';
    }

    final charger = booking.charger;
    final dateStr =
        '${booking.startTime.day} ${_monthNames[booking.startTime.month]}';
    final timeStr =
        '${_formatTimeForDisplay(TimeOfDay.fromDateTime(booking.startTime))} – ${_formatTimeForDisplay(TimeOfDay.fromDateTime(booking.endTime))}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              charger?.name ?? 'Laadpaal',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (charger != null) ...[
              const SizedBox(height: 2),
              Text(
                charger.address,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (isUpcoming) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancel(booking),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Annuleren'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    textStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INKOMENDE BOEKINGEN — inbox voor paal-eigenaren
// ============================================================================
class IncomingBookingsScreen extends StatefulWidget {
  const IncomingBookingsScreen({Key? key}) : super(key: key);

  @override
  State<IncomingBookingsScreen> createState() => _IncomingBookingsScreenState();
}

class _IncomingBookingsScreenState extends State<IncomingBookingsScreen> {
  List<Booking> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // Haal alle boekingen op van chargers waar ik eigenaar van ben.
      // !inner zorgt ervoor dat alleen rows met matching charger worden teruggegeven,
      // en dat de eq-filter op chargers.owner_id correct werkt.
      final data = await supabase
          .from('bookings')
          .select('*, chargers!inner(*)')
          .eq('chargers.owner_id', userId)
          .order('start_time', ascending: true);

      final list = (data as List)
          .map((m) => Booking.fromMap(m as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _bookings = list;
        _loading = false;
      });

      // Markeer alle ongelezen boekingen als gezien zodra het scherm open is
      final unreadIds = list
          .where((b) => !b.viewedByOwner)
          .map((b) => b.id)
          .toList();
      if (unreadIds.isNotEmpty) {
        try {
          await supabase
              .from('bookings')
              .update({'viewed_by_owner': true})
              .inFilter('id', unreadIds);
        } catch (_) {
          // Niet fataal; volgende keer proberen we opnieuw
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon boekingen niet laden: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDateHeader(DateTime dt) {
    final weekday = _shortWeekdayNames[dt.weekday];
    final month = _monthNames[dt.month];
    return '$weekday ${dt.day} $month';
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(start.hour)}:${two(start.minute)} – ${two(end.hour)}:${two(end.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = _bookings
        .where((b) => b.endTime.isAfter(now) && b.status != 'cancelled')
        .toList();
    final past = _bookings
        .where((b) => !b.endTime.isAfter(now) || b.status == 'cancelled')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inkomende boekingen'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _bookings.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _sectionHeader('Aankomend', upcoming.length),
                        const SizedBox(height: 8),
                        ...upcoming.map(_bookingCard),
                        const SizedBox(height: 24),
                      ],
                      if (past.isNotEmpty) ...[
                        _sectionHeader('Geschiedenis', past.length),
                        const SizedBox(height: 8),
                        ...past.map(_bookingCard),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nog geen boekingen',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Zodra iemand een van jouw palen reserveert, verschijnt dat hier.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bookingCard(Booking b) {
    final isCancelled = b.status == 'cancelled';
    final isPast = !b.endTime.isAfter(DateTime.now());
    final chargerName = b.charger?.name ?? 'Laadpaal';
    final bookerName = b.userName ?? 'Onbekende gebruiker';

    Color pillColor;
    String pillText;
    if (isCancelled) {
      pillColor = AppColors.danger;
      pillText = 'Geannuleerd';
    } else if (isPast) {
      pillColor = AppColors.textSecondary;
      pillText = 'Afgelopen';
    } else {
      pillColor = AppColors.primary;
      pillText = 'Bevestigd';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookerName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chargerName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    pillText,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: pillColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDateHeader(b.startTime),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimeRange(b.startTime, b.endTime),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (b.message != null && b.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b.message!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ============================================
// LoginScreen - e-mail + wachtwoord inloggen
// ============================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Vul e-mail en wachtwoord in');
      return;
    }

    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // AuthGate regelt automatisch de navigatie naar HomeScreen
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Er ging iets mis. Probeer het opnieuw.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Logo-badge groot in het midden
              Center(child: _bigBrandBadge()),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Welkom terug',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Log in om laadpunten in je buurt te vinden',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _fieldLabel('E-mailadres'),
              _authTextField(
                controller: _emailController,
                hint: 'jouw@email.nl',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _fieldLabel('Wachtwoord'),
              _authTextField(
                controller: _passwordController,
                hint: 'Minimaal 6 tekens',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 8),
              // "Wachtwoord vergeten?" rechts uitgelijnd onder het wachtwoordveld
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Wachtwoord vergeten?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Inloggen'),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Nog geen account? ',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Registreer',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// SignupScreen - account aanmaken met naam + e-mail + wachtwoord
// ============================================
class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Vul alle velden in');
      return;
    }
    if (password.length < 6) {
      _showError('Wachtwoord moet minimaal 6 tekens zijn');
      return;
    }

    setState(() => _loading = true);
    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
        // full_name komt terecht in raw_user_meta_data en wordt door onze
        // handle_new_user-trigger in de profiles-tabel gezet
        data: {'full_name': name},
      );
      // AuthGate regelt automatisch de navigatie naar HomeScreen
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Er ging iets mis. Probeer het opnieuw.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Account aanmaken',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Word onderdeel van de Pluggo-community',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              _fieldLabel('Jouw naam'),
              _authTextField(
                controller: _nameController,
                hint: 'Bijvoorbeeld Jan de Vries',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),
              _fieldLabel('E-mailadres'),
              _authTextField(
                controller: _emailController,
                hint: 'jouw@email.nl',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _fieldLabel('Wachtwoord'),
              _authTextField(
                controller: _passwordController,
                hint: 'Minimaal 6 tekens',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signUp,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Account aanmaken'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Door een account aan te maken ga je akkoord met onze ',
                      ),
                      TextSpan(
                        text: 'Algemene voorwaarden',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _openExternalUrl(termsOfServiceUrl),
                      ),
                      const TextSpan(text: ' en ons '),
                      TextSpan(
                        text: 'Privacybeleid',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _openExternalUrl(privacyPolicyUrl),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// ForgotPasswordScreen - stuurt een Supabase reset-email
// ============================================
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({Key? key, this.initialEmail = ''})
      : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _loading = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Vul een geldig e-mailadres in');
      return;
    }
    setState(() => _loading = true);
    try {
      // Supabase verstuurt een email met een link naar hun hosted reset-pagina.
      // Voor een MVP is dat prima; deep links naar de app is een vervolgstap.
      await supabase.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      // We lekken bewust geen info over of de email bestaat; een generieke
      // succes-state is veiliger. Maar bij netwerk-errors willen we wel iets.
      _showError('Er ging iets mis. Probeer het opnieuw.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _sent ? _sentView() : _formView(),
        ),
      ),
    );
  }

  // Formulier-weergave: email invoeren en verzendknop
  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Wachtwoord vergeten',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vul je e-mailadres in en we sturen je een link om een nieuw wachtwoord te kiezen.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _fieldLabel('E-mailadres'),
        _authTextField(
          controller: _emailController,
          hint: 'jouw@email.nl',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendReset,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text('Stuur resetlink'),
          ),
        ),
      ],
    );
  }

  // Bevestigings-weergave: "check je mailbox"
  Widget _sentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 36,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Check je inbox',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We hebben een e-mail gestuurd naar\n${_emailController.text.trim()}.\n\n'
          'Klik op de link in de mail om een nieuw wachtwoord te kiezen. '
          'Kom daarna terug om in te loggen.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Terug naar inloggen'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  setState(() => _sent = false);
                },
          child: Text(
            'Mail niet ontvangen? Opnieuw proberen',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// Gedeelde helpers voor auth-schermen
// ============================================
Widget _fieldLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

Widget _authTextField({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  bool obscureText = false,
  TextInputType? keyboardType,
  Widget? suffix,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider),
    ),
    child: TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        suffixIcon: suffix,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );
}

Widget _bigBrandBadge() {
  return Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.35),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 40),
  );
}

class _ChargerCard extends StatefulWidget {
  final Charger charger;
  final VoidCallback onTap;
  // True als deze paal van de huidige gebruiker is — dan tonen we een
  // tikbare toggle i.p.v. een statische status-pil.
  final bool isOwner;
  // Callback die wordt aangeroepen na een succesvolle toggle,
  // zodat de HomeScreen de kaart-markers en de lijst kan verversen.
  final VoidCallback? onChanged;

  const _ChargerCard({
    required this.charger,
    required this.onTap,
    this.isOwner = false,
    this.onChanged,
  });

  @override
  State<_ChargerCard> createState() => _ChargerCardState();
}

class _ChargerCardState extends State<_ChargerCard> {
  late bool _available;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _available = widget.charger.available;
  }

  @override
  void didUpdateWidget(covariant _ChargerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Als de charger-prop van buitenaf wijzigt (bv. na _loadChargers),
    // synchroniseren we onze lokale state mee.
    if (oldWidget.charger.available != widget.charger.available) {
      _available = widget.charger.available;
    }
  }

  Future<void> _toggleAvailability() async {
    if (_toggling) return;
    final newValue = !_available;
    // Optimistic update — de knop flipt meteen, zodat het snappy voelt.
    setState(() {
      _available = newValue;
      _toggling = true;
    });
    try {
      await supabase
          .from('chargers')
          .update({'available': newValue})
          .eq('id', widget.charger.id);
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      // Mislukt — terug naar oude waarde
      setState(() => _available = !newValue);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon niet wijzigen: $msg'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail links — foto als beschikbaar, anders icoon
                _thumbnail(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.charger.name,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (widget.charger.solar) ...[
                            const SizedBox(width: 6),
                            _solarBadge(small: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.charger.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '€${widget.charger.price}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            ' /kWh',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.charger.type,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          widget.isOwner
                              ? _ownerTogglePill()
                              : _statusPill(available: _available),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tikbare pil voor de eigenaar — zelfde look als de statische pil
  // plus een ripple + spinner tijdens het omzetten.
  Widget _ownerTogglePill() {
    final color = _available ? AppColors.primary : AppColors.textSecondary;
    final bg = _available
        ? AppColors.primarySoft
        : const Color(0xFFF3F4F6);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _toggling ? null : _toggleAvailability,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_toggling) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
              ] else ...[
                Icon(
                  _available
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  size: 16,
                  color: color,
                ),
              ],
              const SizedBox(width: 6),
              Text(
                _available ? 'Aan' : 'Uit',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    if (widget.charger.photoUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          widget.charger.photoUrls.first,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconThumbnail(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 52,
              height: 52,
              color: AppColors.divider,
            );
          },
        ),
      );
    }
    return _iconThumbnail();
  }

  Widget _iconThumbnail() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _available
            ? AppColors.primarySoft
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.ev_station_rounded,
        color: _available
            ? AppColors.primary
            : AppColors.textSecondary,
        size: 26,
      ),
    );
  }

  Widget _solarBadge({bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.solarSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_rounded, size: small ? 10 : 12, color: AppColors.solar),
          SizedBox(width: small ? 3 : 4),
          Text(
            'Zon',
            style: GoogleFonts.inter(
              fontSize: small ? 10 : 12,
              color: AppColors.solar,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill({required bool available}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: available
            ? AppColors.primarySoft
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: available ? AppColors.primary : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            available ? 'Vrij' : 'Bezet',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: available ? AppColors.primaryDark : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
