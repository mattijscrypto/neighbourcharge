// ============================================================================
// Pluggo — Push notification actions (task #292)
//
// Vangt tap-events op van iOS UNNotificationAction buttons (Verleng 15 / 30
// / 60 min) via de MethodChannel `pluggo/push_actions`. AppDelegate.swift
// stuurt daar een event met { action_id, booking_id, ... } naartoe wanneer
// de user een lockscreen-knop tapt.
//
// Wat we hier doen:
//   1. init() — MethodChannel setUp + "ready" ping naar native zodat pending
//      events geflusht worden (cold-start via action-tap).
//   2. onAction — parseert action_id ("EXTEND_15" / "EXTEND_30" / "EXTEND_60"),
//      roept Supabase RPC public.extend_booking(booking_id, minutes) aan,
//      en toont een SnackBar met het resultaat.
//
// Wat we hier NIET doen:
//   - Deep-link routing (behoefte-bepaald, hier niet nodig).
//   - Android — Android krijgt pas rijke actions in fase 2 via
//     flutter_local_notifications (zie TODO in send-push/index.ts).
//
// Aangeroepen vanuit main.dart in main() na PluggoPush.instance.init().
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push.dart' show PluggoPush;

class PluggoPushActions {
  PluggoPushActions._();
  static final PluggoPushActions instance = PluggoPushActions._();

  static const MethodChannel _channel = MethodChannel('pluggo/push_actions');
  bool _initialized = false;

  /// Zet de channel-listener op en informeer native dat Dart klaar is.
  /// Idempotent — meerdere calls hebben geen effect.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_onNativeCall);

    try {
      // Native kant kan events hebben gebufferd tijdens cold start
      // (user tapte Verleng 30 op lockscreen terwijl app gesloten was).
      // "ready" ping triggert de flush.
      await _channel.invokeMethod('ready');
    } catch (e) {
      if (kDebugMode) debugPrint('[PushActions] ready ping failed: $e');
    }
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method != 'onAction') return null;

    final args = call.arguments;
    if (args is! Map) return null;
    // Cast defensively — MethodChannel geeft Map<Object?, Object?>.
    final data = args.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));

    final actionId = data['action_id'] ?? '';
    if (!actionId.startsWith('EXTEND_')) {
      if (kDebugMode) debugPrint('[PushActions] onbekende action: $actionId');
      return null;
    }
    final minutes = int.tryParse(actionId.substring('EXTEND_'.length));
    if (minutes == null || !(minutes == 15 || minutes == 30 || minutes == 60)) {
      if (kDebugMode) debugPrint('[PushActions] ongeldig minutes-getal: $actionId');
      return null;
    }
    final bookingId = data['booking_id'] ?? '';
    if (bookingId.isEmpty) {
      if (kDebugMode) debugPrint('[PushActions] geen booking_id in payload');
      return null;
    }

    await _handleExtend(bookingId: bookingId, minutes: minutes);
    return null;
  }

  Future<void> _handleExtend({
    required String bookingId,
    required int minutes,
  }) async {
    // Snackbar helper — gebruikt dezelfde messengerKey als PluggoPush.
    void showToast(String text) {
      PluggoPush.messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    try {
      final client = Supabase.instance.client;
      // Guard: als user tijdens de push is uitgelogd, is de RPC niet zinnig.
      if (client.auth.currentUser == null) {
        showToast('Log eerst in om je reservering te verlengen.');
        return;
      }

      final result = await client.rpc(
        'extend_booking',
        params: {
          'p_booking_id': bookingId,
          'p_extra_minutes': minutes,
        },
      );

      // extend_booking returnt jsonb — supabase_flutter geeft dat als Map terug.
      String status = 'unknown';
      if (result is Map) {
        status = result['status']?.toString() ?? 'unknown';
      }

      switch (status) {
        case 'ok':
          showToast('Reservering verlengd met $minutes minuten.');
          break;
        case 'conflict':
          showToast(
            'Er staat een andere boeking direct achter jou — $minutes minuten '
            'past niet meer. Probeer een kortere verlenging.',
          );
          break;
        case 'not_confirmed':
          showToast('Deze reservering is niet meer actief.');
          break;
        case 'no_active_session':
          showToast('Er loopt geen laadsessie meer — verlengen niet nodig.');
          break;
        case 'not_owner':
          showToast('Deze reservering hoort niet bij dit account.');
          break;
        case 'not_found':
          showToast('Reservering niet gevonden.');
          break;
        case 'invalid_minutes':
          showToast('Ongeldige verlenging.');
          break;
        default:
          showToast('Verlengen mislukt. Probeer het via de app.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PushActions] extend_booking error: $e');
      showToast('Kon niet verlengen — check je internetverbinding.');
    }
  }
}
