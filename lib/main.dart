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

// Publieke URL's — gehost op pluggoapp.nl via GitHub Pages custom domain.
const String privacyPolicyUrl = 'https://pluggoapp.nl/privacy.html';
const String termsOfServiceUrl = 'https://pluggoapp.nl/terms.html';

// ============================================
// Launch date — boekingen worden pas mogelijk vanaf deze datum.
// Vóór deze datum kunnen mensen wel hun paal toevoegen, hun account
// aanmaken, en de app verkennen. Iedereen met een account krijgt een
// melding op de launch dag (zie Supabase scheduled function).
// Pas deze datum aan als de launch verschuift.
// ============================================
final DateTime bookingsGoLiveAt = DateTime(2026, 6, 1);
bool get bookingsAreLive => !DateTime.now().isBefore(bookingsGoLiveAt);
// Hoeveel hele dagen tot de launch, in datums (dus niet uren). Op 31 mei
// staat er "over 1 dag" en op 1 juni "vandaag!", ook al is het 23:59.
int get daysUntilLaunch {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final launchDay = DateTime(
    bookingsGoLiveAt.year,
    bookingsGoLiveAt.month,
    bookingsGoLiveAt.day,
  );
  final diff = launchDay.difference(today).inDays;
  return diff < 0 ? 0 : diff;
}
const String launchDateLabel = '1 juni 2026';

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

// ============================================
// LaunchCountdownBanner — herbruikbare oranje banner die op meerdere
// plekken in de app uitlegt dat boekingen pas vanaf [bookingsGoLiveAt]
// open gaan. Toont automatisch niets meer zodra die datum is bereikt.
// `compact` = kleinere variant zonder uitleg (voor in lijsten),
// `showAccountHint` = toon de zin "maak nu vast een account aan" (op
// publieke schermen zoals login/signup waar de gebruiker nog niet ingelogd
// is). Voor ingelogde gebruikers laten we automatisch een ander berichtje
// zien dat ze een melding krijgen op de launch-dag.
// ============================================
class LaunchCountdownBanner extends StatelessWidget {
  final bool compact;
  final bool showAccountHint;
  const LaunchCountdownBanner({
    Key? key,
    this.compact = false,
    this.showAccountHint = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (bookingsAreLive) return const SizedBox.shrink();
    final days = daysUntilLaunch;
    final loggedIn = Supabase.instance.client.auth.currentUser != null;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.solarSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.solar.withOpacity(0.45)),
      ),
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rocket_launch_rounded,
                color: AppColors.solar,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Boekingen gaan live op $launchDateLabel',
                  style: GoogleFonts.inter(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.solar,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  days == 0
                      ? 'vandaag!'
                      : (days == 1 ? 'over 1 dag' : 'over $days dagen'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              loggedIn
                  ? 'Je krijgt automatisch een melding zodra boekingen open gaan. Heb jij zelf een paal? Voeg \'m nu vast toe — vanaf $launchDateLabel kun je gemiddeld €100–200 per maand bijverdienen.'
                  : (showAccountHint
                      ? 'Maak nu vast een account aan, dan krijg je een seintje zodra boekingen open gaan op $launchDateLabel.'
                      : 'Tot die tijd kun je palen verkennen en — als jij er één hebt — die alvast toevoegen.'),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
  final String? ownerEmail;
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
    this.ownerEmail,
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
      ownerEmail: map['owner_email'] as String?,
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
  final String? userEmail;
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
    this.userEmail,
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
      userEmail: map['user_email'] as String?,
      viewedByOwner: (map['viewed_by_owner'] as bool?) ?? false,
      charger: charger,
    );
  }

  Duration get duration => endTime.difference(startTime);
}

// Een review die een booker achterlaat na een afgelopen boeking.
// Bevat sterren voor zowel de paal als de eigenaar, optionele tekst,
// en een optionele reactie van de eigenaar.
class Review {
  final String id;
  final String bookingId;
  final String chargerId;
  final String reviewerId;
  final String ownerId;
  final int ratingCharger;
  final int ratingOwner;
  final String? comment;
  final String? ownerReply;
  final DateTime? ownerRepliedAt;
  final DateTime createdAt;
  // Optioneel: naam van de reviewer voor weergave (komt uit een join of metadata)
  final String? reviewerName;

  const Review({
    required this.id,
    required this.bookingId,
    required this.chargerId,
    required this.reviewerId,
    required this.ownerId,
    required this.ratingCharger,
    required this.ratingOwner,
    this.comment,
    this.ownerReply,
    this.ownerRepliedAt,
    required this.createdAt,
    this.reviewerName,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] as String,
      bookingId: map['booking_id'] as String,
      chargerId: map['charger_id'] as String,
      reviewerId: map['reviewer_id'] as String,
      ownerId: map['owner_id'] as String,
      ratingCharger: (map['rating_charger'] as num).toInt(),
      ratingOwner: (map['rating_owner'] as num).toInt(),
      comment: map['comment'] as String?,
      ownerReply: map['owner_reply'] as String?,
      ownerRepliedAt: map['owner_replied_at'] != null
          ? DateTime.parse(map['owner_replied_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      reviewerName: map['reviewer_name'] as String?,
    );
  }
}

// Een review die de eigenaar van een paal achterlaat over de booker
// na een afgelopen laadsessie. 1 sterren-rating + optioneel commentaar.
class BookerReview {
  final String id;
  final String bookingId;
  final String chargerId;
  final String reviewerId; // de eigenaar
  final String bookerId;
  final int rating;
  final String? comment;
  final String? reviewerName;
  final DateTime createdAt;
  // Reactie van de boeker op deze review (optioneel)
  final String? bookerReply;
  final DateTime? bookerRepliedAt;

  const BookerReview({
    required this.id,
    required this.bookingId,
    required this.chargerId,
    required this.reviewerId,
    required this.bookerId,
    required this.rating,
    this.comment,
    this.reviewerName,
    required this.createdAt,
    this.bookerReply,
    this.bookerRepliedAt,
  });

  factory BookerReview.fromMap(Map<String, dynamic> map) {
    return BookerReview(
      id: map['id'] as String,
      bookingId: map['booking_id'] as String,
      chargerId: map['charger_id'] as String,
      reviewerId: map['reviewer_id'] as String,
      bookerId: map['booker_id'] as String,
      rating: (map['rating'] as num).toInt(),
      comment: map['comment'] as String?,
      reviewerName: map['reviewer_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      bookerReply: map['booker_reply'] as String?,
      bookerRepliedAt: map['booker_replied_at'] != null
          ? DateTime.parse(map['booker_replied_at'] as String).toLocal()
          : null,
    );
  }
}

// Een gesprek tussen twee gebruikers (paarwise). user_a < user_b alfabetisch
// zodat elke combinatie maar één keer voorkomt.
class Conversation {
  final String id;
  final String userAId;
  final String userBId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;
  final DateTime? lastEmailSentAt;
  final DateTime createdAt;
  // Naam van de andere partij (uit join met bookings of metadata)
  final String? otherUserName;
  // Aantal ongelezen berichten voor de huidige gebruiker (handmatig berekend)
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.userAId,
    required this.userBId,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.lastEmailSentAt,
    required this.createdAt,
    this.otherUserName,
    this.unreadCount = 0,
  });

  // De id van de andere gebruiker (gegeven mijn user-id)
  String otherUserId(String myId) => userAId == myId ? userBId : userAId;

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      userAId: map['user_a_id'] as String,
      userBId: map['user_b_id'] as String,
      lastMessageAt: map['last_message_at'] != null
          ? DateTime.parse(map['last_message_at'] as String).toLocal()
          : null,
      lastMessagePreview: map['last_message_preview'] as String?,
      lastMessageSenderId: map['last_message_sender_id'] as String?,
      lastEmailSentAt: map['last_email_sent_at'] != null
          ? DateTime.parse(map['last_email_sent_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Conversation copyWith({String? otherUserName, int? unreadCount}) {
    return Conversation(
      id: id,
      userAId: userAId,
      userBId: userBId,
      lastMessageAt: lastMessageAt,
      lastMessagePreview: lastMessagePreview,
      lastMessageSenderId: lastMessageSenderId,
      lastEmailSentAt: lastEmailSentAt,
      createdAt: createdAt,
      otherUserName: otherUserName ?? this.otherUserName,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// Een individueel chatbericht binnen een conversation
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String body;
  final DateTime createdAt;
  final DateTime? seenAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    required this.body,
    required this.createdAt,
    this.seenAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      senderName: map['sender_name'] as String?,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      seenAt: map['seen_at'] != null
          ? DateTime.parse(map['seen_at'] as String).toLocal()
          : null,
    );
  }
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
  bool _loading = true;
  String? _error;

  // Gemiddelde charger-rating per paal (op rating_charger uit reviews tabel)
  // en aantal reviews. Worden samen met _loadChargers opgehaald.
  Map<String, double> _ratingByChargerId = {};
  Map<String, int> _reviewCountByChargerId = {};

  // Zoekbalk: live filteren op naam / adres / beschrijving
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Map filter chips — MVP: 3 simpele toggles die mét de zoektekst samenwerken
  bool _filterAvailable = false;
  bool _filterSolar = false;
  bool _filterNearby = false;

  // Laatste bekende positie van de gebruiker — nodig voor de "Dichtbij"-filter.
  // Wordt ingevuld zodra we succesvol Geolocator.getCurrentPosition hebben gedaan.
  Position? _myPosition;
  static const double _nearbyRadiusKm = 10.0;

  // Aantal ongelezen binnenkomende boekingen (voor rode badge op profielicoon)
  int _unreadIncoming = 0;
  // Aantal ongelezen ontvangen reviews (zowel als boeker als eigenaar)
  int _unreadReviews = 0;
  // Aantal ongelezen chatberichten in alle gesprekken
  int _unreadMessages = 0;

  // Wordt true zodra de user permissie heeft gegeven; dan tonen we de blauwe dot
  bool _showMyLocation = false;
  // Voorkomt dat we meerdere keren tegelijk locatie proberen op te halen
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _loadChargers();
    _loadUnreadIncoming();
    _loadUnreadReviews();
    _loadUnreadMessages();
    // Bij elke toetsaanslag direct filteren (MVP-schaal is dit prima)
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Gefilterde lijst op basis van zoekterm. Case-insensitive match op
  // naam, adres en beschrijving — dat dekt in de praktijk ook stads- en
  // straatnamen, want die zitten in het adres.
  List<Charger> get _visibleChargers {
    final q = _searchQuery.trim().toLowerCase();
    final me = _myPosition;
    return _chargers.where((c) {
      // Tekst-filter
      if (q.isNotEmpty) {
        final match = c.name.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q);
        if (!match) return false;
      }
      // Chip: alleen beschikbaar
      if (_filterAvailable && !c.available) return false;
      // Chip: alleen zonne-energie
      if (_filterSolar && !c.solar) return false;
      // Chip: alleen palen binnen straal van mijn locatie
      if (_filterNearby && me != null) {
        final meters = Geolocator.distanceBetween(
          me.latitude,
          me.longitude,
          c.position.latitude,
          c.position.longitude,
        );
        if (meters > _nearbyRadiusKm * 1000) return false;
      }
      return true;
    }).toList();
  }

  /// Handig voor bijv. het filter-icoontje: laat zien hoeveel filters aan staan.
  int get _activeFilterCount {
    var n = 0;
    if (_filterAvailable) n++;
    if (_filterSolar) n++;
    if (_filterNearby) n++;
    return n;
  }

  // Markers worden live herberekend uit de zichtbare palen, zodat het
  // kaart-beeld meeloopt met de zoekbalk.
  Set<Marker> get _visibleMarkers {
    return _visibleChargers.map((charger) {
      double hue;
      if (!charger.available) {
        hue = BitmapDescriptor.hueRed;
      } else if (charger.solar) {
        hue = BitmapDescriptor.hueYellow;
      } else {
        hue = 160;
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

      setState(() {
        _showMyLocation = true;
        _myPosition = pos;
      });

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

  /// Zet de "Dichtbij"-filter aan of uit. Als hij aan gaat en we hebben
  /// nog geen locatie, vragen we eerst permissie en halen we de positie op.
  Future<void> _toggleNearbyFilter() async {
    // Uit → gewoon uitzetten
    if (_filterNearby) {
      setState(() => _filterNearby = false);
      return;
    }

    // Aan zetten: zorg dat we een positie hebben
    if (_myPosition == null) {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Zet locatievoorzieningen aan om op afstand te filteren.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

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
                'Zonder locatietoestemming kunnen we de afstandsfilter niet toepassen.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        if (!mounted) return;
        setState(() {
          _myPosition = pos;
          _showMyLocation = true;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kon locatie niet ophalen: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _filterNearby = true);
  }

  /// Animeer de kaart naar de huidige gefilterde resultaten.
  /// - 0 treffers: snackbar "Niks gevonden"
  /// - 1 treffer: inzoomen op die paal (zoom 15)
  /// - >1 treffer: de kaart zo aanpassen dat alle treffers zichtbaar zijn
  Future<void> _moveCameraToVisibleResults() async {
    FocusScope.of(context).unfocus();
    final results = _visibleChargers;
    final controller = mapController;
    if (controller == null) return;

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Geen laadpunten gevonden voor deze zoekopdracht'),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (results.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: results.first.position, zoom: 15),
        ),
      );
      return;
    }

    // Meerdere treffers: bereken bounding box
    double minLat = results.first.position.latitude;
    double maxLat = results.first.position.latitude;
    double minLng = results.first.position.longitude;
    double maxLng = results.first.position.longitude;
    for (final c in results) {
      if (c.position.latitude < minLat) minLat = c.position.latitude;
      if (c.position.latitude > maxLat) maxLat = c.position.latitude;
      if (c.position.longitude < minLng) minLng = c.position.longitude;
      if (c.position.longitude > maxLng) maxLng = c.position.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60),
    );
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

  // Aantal ongelezen reviews ophalen — som van twee queries:
  // 1) reviews op palen waar ik eigenaar van ben
  // 2) booker_reviews waar ik de boeker ben
  Future<void> _loadUnreadReviews() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final asOwner = await supabase
          .from('reviews')
          .select('id')
          .eq('owner_id', userId)
          .eq('seen_by_recipient', false);
      final asBooker = await supabase
          .from('booker_reviews')
          .select('id')
          .eq('booker_id', userId)
          .eq('seen_by_recipient', false);
      if (!mounted) return;
      setState(() {
        _unreadReviews =
            (asOwner as List).length + (asBooker as List).length;
      });
    } catch (_) {
      // Stil falen: badge blijft op vorige waarde
    }
  }

  // Aantal ongelezen chatberichten in al mijn gesprekken
  Future<void> _loadUnreadMessages() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // 1) Welke conversations doe ik mee?
      final convs = await supabase
          .from('conversations')
          .select('id')
          .or('user_a_id.eq.$userId,user_b_id.eq.$userId');
      final convIds = (convs as List)
          .map((c) => (c as Map<String, dynamic>)['id'] as String)
          .toList();
      if (convIds.isEmpty) {
        if (!mounted) return;
        setState(() => _unreadMessages = 0);
        return;
      }
      // 2) Tel ongelezen berichten waarvan ik niet de afzender ben
      final rows = await supabase
          .from('messages')
          .select('id')
          .inFilter('conversation_id', convIds)
          .neq('sender_id', userId)
          .filter('seen_at', 'is', null);
      if (!mounted) return;
      setState(() {
        _unreadMessages = (rows as List).length;
      });
    } catch (_) {
      // Stil falen
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

      // Reviews ophalen om gemiddelde per paal te berekenen.
      // Niet fataal — bij een fout tonen we gewoon geen sterren.
      final ratings = <String, double>{};
      final counts = <String, int>{};
      try {
        final reviewRows = await supabase
            .from('reviews')
            .select('charger_id, rating_charger');
        final byCharger = <String, List<int>>{};
        for (final r in reviewRows as List) {
          final m = r as Map<String, dynamic>;
          final cid = m['charger_id'] as String?;
          final rc = m['rating_charger'];
          if (cid == null || rc == null) continue;
          byCharger.putIfAbsent(cid, () => []).add((rc as num).toInt());
        }
        byCharger.forEach((cid, list) {
          if (list.isEmpty) return;
          ratings[cid] = list.reduce((a, b) => a + b) / list.length;
          counts[cid] = list.length;
        });
      } catch (_) {/* reviews zijn optioneel voor de lijst */}

      setState(() {
        _chargers = chargers;
        _ratingByChargerId = ratings;
        _reviewCountByChargerId = counts;
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
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
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
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                    // Als de naam is bijgewerkt heropenen we de sheet zodat
                    // de nieuwe naam meteen zichtbaar is.
                    if (updated == true && mounted) {
                      setState(() {});
                      _showProfileSheet();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(16),
                            image: avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(avatarUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                  size: 26,
                                )
                              : null,
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
                        const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyChargersScreen(),
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
                          Icons.ev_station_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Mijn paal',
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
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyReviewsScreen(),
                      ),
                    );
                    // Badge opnieuw ophalen zodra je terug bent
                    _loadUnreadReviews();
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
                          Icons.star_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Mijn beoordelingen',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_unreadReviews > 0) ...[
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
                              '$_unreadReviews',
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
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConversationsScreen(),
                      ),
                    );
                    _loadUnreadMessages();
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
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Berichten',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_unreadMessages > 0) ...[
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
                              '$_unreadMessages',
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
            markers: _visibleMarkers,
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
                          _loadUnreadReviews();
                          _loadUnreadMessages();
                        },
                      ),
                      const SizedBox(width: 8),
                      _roundIconButton(
                        icon: Icons.person_outline_rounded,
                        onTap: _showProfileSheet,
                        badgeCount:
                            _unreadIncoming + _unreadReviews + _unreadMessages,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Zoekbalk met pil-vorm en zachte schaduw — filtert live
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: softShadow,
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _moveCameraToVisibleResults(),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Zoek op naam, adres of stad…',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                        ),
                        // Kruisje alleen zichtbaar zodra er iets getypt is
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Horizontaal scrollende filter-chips — werken samen met
                  // de zoekbalk, dus je kunt typen + filters combineren.
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      children: [
                        _filterChip(
                          label: 'Beschikbaar',
                          icon: Icons.check_circle_rounded,
                          selected: _filterAvailable,
                          onTap: () => setState(
                              () => _filterAvailable = !_filterAvailable),
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          label: 'Zonne-energie',
                          icon: Icons.wb_sunny_rounded,
                          selected: _filterSolar,
                          onTap: () =>
                              setState(() => _filterSolar = !_filterSolar),
                        ),
                        const SizedBox(width: 8),
                        _filterChip(
                          label: 'Dichtbij (10 km)',
                          icon: Icons.near_me_rounded,
                          selected: _filterNearby,
                          onTap: _toggleNearbyFilter,
                        ),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(width: 8),
                          _filterChip(
                            label: 'Wis filters',
                            icon: Icons.close_rounded,
                            selected: false,
                            onTap: () => setState(() {
                              _filterAvailable = false;
                              _filterSolar = false;
                              _filterNearby = false;
                            }),
                          ),
                        ],
                      ],
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
                                '${_visibleChargers.length}',
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
                    // Pre-launch banner — alleen zichtbaar zolang
                    // bookingsAreLive == false. Toont aan iedereen die
                    // de palenlijst opent dat boekingen op 1 juni open gaan.
                    if (!bookingsAreLive)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: const LaunchCountdownBanner(),
                      ),
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

  /// Pil-vormige filter-chip onder de zoekbalk. Groene fill als hij aan staat,
  /// witte kaart-stijl als hij uit staat.
  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg = selected ? AppColors.primary : AppColors.surface;
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? null : softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
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
    // Helemaal geen palen in de database — lege database state
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

    // Wel palen, maar filter geeft niks — "geen resultaten" state
    final visible = _visibleChargers;
    if (visible.isEmpty) {
      return SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Niks gevonden',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Probeer een andere zoekterm',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Zoekopdracht wissen'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    final currentUserId = supabase.auth.currentUser?.id;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final charger = visible[index];
        final isOwner =
            charger.ownerId != null && charger.ownerId == currentUserId;
        return _ChargerCard(
          charger: charger,
          onTap: () => _openDetail(charger),
          isOwner: isOwner,
          onChanged: _loadChargers,
          avgRating: _ratingByChargerId[charger.id],
          reviewCount: _reviewCountByChargerId[charger.id] ?? 0,
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
            'owner_email': supabase.auth.currentUser?.email,
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
        // Houd owner_email synchroon met huidig account (voor mailnotificaties)
        'owner_email': supabase.auth.currentUser?.email,
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

  // Reviews voor deze paal — sorteren we van nieuw naar oud bij ophalen.
  List<Review> _reviews = [];
  bool _loadingReviews = true;

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
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final data = await supabase
          .from('reviews')
          .select()
          .eq('charger_id', charger.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _reviews = (data as List)
            .map((row) => Review.fromMap(row as Map<String, dynamic>))
            .toList();
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  // Gemiddelden — null als er geen reviews zijn
  double? get _avgChargerRating {
    if (_reviews.isEmpty) return null;
    final sum = _reviews.fold<int>(0, (s, r) => s + r.ratingCharger);
    return sum / _reviews.length;
  }

  double? get _avgOwnerRating {
    if (_reviews.isEmpty) return null;
    final sum = _reviews.fold<int>(0, (s, r) => s + r.ratingOwner);
    return sum / _reviews.length;
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
          .not('status', 'in', '(cancelled,rejected)')
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
            const SizedBox(height: 16),
            // === Reviews-sectie ===
            _reviewsCard(),
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Vóór de launch-datum tonen we de countdown-banner
                        // boven de knop, en is de knop zelf uitgegrijsd.
                        if (!bookingsAreLive) ...[
                          const LaunchCountdownBanner(),
                          const SizedBox(height: 12),
                        ],
                        ElevatedButton(
                          onPressed: (charger.available && bookingsAreLive)
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
                            !bookingsAreLive
                                ? 'Boekingen open vanaf $launchDateLabel'
                                : (charger.available
                                    ? 'Reserveer nu'
                                    : 'Momenteel bezet'),
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

  // Statische rij van 5 sterren (read-only) — voor het tonen van een rating.
  Widget _starsDisplay(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating > i;
        return Padding(
          padding: const EdgeInsets.only(right: 1),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: filled ? const Color(0xFFFFC107) : AppColors.divider,
          ),
        );
      }),
    );
  }

  // Vraagt eigenaar om reactie en slaat die op via UPDATE.
  Future<void> _replyToReview(Review review) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reageer op review'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Bedankt voor je review!',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Plaatsen'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;

    try {
      await supabase.from('reviews').update({
        'owner_reply': text,
        'owner_replied_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', review.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reactie geplaatst'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon reactie niet plaatsen: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Kaart met de reviews + gemiddeldes bovenaan.
  Widget _reviewsCard() {
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
                Icons.star_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Reviews',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_reviews.length}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingReviews)
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
          else if (_reviews.isEmpty)
            Text(
              'Nog geen reviews. Boekers kunnen na hun laadsessie een review achterlaten.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            )
          else ...[
            // Gemiddelden bovenaan
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laadpaal',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Color(0xFFFFC107),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _avgChargerRating!.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eigenaar',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Color(0xFFFFC107),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _avgOwnerRating!.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            // Lijst reviews
            ..._reviews.map((r) => _reviewTile(r)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _reviewTile(Review review) {
    final dateStr =
        '${review.createdAt.day} ${_monthNames[review.createdAt.month]} ${review.createdAt.year}';
    final ownerCanReply = _isOwner && review.ownerReply == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName ?? 'Buur',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Twee mini-rijen: paal-rating + eigenaar-rating
          Row(
            children: [
              Text(
                'Paal',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              _starsDisplay(review.ratingCharger, size: 14),
              const SizedBox(width: 14),
              Text(
                'Eigenaar',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              _starsDisplay(review.ratingOwner, size: 14),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
          // Reactie van eigenaar (indien gegeven)
          if (review.ownerReply != null && review.ownerReply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.reply_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reactie eigenaar',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.ownerReply!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Eigenaar mag reageren (alleen als er nog geen reactie is)
          if (ownerCanReply) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _replyToReview(review),
              icon: const Icon(Icons.reply_rounded, size: 16),
              label: const Text('Reageer'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
      // Overlap = existing.start < new.end AND existing.end > new.start.
      // We sluiten geannuleerde en geweigerde boekingen uit — pending +
      // confirmed blokkeren dus wel een tijdslot.
      final overlapping = await supabase
          .from('bookings')
          .select('id, status')
          .eq('charger_id', widget.charger.id)
          .not('status', 'in', '(cancelled,rejected)')
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
        'user_email': user.email, // voor accept/reject mail
        'start_time': startDT.toUtc().toIso8601String(),
        'end_time': endDT.toUtc().toIso8601String(),
        // Eigenaar moet aanvragen eerst goedkeuren
        'status': 'pending',
        'message': _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      });

      // Stuur de eigenaar een mail dat er een nieuwe aanvraag is.
      // Fire-and-forget: faalt stilletjes als er geen owner_email is.
      _sendNewRequestEmailToOwner(
        ownerEmail: widget.charger.ownerEmail,
        chargerName: widget.charger.name,
        chargerAddress: widget.charger.address,
        bookerName: userName,
        startDT: startDT,
        endDT: endDT,
        message: _messageController.text.trim(),
      );

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

  // ----------------------------------------------------------------
  // Mail naar eigenaar bij nieuwe aanvraag. Fire-and-forget.
  // ----------------------------------------------------------------
  Future<void> _sendNewRequestEmailToOwner({
    required String? ownerEmail,
    required String chargerName,
    required String chargerAddress,
    required String bookerName,
    required DateTime startDT,
    required DateTime endDT,
    required String message,
  }) async {
    if (ownerEmail == null || ownerEmail.isEmpty) return;

    String two(int n) => n.toString().padLeft(2, '0');
    final weekday = _shortWeekdayNames[startDT.weekday];
    final month = _monthNames[startDT.month];
    final datum = '$weekday ${startDT.day} $month';
    final start = '${two(startDT.hour)}:${two(startDT.minute)}';
    final eind = '${two(endDT.hour)}:${two(endDT.minute)}';

    final subject = 'Nieuwe boekingsaanvraag voor $chargerName';

    final adresRegel = chargerAddress.isEmpty
        ? ''
        : '<tr><td style="padding:6px 0;color:#666;">Adres</td><td style="padding:6px 0;font-weight:500;">$chargerAddress</td></tr>';

    final messageBlok = message.isEmpty
        ? ''
        : '''
<div style="background:#F5F5F5;padding:14px 16px;margin:0 0 24px;border-radius:6px;">
  <p style="margin:0 0 4px;color:#666;font-size:12px;text-transform:uppercase;letter-spacing:0.5px;">Bericht van $bookerName</p>
  <p style="margin:0;color:#222;font-size:14px;font-style:italic;">"$message"</p>
</div>''';

    final html = '''
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#F5F5F5;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;">
  <div style="max-width:600px;margin:0 auto;background:#fff;padding:32px 24px;">
    <h1 style="margin:0 0 8px;color:#1976D2;font-size:24px;">Pluggo</h1>
    <p style="margin:0 0 24px;color:#666;font-size:14px;">Buren laden bij buren</p>

    <h2 style="margin:0 0 16px;font-size:20px;color:#222;">Nieuwe boekingsaanvraag</h2>

    <div style="background:#FFF8E1;border-left:4px solid #F57C00;padding:16px 20px;margin:0 0 24px;border-radius:6px;">
      <p style="margin:0;color:#E65100;font-size:14px;">$bookerName wil je laadpaal reserveren. Open de Pluggo-app om de aanvraag te accepteren of weigeren.</p>
    </div>

    <table style="width:100%;border-collapse:collapse;font-size:14px;color:#222;margin:0 0 24px;">
      <tr><td style="padding:6px 0;color:#666;width:90px;">Paal</td><td style="padding:6px 0;font-weight:500;">$chargerName</td></tr>
      $adresRegel
      <tr><td style="padding:6px 0;color:#666;">Datum</td><td style="padding:6px 0;font-weight:500;">$datum</td></tr>
      <tr><td style="padding:6px 0;color:#666;">Tijd</td><td style="padding:6px 0;font-weight:500;">$start – $eind</td></tr>
    </table>

    $messageBlok

    <p style="margin:0 0 8px;color:#444;font-size:14px;">Open de Pluggo-app → tabblad <strong>Inkomend</strong> om te beslissen.</p>
    <hr style="border:none;border-top:1px solid #eee;margin:32px 0 16px;">
    <p style="margin:0;color:#999;font-size:12px;">Je ontvangt deze mail omdat iemand je laadpaal via Pluggo wil boeken.</p>
  </div>
</body>
</html>
''';

    try {
      await supabase.functions.invoke(
        'send-email',
        body: {
          'to': ownerEmail,
          'subject': subject,
          'html': html,
        },
      );
    } catch (_) {
      // best-effort
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
            // Vóór de launch-datum: nogmaals de banner + uitgegrijsde knop
            // (defense-in-depth — normaal kun je hier niet eens komen omdat
            // de knop op het detailscherm al uitgegrijsd is).
            if (!bookingsAreLive) ...[
              const LaunchCountdownBanner(),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_submitting || _loadingSlot || !bookingsAreLive)
                    ? null
                    : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        bookingsAreLive
                            ? 'Bevestig reservering'
                            : 'Boekingen open vanaf $launchDateLabel',
                      ),
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
                Icons.hourglass_top_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aanvraag verstuurd!',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'De eigenaar moet je aanvraag nog goedkeuren. Je krijgt bericht zodra dat is gebeurd.\n\n${charger.name}\n${date.day} ${_monthNames[date.month]} · ${_formatTimeForDisplay(start)}–${_formatTimeForDisplay(end)}',
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
// MyChargersScreen — overzicht van alle palen van de ingelogde gebruiker.
// Tikken op een paal opent het detailscherm. Bovenaan een knop om snel
// een nieuwe paal toe te voegen.
// ============================================
class MyChargersScreen extends StatefulWidget {
  const MyChargersScreen({Key? key}) : super(key: key);

  @override
  State<MyChargersScreen> createState() => _MyChargersScreenState();
}

class _MyChargersScreenState extends State<MyChargersScreen> {
  bool _loading = true;
  List<Charger> _chargers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await supabase
          .from('chargers')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false);
      final list = (data as List)
          .map((m) => Charger.fromMap(m as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _chargers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon palen niet laden: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openDetail(Charger c) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(charger: c)),
    );
    // Als de paal aangepast of verwijderd is, lijst verversen
    if (changed == true) _load();
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddChargerScreen()),
    );
    if (added == true) _load();
  }

  Widget _chargerTile(Charger c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(c),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Foto óf icoon-fallback
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  image: c.photoUrls.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(c.photoUrls.first),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: c.photoUrls.isEmpty
                    ? const Icon(
                        Icons.ev_station_rounded,
                        color: AppColors.primary,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.address,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.available
                                ? AppColors.primary.withOpacity(0.12)
                                : AppColors.divider,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            c.available ? 'Beschikbaar' : 'Niet beschikbaar',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: c.available
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (c.solar) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.wb_sunny_rounded,
                                  size: 11,
                                  color: Color(0xFFB78900),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Zon',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFB78900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
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
                Icons.ev_station_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nog geen palen',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Voeg je laadpaal toe en deel hem met je buren.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Voeg paal toe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
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
        title: const Text('Mijn paal'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (!_loading && _chargers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Voeg paal toe',
              onPressed: _openAdd,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _chargers.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: _chargers.map(_chargerTile).toList(),
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
  // IDs van boekingen waar deze gebruiker al een review voor heeft achtergelaten —
  // gebruikt om "Schrijf review" vs. "Beoordeeld" badge te bepalen.
  Set<String> _reviewedBookingIds = {};

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

      // Reviews die deze gebruiker al heeft achtergelaten (alleen booking_id nodig)
      final reviewRows = await supabase
          .from('reviews')
          .select('booking_id')
          .eq('reviewer_id', userId);
      final reviewedIds = (reviewRows as List)
          .map((r) => (r as Map<String, dynamic>)['booking_id'] as String)
          .toSet();

      if (!mounted) return;
      setState(() {
        _bookings = (data as List)
            .map((row) => Booking.fromMap(row as Map<String, dynamic>))
            .toList();
        _reviewedBookingIds = reviewedIds;
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
    final isRejected = booking.status == 'rejected';
    final isPending = booking.status == 'pending';
    final isUpcoming =
        !isPast && !isCancelled && !isRejected && !isPending;

    Color accent;
    String label;
    if (isCancelled) {
      accent = AppColors.danger;
      label = 'Geannuleerd';
    } else if (isRejected) {
      accent = AppColors.danger;
      label = 'Geweigerd';
    } else if (isPending) {
      accent = const Color(0xFFE0A030); // amber/oranje
      label = 'In afwachting';
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
            // Bericht aan de eigenaar — altijd zichtbaar (ook na annuleren),
            // zodat boeker en eigenaar over en weer kunnen communiceren.
            if (charger?.ownerId != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          otherUserId: charger!.ownerId!,
                          otherUserName:
                              'Eigenaar ${charger.name}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16),
                  label: const Text('Bericht aan eigenaar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            // Annuleer-knop tonen voor toekomstige bevestigde of nog
            // openstaande aanvragen — niet voor afgelopen/al geannuleerde
            // of geweigerde boekingen.
            if ((isUpcoming || isPending) && !isPast) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancel(booking),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text(isPending ? 'Aanvraag intrekken' : 'Annuleren'),
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
            // Afgelopen + bevestigd → review actie tonen
            // (geen review op geannuleerd of geweigerd of pending)
            if (isPast && booking.status == 'confirmed') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _reviewedBookingIds.contains(booking.id)
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Beoordeeld',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  WriteReviewScreen(booking: booking),
                            ),
                          );
                          if (result == true) _load();
                        },
                        icon: const Icon(Icons.star_rounded, size: 16),
                        label: const Text('Schrijf review'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
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
// PROFIEL BEWERKEN — naam aanpassen in user_metadata
// ============================================================================
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _saving = false;

  // Huidige avatar-URL uit user_metadata (kan null zijn als niet gezet)
  String? _currentAvatarUrl;
  // Net geselecteerde foto die nog moet worden geüpload
  XFile? _pickedAvatar;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    final meta = user?.userMetadata;
    _nameController = TextEditingController(
      text: (meta?['full_name'] as String?) ?? '',
    );
    _currentAvatarUrl = meta?['avatar_url'] as String?;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _pickedAvatar = picked);
  }

  /// Uploadt de gekozen foto naar bucket `avatars` onder pad `{userId}/avatar.{ext}`.
  /// Returnt de publieke URL (met cachebuster zodat de app de nieuwe foto ziet).
  Future<String> _uploadAvatar(XFile file, String userId) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final path = '$userId/avatar.$ext';
    await supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true,
          ),
        );
    final url = supabase.storage.from('avatars').getPublicUrl(path);
    // Cachebuster: voorkomt dat oude cache-versie van de avatar blijft hangen
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'Niet ingelogd';

      String? avatarUrl = _currentAvatarUrl;
      if (_pickedAvatar != null) {
        avatarUrl = await _uploadAvatar(_pickedAvatar!, userId);
      }

      final newName = _nameController.text.trim();
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': newName,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          },
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profiel bijgewerkt'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon profiel niet opslaan: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profiel bewerken'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar — tapbaar om te veranderen
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(28),
                            image: _pickedAvatar != null
                                ? DecorationImage(
                                    image: FileImage(File(_pickedAvatar!.path)),
                                    fit: BoxFit.cover,
                                  )
                                : (_currentAvatarUrl != null
                                    ? DecorationImage(
                                        image:
                                            NetworkImage(_currentAvatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                          ),
                          child: (_pickedAvatar == null &&
                                  _currentAvatarUrl == null)
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                  size: 44,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Naam
                Text(
                  'Naam',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Jouw volledige naam',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Vul je naam in';
                    if (v.length < 2) return 'Minimaal 2 tekens';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // E-mail (read-only)
                Text(
                  'E-mailadres',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Je e-mailadres kun je momenteel niet zelf wijzigen.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                // Opslaan
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Opslaan',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MIJN BEOORDELINGEN — alle reviews die over jou gaan, in één scherm
// Twee secties: ontvangen als boeker (uit booker_reviews) en als eigenaar
// (uit reviews op palen die je bezit). Markeert ongelezen reviews als gezien
// zodra het scherm opent.
// ============================================================================
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({Key? key}) : super(key: key);

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  bool _loading = true;
  // Reviews die door boekers over mijn palen / mij als eigenaar zijn geschreven
  List<Review> _ownerReviews = [];
  // Naast elke review: de naam van de paal (om context te tonen)
  Map<String, String> _chargerNamesById = {};
  // Booker reviews die door eigenaren over mij zijn geschreven
  List<BookerReview> _bookerReviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // 1) Reviews op mijn palen (ik ben eigenaar). We voegen meteen een join
      //    op chargers toe om de paal-naam te kunnen tonen.
      final ownerRows = await supabase
          .from('reviews')
          .select('*, chargers(name)')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);
      final ownerList = <Review>[];
      final names = <String, String>{};
      for (final raw in ownerRows as List) {
        final m = raw as Map<String, dynamic>;
        ownerList.add(Review.fromMap(m));
        final ch = m['chargers'];
        if (ch is Map<String, dynamic>) {
          final n = ch['name'] as String?;
          if (n != null) names[m['charger_id'] as String] = n;
        }
      }

      // 2) Booker reviews waar ik de boeker ben.
      final bookerRows = await supabase
          .from('booker_reviews')
          .select()
          .eq('booker_id', userId)
          .order('created_at', ascending: false);
      final bookerList = (bookerRows as List)
          .map((r) => BookerReview.fromMap(r as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _ownerReviews = ownerList;
        _chargerNamesById = names;
        _bookerReviews = bookerList;
        _loading = false;
      });

      // 3) Markeer alle ongelezen reviews als gezien — fire-and-forget,
      //    een fout hier mag het scherm niet blokkeren.
      _markAsSeen(userId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon beoordelingen niet laden: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markAsSeen(String userId) async {
    try {
      await supabase
          .from('reviews')
          .update({'seen_by_recipient': true})
          .eq('owner_id', userId)
          .eq('seen_by_recipient', false);
    } catch (_) {/* niet fataal */}
    try {
      await supabase
          .from('booker_reviews')
          .update({'seen_by_recipient': true})
          .eq('booker_id', userId)
          .eq('seen_by_recipient', false);
    } catch (_) {/* niet fataal */}
  }

  // Gemiddelde van een lijst getallen, of null bij lege lijst
  double? _avg(List<num> values) {
    if (values.isEmpty) return null;
    final sum = values.fold<num>(0, (a, b) => a + b);
    return sum / values.length;
  }

  Widget _starsRow(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final n = i + 1;
        IconData icon;
        if (rating >= n) {
          icon = Icons.star_rounded;
        } else if (rating >= n - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: const Color(0xFFFFC107));
      }),
    );
  }

  String _formatDate(DateTime dt) {
    final month = _monthNames[dt.month];
    return '${dt.day} $month ${dt.year}';
  }

  Widget _avgHeader({
    required String title,
    required int count,
    double? avgPrimary,
    String? primaryLabel,
    double? avgSecondary,
    String? secondaryLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 8),
          if (count == 0)
            Text(
              'Nog geen beoordelingen',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (avgPrimary != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _starsRow(avgPrimary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${avgPrimary.toStringAsFixed(1)} ${primaryLabel ?? ''}'
                            .trim(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                if (avgSecondary != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _starsRow(avgSecondary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${avgSecondary.toStringAsFixed(1)} ${secondaryLabel ?? ''}'
                            .trim(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                Text(
                  '$count beoordelingen',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _ownerReviewTile(Review r) {
    final reviewer = (r.reviewerName?.trim().isNotEmpty ?? false)
        ? r.reviewerName!
        : 'Anoniem';
    final chargerName = _chargerNamesById[r.chargerId] ?? 'Laadpaal';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewer,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Over $chargerName · ${_formatDate(r.createdAt)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Paal',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _starsRow(r.ratingCharger.toDouble()),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'Eigenaar',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _starsRow(r.ratingOwner.toDouble()),
            ],
          ),
          if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.comment!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          if (r.ownerReply != null && r.ownerReply!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jouw reactie',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.ownerReply!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bookerReviewTile(BookerReview r) {
    final reviewer = (r.reviewerName?.trim().isNotEmpty ?? false)
        ? r.reviewerName!
        : 'Eigenaar';
    final hasReply = r.bookerReply != null && r.bookerReply!.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewer,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(r.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _starsRow(r.rating.toDouble(), size: 18),
            ],
          ),
          if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.comment!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          // Reactie van de boeker (als die er is) of een knop om te reageren
          if (hasReply) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Jouw reactie',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _replyToBookerReview(r),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Bewerk',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.bookerReply!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _replyToBookerReview(r),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text('Reageer'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
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
    );
  }

  // Boeker plaatst of bewerkt een reactie op een booker_review die over hem gaat
  Future<void> _replyToBookerReview(BookerReview r) async {
    final controller = TextEditingController(text: r.bookerReply ?? '');
    final isEditing =
        r.bookerReply != null && r.bookerReply!.trim().isNotEmpty;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEditing ? 'Bewerk reactie' : 'Reageer op beoordeling'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Bedankt voor de beoordeling!',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, controller.text.trim());
            },
            child: Text(isEditing ? 'Opslaan' : 'Plaatsen'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;

    try {
      await supabase.from('booker_reviews').update({
        'booker_reply': text,
        'booker_replied_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Reactie bijgewerkt' : 'Reactie geplaatst'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon reactie niet plaatsen: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                Icons.star_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nog geen beoordelingen',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Zodra iemand jou of een van je palen beoordeelt, verschijnt dat hier.',
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

  @override
  Widget build(BuildContext context) {
    final ownerCount = _ownerReviews.length;
    final bookerCount = _bookerReviews.length;
    final avgCharger = _avg(
      _ownerReviews.map<num>((r) => r.ratingCharger).toList(),
    );
    final avgOwner = _avg(
      _ownerReviews.map<num>((r) => r.ratingOwner).toList(),
    );
    final avgBooker = _avg(
      _bookerReviews.map<num>((r) => r.rating).toList(),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mijn beoordelingen'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : (ownerCount == 0 && bookerCount == 0)
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      // ─── Sectie 1: ontvangen als boeker ──────────────
                      _avgHeader(
                        title: 'ALS BOEKER ONTVANGEN',
                        count: bookerCount,
                        avgPrimary: avgBooker,
                      ),
                      ..._bookerReviews.map(_bookerReviewTile),
                      const SizedBox(height: 16),
                      // ─── Sectie 2: ontvangen als eigenaar ────────────
                      _avgHeader(
                        title: 'ALS EIGENAAR ONTVANGEN',
                        count: ownerCount,
                        avgPrimary: avgCharger,
                        primaryLabel: 'paal',
                        avgSecondary: avgOwner,
                        secondaryLabel: 'eigenaar',
                      ),
                      ..._ownerReviews.map(_ownerReviewTile),
                    ],
                  ),
                ),
    );
  }
}

// ============================================================================
// REVIEW SCHRIJVEN — sterren voor paal + eigenaar, optioneel commentaar
// ============================================================================
class WriteReviewScreen extends StatefulWidget {
  final Booking booking;
  const WriteReviewScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int _ratingCharger = 0;
  int _ratingOwner = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ratingCharger == 0 || _ratingOwner == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geef voor zowel de paal als de eigenaar een aantal sterren.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final charger = widget.booking.charger;
    final ownerId = charger?.ownerId;
    if (charger == null || ownerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kan paalgegevens niet vinden — probeer opnieuw.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = supabase.auth.currentUser;
      final userId = user?.id;
      final commentText = _commentController.text.trim();
      // Snapshotten van de naam, zodat een latere naamwijziging
      // oude reviews niet verandert.
      final reviewerName =
          (user?.userMetadata?['full_name'] as String?)?.trim();
      await supabase.from('reviews').insert({
        'booking_id': widget.booking.id,
        'charger_id': widget.booking.chargerId,
        'reviewer_id': userId,
        'owner_id': ownerId,
        'rating_charger': _ratingCharger,
        'rating_owner': _ratingOwner,
        if (commentText.isNotEmpty) 'comment': commentText,
        if (reviewerName != null && reviewerName.isNotEmpty)
          'reviewer_name': reviewerName,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bedankt voor je review!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      // Foutmelding korter maken — DB-errors zijn technisch
      var msg = e.toString();
      if (msg.contains('duplicate') || msg.contains('unique')) {
        msg = 'Je hebt deze boeking al beoordeeld.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Een rij van 5 tikbare sterren voor één rating-categorie.
  Widget _starRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final n = i + 1;
            final filled = value >= n;
            return GestureDetector(
              onTap: () => onChanged(n),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: filled
                      ? const Color(0xFFFFC107)
                      : AppColors.textSecondary,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final charger = widget.booking.charger;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Schrijf review'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Charger-card bovenaan ter herinnering welke paal het is
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.ev_station_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            charger?.name ?? 'Laadpaal',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (charger != null)
                            Text(
                              charger.address,
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
              ),
              const SizedBox(height: 28),
              _starRow(
                label: 'De laadpaal',
                value: _ratingCharger,
                onChanged: (n) => setState(() => _ratingCharger = n),
              ),
              const SizedBox(height: 24),
              _starRow(
                label: 'De eigenaar',
                value: _ratingOwner,
                onChanged: (n) => setState(() => _ratingOwner = n),
              ),
              const SizedBox(height: 28),
              Text(
                'Commentaar (optioneel)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Hoe ging het laden? Wat zou je je buur willen meegeven?',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Plaats review',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WRITE BOOKER REVIEW — eigenaar beoordeelt de boeker na een afgelopen sessie
// ============================================================================
class WriteBookerReviewScreen extends StatefulWidget {
  final Booking booking;
  const WriteBookerReviewScreen({Key? key, required this.booking})
      : super(key: key);

  @override
  State<WriteBookerReviewScreen> createState() =>
      _WriteBookerReviewScreenState();
}

class _WriteBookerReviewScreenState extends State<WriteBookerReviewScreen> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geef de boeker een aantal sterren.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final charger = widget.booking.charger;
    final bookerId = widget.booking.userId;
    if (charger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kan paalgegevens niet vinden — probeer opnieuw.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = supabase.auth.currentUser;
      final userId = user?.id;
      final commentText = _commentController.text.trim();
      // Snapshot van de naam zodat een latere naamwijziging
      // oude reviews niet verandert.
      final reviewerName =
          (user?.userMetadata?['full_name'] as String?)?.trim();
      await supabase.from('booker_reviews').insert({
        'booking_id': widget.booking.id,
        'charger_id': widget.booking.chargerId,
        'reviewer_id': userId,
        'booker_id': bookerId,
        'rating': _rating,
        if (commentText.isNotEmpty) 'comment': commentText,
        if (reviewerName != null && reviewerName.isNotEmpty)
          'reviewer_name': reviewerName,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bedankt voor je beoordeling!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString();
      if (msg.contains('duplicate') || msg.contains('unique')) {
        msg = 'Je hebt deze boeking al beoordeeld.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _starRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final n = i + 1;
            final filled = value >= n;
            return GestureDetector(
              onTap: () => onChanged(n),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: filled
                      ? const Color(0xFFFFC107)
                      : AppColors.textSecondary,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookerName = widget.booking.userName ?? 'Boeker';
    final charger = widget.booking.charger;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Beoordeel boeker'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booker-card bovenaan ter herinnering wie het was
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (charger != null)
                            Text(
                              'Laadde bij ${charger.name}',
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
              ),
              const SizedBox(height: 28),
              _starRow(
                label: 'Hoe was deze boeker?',
                value: _rating,
                onChanged: (n) => setState(() => _rating = n),
              ),
              const SizedBox(height: 28),
              Text(
                'Commentaar (optioneel)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText:
                      'Was de boeker netjes, op tijd, communicatief?',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Plaats beoordeling',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
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
  // IDs van boekingen die deze eigenaar al heeft beoordeeld —
  // gebruikt om "Beoordeel boeker" vs. "Beoordeeld" badge te bepalen.
  Set<String> _reviewedByMeBookingIds = {};

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

      // Haal de booking_ids op die ik (als eigenaar) al heb beoordeeld.
      final reviewedRows = await supabase
          .from('booker_reviews')
          .select('booking_id')
          .eq('reviewer_id', userId);
      final reviewedIds = (reviewedRows as List)
          .map((r) => (r as Map<String, dynamic>)['booking_id'] as String)
          .toSet();

      if (!mounted) return;
      setState(() {
        _bookings = list;
        _reviewedByMeBookingIds = reviewedIds;
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
    // Pending = wacht op mijn goedkeuring. Komt bovenaan, ook als de starttijd
    // al verlopen is (dan kan ik 'm alsnog weigeren).
    final pending =
        _bookings.where((b) => b.status == 'pending').toList();
    final upcoming = _bookings
        .where((b) =>
            b.status == 'confirmed' && b.endTime.isAfter(now))
        .toList();
    final past = _bookings
        .where((b) =>
            b.status != 'pending' &&
            (!b.endTime.isAfter(now) ||
                b.status == 'cancelled' ||
                b.status == 'rejected'))
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
                      if (pending.isNotEmpty) ...[
                        _sectionHeader('Wacht op jou', pending.length),
                        const SizedBox(height: 8),
                        ...pending.map(_bookingCard),
                        const SizedBox(height: 24),
                      ],
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
    final isRejected = b.status == 'rejected';
    final isPending = b.status == 'pending';
    final isPast = !b.endTime.isAfter(DateTime.now());
    final chargerName = b.charger?.name ?? 'Laadpaal';
    final bookerName = b.userName ?? 'Onbekende gebruiker';

    Color pillColor;
    String pillText;
    if (isCancelled) {
      pillColor = AppColors.danger;
      pillText = 'Geannuleerd';
    } else if (isRejected) {
      pillColor = AppColors.danger;
      pillText = 'Geweigerd';
    } else if (isPending) {
      pillColor = const Color(0xFFE0A030);
      pillText = 'In afwachting';
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
            // Bericht aan boeker — altijd zichtbaar
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        otherUserId: b.userId,
                        otherUserName: bookerName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Bericht'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Pending → Accepteer + Weiger knoppen
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _decideOnBooking(b, accept: false),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Weiger'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _decideOnBooking(b, accept: true),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Accepteer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Afgelopen + bevestigd (geen pending/cancelled/rejected) →
            // eigenaar kan boeker beoordelen
            if (isPast && b.status == 'confirmed') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _reviewedByMeBookingIds.contains(b.id)
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Beoordeeld',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  WriteBookerReviewScreen(booking: b),
                            ),
                          );
                          if (result == true) _load();
                        },
                        icon: const Icon(Icons.star_rounded, size: 16),
                        label: const Text('Beoordeel boeker'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
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

  // Opent een dialog met booker review-samenvatting + bevestigingsknop.
  // accept=true -> status wordt 'confirmed', anders 'rejected'.
  Future<void> _decideOnBooking(Booking b, {required bool accept}) async {
    // 1) Haal eerdere booker_reviews over deze gebruiker op (door alle
    //    eigenaren samen). RLS staat dit toe (public select op
    //    booker_reviews).
    List<BookerReview> previousReviews = [];
    try {
      final rows = await supabase
          .from('booker_reviews')
          .select()
          .eq('booker_id', b.userId)
          .order('created_at', ascending: false)
          .limit(20);
      previousReviews = (rows as List)
          .map((r) => BookerReview.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {/* niet fataal — toon dialog zonder reviews */}

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _AcceptRejectDialog(
        booking: b,
        previousReviews: previousReviews,
        accept: accept,
      ),
    );
    if (confirmed != true) return;

    // 2) Status updaten in DB
    try {
      await supabase
          .from('bookings')
          .update({'status': accept ? 'confirmed' : 'rejected'})
          .eq('id', b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Boeking geaccepteerd. ${b.userName ?? "De boeker"} krijgt bericht.'
              : 'Boeking geweigerd. ${b.userName ?? "De boeker"} krijgt bericht.'),
          backgroundColor:
              accept ? AppColors.primary : AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
      // 3) Roep send-email edge function aan om de boeker per e-mail te
      //    informeren. Fire-and-forget — als het faalt blokkeert dat de UI niet.
      _sendDecisionEmail(b, accept);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon status niet bijwerken: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ----------------------------------------------------------------
  // Stuur de boeker een e-mail bij een accept/reject beslissing.
  // Roept de bestaande Supabase edge function `send-email` aan, die
  // Resend gebruikt en {to, subject, html} verwacht.
  // Fire-and-forget — faalt stilletjes als er geen email-adres is.
  // ----------------------------------------------------------------
  Future<void> _sendDecisionEmail(Booking b, bool accept) async {
    final to = b.userEmail;
    if (to == null || to.isEmpty) return; // oudere boekingen zonder email

    final chargerName = b.charger?.name ?? 'de laadpaal';
    final chargerAddress = b.charger?.address ?? '';
    final boekerNaam = b.userName?.split(' ').first ?? 'daar';

    // Datum/tijd in NL formaat (gebruik bestaande helpers, geen intl)
    final datum = _formatDateHeader(b.startTime);
    String two(int n) => n.toString().padLeft(2, '0');
    final start = '${two(b.startTime.hour)}:${two(b.startTime.minute)}';
    final eind = '${two(b.endTime.hour)}:${two(b.endTime.minute)}';

    final subject = accept
        ? 'Je boeking bij $chargerName is bevestigd '
        : 'Je aanvraag voor $chargerName is helaas afgewezen';

    final statusBlok = accept
        ? '''
<div style="background:#E8F5E9;border-left:4px solid #2E7D32;padding:16px 20px;margin:24px 0;border-radius:6px;">
  <p style="margin:0;color:#1B5E20;font-size:16px;font-weight:600;">Bevestigd</p>
  <p style="margin:4px 0 0;color:#1B5E20;font-size:14px;">De eigenaar heeft je aanvraag goedgekeurd. Je kunt op het afgesproken moment komen laden.</p>
</div>'''
        : '''
<div style="background:#FFEBEE;border-left:4px solid #C62828;padding:16px 20px;margin:24px 0;border-radius:6px;">
  <p style="margin:0;color:#B71C1C;font-size:16px;font-weight:600;">Afgewezen</p>
  <p style="margin:4px 0 0;color:#B71C1C;font-size:14px;">Helaas heeft de eigenaar je aanvraag voor dit tijdslot afgewezen. Probeer eens een ander moment of een andere paal in de buurt.</p>
</div>''';

    final adresRegel = chargerAddress.isEmpty
        ? ''
        : '<tr><td style="padding:6px 0;color:#666;">Adres</td><td style="padding:6px 0;font-weight:500;">$chargerAddress</td></tr>';

    final html = '''
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#F5F5F5;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;">
  <div style="max-width:600px;margin:0 auto;background:#fff;padding:32px 24px;">
    <h1 style="margin:0 0 8px;color:#1976D2;font-size:24px;">Pluggo</h1>
    <p style="margin:0 0 24px;color:#666;font-size:14px;">Buren laden bij buren</p>

    <h2 style="margin:0 0 16px;font-size:20px;color:#222;">Hoi $boekerNaam,</h2>

    $statusBlok

    <table style="width:100%;border-collapse:collapse;font-size:14px;color:#222;margin:0 0 24px;">
      <tr><td style="padding:6px 0;color:#666;width:90px;">Paal</td><td style="padding:6px 0;font-weight:500;">$chargerName</td></tr>
      $adresRegel
      <tr><td style="padding:6px 0;color:#666;">Datum</td><td style="padding:6px 0;font-weight:500;">$datum</td></tr>
      <tr><td style="padding:6px 0;color:#666;">Tijd</td><td style="padding:6px 0;font-weight:500;">$start – $eind</td></tr>
    </table>

    <p style="margin:0 0 8px;color:#444;font-size:14px;">Open de Pluggo-app om je boeking te bekijken.</p>
    <hr style="border:none;border-top:1px solid #eee;margin:32px 0 16px;">
    <p style="margin:0;color:#999;font-size:12px;">Je ontvangt deze mail omdat je een boeking hebt aangevraagd via Pluggo.</p>
  </div>
</body>
</html>
''';

    try {
      await supabase.functions.invoke(
        'send-email',
        body: {
          'to': to,
          'subject': subject,
          'html': html,
        },
      );
    } catch (_) {
      // E-mail is best-effort; in-app status is leidend.
    }
  }
}

// ============================================================================
// ACCEPT/REJECT BEVESTIGINGS-DIALOG met booker review summary
// ============================================================================
class _AcceptRejectDialog extends StatelessWidget {
  final Booking booking;
  final List<BookerReview> previousReviews;
  final bool accept;

  const _AcceptRejectDialog({
    required this.booking,
    required this.previousReviews,
    required this.accept,
  });

  double? get _avgRating {
    if (previousReviews.isEmpty) return null;
    final sum =
        previousReviews.fold<int>(0, (a, b) => a + b.rating);
    return sum / previousReviews.length;
  }

  Widget _stars(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final n = i + 1;
        IconData icon;
        if (rating >= n) {
          icon = Icons.star_rounded;
        } else if (rating >= n - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: const Color(0xFFFFC107));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookerName = booking.userName ?? 'Deze boeker';
    final avg = _avgRating;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                accept
                    ? 'Boeking accepteren?'
                    : 'Boeking weigeren?',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                accept
                    ? '$bookerName krijgt direct bericht dat de aanvraag is geaccepteerd.'
                    : '$bookerName krijgt direct bericht dat de aanvraag is geweigerd.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Text(
                'EERDERE BEOORDELINGEN VAN DEZE BOEKER',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              if (previousReviews.isEmpty)
                Text(
                  'Nog geen eerdere beoordelingen — dit is hun eerste boeking via Pluggo (of niemand heeft ze nog beoordeeld).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                )
              else ...[
                Row(
                  children: [
                    _stars(avg!, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${avg.toStringAsFixed(1)} · ${previousReviews.length} review${previousReviews.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: previousReviews.length,
                    itemBuilder: (ctx, i) {
                      final r = previousReviews[i];
                      final reviewer =
                          (r.reviewerName?.trim().isNotEmpty ?? false)
                              ? r.reviewerName!
                              : 'Eigenaar';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _stars(r.rating.toDouble(), size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      reviewer,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (r.comment != null &&
                                  r.comment!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  r.comment!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Annuleer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            accept ? AppColors.primary : AppColors.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        accept ? 'Accepteer' : 'Weiger',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CHAT — gesprekken-inbox + chatscherm tussen 2 gebruikers (per partner)
// ============================================================================

// Helper: zoek of maak een conversation tussen huidige user en otherUserId.
// Sorteert ids alfabetisch zodat (A,B) en (B,A) hetzelfde gesprek zijn.
Future<Conversation?> _findOrCreateConversation(
  String otherUserId, {
  String? otherUserName,
}) async {
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return null;
  final ids = [myId, otherUserId]..sort();
  final userA = ids.first;
  final userB = ids.last;
  try {
    // Eerst proberen op te halen
    final existing = await supabase
        .from('conversations')
        .select()
        .eq('user_a_id', userA)
        .eq('user_b_id', userB)
        .maybeSingle();
    if (existing != null) {
      return Conversation.fromMap(existing as Map<String, dynamic>)
          .copyWith(otherUserName: otherUserName);
    }
    // Niet bestaand — aanmaken
    final inserted = await supabase
        .from('conversations')
        .insert({'user_a_id': userA, 'user_b_id': userB})
        .select()
        .single();
    return Conversation.fromMap(inserted as Map<String, dynamic>)
        .copyWith(otherUserName: otherUserName);
  } catch (_) {
    return null;
  }
}

// Inbox: lijst van alle gesprekken van de huidige gebruiker
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  bool _loading = true;
  List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final rows = await supabase
          .from('conversations')
          .select()
          .or('user_a_id.eq.$myId,user_b_id.eq.$myId')
          .order('last_message_at', ascending: false);

      // Bouw lijst, voeg naam van andere partij toe (uit bookings.user_name
      // of charger.owner — voor MVP halen we 'm uit recente boekingen).
      final list = <Conversation>[];
      for (final r in rows as List) {
        list.add(Conversation.fromMap(r as Map<String, dynamic>));
      }

      // Naam-resolutie: kijk in bookings welke naam bij elk other-user-id hoort
      final otherIds = list.map((c) => c.otherUserId(myId)).toSet().toList();
      final namesById = <String, String>{};
      if (otherIds.isNotEmpty) {
        try {
          // Andere partij als boeker
          final asBooker = await supabase
              .from('bookings')
              .select('user_id, user_name')
              .inFilter('user_id', otherIds);
          for (final b in asBooker as List) {
            final m = b as Map<String, dynamic>;
            final uid = m['user_id'] as String?;
            final nm = m['user_name'] as String?;
            if (uid != null && nm != null) namesById[uid] = nm;
          }
        } catch (_) {/* niet fataal */}
      }

      // Ongelezen-aantal per conversation: simpel via count-query per stuk
      final unreadById = <String, int>{};
      for (final c in list) {
        try {
          final unreadRows = await supabase
              .from('messages')
              .select('id')
              .eq('conversation_id', c.id)
              .neq('sender_id', myId)
              .filter('seen_at', 'is', null);
          unreadById[c.id] = (unreadRows as List).length;
        } catch (_) {
          unreadById[c.id] = 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _conversations = list
            .map((c) => c.copyWith(
                  otherUserName: namesById[c.otherUserId(myId)],
                  unreadCount: unreadById[c.id] ?? 0,
                ))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _previewTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'nu';
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inDays < 1) return '${diff.inHours} u';
    if (diff.inDays < 7) return '${diff.inDays} d';
    return '${dt.day} ${_monthNames[dt.month].substring(0, 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Berichten',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 56, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'Nog geen berichten',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stuur een bericht via de detailpagina van een paal of vanuit je boekingen.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (ctx, i) {
                      final c = _conversations[i];
                      final name = c.otherUserName ?? 'Gebruiker';
                      final preview = c.lastMessagePreview ?? '';
                      final unread = c.unreadCount;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primarySoft,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontWeight:
                                unread > 0 ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          preview.isEmpty ? 'Nieuw gesprek' : preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: unread > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _previewTime(c.lastMessageAt),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unread',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () async {
                          if (myId == null) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                otherUserId: c.otherUserId(myId),
                                otherUserName: name,
                                conversation: c,
                              ),
                            ),
                          );
                          _load(); // herlaad bij terugkeer
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

// Het gesprek zelf: lijst van messages + input onderaan
class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String? otherUserName;
  // Optioneel: meegeven als je 'm al hebt, anders zoeken/aanmaken
  final Conversation? conversation;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    this.otherUserName,
    this.conversation,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Conversation? _conversation;
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    Conversation? conv = widget.conversation;
    conv ??= await _findOrCreateConversation(widget.otherUserId,
        otherUserName: widget.otherUserName);
    if (!mounted) return;
    if (conv == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _conversation = conv);
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    final conv = _conversation;
    if (conv == null) return;
    try {
      final rows = await supabase
          .from('messages')
          .select()
          .eq('conversation_id', conv.id)
          .order('created_at', ascending: true);
      final list = (rows as List)
          .map((r) => ChatMessage.fromMap(r as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _scrollToBottom();
      _markAsSeen();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _markAsSeen() async {
    final conv = _conversation;
    final myId = supabase.auth.currentUser?.id;
    if (conv == null || myId == null) return;
    try {
      await supabase
          .from('messages')
          .update({'seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('conversation_id', conv.id)
          .neq('sender_id', myId)
          .filter('seen_at', 'is', null);
    } catch (_) {/* niet fataal */}
  }

  Future<void> _sendMessage() async {
    final conv = _conversation;
    final body = _inputController.text.trim();
    if (conv == null || body.isEmpty) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final senderName = user.userMetadata != null &&
            user.userMetadata!['full_name'] is String
        ? user.userMetadata!['full_name'] as String
        : (user.email ?? 'Onbekend');

    setState(() => _sending = true);
    _inputController.clear();

    try {
      // Optimistic UI: voeg bericht toe vóór de server-call
      final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
      final temp = ChatMessage(
        id: tempId,
        conversationId: conv.id,
        senderId: user.id,
        senderName: senderName,
        body: body,
        createdAt: DateTime.now(),
      );
      setState(() => _messages = [..._messages, temp]);
      _scrollToBottom();

      // Insert message
      await supabase.from('messages').insert({
        'conversation_id': conv.id,
        'sender_id': user.id,
        'sender_name': senderName,
        'body': body,
      });

      // Update conversation preview
      await supabase.from('conversations').update({
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
        'last_message_preview':
            body.length > 100 ? '${body.substring(0, 100)}…' : body,
        'last_message_sender_id': user.id,
      }).eq('id', conv.id);

      // Email-notificatie (gebundeld: max 1 per uur per gesprek)
      _maybeSendChatEmail(conv, senderName, body);

      // Herlaad de echte messages (vervangt temp door echte row)
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bericht niet verstuurd: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Stuurt mail naar de andere partij, max 1x per uur per conversation.
  Future<void> _maybeSendChatEmail(
      Conversation conv, String senderName, String body) async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;
    final otherId = conv.otherUserId(myId);

    // Check throttle: laatste mail moet > 1u geleden zijn (of null)
    final last = conv.lastEmailSentAt;
    if (last != null && DateTime.now().difference(last).inHours < 1) {
      return; // gebundeld
    }

    // Other user email opzoeken via bookings (heeft user_email) of chargers
    String? otherEmail;
    try {
      final asBooker = await supabase
          .from('bookings')
          .select('user_email')
          .eq('user_id', otherId)
          .not('user_email', 'is', null)
          .limit(1)
          .maybeSingle();
      if (asBooker != null) {
        otherEmail = (asBooker as Map<String, dynamic>)['user_email'] as String?;
      }
    } catch (_) {/* niet fataal */}
    if (otherEmail == null || otherEmail.isEmpty) {
      try {
        final asOwner = await supabase
            .from('chargers')
            .select('owner_email')
            .eq('owner_id', otherId)
            .not('owner_email', 'is', null)
            .limit(1)
            .maybeSingle();
        if (asOwner != null) {
          otherEmail =
              (asOwner as Map<String, dynamic>)['owner_email'] as String?;
        }
      } catch (_) {/* niet fataal */}
    }
    if (otherEmail == null || otherEmail.isEmpty) return;

    final preview =
        body.length > 200 ? '${body.substring(0, 200)}…' : body;
    final subject = 'Nieuw bericht van $senderName op Pluggo';
    final html = '''
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#F5F5F5;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;">
  <div style="max-width:600px;margin:0 auto;background:#fff;padding:32px 24px;">
    <h1 style="margin:0 0 8px;color:#00795A;font-size:24px;">Pluggo</h1>
    <p style="margin:0 0 24px;color:#666;font-size:14px;">Buren laden bij buren</p>
    <h2 style="margin:0 0 16px;font-size:20px;color:#222;">Nieuw bericht van $senderName</h2>
    <div style="background:#E6F7F1;border-left:4px solid #00A87E;padding:16px 20px;margin:0 0 24px;border-radius:6px;">
      <p style="margin:0;color:#222;font-size:14px;font-style:italic;">"$preview"</p>
    </div>
    <p style="margin:0 0 8px;color:#444;font-size:14px;">Open de Pluggo-app om te reageren. Vervolgberichten in dit gesprek krijgen pas weer een mail na een uur, zodat je inbox rustig blijft.</p>
    <hr style="border:none;border-top:1px solid #eee;margin:32px 0 16px;">
    <p style="margin:0;color:#999;font-size:12px;">Je ontvangt deze mail omdat iemand je een bericht stuurde via Pluggo.</p>
  </div>
</body>
</html>
''';

    try {
      await supabase.functions.invoke('send-email', body: {
        'to': otherEmail,
        'subject': subject,
        'html': html,
      });
      // Throttle-timestamp updaten zodat volgende mail pas na 1u kan
      await supabase.from('conversations').update({
        'last_email_sent_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', conv.id);
    } catch (_) {/* best-effort */}
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;
    final name = widget.otherUserName ?? 'Gebruiker';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Nog geen berichten — stuur de eerste!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          final isMe = m.senderId == myId;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                boxShadow: softShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.body,
                                    style: GoogleFonts.inter(
                                      color: isMe
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatTime(m.createdAt),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: isMe
                                          ? Colors.white70
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Input
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewPadding.bottom + 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Schrijf een bericht…',
                      hintStyle: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending ? null : _sendMessage,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    Colors.white),
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              const SizedBox(height: 24),
              // Vóór 1 juni: launch-banner zodat nieuwe downloaders zien
              // dat ze een seintje krijgen als ze nu vast een account
              // aanmaken. Verdwijnt automatisch zodra de launch live is.
              if (!bookingsAreLive) ...[
                const LaunchCountdownBanner(showAccountHint: true),
                const SizedBox(height: 24),
              ],
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
              const SizedBox(height: 20),
              // Pre-launch banner — gebruikers die nu vast registreren
              // krijgen een seintje zodra boekingen open gaan op 1 juni.
              if (!bookingsAreLive) ...[
                const LaunchCountdownBanner(showAccountHint: true),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 12),
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
  // Optioneel: gemiddelde charger-rating (1-5) en aantal reviews.
  // null = (nog) niet geladen of geen reviews → niets tonen.
  final double? avgRating;
  final int reviewCount;

  const _ChargerCard({
    required this.charger,
    required this.onTap,
    this.isOwner = false,
    this.onChanged,
    this.avgRating,
    this.reviewCount = 0,
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
                      // Sterren + aantal reviews — alleen tonen als er
                      // tenminste 1 review is.
                      if (widget.avgRating != null && widget.reviewCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF9A825),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.avgRating!.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${widget.reviewCount})',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
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
