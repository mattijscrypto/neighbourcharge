// Pluggo — StripeService
// ----------------------------------------------------------------------------
// Wrapper rond de Supabase Edge Functions voor Stripe Connect:
//
//   • stripe-onboard-account  → paaleigenaar onboarding (KYC via Stripe-hosted)
//   • create-payment-stripe   → **Pad 2**: Checkout Session + checkout_url
//                               (browser-redirect ipv native PaymentSheet)
//
// **Pad 2 achtergrond**: na 3 dagen vastlopen op een silent hang in
// flutter_stripe 11.5.0 PaymentSheet (iOS 26.3.1 + FlutterSceneDelegate +
// FlutterImplicitEngineDelegate maakt presenting view controller onvindbaar)
// pivoteren we naar Stripe Checkout via browser-redirect. UI opent de
// checkout_url in Safari via url_launcher; webhook updatet booking server-side;
// app pollt booking-status na terugkeer.
//
// Alle errors worden gegooid als StripeServiceException met een Nederlands
// bericht dat direct in een SnackBar gezet kan worden. Logs gaan via debugPrint
// zodat we in productie via Sentry / console kunnen traceren.
// ----------------------------------------------------------------------------

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uitkomst van [StripeService.startOnboarding].
class StripeOnboardingResult {
  /// Stripe Connect account-id, format `acct_…`. Wordt al opgeslagen op het
  /// profiel door de edge function — Flutter hoeft 'm alleen te tonen als
  /// debug-info en bij een refresh van het profiel.
  final String stripeAccountId;

  /// Kortlevende Stripe-hosted KYC URL (vervalt binnen minuten). Direct openen
  /// in een in-app browser-tab (`url_launcher` met externalApplication of
  /// inAppWebView). Stripe redirect na voltooien naar de configured deep links.
  final String onboardingUrl;

  /// True als de paaleigenaar al een bestaand stripe_account_id had — dan
  /// is dit een hervatting van eerdere onboarding, niet een fresh start.
  final bool reused;

  /// True als de account al door Stripe geverifieerd is (charges_enabled).
  /// In dat geval is de onboardingUrl een readonly dashboard-view ipv KYC,
  /// maar 'm openen mag nog steeds (gebruiker kan bv. bankrekening wijzigen).
  final bool alreadyVerified;

  const StripeOnboardingResult({
    required this.stripeAccountId,
    required this.onboardingUrl,
    required this.reused,
    required this.alreadyVerified,
  });

  factory StripeOnboardingResult.fromMap(Map<String, dynamic> map) {
    return StripeOnboardingResult(
      stripeAccountId: map['stripe_account_id'] as String? ?? '',
      onboardingUrl: map['onboarding_url'] as String? ?? '',
      reused: map['reused'] as bool? ?? false,
      alreadyVerified: map['already_verified'] as bool? ?? false,
    );
  }
}

/// Uitkomst van [StripeService.createCheckoutSession] — Pad 2 (browser-redirect).
///
/// De Flutter app opent [checkoutUrl] in Safari via url_launcher
/// (LaunchMode.externalApplication). Stripe handelt de hele payment-UI
/// af op checkout.stripe.com — kaart, iDEAL, Apple Pay, Google Pay.
/// Bij success/cancel redirect Stripe naar onze stripe-checkout-return
/// edge function, die een pluggo:// deep link opent.
///
/// De definitieve betaalstatus komt binnen via de stripe-webhook
/// (checkout.session.completed + payment_intent.succeeded). De Flutter
/// app pollt na terugkeer de booking.payment_status om de UI te
/// refreshen — niet vertrouwen op deep link alone.
class StripeCheckoutSessionResult {
  /// Stripe Checkout URL — `https://checkout.stripe.com/c/pay/cs_…`.
  /// Open via `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`.
  /// Niet in een in-app WebView openen — Apple Pay / Google Pay werkt
  /// alleen in de echte Safari/Chrome.
  final String checkoutUrl;

  /// Checkout Session ID — `cs_test_…` / `cs_live_…`. Handig voor
  /// support/debugging en om client-side te checken of een terugkomende
  /// deeplink bij deze sessie hoort (?session_id=… query param).
  final String checkoutSessionId;

  /// Rij-id in de payments tabel — Flutter kan deze meegeven aan refresh
  /// queries om te checken of de betaling volledig verwerkt is.
  final String paymentId;

  /// Bedragen voor UI-weergave (we tonen ze al vóór de checkout, maar
  /// na de edge function zijn ze server-authoritatief).
  final int amountCents;
  final int serviceFeeCents;
  final int ownerShareCents;

  /// True als we een bestaande open Checkout Session hergebruiken (bv.
  /// nadat gebruiker browser sloot en terugkwam in de app).
  final bool reused;

  const StripeCheckoutSessionResult({
    required this.checkoutUrl,
    required this.checkoutSessionId,
    required this.paymentId,
    required this.amountCents,
    required this.serviceFeeCents,
    required this.ownerShareCents,
    this.reused = false,
  });

  factory StripeCheckoutSessionResult.fromMap(Map<String, dynamic> map) {
    return StripeCheckoutSessionResult(
      checkoutUrl: map['checkout_url'] as String? ?? '',
      checkoutSessionId: map['checkout_session_id'] as String? ?? '',
      paymentId: map['payment_id'] as String? ?? '',
      amountCents: (map['amount_cents'] as num?)?.toInt() ?? 0,
      serviceFeeCents: (map['service_fee_cents'] as num?)?.toInt() ?? 0,
      ownerShareCents: (map['owner_share_cents'] as num?)?.toInt() ?? 0,
      reused: map['reused'] as bool? ?? false,
    );
  }
}

/// Uitkomst van [StripeService.createPaymentIntent].
///
/// **DEPRECATED na Pad 2 pivot** — vervangen door [StripeCheckoutSessionResult].
/// Klasse blijft staan zodat eventuele bestaande UI-code niet meteen breekt,
/// maar de bijbehorende `createPaymentIntent` methode gooit nu een duidelijke
/// fout met een hint om naar `createCheckoutSession` te switchen.
class StripePaymentIntentResult {
  /// client_secret format `pi_…_secret_…` — wordt aan
  /// Stripe.instance.initPaymentSheet meegegeven. NIET loggen of opslaan,
  /// dit is een gevoelige string die transacties kan voltooien.
  final String clientSecret;

  /// PaymentIntent id `pi_…` — handig voor support/debugging.
  final String paymentIntentId;

  /// Rij-id in de payments tabel — Flutter kan deze meegeven aan refresh
  /// queries om te checken of de betaling volledig verwerkt is.
  final String paymentId;

  /// Bedragen voor UI-weergave (we tonen ze al vóór de PaymentSheet, maar
  /// na de edge function zijn ze server-authoritatief).
  final int amountCents;
  final int serviceFeeCents;
  final int ownerShareCents;

  /// Connected account id van de paaleigenaar — debug-info, niet voor UI.
  final String? destinationAccountId;

  const StripePaymentIntentResult({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.paymentId,
    required this.amountCents,
    required this.serviceFeeCents,
    required this.ownerShareCents,
    this.destinationAccountId,
  });

  factory StripePaymentIntentResult.fromMap(Map<String, dynamic> map) {
    return StripePaymentIntentResult(
      clientSecret: map['client_secret'] as String? ?? '',
      paymentIntentId: map['payment_intent_id'] as String? ?? '',
      paymentId: map['payment_id'] as String? ?? '',
      amountCents: (map['amount_cents'] as num?)?.toInt() ?? 0,
      serviceFeeCents: (map['service_fee_cents'] as num?)?.toInt() ?? 0,
      ownerShareCents: (map['owner_share_cents'] as num?)?.toInt() ?? 0,
      destinationAccountId: map['destination_account_id'] as String?,
    );
  }
}

/// Gegooid bij alle voorspelbare faal-paden — UI hoort dit te catchen en
/// het bericht in een SnackBar te tonen. NL-only, geen i18n nodig.
class StripeServiceException implements Exception {
  final String message;
  final int? statusCode;

  StripeServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'StripeServiceException($statusCode): $message';
}

/// Singleton wrapper. Gebruik [StripeService.instance].
///
/// Voorbeeld:
/// ```dart
/// try {
///   final result = await StripeService.instance.startOnboarding();
///   await launchUrl(Uri.parse(result.onboardingUrl), ...);
/// } on StripeServiceException catch (e) {
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text(e.message)),
///   );
/// }
/// ```
class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  SupabaseClient get _client => Supabase.instance.client;

  // --------------------------------------------------------------------------
  // ONBOARDING — paaleigenaar maakt Stripe Connect account aan en wordt
  // doorgestuurd naar Stripe-hosted KYC. Vereist dat het profiel al
  // business_type heeft ingevuld (BTW-vragenlijst).
  // --------------------------------------------------------------------------
  Future<StripeOnboardingResult> startOnboarding() async {
    try {
      debugPrint('StripeService.startOnboarding: invoking edge function');
      final res = await _client.functions
          .invoke('stripe-onboard-account')
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('StripeService.startOnboarding: TIMEOUT na 20s — netwerk hangt');
              throw StripeServiceException(
                'Server reageert niet — controleer je internetverbinding en probeer opnieuw',
              );
            },
          );
      debugPrint('StripeService.startOnboarding: edge function returned status=${res.status}');
      _throwIfError(res, fallback: 'Kon Stripe-onboarding niet starten');

      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw StripeServiceException(
          'Onverwacht antwoord van server bij onboarding',
        );
      }

      final result = StripeOnboardingResult.fromMap(data);
      if (result.onboardingUrl.isEmpty) {
        throw StripeServiceException(
          'Geen onboarding-link ontvangen van Stripe',
        );
      }
      return result;
    } on StripeServiceException {
      rethrow;
    } on FunctionException catch (e, st) {
      debugPrint('StripeService.startOnboarding FunctionException: $e\n$st');
      throw _functionExceptionToStripeException(
        e,
        fallback: 'Kon Stripe-onboarding niet starten',
      );
    } catch (e, st) {
      debugPrint('StripeService.startOnboarding failed: $e\n$st');
      throw StripeServiceException(
        'Onbekende fout bij starten van Stripe-onboarding: $e',
      );
    }
  }

  // --------------------------------------------------------------------------
  // PAYMENT — boeker triggert betaling voor een boeking waar de owner kWh
  // op heeft gezet. Edge function valideert alles (booking-status, owner
  // charges_enabled, idempotency) en geeft een Stripe Checkout URL terug.
  //
  // **Pad 2** flow:
  //   1. Edge function maakt een Stripe Checkout Session aan (mode=payment
  //      met destination charge via payment_intent_data).
  //   2. Wij krijgen checkout_url terug.
  //   3. UI opent die URL in Safari via url_launcher externalApplication.
  //   4. Stripe handelt betaalUI af; redirect bij success/cancel naar
  //      onze stripe-checkout-return edge function → pluggo:// deep link.
  //   5. App pollt na terugkeer booking.payment_status. Webhook is
  //      source-of-truth en updatet de booking server-side.
  // --------------------------------------------------------------------------
  Future<StripeCheckoutSessionResult> createCheckoutSession({
    required String bookingId,
  }) async {
    try {
      debugPrint('StripeService.createCheckoutSession: invoking edge function for booking $bookingId');
      final res = await _client.functions
          .invoke(
            'create-payment-stripe',
            body: {'booking_id': bookingId},
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('StripeService.createCheckoutSession: TIMEOUT na 20s — netwerk hangt');
              throw StripeServiceException(
                'Server reageert niet — controleer je internetverbinding en probeer opnieuw',
              );
            },
          );
      debugPrint('StripeService.createCheckoutSession: edge function returned status=${res.status}');
      _throwIfError(res, fallback: 'Kon betaling niet voorbereiden');

      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw StripeServiceException(
          'Onverwacht antwoord van server bij betaling',
        );
      }

      final result = StripeCheckoutSessionResult.fromMap(data);
      if (result.checkoutUrl.isEmpty) {
        throw StripeServiceException(
          'Geen checkout-URL ontvangen van Stripe',
        );
      }
      return result;
    } on StripeServiceException {
      rethrow;
    } on FunctionException catch (e, st) {
      debugPrint('StripeService.createCheckoutSession FunctionException: $e\n$st');
      throw _functionExceptionToStripeException(
        e,
        fallback: 'Kon betaling niet voorbereiden',
      );
    } catch (e, st) {
      debugPrint('StripeService.createCheckoutSession failed: $e\n$st');
      throw StripeServiceException(
        'Onbekende fout bij voorbereiden van betaling: $e',
      );
    }
  }

  /// **DEPRECATED na Pad 2 pivot.** Gebruik [createCheckoutSession].
  ///
  /// De PaymentIntent + flutter_stripe PaymentSheet flow is verlaten omdat
  /// het sheet onzichtbaar rendert op iOS 26.3.1 in combinatie met
  /// flutter_stripe 11.5.0 + FlutterSceneDelegate. Houd deze methode-stub
  /// in de codebase zodat oude oproepen een nette fout geven i.p.v.
  /// silent te falen op een verwijderde class.
  @Deprecated('Gebruik createCheckoutSession (Pad 2)')
  Future<StripePaymentIntentResult> createPaymentIntent({
    required String bookingId,
  }) async {
    throw StripeServiceException(
      'PaymentIntent-flow is uitgeschakeld — gebruik createCheckoutSession()',
    );
  }

  // --------------------------------------------------------------------------
  // POLL — na opening van de Checkout URL pollen we booking.payment_status
  // tot 'ie 'paid' is of we de max-wachttijd hebben overschreden.
  //
  // We pollen op booking-niveau (niet payment-niveau) omdat de webhook
  // beide tegelijk update; booking is de canonical user-facing state.
  //
  // Returns true bij payment_status='paid', false bij timeout/cancel/failed.
  // --------------------------------------------------------------------------
  Future<bool> waitForBookingPayment({
    required String bookingId,
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    debugPrint('StripeService.waitForBookingPayment: polling booking $bookingId every ${interval.inSeconds}s for up to ${timeout.inMinutes}m');

    while (DateTime.now().isBefore(deadline)) {
      try {
        final row = await _client
            .from('bookings')
            .select('payment_status')
            .eq('id', bookingId)
            .maybeSingle();
        final status = row?['payment_status'] as String?;
        debugPrint('StripeService.waitForBookingPayment: status=$status');
        if (status == 'paid') return true;
        if (status == 'refunded') return false;
        // 'pending' → blijven pollen
      } catch (e) {
        debugPrint('StripeService.waitForBookingPayment: poll error (ignored): $e');
        // Negeren — probeer volgende cycle opnieuw. Netwerk-glitches mogen
        // de hele wacht-loop niet afbreken.
      }
      await Future<void>.delayed(interval);
    }
    debugPrint('StripeService.waitForBookingPayment: TIMEOUT na ${timeout.inMinutes}m — geen paid status gezien');
    return false;
  }

  /// Vertaalt een [FunctionException] van supabase_flutter naar een typed
  /// [StripeServiceException] met daarin de server-foutmelding (als die te
  /// extraheren is uit `details`). Anders valt 'ie terug op [fallback].
  StripeServiceException _functionExceptionToStripeException(
    FunctionException e, {
    required String fallback,
  }) {
    String message = fallback;
    final details = e.details;
    if (details is Map) {
      final err = details['error'];
      if (err is String && err.isNotEmpty) {
        message = err;
      }
    } else if (details is String && details.isNotEmpty) {
      message = details;
    }
    return StripeServiceException(message, statusCode: e.status);
  }

  // --------------------------------------------------------------------------
  // Helper: edge function FunctionResponse evalueren. supabase.functions.invoke
  // gooit geen exception bij non-2xx — we moeten zelf status + error body
  // ontleden en omzetten naar een typed exception.
  // --------------------------------------------------------------------------
  void _throwIfError(FunctionResponse res, {required String fallback}) {
    final status = res.status ?? 0;
    if (status < 400) return;

    final data = res.data;
    String message = fallback;
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is String && err.isNotEmpty) {
        message = err;
      }
    }
    throw StripeServiceException(message, statusCode: status);
  }
}
