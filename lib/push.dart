// ============================================================================
// Pluggo — Push notifications via Firebase Cloud Messaging (FCM)
//
// Verantwoordelijkheden:
//   1. Firebase initialiseren (via firebase_core).
//   2. iOS-permissie regelen op het juiste moment ("bij eerste echte event"
//      i.p.v. direct bij app-start, zodat users context hebben).
//   3. FCM device token ophalen + registreren in onze user_devices tabel via
//      de SQL-functie register_device_token. Bij token-rotatie (Firebase kan
//      tokens periodiek vernieuwen) wordt de nieuwe ook opgeslagen.
//   4. Foreground messages: tonen als SnackBar via een global ScaffoldMessenger.
//   5. Background/terminated taps: payload onthouden zodat HomeScreen er na
//      open op kan reageren (bv. naar inkomende boekingen springen).
//
// Belangrijk: dit bestand bevat GEEN UI-screens. Het wordt aangeroepen vanuit
// main.dart en strategische plekken in de app. Houd het zo dunmogelijk.
// ============================================================================

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level handler voor messages die binnenkomen terwijl de app volledig is
/// gesloten (terminated). Moet een top-level of static functie zijn (Firebase
/// vereiste). We doen hier bewust NIETS visueel — iOS toont de notificatie
/// zelf via APNs zodra `notification` in de payload zit.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Bewust leeg. Logging hier is niet bruikbaar zonder Firebase-init,
  // en die is in deze isolate al automatisch opgezet door het framework.
}

/// Tri-state resultaat voor de "Notificaties aanzetten"-knop in het
/// profielmenu. Zie [PluggoPush.requestForUserActionButton] voor uitleg.
enum NotificationActionOutcome {
  alreadyEnabled,
  justEnabled,
  denied,
}

class PluggoPush {
  PluggoPush._();
  static final PluggoPush instance = PluggoPush._();

  /// Global key zodat we vanuit deze service een SnackBar kunnen tonen
  /// zonder een BuildContext mee te slepen. Wordt aan MaterialApp gehangen.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _initialized = false;
  bool _registered = false;

  /// Payload van een notificatie die de app heeft *geopend* terwijl deze
  /// terminated/background was. HomeScreen kan dit checken na build().
  RemoteMessage? pendingTapMessage;

  /// Roep dit één keer aan in main(), vóór runApp.
  /// Zet alleen Firebase op + de background handler. GEEN permissie-vraag.
  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      _initialized = true;
    } catch (e) {
      // Firebase mag nooit de app blokkeren — als de plist mist of er iets
      // misgaat, log alleen en draai door.
      if (kDebugMode) {
        debugPrint('[PluggoPush] Firebase init mislukt: $e');
      }
    }
  }

  /// Roep dit aan na succesvolle login. Doet NIETS als permissie nog niet
  /// is verleend (geen pop-up). Wel: als user al ja heeft gezegd in het
  /// verleden, halen we het token op en zetten/refreshen we de registratie.
  Future<void> maybeRegisterAfterLogin() async {
    if (!_initialized) return;
    if (Supabase.instance.client.auth.currentUser == null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      // getNotificationSettings() opent geen dialoog, alleen lezen.
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _registerToken();
        _wireForegroundHandlers();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PluggoPush] maybeRegister: $e');
    }
  }

  /// Roep dit aan op "eerste echte event" momenten (eerste boeking, eerste
  /// paal toevoegen, of een expliciete knop in instellingen). Toont de
  /// systeemdialoog als de user nog niet is gevraagd. Returnt true als
  /// permissie verleend werd (of al stond).
  Future<bool> requestPermissionAndRegister() async {
    if (!_initialized) return false;
    if (Supabase.instance.client.auth.currentUser == null) return false;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        await _registerToken();
        _wireForegroundHandlers();
      }
      return granted;
    } catch (e) {
      if (kDebugMode) debugPrint('[PluggoPush] requestPermission: $e');
      return false;
    }
  }

  /// Stuurt een push notification naar de opgegeven user_id via de
  /// Supabase edge function `send-push`. Fire-and-forget: faalt
  /// stilletjes en logt alleen in debug. We willen NOOIT dat een
  /// notification-fout een user-flow blokkeert.
  ///
  /// `data` mag arbitraire payload zijn — moet stringwaarden bevatten
  /// (FCM-vereiste; de edge function converteert defensief, maar wij
  /// houden het hier al netjes).
  static Future<void> sendTo({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-push',
        body: {
          'user_id': userId,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PluggoPush] sendTo($userId) failed: $e');
    }
  }

  /// Voor de "Notificaties"-knop in het profielmenu. Geeft een tri-state
  /// terug zodat de UI exact weet welke feedback te tonen:
  ///   • [NotificationActionOutcome.alreadyEnabled] — was al toegestaan
  ///     (snackbar "Meldingen staan al aan")
  ///   • [NotificationActionOutcome.justEnabled] — gebruiker zei net Ja op
  ///     de dialoog (snackbar "Meldingen aangezet")
  ///   • [NotificationActionOutcome.denied] — geweigerd (toon dialoog met
  ///     uitleg hoe het via OS-instellingen alsnog aan kan)
  ///
  /// Belangrijk: op iOS én Android 13+ kun je `requestPermission` na een
  /// "Niet toestaan" niet opnieuw triggeren — het OS geeft dan stil de
  /// laatste status terug zonder dialoog. Vandaar de fallback-dialoog
  /// in de UI laag voor de denied-case.
  Future<NotificationActionOutcome> requestForUserActionButton() async {
    if (!_initialized) return NotificationActionOutcome.denied;
    if (Supabase.instance.client.auth.currentUser == null) {
      return NotificationActionOutcome.denied;
    }
    try {
      final messaging = FirebaseMessaging.instance;

      // Eerst lezen — als al granted: alleen token-registratie herverifiëren
      // (kan eerder mislukt zijn) en klaar.
      final current = await messaging.getNotificationSettings();
      if (current.authorizationStatus == AuthorizationStatus.authorized ||
          current.authorizationStatus == AuthorizationStatus.provisional) {
        await _registerToken();
        _wireForegroundHandlers();
        return NotificationActionOutcome.alreadyEnabled;
      }

      // Niet (meer) granted — vraag opnieuw. Op systemen die geen tweede
      // dialoog tonen valt 'ie meteen terug op de huidige status.
      final result = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final granted = result.authorizationStatus ==
              AuthorizationStatus.authorized ||
          result.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        await _registerToken();
        _wireForegroundHandlers();
        return NotificationActionOutcome.justEnabled;
      }
      return NotificationActionOutcome.denied;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PluggoPush] requestForUserActionButton: $e');
      }
      return NotificationActionOutcome.denied;
    }
  }

  /// Verwijder de huidige device-token uit user_devices (logout).
  /// Voorkomt pushes naar de vorige eigenaar als iemand anders inlogt.
  Future<void> unregisterCurrentDevice() async {
    if (!_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null) return;
      final supabase = Supabase.instance.client;
      await supabase.from('user_devices').delete().eq('fcm_token', token);
      // En het token zelf weggooien zodat een nieuwe user een vers token krijgt.
      await messaging.deleteToken();
      _registered = false;
    } catch (e) {
      if (kDebugMode) debugPrint('[PluggoPush] unregister: $e');
    }
  }

  // --- Interne helpers -----------------------------------------------------

  Future<void> _registerToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Op iOS hebben we eerst een APNs token nodig vóór FCM een token kan
      // genereren. Even kort wachten/proberen zonder forever te blokkeren.
      String? apnsToken;
      for (int i = 0; i < 10; i++) {
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      await _persistToken(token);
      _registered = true;

      // Token rotation: Firebase kan tokens vernieuwen. Bij refresh opnieuw
      // opslaan. We hangen maar één keer aan deze stream.
      messaging.onTokenRefresh.listen(_persistToken);
    } catch (e) {
      if (kDebugMode) debugPrint('[PluggoPush] _registerToken: $e');
    }
  }

  Future<void> _persistToken(String token) async {
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'web';
      await Supabase.instance.client.rpc(
        'register_device_token',
        params: {
          'p_token': token,
          'p_platform': platform,
          'p_app_version': null,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PluggoPush] _persistToken: $e');
    }
  }

  bool _foregroundWired = false;
  void _wireForegroundHandlers() {
    if (_foregroundWired) return;
    _foregroundWired = true;

    // Foreground: app is open en op scherm. iOS toont default GEEN banner —
    // wij tonen een SnackBar zodat de user iets ziet.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      final title = notification.title ?? 'Nieuwe melding';
      final body = notification.body ?? '';
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body),
              ],
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });

    // Tap op een banner terwijl app in background was → app komt naar voren.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      pendingTapMessage = message;
      // HomeScreen of een listener kan dit oppikken bij build/resume.
    });

    // Cold start: was de app open vanuit een notification tap?
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) pendingTapMessage = message;
    });
  }
}
