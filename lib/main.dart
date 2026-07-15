import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'live_charging_widget.dart';
import 'push.dart';
import 'push_actions.dart';
import 'stripe_service.dart';
import 'vehicle_presets.dart';

// Supabase configuratie
// Voor een echt product horen deze in environment variables,
// maar voor een MVP is dit prima. De publishable key is veilig om te delen.
const String supabaseUrl = 'https://vfqpijlicngnomrsasvf.supabase.co';
const String supabaseAnonKey = 'sb_publishable_6LYdmmkM6efPz5WJzi5tiQ_0qiXqML1';

// Stripe publishable key — veilig om client-side te exposen (Stripe SDK
// gebruikt 'm alleen om payment-methods te tokeniseren, niet om charges
// te maken). De geheime sk_test_… key staat alleen server-side in de
// Supabase Edge Functions secrets.
//
// TEST mode (huidig): pk_test_…
// LIVE mode (cutover 7 juli 2026): vervang door pk_live_… én rebuild de
// app voor productie release. Geen runtime toggle — Stripe.publishableKey
// staat vast voor de hele app lifecycle na main().
const String stripePublishableKey =
    'pk_test_51TZtsPHUR6BWGt6YgaTrqtgmEs3SNehFj6uTR4ceP9hNIi8ekXpZFWM925cmsWuTucIVwb9M9z5rkAXPN9lFnEgo00L7mmpk4v';

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
final DateTime bookingsGoLiveAt = DateTime(2026, 7, 7);

// Bypass van de date-gate kent twee bronnen:
//
//  1. [bypassEmails] — hardcoded "core"-lijst. Reviewers en founders. Deze
//     vier veranderen nooit, dus we houden ze in code zodat ze óók werken
//     als de DB onbereikbaar is (eerste launch, offline modus, kapotte RLS).
//
//  2. [_dbBypassEmailMatched] — runtime gecachte boolean die zegt of de
//     huidige user op de DB-tabel `public.bypass_emails` staat. Wordt
//     gerefresht bij app-start en bij iedere auth state change. Hierdoor
//     kunnen we testers toevoegen via Supabase Studio zonder rebuild.
//
// Na launch op [bookingsGoLiveAt] heeft dit hele systeem geen effect meer
// (de date-gate is dan überhaupt al open).
const List<String> bypassEmails = [
  'apple-review@pluggoapp.nl',
  'google-review@pluggoapp.nl',
  'm.sloothovenier@gmail.com',
  'rakawakka@gmail.com',
];

// Cache: staat de huidige ingelogde user op `public.bypass_emails`?
// Wordt gevuld door [refreshBypassEmailCache], dat we vanuit main() en
// vanuit de auth-state listener aanroepen. Default false zodat we bij
// onbekendheid terugvallen op de date-gate (veilig: niemand-bypass).
bool _dbBypassEmailMatched = false;

/// Fetcht of de huidige user op `public.bypass_emails` staat en cachet
/// het resultaat. Roep aan na elke auth state change — bij login wil je
/// 'm voor de juiste user opnieuw checken, bij logout wil je 'm op false
/// hebben staan zodat de date-gate weer actief is.
///
/// Faalt stil bij netwerk- of RLS-fouten: dan blijft de oude cache staan
/// (of false als 'ie nooit gezet is). Een tester die geen netwerk heeft
/// kan dus de eerste keer niet bypassen — dat is acceptabel.
Future<void> refreshBypassEmailCache() async {
  try {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) {
      _dbBypassEmailMatched = false;
      return;
    }
    // RLS staat alleen toe dat de user z'n eigen rij ziet, dus een hit
    // betekent: deze user staat op de lijst. count: exact is precies wat
    // we willen — we hebben de rij-inhoud niet nodig, alleen of 'ie bestaat.
    final response = await Supabase.instance.client
        .from('bypass_emails')
        .select('email')
        .eq('email', email.toLowerCase())
        .limit(1)
        .maybeSingle();
    _dbBypassEmailMatched = response != null;
  } catch (_) {
    // Stille fallback: laat cache staan, val terug op de hardcoded lijst
    // en de date-gate. Niet erg — testers kunnen later opnieuw inloggen.
  }
}

bool get bookingsAreLive {
  try {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email != null && bypassEmails.contains(email.toLowerCase())) {
      return true;
    }
  } catch (_) {
    // Supabase nog niet geïnitialiseerd — val terug op de date-gate
  }
  if (_dbBypassEmailMatched) return true;
  return !DateTime.now().isBefore(bookingsGoLiveAt);
}
// Hoeveel hele dagen tot de launch, in datums (dus niet uren). Op 6 juli
// staat er "over 1 dag" en op 7 juli "vandaag!", ook al is het 23:59.
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
const String launchDateLabel = '7 juli 2026';

// ============================================
// IBAN-helpers — voor uitbetalingen aan eigenaren via Stripe Connect (SEPA).
// Zonder geldige IBAN kunnen we het host-aandeel (paalprijs − €0,03/kWh)
// niet doorbetalen, dus blokkeren we het paal-toevoegen-flow tot er een
// IBAN op het profiel staat.
// ============================================

/// NL-IBAN-check in twee lagen:
/// 1) Structureel — 18 tekens "NL" + 2 cijfers + 4 letters + 10 cijfers
/// 2) Mod-97 checksum (ISO 13616) — vangt typo's in de controlegetallen
/// Spaties bij invoer mogen, andere landcodes niet (Pluggo betaalt voorlopig
/// alleen Nederlandse rekeningen uit).
bool isValidNlIban(String input) {
  final cleaned = input.replaceAll(' ', '').toUpperCase();
  final regex = RegExp(r'^NL\d{2}[A-Z]{4}\d{10}$');
  if (!regex.hasMatch(cleaned)) return false;
  return _ibanMod97Check(cleaned);
}

/// IBAN mod-97 check (ISO 13616): verplaats de eerste 4 tekens naar achter,
/// converteer letters naar 2-cijferige nummers (A=10..Z=35), check dat het
/// resterende getal mod 97 == 1. NL-IBAN wordt ~24 cijfers na conversie,
/// dus BigInt is nodig (te groot voor Int64).
bool _ibanMod97Check(String iban) {
  final rearranged = iban.substring(4) + iban.substring(0, 4);
  final buf = StringBuffer();
  for (final ch in rearranged.codeUnits) {
    if (ch >= 0x30 && ch <= 0x39) {
      // '0'-'9'
      buf.writeCharCode(ch);
    } else if (ch >= 0x41 && ch <= 0x5A) {
      // 'A'-'Z' → A=10, B=11, ... Z=35
      buf.write((ch - 55).toString());
    } else {
      return false;
    }
  }
  try {
    return BigInt.parse(buf.toString()) % BigInt.from(97) == BigInt.one;
  } catch (_) {
    return false;
  }
}

/// Normaliseert IBAN naar uppercase zonder spaties — zo slaan we 'm op.
String normalizeIban(String input) {
  return input.replaceAll(' ', '').toUpperCase();
}

/// Mooi geformatteerde weergave: "NL12 ABCD 0123 4567 89".
String prettyIban(String iban) {
  final clean = iban.replaceAll(' ', '');
  final buffer = StringBuffer();
  for (var i = 0; i < clean.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(clean[i]);
  }
  return buffer.toString();
}

/// TextInputFormatter die tijdens typen automatisch elke 4 tekens een spatie
/// invoegt en alles uppercase maakt — geeft IBAN-veld een "NL12 ABCD 0123 ..."
/// look-and-feel zonder dat user handmatig spaties hoeft te typen.
/// Limiet: 22 tekens (18 cijfers/letters + 4 spaties) voor NL-IBAN.
class IbanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean =
        newValue.text.replaceAll(' ', '').toUpperCase();
    // Cap op 18 tekens (NL-IBAN-lengte) zodat we niet eindeloos doortypen.
    final capped = clean.length > 18 ? clean.substring(0, 18) : clean;
    final buf = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(capped[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Haalt de IBAN op die in `profiles.iban` voor de huidige gebruiker staat.
/// Returnt null als de gebruiker niet ingelogd is, geen profielrij heeft,
/// of nog geen IBAN heeft ingevuld.
Future<String?> fetchCurrentUserIban() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('iban')
        .eq('id', userId)
        .maybeSingle();
    final iban = row?['iban'] as String?;
    if (iban == null || iban.trim().isEmpty) return null;
    return iban;
  } catch (_) {
    return null;
  }
}

// ============================================
// Pricing helpers — pay-after-charge model.
// Owner vult na de laadbeurt het werkelijk afgenomen kWh in; daarmee is
// het exacte bedrag bekend. Geen schatting meer vooraf.
// Formules moeten matchen met supabase/functions/create-payment-stripe/index.ts.
//
// Fee-model (per mei 2026): vaste fee van €0,03/kWh aan beide kanten +
// een eenmalige €0,40 transactiefee bij mini-sessies onder 10 kWh.
//   • Booker betaalt: kWh × (paalprijs + €0,03)  + €0,40 als kWh < 10
//   • Host ontvangt:  kWh × (paalprijs − €0,03)  — altijd, los van sessiegrootte
//   • Pluggo houdt:   kWh × €0,06 + (kWh < 10 ? €0,40 : 0)
// Het is geen percentage; bewust gekozen omdat de iDEAL-fee van Stripe
// een vast bedrag (~€0,29) is waar een procentuele fee bij kleine sessies
// onder zou duiken. De €0,40 small-session fee dekt expliciet de
// iDEAL-transactiekosten bij sessies <10 kWh; bij grotere sessies
// dekt de €0,06/kWh ze ruimschoots zelf.
// ============================================

/// Booker-fee in euro per kWh — wordt bovenop de paalprijs getoond én
/// betaald. Staat ook in T&Cs en FAQ.
const double bookerFeePerKwh = 0.03;

/// Host-fee in euro per kWh — wordt afgetrokken van de paalprijs bij
/// de uitbetaling aan de eigenaar. Staat ook in T&Cs en FAQ.
const double hostFeePerKwh = 0.03;

/// Totaal Pluggo-aandeel per kWh (booker- + host-fee).
const double pluggoFeePerKwh = bookerFeePerKwh + hostFeePerKwh;

/// Drempel waaronder een sessie als "mini-sessie" geldt; daaronder geldt
/// een extra vaste transactiefee bovenop het kWh-tarief. Komt ook in
/// T&Cs en FAQ.
const double smallSessionThresholdKwh = 10.0;

/// Eenmalige extra fee (euro) die de booker betaalt bij sessies onder
/// [smallSessionThresholdKwh]. Bedoeld om de iDEAL-kosten van Stripe op
/// kleine sessies te dekken. Wordt NIET afgetrokken van het host-aandeel
/// — die ontvangt altijd zijn volle paalprijs minus €0,03/kWh.
const double smallSessionFeeEur = 0.40;

/// Hoeveel dagen mag een betaalverzoek openstaan voordat de boeker
/// nieuwe boekingen niet meer mag maken. Komt ook in T&Cs te staan.
const int maxDaysOutstandingPayment = 7;

/// Parse charger.price (String, bv "0.30") naar double. Accepteert zowel
/// "." als "," als decimaalscheidingsteken.
double parseChargerPrice(String price) {
  return double.tryParse(price.replaceAll(',', '.')) ?? 0.0;
}

/// Wat de booker per kWh ziet en betaalt: paalprijs + €0,03 servicefee.
double bookerPricePerKwh(String chargerPrice) {
  return parseChargerPrice(chargerPrice) + bookerFeePerKwh;
}

/// Wat de host per kWh netto ontvangt: paalprijs − €0,03 servicefee.
double hostNetPricePerKwh(String chargerPrice) {
  final p = parseChargerPrice(chargerPrice) - hostFeePerKwh;
  return p < 0 ? 0 : p;
}

/// "€0,33/kWh"-stijl label voor wat de booker ziet (incl. servicefee).
String formatBookerPricePerKwhLabel(String chargerPrice) {
  final p = bookerPricePerKwh(chargerPrice);
  return '€${p.toStringAsFixed(2).replaceAll('.', ',')}/kWh';
}

/// Geeft de small-session fee (euro) voor de gegeven sessiegrootte.
/// Bij sessies onder [smallSessionThresholdKwh] is dat [smallSessionFeeEur],
/// anders 0.
double smallSessionFeeFor(double kwh) {
  if (kwh <= 0) return 0;
  return kwh < smallSessionThresholdKwh ? smallSessionFeeEur : 0;
}

/// Bereken het totale bedrag (euro) dat de boeker betaalt voor een boeking:
/// kWh × (paalprijs + €0,03 booker-fee) + €0,40 als kWh < 10.
double calculateBookingTotalEuro(double kwh, String chargerPrice) {
  if (kwh <= 0) return 0;
  final price = parseChargerPrice(chargerPrice);
  if (price <= 0) return 0;
  return kwh * (price + bookerFeePerKwh) + smallSessionFeeFor(kwh);
}

/// Totaal Pluggo-aandeel (euro) voor een boeking: kWh × €0,06 + eventuele
/// small-session fee. Host-aandeel wordt NIET verlaagd door de small-session
/// fee.
double calculatePluggoFeeEuro(double kwh) {
  if (kwh <= 0) return 0;
  return kwh * pluggoFeePerKwh + smallSessionFeeFor(kwh);
}

/// Bereken het bedrag voor een boeking als de owner al kWh heeft ingevuld.
/// Returnt null als kWh nog niet bekend is.
///
/// LET OP: gebruik dit alleen voor preview-doeleinden (bv. de owner toont
/// een live-berekening tijdens kWh invullen). Voor het tonen van het bedrag
/// dat de boeker daadwerkelijk gaat betalen — of al heeft betaald — gebruik
/// [bookingPayableEuro], die voorrang geeft aan total_amount_cents.
double? calculatedBookingEuro(Booking b) {
  final kwh = b.kwhConsumed;
  final charger = b.charger;
  if (kwh == null || charger == null) return null;
  return calculateBookingTotalEuro(kwh, charger.price);
}

/// Het bedrag dat de boeker gaat betalen of al heeft betaald.
///
/// Voorkeur: `total_amount_cents` op de boeking — dit is vastgezet door de
/// owner op het moment van het betaalverzoek en wijzigt daarna niet meer,
/// ook niet als de owner de paalprijs aanpast. Dit garandeert dat wat de
/// booker in de UI ziet 1-op-1 matcht met wat Stripe daadwerkelijk charged.
///
/// Fallback: `kWh × paalprijs` voor edge cases waar `total_amount_cents` om
/// een of andere reden nog niet gevuld zou zijn (zou niet horen voor te komen
/// na het betaalverzoek, maar defensief is goedkoop).
double? bookingPayableEuro(Booking b) {
  final tac = b.totalAmountCents;
  if (tac != null && tac > 0) return tac / 100.0;
  return calculatedBookingEuro(b);
}

/// Format een cent-bedrag naar "€12,34"-stijl voor UI-weergave.
String formatEuroCents(int cents) {
  final euros = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  return '€$euros';
}

/// Format een euro double naar "€12,34"-stijl.
String formatEuroDouble(double euro) {
  final s = euro.toStringAsFixed(2).replaceAll('.', ',');
  return '€$s';
}

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
  // Waarschuwingstinten — gebruikt voor "vereiste actie" banners en
  // setup-tips (bv. lege beschikbaarheid). Iets zachter dan danger.
  static const warning = Color(0xFFE08600);
  static const warningSoft = Color(0xFFFFF4E0);
  static const warningDark = Color(0xFF8A5300);

  // Pluggo Pionier — gouden tinten voor de badge op profielen van
  // vroeg-adopters. Iets warmer dan `solar` en bewust premium.
  static const pioneer = Color(0xFFD4A437);     // Klassiek goud
  static const pioneerDark = Color(0xFF8C6A1A); // Voor tekst/icon-contrast
  static const pioneerSoft = Color(0xFFFDF6E0); // Achtergrond voor badge-pill
}

// ============================================
// PioneerBadge — gouden badge voor Pluggo Pioniers (vroeg-adopters).
// Drie groottes:
//   • PioneerBadgeSize.small  — compacte pill voor charger-cards op de map
//   • PioneerBadgeSize.medium — voor charger-detailscherm + onder profielnaam
//   • PioneerBadgeSize.large  — prominent op het profielscherm
// ============================================
enum PioneerBadgeSize { small, medium, large }

class PioneerBadge extends StatelessWidget {
  final PioneerBadgeSize size;
  final bool showLabel; // false = alleen icoon (handig op kleine kaartjes)

  const PioneerBadge({
    Key? key,
    this.size = PioneerBadgeSize.medium,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double iconSize;
    final double fontSize;
    final EdgeInsetsGeometry padding;
    switch (size) {
      case PioneerBadgeSize.small:
        iconSize = 12;
        fontSize = 10;
        padding =
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
        break;
      case PioneerBadgeSize.medium:
        iconSize = 14;
        fontSize = 12;
        padding =
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
        break;
      case PioneerBadgeSize.large:
        iconSize = 18;
        fontSize = 14;
        padding =
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
        break;
    }

    final radius = size == PioneerBadgeSize.large ? 14.0 : 10.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE7A0), Color(0xFFD4A437)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: size == PioneerBadgeSize.large
            ? [
                BoxShadow(
                  color: AppColors.pioneer.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
        border: Border.all(
          color: AppColors.pioneerDark.withOpacity(0.4),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: iconSize,
            color: AppColors.pioneerDark,
          ),
          if (showLabel) ...[
            SizedBox(width: size == PioneerBadgeSize.small ? 3 : 5),
            Text(
              'Pionier',
              style: GoogleFonts.inter(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: AppColors.pioneerDark,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
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
// priceFeedback — herbruikbaar widget dat onder een prijs-per-kWh-veld
// staat en in realtime feedback geeft. Doel: voorkomen dat eigenaars
// ofwel onder kostprijs (~€0,21) ofwel boven publieke palen (€0,55+)
// gaan zitten. Groene zone: €0,30 – €0,45.
// ============================================
Widget priceFeedback(TextEditingController controller) {
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final raw = controller.text.replaceAll(',', '.').trim();
      final price = double.tryParse(raw);

      // Statische helper — altijd zichtbaar
      const helperLine = Padding(
        padding: EdgeInsets.only(left: 4, top: 8),
        child: Text(
          '🟢 Aanbevolen: €0,30 – €0,45  ·  Publiek: €0,40+  ·  Snellader: €0,65+',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );

      // Dynamische feedback alleen bij geldige input
      Widget? dynamic_;
      if (price != null && price > 0) {
        Color color;
        IconData icon;
        String message;
        if (price < 0.25) {
          color = AppColors.danger;
          icon = Icons.warning_amber_rounded;
          message = 'Je dekt je stroomkosten amper. Weet je het zeker?';
        } else if (price < 0.30) {
          color = AppColors.solar;
          icon = Icons.info_outline;
          message = 'Onderkant van de markt — veel laders, beperkte marge.';
        } else if (price <= 0.45) {
          color = AppColors.primary;
          icon = Icons.check_circle_outline;
          message = 'Aantrekkelijk voor laders en gezonde marge voor jou.';
        } else if (price <= 0.55) {
          color = AppColors.solar;
          icon = Icons.info_outline;
          message = 'Je nadert het publieke paaltarief — overweeg iets lager.';
        } else {
          color = AppColors.danger;
          icon = Icons.warning_amber_rounded;
          message = 'Hoger dan publieke palen — laders kiezen waarschijnlijk daar.';
        }
        dynamic_ = Padding(
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          helperLine,
          if (dynamic_ != null) dynamic_,
        ],
      );
    },
  );
}

// ============================================
// freeVendInfo — uitklapbare uitlegkaart in de "paal toevoegen" en
// "paal bewerken"-flow. Wijst eigenaars erop dat hun paal in vrij-laden
// modus moet staan zodat boekers zonder eigen laadpas kunnen laden,
// en geeft per merk een korte hint hoe je dat instelt.
// ============================================
Widget _freeVendBrandTip(String brand, String tip) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        children: [
          TextSpan(
            text: '$brand — ',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          TextSpan(text: tip),
        ],
      ),
    ),
  );
}

Widget freeVendInfo() {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.solarSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.solar.withOpacity(0.45)),
    ),
    child: Theme(
      data: ThemeData().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: AppColors.solar,
        collapsedIconColor: AppColors.solar,
        leading: const Icon(Icons.lightbulb_outline, color: AppColors.solar),
        title: Text(
          'Zet je paal op "vrij laden"',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'Anders kan een boeker zonder jouw laadpas niet laden.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        children: [
          Text(
            'In vrij-laden modus (ook wel "Plug & Charge", "Auto-Start" '
            'of "Free Vend") start het laden zodra de stekker in de auto '
            'zit — zonder laadpas of app. Per merk heet die instelling anders:',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _freeVendBrandTip(
            'Alfen Eve',
            '"Plug & Charge" aanvinken in de Alfen-app of via je installateur.',
          ),
          _freeVendBrandTip(
            'Wallbox',
            '"Auto-Lock" uit in de myWallbox-app.',
          ),
          _freeVendBrandTip(
            'Easee',
            '"Vrij laden" inschakelen in de Easee-app.',
          ),
          _freeVendBrandTip(
            'EVBox',
            'Via je installateur of het EVBox-portal.',
          ),
          _freeVendBrandTip(
            'Heidelberg / Schneider / overig',
            'Vaak een DIP-switch in de paal of via je installateur.',
          ),
          const SizedBox(height: 8),
          Text(
            'Twijfel je? Bel je installateur of mail info@pluggoapp.nl — we helpen je op weg.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================
// _cableSelector — twee-knops keuze: paal-met-kabel óf zelf-meebrengen.
// Belangrijk voor laders zodat ze weten of ze hun eigen kabel mee moeten.
// ============================================
Widget _cableSelector({
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  Widget option({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return Row(
    children: [
      option(
        selected: value == true,
        icon: Icons.cable_rounded,
        label: 'Met kabel',
        onTap: () => onChanged(true),
      ),
      const SizedBox(width: 8),
      option(
        selected: value == false,
        icon: Icons.power_outlined,
        label: 'Zelf meebrengen',
        onTap: () => onChanged(false),
      ),
    ],
  );
}

// ============================================
// _accessTypePicker — keuzelijst voor hoe een lader op de plek komt.
// Vijf opties; gebruikt Wrap zodat het op kleine schermen netjes afbreekt.
// ============================================
Widget _accessTypePicker({
  required String selected,
  required ValueChanged<String> onChanged,
}) {
  final entries = kAccessTypeLabels.entries.toList();
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: entries.map((e) {
      final isSelected = e.key == selected;
      return GestureDetector(
        onTap: () => onChanged(e.key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                kAccessTypeIcons[e.key] ?? Icons.help_outline,
                size: 16,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                e.value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );
}

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

// ============================================
// Google Places Autocomplete + Details
// --------------------------------------------
// Voor adres-invoer bij paal toevoegen: laat eigenaar tijdens typen uit
// een lijst Nederlandse adressen kiezen i.p.v. zelf typen. Voorkomt
// typo's waardoor palen niet geocoderen en dus nooit op de kaart komen.
//
// Sessie-tokens: één UUID-achtig token per zoekvraag, zodat
// Autocomplete + Details samen als 1 sessie gefactureerd worden
// (~€0.014 per nieuwe paal i.p.v. per request). Token wordt
// hergebruikt voor elke keystroke en weggegooid na de Details-call.
//
// Vereist dat Places API is aangezet in Google Cloud Console
// (hetzelfde project als Geocoding API; zelfde key).
// ============================================
class PlacePrediction {
  final String placeId;
  final String description; // bv. "Zonnelaan 12, 1234 AB Amersfoort, Nederland"
  const PlacePrediction({required this.placeId, required this.description});
}

class PlaceDetailsResult {
  final String formattedAddress;
  final LatLng coords;
  const PlaceDetailsResult({
    required this.formattedAddress,
    required this.coords,
  });
}

String newPlacesSessionToken() {
  // Google accepteert elke opaque string ≤36 chars als session token.
  // Mix van timestamp + 2 secure-random hex = uniek genoeg voor 1 sessie
  // zonder externe uuid-package.
  final r = math.Random.secure();
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final a = r.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  final b = r.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  return '$ts$a$b';
}

Future<List<PlacePrediction>> placesAutocompleteNL(
  String query, {
  required String sessionToken,
}) async {
  if (query.trim().length < 3) return const [];
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/place/autocomplete/json'
    '?input=${Uri.encodeComponent(query)}'
    '&components=country:nl'
    '&language=nl'
    '&types=address'
    '&sessiontoken=$sessionToken'
    '&key=$googleMapsApiKey',
  );
  try {
    final res = await http.get(url);
    if (res.statusCode != 200) return const [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    // OVER_QUERY_LIMIT / REQUEST_DENIED / INVALID_REQUEST → stil falen.
    // Geen rode SnackBar terwijl gebruiker typt.
    if (status != 'OK' && status != 'ZERO_RESULTS') return const [];
    final preds = (data['predictions'] as List? ?? const [])
        .map((p) => PlacePrediction(
              placeId: (p as Map)['place_id'] as String,
              description: p['description'] as String,
            ))
        .toList();
    return preds.take(5).toList();
  } catch (_) {
    // Netwerk-glitch tijdens typen → stilte is beter dan een error-popup.
    return const [];
  }
}

Future<PlaceDetailsResult> placeDetails(
  String placeId, {
  required String sessionToken,
}) async {
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/place/details/json'
    '?place_id=$placeId'
    '&fields=geometry,formatted_address'
    '&sessiontoken=$sessionToken'
    '&key=$googleMapsApiKey',
  );
  final res = await http.get(url);
  if (res.statusCode != 200) {
    throw Exception('Adres-details ophalen mislukt');
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (data['status'] != 'OK') {
    throw Exception('Adres niet gevonden bij Google (${data['status']})');
  }
  final result = data['result'] as Map<String, dynamic>;
  final loc = (result['geometry'] as Map)['location'] as Map;
  return PlaceDetailsResult(
    formattedAddress: result['formatted_address'] as String,
    coords: LatLng(
      (loc['lat'] as num).toDouble(),
      (loc['lng'] as num).toDouble(),
    ),
  );
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

  // Firebase init eerst — dit zet alleen de SDK op, vraagt nog géén push-
  // permissie. Dat doen we pas op het juiste moment in de app.
  await PluggoPush.instance.init();

  // Push action-buttons (task #292): MethodChannel-listener registreren
  // zodat lockscreen taps op "Verleng 15/30/60 min" een RPC-call triggeren.
  // Native (AppDelegate.swift) buffert eventuele cold-start events tot de
  // Dart-kant "ready" pingt — dat gebeurt in init() hier.
  unawaited(PluggoPushActions.instance.init());

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Stripe SDK initialiseren — alleen de publishable key, geen Apple Pay
  // merchant identifier (die voegen we toe als we Apple Pay aanzetten;
  // voor launch is iDEAL + kaart genoeg).
  //
  // applySettings() NIET awaiten en NOOIT laten blokkeren in main(): op
  // sommige Android-tablets (gezien op Samsung Tab A8 + Android 14, Unisoc
  // T618 zonder volledige Google Wallet) hangt de native Google Pay
  // readiness-check eindeloos. Zonder timeout/unawaited bleef de splash
  // hangen omdat runApp() nooit werd bereikt.
  //
  // Fire-and-forget met 5s timeout en stille catch — Stripe queue't calls
  // tot de SDK klaar is, dus bij feitelijk gebruik (checkout, onboarding)
  // wordt 'ie alsnog correct geïnitialiseerd door flutter_stripe zelf.
  Stripe.publishableKey = stripePublishableKey;
  unawaited(
    Stripe.instance
        .applySettings()
        .timeout(const Duration(seconds: 5))
        .catchError((_) {}),
  );

  // Vul de bypass-cache zodra Supabase staat. Als er een actieve session is,
  // checkt 'ie meteen of de user op de DB-lijst staat zodat de date-gate al
  // open is bij de eerste render. Geen await op het Future: we willen de
  // UI niet vertragen — bij een trage refresh ziet de tester even een
  // gesloten gate die binnen ~500ms opengaat zodra de fetch terug is.
  unawaited(refreshBypassEmailCache());

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
  final bool cableIncluded;
  final String accessType; // 'open', 'gate_code', 'doorbell', 'key', 'other'
  // Pionier-status van de eigenaar. Bepaalt of we de gouden badge tonen en
  // of deze paal voorrang krijgt in search results binnen hetzelfde
  // postcode-gebied. Komt uit profiles.is_pioneer via een PostgREST embed.
  final bool ownerIsPioneer;
  // True als `position` en `address` de exacte locatie zijn (owner of
  // confirmed booker). False als ze fuzzy zijn (publieke kaart, niet-
  // geboekte detail). De UI gebruikt deze vlag om "Open in Maps"-knoppen
  // te verbergen en een waarschuwing te tonen. Zie migratie 0010 en de
  // `chargers_public` view voor de server-kant.
  final bool isExactLocation;
  // Maximaal laadvermogen van de paal in kW. Uit `chargers.max_power_kw`
  // (nullable — eigenaar heeft 'm niet altijd ingevuld). Gebruikt voor
  // ETA-berekening in de LiveChargingCard: effective_kw = LEAST(paal, auto).
  // Zie migratie 0023.
  final double? maxPowerKw;

  // OCPP-koppeling: identifier waarmee deze paal bij het CSMS bekend staat
  // (chargers.ocpp_charger_id in de DB, gezet zodra de eigenaar de paal
  // met het OCPP-endpoint verbindt). Null zolang de paal 'unmanaged' is —
  // dan tonen we in de app géén "Start laden nu"/"Stop laden nu"-knoppen
  // want er is niks om een RemoteStart/Stop naartoe te sturen. Zie task
  // #293 en de remote-start-session / remote-stop-session edge functions.
  final String? ocppChargerId;

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
    this.cableIncluded = true,
    this.accessType = 'open',
    this.ownerIsPioneer = false,
    this.isExactLocation = false,
    this.maxPowerKw,
    this.ocppChargerId,
  });

  // Van een database-rij (Map) naar een Charger-object.
  //
  // `isExactLocation` moet door de caller worden meegegeven op basis van
  // de bron-tabel: `true` als de rij uit `chargers` komt (owner of
  // confirmed booker mag exacte locatie zien), `false` als hij uit de
  // `chargers_public` view komt (fuzzy locatie). Default false — bij
  // twijfel tonen we fuzzy, never exact.
  factory Charger.fromMap(
    Map<String, dynamic> map, {
    bool isExactLocation = false,
  }) {
    final photosRaw = map['photo_urls'];
    final photos = photosRaw is List
        ? photosRaw.whereType<String>().toList()
        : <String>[];
    // PostgREST embed levert profiles als nested object (`owner_profile`)
    // óf als losse `owner_is_pioneer` als we 't expliciet flattenen.
    // Bij geen embed (oude code-paden) is dit `false` — geen Pionier-badge.
    bool ownerIsPioneer = map['owner_is_pioneer'] as bool? ?? false;
    final ownerProfile = map['owner_profile'];
    if (ownerProfile is Map &&
        ownerProfile['is_pioneer'] is bool) {
      ownerIsPioneer = ownerProfile['is_pioneer'] as bool;
    }
    // `chargers_public` view geeft (nog) het volledige adres terug; we
    // derivaten hier client-side het fuzzy adres (alleen postcode+plaats).
    // Eigenaar/confirmed booker krijgen het echte adres één-op-één.
    final rawAddress = map['address'] as String;
    final displayedAddress =
        isExactLocation ? rawAddress : fuzzyAddress(rawAddress);
    return Charger(
      id: map['id'] as String,
      name: map['name'] as String,
      address: displayedAddress,
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
      cableIncluded: map['cable_included'] as bool? ?? true,
      accessType: map['access_type'] as String? ?? 'open',
      ownerIsPioneer: ownerIsPioneer,
      isExactLocation: isExactLocation,
      maxPowerKw: (map['max_power_kw'] as num?)?.toDouble(),
      // Alleen zichtbaar voor owner/booker via `chargers.*` (RLS + column
      // grants); publieke chargers_public view geeft dit nooit terug. Als
      // key ontbreekt of expliciet null is → paal is niet aan CSMS gekoppeld.
      ocppChargerId: map['ocpp_charger_id'] as String?,
    );
  }
}

// Maakt een fuzzy-versie van een adres door huisnummer + straatnaam weg te
// laten en alleen postcode + plaats (of alleen plaats) over te houden.
// Gebruikt op de publieke kaart en de detail-screen voor niet-boekers,
// zodat het thuisadres van de eigenaar niet wordt onthuld.
//
// "Berkenlaan 14, 3811 AB Amersfoort"   → "3811 AB Amersfoort"
// "Hoofdstraat 1A 1234 CD Utrecht"       → "1234 CD Utrecht"
// "testlaan 5 Amersfoort"                → "Amersfoort"
// "kruiskamp 14 amersfoort"              → "amersfoort"
// "storkstraat 6 Leusden"                → "Leusden"
// "Onbekend adres"                       → "Onbekend adres" (fallback)
//
// Algoritme:
//   1) Postcode-anker: NL-postcode (4 cijfers + 2 hoofdletters) — pak alles
//      vanaf de postcode.
//   2) Huisnummer-anker: eerste huisnummer in de string — pak alles erna.
//   3) Geen van beide gevonden: geef het origineel terug (geen leak — er
//      stond toch geen straatnummer in).
String fuzzyAddress(String exact) {
  final trimmed = exact.trim();

  // 1) Postcode-pad — "...3811 AB Amersfoort" → "3811 AB Amersfoort"
  final pcMatch =
      RegExp(r'(\d{4}\s?[A-Z]{2}.*)$').firstMatch(trimmed);
  if (pcMatch != null) {
    return pcMatch.group(1)!.trim();
  }

  // 2) Huisnummer-pad — "testlaan 5 Amersfoort" → "Amersfoort"
  //    \d+[A-Za-z]? vangt huisnummers met optionele letter-suffix (5, 14A).
  //    Daarna optionele komma + whitespace, dan capture wat overblijft.
  final nrMatch =
      RegExp(r'\d+[A-Za-z]?\s*,?\s*(.+)$').firstMatch(trimmed);
  if (nrMatch != null) {
    final after = nrMatch.group(1)!.trim();
    if (after.isNotEmpty) return after;
  }

  // 3) Geen huisnummer/postcode in het adres — niets te fuzzen.
  return trimmed;
}

// Display-labels en iconen voor access_type (één bron van waarheid).
const Map<String, String> kAccessTypeLabels = {
  'open': 'Vrij toegankelijk',
  'gate_code': 'Hek met code',
  'doorbell': 'Aanbellen bij aankomst',
  'key': 'Sleutel afhalen',
  'other': 'Anders (zie instructies)',
};

const Map<String, IconData> kAccessTypeIcons = {
  'open': Icons.home_outlined,
  'gate_code': Icons.lock_outline,
  'doorbell': Icons.doorbell_outlined,
  'key': Icons.key_outlined,
  'other': Icons.more_horiz_rounded,
};

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
  // Payment-velden — Stripe Connect Express + pay-after-charge refactor.
  // payment_status enum: 'unpaid' | 'pending' | 'paid' | 'failed' | 'refunded' | 'partially_refunded'
  final String paymentStatus;
  final int? totalAmountCents;
  // Pay-after-charge: owner vult kWh in na de laadbeurt, dan kan boeker betalen.
  final double? kwhConsumed;
  final DateTime? paymentRequestedAt;
  // SoC-velden voor OCPP-sessie (task #287): startSocPct is optioneel
  // — als user 'm bij boeken niet zette, kunnen we geen absoluut % tonen.
  // targetSocPct is NOT NULL in DB met default 80 (batterij-vriendelijk).
  // Zie migratie 0023.
  final int? startSocPct;
  final int targetSocPct;
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
    this.paymentStatus = 'unpaid',
    this.totalAmountCents,
    this.kwhConsumed,
    this.paymentRequestedAt,
    this.startSocPct,
    this.targetSocPct = 80,
    this.charger,
  });

  factory Booking.fromMap(Map<String, dynamic> map) {
    // Als we een joined charger meekregen, parsen we 'm ook. De
    // PostgREST-join leest uit de echte `chargers`-tabel (incl. exacte
    // lat/lng/address), maar de booker mag het exacte adres pas zien
    // ná confirmation. Daarom: status == 'confirmed' → exact, anders
    // fuzzy. Zie migratie 0010.
    Charger? charger;
    final chargerMap = map['chargers'];
    if (chargerMap is Map<String, dynamic>) {
      final isConfirmed = map['status'] == 'confirmed';
      charger = Charger.fromMap(chargerMap, isExactLocation: isConfirmed);
    }
    // kwh_consumed is numeric in DB → komt als num of String binnen
    double? parseKwh(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v)?.toLocal();
      return null;
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
      paymentStatus: (map['payment_status'] as String?) ?? 'unpaid',
      totalAmountCents: map['total_amount_cents'] as int?,
      kwhConsumed: parseKwh(map['kwh_consumed']),
      paymentRequestedAt: parseTs(map['payment_requested_at']),
      startSocPct: (map['start_soc_pct'] as num?)?.toInt(),
      // Default 80 als kolom om wat voor reden dan ook null zou zijn
      // (bestaat niet in de rij, oude data van vóór migratie 0023, etc.)
      targetSocPct: (map['target_soc_pct'] as num?)?.toInt() ?? 80,
      charger: charger,
    );
  }

  Duration get duration => endTime.difference(startTime);

  /// True als de boeking is afgelopen.
  bool get isFinished => DateTime.now().isAfter(endTime);

  /// True als de owner kWh moet invullen voor deze boeking.
  /// Voorwaarden: confirmed, eindtijd voorbij, kwh nog niet ingevuld,
  /// nog niet al betaald.
  bool get awaitingKwhInput =>
      status == 'confirmed' &&
      isFinished &&
      kwhConsumed == null &&
      paymentStatus != 'paid';

  /// True als de owner kWh heeft ingevuld én de boeker nog moet betalen.
  /// Toont in de UI de "Betalen"-knop met het exacte bedrag.
  bool get awaitingPayment =>
      status == 'confirmed' &&
      paymentRequestedAt != null &&
      (paymentStatus == 'unpaid' || paymentStatus == 'pending' ||
          paymentStatus == 'failed');

  bool get isPaid => paymentStatus == 'paid';
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
      // Global ScaffoldMessenger zodat PluggoPush vanuit foreground-handlers
      // SnackBars kan tonen zonder een BuildContext te kennen.
      scaffoldMessengerKey: PluggoPush.messengerKey,
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
  // Onthouden of we voor de huidige sessie de stille push-registratie al
  // hebben gedaan, zodat we het maar één keer per sessie aanroepen.
  String? _pushRegisteredForUserId;

  void _maybePushRegister() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _pushRegisteredForUserId = null;
      return;
    }
    if (_pushRegisteredForUserId == user.id) return;
    _pushRegisteredForUserId = user.id;
    // Geen await — pas op de achtergrond, mag de UI niet blokkeren.
    PluggoPush.instance.maybeRegisterAfterLogin();
  }

  @override
  void initState() {
    super.initState();
    // Bij cold start met bestaande sessie ook proberen.
    _maybePushRegister();
  }

  @override
  Widget build(BuildContext context) {
    // Luister naar auth state changes zodat UI direct reageert op login/logout
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Check de initiële session (direct na app-start)
        final session = supabase.auth.currentSession;
        // Bypass-cache opnieuw vullen bij iedere auth-state-change. Bij
        // login: check of deze user op de DB-lijst staat. Bij logout: zet
        // 'm op false zodat de date-gate weer dichtgaat. Fire-and-forget.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(refreshBypassEmailCache());
        });
        if (session != null) {
          // Stille registratie — alleen als user al permissie heeft gegeven.
          // De systeem-popup vragen we pas op een "echt event" moment.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybePushRegister();
          });
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
  // Eigen-actie buckets (geen viewed-flag, puur status-afgeleid):
  //   _kwhNeededOwner: afgelopen confirmed-boekingen op MIJN palen waar de
  //                    kWh nog ingevuld moet worden voordat de boeker kan betalen.
  //   _payNeededBooker: confirmed-boekingen waar IK boeker ben en de owner
  //                     het kWh-bedrag al heeft klaargezet — ik moet betalen.
  // Beide tellen mee in de profielicoon-badge én in een eigen badge per
  // menu-item, zodat een vereiste actie nooit meer onopgemerkt blijft.
  int _kwhNeededOwner = 0;
  int _payNeededBooker = 0;

  // Wordt true zodra de user permissie heeft gegeven; dan tonen we de blauwe dot
  bool _showMyLocation = false;
  // Voorkomt dat we meerdere keren tegelijk locatie proberen op te halen
  bool _locating = false;

  // Controller voor de sleepbare bottom sheet. Nodig om de sheet-hoogte
  // programmatisch te sturen wanneer de user op het grijze handvat sleept
  // (in plaats van op de scrollbare lijst eronder). Zonder eigen controller
  // is de handle een dood stuk UI — dan werkt slepen alleen op de kaarten.
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Snap-punten voor de bottom sheet — moeten overeenkomen met wat we aan
  // DraggableScrollableSheet zelf meegeven (snapSizes), anders spring hij
  // na drag-end naar een andere positie dan waar hij normaal snapt.
  static const List<double> _sheetSnaps = [0.18, 0.32, 0.85];

  @override
  void initState() {
    super.initState();
    _loadChargers();
    _loadUnreadIncoming();
    _loadUnreadReviews();
    _loadUnreadMessages();
    _loadKwhNeededOwner();
    _loadPayNeededBooker();
    // Bij elke toetsaanslag direct filteren (MVP-schaal is dit prima)
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // === Sleep-handlers voor het grijze handvat + header van de bottom sheet ===
  //
  // Zonder deze handlers is het handvat een dood stuk UI: de
  // DraggableScrollableSheet reageert alleen op scroll-gebaren binnen de
  // lijst eronder. Deze GestureDetector vertaalt vertikale drags op het
  // handvat/header direct naar sheet-hoogte-veranderingen via de controller.
  void _onSheetHandleDragUpdate(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight <= 0) return;
    final newSize = (_sheetController.size - details.delta.dy / screenHeight)
        .clamp(_sheetSnaps.first, _sheetSnaps.last);
    _sheetController.jumpTo(newSize);
  }

  void _onSheetHandleDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    // Snap naar dichtstbijzijnde snap-punt zodat het gedrag overeenkomt met
    // wat DraggableScrollableSheet zelf doet bij drags op de lijst.
    final current = _sheetController.size;
    final target = _sheetSnaps.reduce(
      (a, b) => (a - current).abs() < (b - current).abs() ? a : b,
    );
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
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
          // Booker-facing: paalprijs + €0,03 servicefee = wat de booker betaalt.
          snippet: '${formatBookerPricePerKwhLabel(charger.price)} · ${charger.type}',
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

  // Aantal afgelopen boekingen op MIJN palen waar ik nog kWh moet invullen
  // voordat de boeker kan betalen. Filtert in de DB op de meeste criteria;
  // de "is afgelopen"-check is end_time < now() — iets wat we hier rechtstreeks
  // aan Supabase meegeven via .lt zodat we ook geen null-rijen meekrijgen.
  Future<void> _loadKwhNeededOwner() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final data = await supabase
          .from('bookings')
          .select('id, chargers!inner(owner_id)')
          .eq('chargers.owner_id', userId)
          .eq('status', 'confirmed')
          .filter('kwh_consumed', 'is', null)
          .neq('payment_status', 'paid')
          .lt('end_time', nowIso);
      if (!mounted) return;
      setState(() {
        _kwhNeededOwner = (data as List).length;
      });
    } catch (_) {
      // Stil falen: badge blijft op vorige waarde
    }
  }

  // Aantal van mijn eigen boekingen waar ik nog moet betalen — dwz. de owner
  // heeft kWh ingevuld (payment_requested_at is not null) maar de status is
  // nog unpaid/pending/failed.
  Future<void> _loadPayNeededBooker() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await supabase
          .from('bookings')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'confirmed')
          .not('payment_requested_at', 'is', null)
          .neq('payment_status', 'paid');
      if (!mounted) return;
      setState(() {
        _payNeededBooker = (data as List).length;
      });
    } catch (_) {
      // Stil falen
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
      // Stap 1: alle palen ophalen, gesorteerd op aanmaakdatum (zoals
      // voorheen). We bevragen `chargers_public` (view), die FUZZY lat/lng
      // teruggeeft — exact thuisadres blijft voor de eigenaar / confirmed
      // booker. Zie migratie 0010_fuzzy_charger_location.sql.
      //
      // De view includeert al een `owner_profile` JSON met is_pioneer, dus
      // de oude separate profiles-query (hieronder) wordt feitelijk
      // redundant; we laten 'm voorlopig staan als veiligheidsnet voor
      // het geval een rij om wat voor reden dan ook geen embed heeft.
      final data = await supabase
          .from('chargers_public')
          .select()
          .order('created_at', ascending: false);

      var chargers = (data as List)
          .map((row) => Charger.fromMap(
                row as Map<String, dynamic>,
                isExactLocation: false,
              ))
          .toList();

      // Stap 2: voor alle unieke owner-IDs ophalen of ze Pionier zijn.
      // Eén losse query — minimale roundtrip, voorkomt N+1.
      final ownerIds = chargers
          .map((c) => c.ownerId)
          .whereType<String>()
          .toSet()
          .toList();
      final pioneerIds = <String>{};
      if (ownerIds.isNotEmpty) {
        try {
          final profileRows = await supabase
              .from('profiles')
              .select('id, is_pioneer')
              .inFilter('id', ownerIds)
              .eq('is_pioneer', true);
          for (final r in profileRows as List) {
            final m = r as Map<String, dynamic>;
            final pid = m['id'] as String?;
            if (pid != null) pioneerIds.add(pid);
          }
        } catch (_) {
          // Niet fataal — bij een fout tonen we gewoon geen Pionier-badges.
        }
      }

      // Pionier-vlag op de Charger-objecten zetten (we maken nieuwe instances
      // omdat Charger immutable is). We behouden bewust isExactLocation: false
      // — deze lijst komt uit de publieke map en blijft fuzzy.
      chargers = chargers
          .map((c) => Charger(
                id: c.id,
                name: c.name,
                address: c.address,
                price: c.price,
                type: c.type,
                available: c.available,
                solar: c.solar,
                position: c.position,
                description: c.description,
                instructions: c.instructions,
                ownerId: c.ownerId,
                ownerEmail: c.ownerEmail,
                photoUrls: c.photoUrls,
                cableIncluded: c.cableIncluded,
                accessType: c.accessType,
                isExactLocation: false,
                ownerIsPioneer:
                    c.ownerId != null && pioneerIds.contains(c.ownerId),
              ))
          .toList();

      // Sorteer: Pioniers bovenaan, daarna op aanmaakdatum (zoals voorheen).
      // Geo-afstand komt elders aan bod (filter op kaart), hier gaat het om
      // de list-volgorde in het bottom sheet / search results.
      chargers.sort((a, b) {
        if (a.ownerIsPioneer != b.ownerIsPioneer) {
          return a.ownerIsPioneer ? -1 : 1;
        }
        return 0; // behoud created_at-volgorde uit de query
      });

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
    // Stripe-gate: paaleigenaar moet BTW-status hebben ingevuld + Stripe
    // Connect-account verified (charges_enabled = true) voordat we PaymentIntents
    // met transfer_data.destination kunnen aanmaken. Zie ensureStripeReadyOrPrompt
    // voor de twee-staps flow (BTW-vragenlijst + Stripe-hosted KYC).
    final ok = await ensureStripeReadyOrPrompt(context);
    if (!ok) return;
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

  // Handler voor de "Notificaties"-knop in het profielmenu. Drie scenario's:
  //   • Permissie staat al aan → korte bevestiging via snackbar.
  //   • Permissie was nog niet gevraagd en user zegt nu ja → snackbar
  //     "Meldingen aangezet" + token wordt direct geregistreerd in DB.
  //   • Permissie is (eerder) geweigerd → dialoog met instructies om
  //     handmatig via OS-instellingen aan te zetten. iOS/Android tonen na
  //     een eerdere "Niet toestaan" geen tweede dialoog meer.
  Future<void> _handleNotificationsAction() async {
    final outcome = await PluggoPush.instance.requestForUserActionButton();
    if (!mounted) return;

    switch (outcome) {
      case NotificationActionOutcome.alreadyEnabled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Meldingen staan al aan'),
            duration: Duration(seconds: 3),
          ),
        );
        break;
      case NotificationActionOutcome.justEnabled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Meldingen aangezet'),
            duration: Duration(seconds: 3),
          ),
        );
        break;
      case NotificationActionOutcome.denied:
        await showDialog<void>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Meldingen aanzetten'),
            content: const Text(
              'Pluggo mag op dit toestel geen meldingen sturen. Zet ze aan '
              'via je telefoon-instellingen:\n\n'
              '1. Open de instellingen van je telefoon\n'
              '2. Ga naar Apps → Pluggo → Meldingen\n'
              '   (iOS: Instellingen → Pluggo → Berichtgeving)\n'
              '3. Zet meldingen aan\n\n'
              'Sluit Pluggo daarna helemaal af (uit recents vegen) en open '
              "'m opnieuw. Dan worden je notificaties geregistreerd.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Begrepen'),
              ),
            ],
          ),
        );
        break;
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
                    // Badges opnieuw ophalen zodra je terug bent — zowel
                    // 'nieuwe boeking' als 'kWh nodig' staan in dit scherm.
                    _loadUnreadIncoming();
                    _loadKwhNeededOwner();
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
                        // Som van nieuwe-boeking + kWh-nodig badges.
                        // Beide acties leven in IncomingBookingsScreen, dus
                        // we plakken ze samen tot één duidelijk getal.
                        if (_unreadIncoming + _kwhNeededOwner > 0) ...[
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
                              '${_unreadIncoming + _kwhNeededOwner}',
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
                        builder: (_) => const MyBookingsScreen(),
                      ),
                    );
                    // Na terugkeer badge opnieuw ophalen — als de boeker
                    // 'm betaald heeft moet de telling naar 0.
                    _loadPayNeededBooker();
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
                        // Badge wanneer er een betaling openstaat (owner heeft
                        // kWh ingevuld maar boeker heeft nog niet betaald).
                        if (_payNeededBooker > 0) ...[
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
                              '$_payNeededBooker',
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
                // Notificaties — herstel-knop voor testers/users die de
                // permissie-dialoog hebben afgewezen of nooit zagen.
                // Zonder deze knop moeten ze handmatig via OS-instellingen,
                // wat veel testers niet zelf doen.
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _handleNotificationsAction();
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
                          Icons.notifications_active_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Notificaties',
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
                    // Eerst FCM token los koppelen — anders blijven pushes
                    // bedoeld voor de oude user op dit toestel binnenkomen
                    // als iemand anders straks inlogt.
                    await PluggoPush.instance.unregisterCurrentDevice();
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

      // 5) FCM token lokaal weggooien zodat de volgende inlog-user op dit
      //    device een vers token krijgt (DB-rij wordt sowieso al door
      //    cascade op auth.users.delete opgeruimd).
      await PluggoPush.instance.unregisterCurrentDevice();

      // 6) Sign out — AuthGate stuurt terug naar login
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
                          _loadKwhNeededOwner();
                          _loadPayNeededBooker();
                        },
                      ),
                      const SizedBox(width: 8),
                      _roundIconButton(
                        icon: Icons.person_outline_rounded,
                        onTap: _showProfileSheet,
                        // Profielicoon-badge: som van álle vereiste acties.
                        badgeCount: _unreadIncoming +
                            _unreadReviews +
                            _unreadMessages +
                            _kwhNeededOwner +
                            _payNeededBooker,
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
            controller: _sheetController,
            initialChildSize: 0.32,
            minChildSize: _sheetSnaps.first,
            maxChildSize: _sheetSnaps.last,
            snap: true,
            snapSizes: _sheetSnaps,
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
                    // Sleep-zone: handvat + header + banner reageren allemaal
                    // op vertikale drags via de sheet-controller. HitTestBehavior
                    // .opaque zorgt dat óók de lege ruimtes tussen widgets drag-
                    // gebaren opvangen — anders werkt slepen alleen op het
                    // handvat zelf en niet op de omringende padding.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _onSheetHandleDragUpdate,
                      onVerticalDragEnd: _onSheetHandleDragEnd,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
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
                          // de palenlijst opent dat boekingen op 7 juli open
                          // gaan.
                          if (!bookingsAreLive)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: const LaunchCountdownBanner(),
                            ),
                        ],
                      ),
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

// ============================================
// ensureIbanOrPrompt — gate voor het paal-toevoegen-flow.
// Returnt true als de gebruiker een IBAN heeft (of er net één heeft
// ingevuld via de prompt). Returnt false als de gebruiker afziet —
// dan blokkeren we het toevoegen.
// ============================================
Future<bool> ensureIbanOrPrompt(BuildContext context) async {
  final iban = await fetchCurrentUserIban();
  if (iban != null) return true;
  if (!context.mounted) return false;

  // Vraag toestemming om door te gaan naar het profielscherm.
  final goToProfile = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('IBAN nodig'),
      content: const Text(
        'Om een paal aan te bieden hebben we je IBAN nodig. '
        'Pluggo int de betalingen van boekers en stort jouw aandeel '
        '(je paalprijs minus €0,03/kWh servicefee) elke 14 dagen op je rekening.\n\n'
        'Wil je je IBAN nu invullen?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Later'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Invullen'),
        ),
      ],
    ),
  );

  if (goToProfile != true) return false;
  if (!context.mounted) return false;

  // Stuur door naar het profielscherm. Daar kunnen ze IBAN invullen
  // en opslaan; bij terugkeer checken we opnieuw of er nu wél een IBAN is.
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
  );
  final ibanAfter = await fetchCurrentUserIban();
  return ibanAfter != null;
}

// ============================================
// ensureStripeReadyOrPrompt — gate voor de paal-toevoegen-flow onder Stripe.
//
// Vervangt ensureIbanOrPrompt() voor Stripe Connect: bij Stripe verzamelt
// Stripe-hosted KYC zelf IBAN + KvK + identiteit, dus we hoeven die niet
// langer in-app te vragen. Wel hebben we 2 voorvragen nodig:
//
//   1. business_type (particulier/eenmanszaak/bv/overig) — bepaalt of we
//      straks een KOR-factuur of BTW-factuur genereren. Stripe weet dit niet.
//   2. stripe_charges_enabled == true — pas dan kunnen we PaymentIntents
//      met transfer_data.destination = dit account aanmaken.
//
// Flow:
//   • Mist business_type → dialoog → BtwVragenlijstScreen (Save = pop(true))
//   • Geen Stripe account of charges nog uit → dialoog → StripeOnboardingScreen
//   • Beide vereisten OK → return true → caller mag AddChargerScreen openen
//
// Returnt false zodra de gebruiker ergens afhaakt (cancel / dialoog 'Later').
// ============================================
Future<bool> ensureStripeReadyOrPrompt(BuildContext context) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;

  // 1. Eén roundtrip naar de DB — pak alles wat we nodig hebben.
  Map<String, dynamic>? row;
  try {
    row = await supabase
        .from('profiles')
        .select('business_type, stripe_account_id, stripe_charges_enabled')
        .eq('id', userId)
        .maybeSingle();
  } catch (e) {
    debugPrint('ensureStripeReadyOrPrompt: fetch failed: $e');
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kon profiel niet ophalen, probeer opnieuw')),
    );
    return false;
  }

  final businessType = row?['business_type'] as String?;
  final stripeAccountId = row?['stripe_account_id'] as String?;
  final chargesEnabled = (row?['stripe_charges_enabled'] as bool?) ?? false;

  // 2. Check 1 — BTW-vragenlijst. Dit moet áltijd eerst, omdat de
  // stripe-onboard-account edge function 409 teruggeeft zonder business_type.
  if (businessType == null) {
    if (!context.mounted) return false;
    final goToBtw = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Even 3 korte vragen'),
        content: const Text(
          'Voordat je je paal aanbiedt vragen we 3 dingen over je '
          'belastingsituatie. Dit hebben we nodig om straks de juiste '
          'factuur voor je te maken.\n\n'
          'Duurt minder dan een minuut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Starten'),
          ),
        ],
      ),
    );
    if (goToBtw != true) return false;
    if (!context.mounted) return false;

    final btwSaved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BtwVragenlijstScreen()),
    );
    if (btwSaved != true) return false;
    // BTW gelukt — val door naar Stripe-check hieronder.
  }

  // 3. Check 2 — Stripe Connect account verified.
  // chargesEnabled is true alleen ná succesvolle KYC-verificatie door Stripe.
  if (!chargesEnabled) {
    if (!context.mounted) return false;
    final goToStripe = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Verifiëren bij Stripe'),
        content: Text(
          stripeAccountId == null
              ? 'Pluggo gebruikt Stripe om betalingen veilig af te handelen. '
                'We sturen je nu door naar Stripe voor een korte verificatie '
                '(KvK, IBAN, identiteit). Duurt 3–5 minuten.\n\n'
                'Pas daarna kun je je eerste paal aanbieden.'
              : 'Je Stripe-verificatie is nog niet afgerond. '
                'We sturen je opnieuw naar Stripe om \'m af te maken.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Naar Stripe'),
          ),
        ],
      ),
    );
    if (goToStripe != true) return false;
    if (!context.mounted) return false;

    // StripeOnboardingScreen popt met `true` zodra charges_enabled = true.
    // Vóór die tijd kan de gebruiker via back-button met null/false weggaan.
    final stripeOk = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StripeOnboardingScreen()),
    );
    if (stripeOk != true) {
      // Eén extra DB-check: deep-link kan onboarding op de achtergrond hebben
      // afgerond (account.updated webhook → charges_enabled = true) terwijl
      // het scherm met pop(null) sloot. Liever 1 extra query dan gebruiker
      // onterecht blokkeren.
      try {
        final recheck = await supabase
            .from('profiles')
            .select('stripe_charges_enabled')
            .eq('id', userId)
            .maybeSingle();
        return (recheck?['stripe_charges_enabled'] as bool?) == true;
      } catch (_) {
        return false;
      }
    }
  }

  return true;
}

// ============================================
// BtwVragenlijstScreen — verplichte 3-vragen-check vóór Stripe-onboarding.
//
// Stripe Connect Express wil straks zelf de IBAN, KvK-nummer en
// identiteit verifiëren via z'n eigen hosted KYC. Maar Pluggo heeft de
// `business_type` + `vat_status` velden nodig om straks de juiste
// self-billing-factuur (KOR-template óf BTW-template) te genereren —
// die invoice engine moet weten of de paaleigenaar BTW aftrekt of niet.
//
// We vragen daarom 3 dingen vooraf en slaan ze op in profiles. Bij
// 'particulier' of geen-onderneming wordt vat_status automatisch 'none'
// (geen optie tot KOR/BTW). Bij eenmanszaak/bv vragen we KvK-nummer
// (8 cijfers, formaat-validatie) en BTW-status (KOR of plichtig).
//
// Dit scherm is reusable: ook later vanuit profielinstellingen openbaar
// te maken als de paaleigenaar van rechtsvorm wisselt.
// ============================================
class BtwVragenlijstScreen extends StatefulWidget {
  const BtwVragenlijstScreen({Key? key}) : super(key: key);

  @override
  State<BtwVragenlijstScreen> createState() => _BtwVragenlijstScreenState();
}

class _BtwVragenlijstScreenState extends State<BtwVragenlijstScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _kvkController = TextEditingController();

  // De keuzes komen 1-op-1 overeen met de Postgres enums in migratie 0012.
  // Niet aanpassen zonder ook de enum te migreren.
  String? _businessType; // 'particulier' | 'eenmanszaak' | 'bv' | 'overig'
  String? _vatStatus; // 'none' | 'kor' | 'btw_plichtig'

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _kvkController.dispose();
    super.dispose();
  }

  /// Laad bestaande waardes — zodat een eigenaar die later 'm opnieuw opent
  /// (bv. vanuit instellingen) z'n eerdere keuze ziet en hoeft alleen het
  /// gewijzigde veld aan te passen.
  Future<void> _loadExisting() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await supabase
          .from('profiles')
          .select('business_type, vat_status, kvk_number')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _businessType = row?['business_type'] as String?;
        _vatStatus = row?['vat_status'] as String?;
        final kvk = row?['kvk_number'] as String?;
        if (kvk != null) _kvkController.text = kvk;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Helper: heeft de gekozen bedrijfsvorm een KvK-nummer nodig?
  bool get _needsKvk =>
      _businessType == 'eenmanszaak' || _businessType == 'bv';

  /// Helper: kan de gebruiker tussen KOR en BTW-plichtig kiezen?
  /// Particulieren zonder onderneming kunnen niet onder BTW vallen.
  bool get _canChooseVat => _businessType != null && _businessType != 'particulier';

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_businessType == null) {
      _showError('Kies een bedrijfsvorm');
      return;
    }

    // Auto-defaults voor vat_status: particulieren krijgen 'none',
    // de rest moet expliciet kiezen.
    final effectiveVatStatus = _businessType == 'particulier'
        ? 'none'
        : _vatStatus;
    if (effectiveVatStatus == null) {
      _showError('Kies of je KOR-ondernemer of BTW-plichtig bent');
      return;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _showError('Niet ingelogd');
      return;
    }

    setState(() => _saving = true);
    try {
      await supabase.from('profiles').update({
        'business_type': _businessType,
        'vat_status': effectiveVatStatus,
        // KvK alleen opslaan als 'ie relevant is voor deze rechtsvorm,
        // anders wissen (gebruiker kan terug naar particulier wisselen).
        'kvk_number':
            _needsKvk ? _kvkController.text.trim() : null,
      }).eq('id', userId);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError('Opslaan mislukt: $e');
      setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
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
        title: const Text('Voor we beginnen'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    // ---------- Intro ----------
                    Text(
                      'Vertel ons even wat je situatie is',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We hebben dit nodig om straks de juiste factuur voor je '
                      'verdiensten te maken. Stripe verifieert daarna apart je '
                      'identiteit en bankrekening.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---------- Vraag 1: bedrijfsvorm ----------
                    _SectionLabel('Wat is je situatie?'),
                    _RadioTile(
                      title: 'Particulier',
                      subtitle: 'Ik heb geen onderneming',
                      value: 'particulier',
                      groupValue: _businessType,
                      onChanged: (v) => setState(() {
                        _businessType = v;
                        if (v == 'particulier') _vatStatus = 'none';
                      }),
                    ),
                    _RadioTile(
                      title: 'ZZP / eenmanszaak',
                      subtitle: 'Ik heb een KvK-inschrijving als eenmanszaak',
                      value: 'eenmanszaak',
                      groupValue: _businessType,
                      onChanged: (v) => setState(() => _businessType = v),
                    ),
                    _RadioTile(
                      title: 'BV',
                      subtitle: 'Besloten vennootschap met KvK-inschrijving',
                      value: 'bv',
                      groupValue: _businessType,
                      onChanged: (v) => setState(() => _businessType = v),
                    ),
                    _RadioTile(
                      title: 'Anders',
                      subtitle: 'VvE, stichting, vereniging, etc.',
                      value: 'overig',
                      groupValue: _businessType,
                      onChanged: (v) => setState(() => _businessType = v),
                    ),

                    // ---------- Vraag 2: KvK (conditional) ----------
                    if (_needsKvk) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('KvK-nummer'),
                      TextFormField(
                        controller: _kvkController,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: InputDecoration(
                          hintText: '12345678',
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) {
                          if (!_needsKvk) return null;
                          final cleaned = v?.trim() ?? '';
                          if (cleaned.isEmpty) return 'KvK-nummer is verplicht';
                          if (!RegExp(r'^\d{8}$').hasMatch(cleaned)) {
                            return 'KvK-nummer is 8 cijfers';
                          }
                          return null;
                        },
                      ),
                    ],

                    // ---------- Vraag 3: BTW-status (conditional) ----------
                    if (_canChooseVat) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Hoe zit het met BTW?'),
                      _RadioTile(
                        title: 'KOR-ondernemer',
                        subtitle:
                            'Ik val onder de Kleine Ondernemers Regeling '
                            '(omzet onder €20.000 per jaar). Ik draag geen BTW af.',
                        value: 'kor',
                        groupValue: _vatStatus,
                        onChanged: (v) => setState(() => _vatStatus = v),
                      ),
                      _RadioTile(
                        title: 'BTW-plichtig',
                        subtitle:
                            'Ik draag zelf BTW af aan de Belastingdienst. '
                            'Pluggo voegt 21% BTW toe aan je verdiensten.',
                        value: 'btw_plichtig',
                        groupValue: _vatStatus,
                        onChanged: (v) => setState(() => _vatStatus = v),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ---------- Opslaan ----------
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Opslaan en doorgaan',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
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

/// Kleine helper-widget voor section labels boven inputs.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ============================================
// StripeOnboardingScreen — paaleigenaar wordt naar Stripe-hosted KYC gestuurd.
//
// Flow:
//   1. Bij open: profiel ophalen (stripe_account_id + status-flags)
//   2. Al verified? → success-state met "Doorgaan"-knop, pop(true)
//   3. Nog niet? → "Start onboarding"-knop
//      → roept StripeService.startOnboarding() aan (POST naar edge function)
//      → krijgt onboarding_url terug (kortlevende Stripe-hosted URL)
//      → opent URL via url_launcher externalApplication (Safari/Chrome)
//   4. Gebruiker doorloopt Stripe-flow (KYC, bankrekening, identiteit)
//      → Stripe redirect naar pluggo://onboarding/stripe-complete OF
//        pluggo://onboarding/stripe-refresh (deep links in stap 5)
//   5. Bij terugkeer in app (AppLifecycleState.resumed): profiel opnieuw
//      ophalen — als webhook account.updated al binnen is, staat
//      stripe_charges_enabled = true en zien we de success-state.
//
// Webhook-timing: account.updated kan ~5s nadat de gebruiker klikt op
// "submit" bij Stripe binnenkomen. Daarom is er ook een handmatige
// "Status verversen"-knop voor als de eerste auto-refresh nog te vroeg is.
// ============================================
class StripeOnboardingScreen extends StatefulWidget {
  const StripeOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<StripeOnboardingScreen> createState() => _StripeOnboardingScreenState();
}

class _StripeOnboardingScreenState extends State<StripeOnboardingScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _starting = false;

  // Profiel-velden uit Supabase (zie 0013_stripe_payment_schema.sql)
  String? _stripeAccountId;
  String? _stripeAccountStatus; // 'pending' | 'review' | 'verified' | …
  bool _chargesEnabled = false;
  bool _payoutsEnabled = false;
  bool _detailsSubmitted = false;
  String? _disabledReason;
  List<String> _currentlyDue = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Wanneer de gebruiker terugkomt uit een externe browser (Stripe-hosted
  /// KYC voltooid), triggert iOS/Android een resume. We refreshen dan
  /// automatisch de profiel-status. Geen polling — één refresh is genoeg
  /// omdat onze deep links daarna ook nog een handmatige refresh kunnen
  /// triggeren (stap 5).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // Eerste pass: lees huidige DB-state zodat de UI iets kan tonen.
      var row = await supabase
          .from('profiles')
          .select(
            'stripe_account_id, stripe_account_status, '
            'stripe_charges_enabled, stripe_payouts_enabled, '
            'stripe_details_submitted, stripe_disabled_reason, '
            'stripe_currently_due',
          )
          .eq('id', userId)
          .maybeSingle();

      // Self-healing tegen kapotte webhook-delivery: als er een Stripe
      // account bestaat maar de status nog niet 'verified' is, roepen we
      // stripe-refresh-account aan. Die polt Stripe direct en syncet de
      // profiel-velden. Daarna lezen we de DB nogmaals zodat de UI de
      // verse state ziet zonder dat de gebruiker uit en weer inloggen
      // hoeft. Faalt de refresh (netwerk/500)? Slikken we in — de
      // eerste-pass state blijft dan gewoon zichtbaar.
      //
      // Dit is bewust idempotent: verified accounts skippen we (geen
      // onnodige Stripe API-calls). Accounts zonder stripe_account_id
      // ook (er valt niks te syncen).
      final currentAccountId = row?['stripe_account_id'] as String?;
      final currentStatus = row?['stripe_account_status'] as String?;
      final shouldRefresh = currentAccountId != null &&
          currentAccountId.isNotEmpty &&
          currentStatus != 'verified' &&
          currentStatus != 'rejected';

      if (shouldRefresh) {
        try {
          await StripeService.instance.refreshAccountStatus();
          // Herlees na de refresh; de edge function heeft de rij bijgewerkt.
          row = await supabase
              .from('profiles')
              .select(
                'stripe_account_id, stripe_account_status, '
                'stripe_charges_enabled, stripe_payouts_enabled, '
                'stripe_details_submitted, stripe_disabled_reason, '
                'stripe_currently_due',
              )
              .eq('id', userId)
              .maybeSingle();
        } catch (e) {
          debugPrint('_loadStatus: refresh mislukt, val terug op DB-state: $e');
          // Bewust geen SnackBar — dit is een silent best-effort refresh.
        }
      }

      if (!mounted) return;
      setState(() {
        _stripeAccountId = row?['stripe_account_id'] as String?;
        _stripeAccountStatus = row?['stripe_account_status'] as String?;
        _chargesEnabled = (row?['stripe_charges_enabled'] as bool?) ?? false;
        _payoutsEnabled = (row?['stripe_payouts_enabled'] as bool?) ?? false;
        _detailsSubmitted = (row?['stripe_details_submitted'] as bool?) ?? false;
        _disabledReason = row?['stripe_disabled_reason'] as String?;
        final due = row?['stripe_currently_due'];
        _currentlyDue = due is List
            ? due.map((e) => e.toString()).toList()
            : <String>[];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kon Stripe-status niet laden: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _startOnboarding() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final result = await StripeService.instance.startOnboarding();
      if (!mounted) return;

      // Open de Stripe-hosted KYC URL in een externe browser. We kiezen
      // bewust externalApplication ipv inAppWebView omdat:
      //   • Stripe's KYC flow Apple Pay / iCloud Keychain integratie
      //     nodig kan hebben, dat werkt niet in een WKWebView.
      //   • Stripe ondersteunt zelf de meeste auth-providers (banken,
      //     iDIN) die WebViews blokkeren via X-Frame-Options.
      //   • Bij voltooiing redirect Stripe naar onze deep link, die
      //     iOS/Android terug naar de app brengt — geen WebView-pop nodig.
      final uri = Uri.parse(result.onboardingUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StripeServiceException('Kon Stripe-pagina niet openen');
      }
      // Wacht op return via lifecycle resume → _loadStatus() doet de rest.
    } on StripeServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Onbekende fout: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  // --------------------------------------------------------------------------
  // Status-mapping → 4 visuele states
  //
  //   1. notStarted   — geen stripe_account_id    → "Start onboarding"
  //   2. inProgress   — account_id + !verified    → "Hervat onboarding"
  //   3. actionNeeded — currently_due not empty   → "Los openstaande punten op"
  //   4. verified     — charges_enabled = true    → "Doorgaan" (success)
  // --------------------------------------------------------------------------
  _OnboardingVisualState get _visualState {
    if (_chargesEnabled) return _OnboardingVisualState.verified;
    if (_stripeAccountId == null || _stripeAccountId!.isEmpty) {
      return _OnboardingVisualState.notStarted;
    }
    if (_currentlyDue.isNotEmpty || _disabledReason != null) {
      return _OnboardingVisualState.actionNeeded;
    }
    return _OnboardingVisualState.inProgress;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Uitbetalingen via Stripe'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Status verversen',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadStatus,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _statusCard(),
                  const SizedBox(height: 20),
                  _infoCard(),
                  const SizedBox(height: 24),
                  _primaryButton(),
                ],
              ),
            ),
    );
  }

  Widget _statusCard() {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String title;
    late final String body;

    switch (_visualState) {
      case _OnboardingVisualState.verified:
        bg = AppColors.primarySoft;
        fg = AppColors.primaryDark;
        icon = Icons.check_circle_rounded;
        title = 'Geverifieerd';
        body =
            'Stripe heeft je gegevens goedgekeurd. Je kunt nu betalingen '
            'ontvangen. Uitbetalingen gaan automatisch.';
        break;
      case _OnboardingVisualState.actionNeeded:
        bg = AppColors.warningSoft;
        fg = AppColors.warningDark;
        icon = Icons.warning_amber_rounded;
        title = 'Actie vereist';
        body = _disabledReason != null
            ? 'Stripe vraagt extra gegevens: ${_friendlyDisabledReason(_disabledReason!)}'
            : 'Stripe heeft nog wat informatie nodig om je account te '
                  'verifiëren. Klik hieronder om de ontbrekende gegevens '
                  'aan te vullen.';
        break;
      case _OnboardingVisualState.inProgress:
        bg = AppColors.solarSoft;
        fg = const Color(0xFF8A5300);
        icon = Icons.hourglass_top_rounded;
        title = 'In behandeling';
        body =
            'Je hebt je gegevens ingediend. Stripe verifieert ze meestal '
            'binnen enkele minuten. Soms duurt het tot een werkdag bij '
            'aanvullende identiteits-checks.';
        break;
      case _OnboardingVisualState.notStarted:
        bg = AppColors.primarySoft;
        fg = AppColors.primaryDark;
        icon = Icons.account_balance_rounded;
        title = 'Nog niet gestart';
        body =
            'Om betalingen te ontvangen, koppel je Pluggo aan Stripe. '
            'Je doorloopt eenmalig een korte verificatie op Stripe.com.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: fg,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wat ga je doen?',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _bullet('Persoonsgegevens invullen'),
          _bullet('Bankrekening koppelen (IBAN)'),
          _bullet('Adres bevestigen'),
          const SizedBox(height: 8),
          // Tip alleen voor nieuwe gebruikers — Stripe vraagt tijdens KYC om
          // een website of productomschrijving. Voor particulieren zonder
          // eigen website is dat verwarrend. Door pluggoapp.nl in te vullen
          // scrapet Stripe zelf de productinfo en hoeft de gebruiker niets
          // meer te typen.
          if (_visualState == _OnboardingVisualState.notStarted)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '💡 Tip: bij "website" kun je pluggoapp.nl invullen. '
                'De rest vult Stripe dan zelf in. Soms vraagt Stripe om '
                'een ID of paspoort — meestal niet nodig.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.primaryDark,
                  height: 1.4,
                ),
              ),
            ),
          Text(
            'Stripe vraagt deze info omdat ze als betaaldienst onder Europese '
            'wetgeving (PSD2) moeten weten wie je bent. Je gegevens blijven '
            'bij Stripe — Pluggo ziet ze niet.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton() {
    late final String label;
    late final VoidCallback? onPressed;
    late final IconData icon;

    switch (_visualState) {
      case _OnboardingVisualState.verified:
        label = 'Doorgaan';
        icon = Icons.arrow_forward_rounded;
        onPressed = () => Navigator.pop(context, true);
        break;
      case _OnboardingVisualState.actionNeeded:
        label = 'Openstaande punten oplossen';
        icon = Icons.open_in_new_rounded;
        onPressed = _starting ? null : _startOnboarding;
        break;
      case _OnboardingVisualState.inProgress:
        // Je hebt KYC al ingediend, Stripe verifieert nog. Primaire actie =
        // status hertesten (webhook kan elk moment binnenkomen). "Hervat
        // onboarding" zou misleidend zijn — er valt niets te hervatten, en
        // klikken stuurt je naar Stripe's summary-scherm waar je alleen je
        // gegevens opnieuw kunt bekijken. Voor de zeldzame gevallen dat je
        // tóch terug naar Stripe wilt (bv. ander IBAN invoeren) is er een
        // secundaire tekstlink onder de hoofdknop.
        label = 'Status verversen';
        icon = Icons.refresh_rounded;
        onPressed = _loading ? null : _loadStatus;
        break;
      case _OnboardingVisualState.notStarted:
        label = 'Start onboarding op Stripe';
        icon = Icons.open_in_new_rounded;
        onPressed = _starting ? null : _startOnboarding;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: onPressed,
            icon: _starting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, size: 20),
            label: Text(
              _starting ? 'Bezig met laden…' : label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        // Secundaire escape-hatch alleen tonen tijdens "In behandeling": als
        // paaleigenaar tóch terug naar Stripe wil (ander IBAN, andere ID).
        // Niet de primaire actie omdat 99% van de gebruikers gewoon moet
        // wachten op de webhook.
        if (_visualState == _OnboardingVisualState.inProgress) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _starting ? null : _startOnboarding,
            child: Text(
              'Gegevens aanpassen in Stripe',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Vertaal Stripe's English `disabled_reason` strings naar iets dat
  /// een paaleigenaar begrijpt. Niet exhaustief — onbekende reasons
  /// vallen terug op de raw string.
  String _friendlyDisabledReason(String reason) {
    switch (reason) {
      case 'requirements.past_due':
        return 'Er staan verplichte velden open die de deadline hebben '
            'gepasseerd. Vul ze nu in om uitbetalingen te hervatten.';
      case 'requirements.pending_verification':
        return 'Stripe is je gegevens aan het controleren. Dit duurt '
            'meestal een werkdag.';
      case 'rejected.fraud':
      case 'rejected.terms_of_service':
      case 'rejected.listed':
      case 'rejected.other':
        return 'Stripe heeft je account geweigerd. Neem contact op met '
            'support@pluggoapp.nl voor hulp.';
      case 'listed':
        return 'Stripe controleert je gegevens tegen sanctielijsten.';
      case 'under_review':
        return 'Je account staat onder review bij Stripe.';
      default:
        return reason; // raw string voor onbekende codes
    }
  }
}

enum _OnboardingVisualState { notStarted, inProgress, actionNeeded, verified }

/// Radio-tile in card-stijl, past beter bij Pluggo's look dan de
/// default Material RadioListTile.
class _RadioTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
  bool _cableIncluded = true;
  String _accessType = 'open';
  bool _saving = false;

  // Coords van het door user gekozen Google Places-adres. Null = nog niks
  // gekozen (of selectie overschreven door verder typen). Bij submit moet
  // dit gezet zijn — anders weigert de form, want zonder lat/lng-paar
  // belandt de paal niet op de kaart.
  LatLng? _selectedCoords;

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

    // Adres moet via de autocomplete-suggesties gekozen zijn. Zonder
    // _selectedCoords hebben we geen geverifieerd geocodeerbaar adres,
    // en eindigt de paal mogelijk op het verkeerde punt of helemaal niet
    // op de kaart.
    if (_selectedCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kies je adres uit de suggesties hierboven'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prijs is geen geldig getal (bijv. 0,35)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Stap 1: gebruik de lat/lng die Google Places ons al gaf bij selectie
      // — geen extra Geocoding-call nodig (scheelt latency + 1 API-call).
      final coords = _selectedCoords!;

      // Stap 2: sla op in Supabase (owner_id is vereist door RLS)
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Je bent niet ingelogd');
      }

      // Insert met .select('id').single(). We selecteren bewust alleen
      // `id` omdat authenticated sinds 0030 geen SELECT-grant meer heeft
      // op alle kolommen (lat/lng geblokkeerd — anders zou een INSERT
      // ... RETURNING * hier falen). Voor het volledige owner-view-object
      // fetchen we hieronder via `my_chargers()`.
      final inserted = await supabase
          .from('chargers')
          .insert({
            'name': _nameController.text.trim(),
            'address': _addressController.text.trim(),
            'price': price,
            'type': _selectedType,
            'available': true,
            'solar': _isSolar,
            'cable_included': _cableIncluded,
            'access_type': _accessType,
            'lat': coords.latitude,
            'lng': coords.longitude,
            'description': _descriptionController.text.trim(),
            'instructions': _instructionsController.text.trim(),
            'owner_id': userId,
            'owner_email': supabase.auth.currentUser?.email,
          })
          .select('id')
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
          content: Text('Paal toegevoegd! Stel nu de beschikbaarheid in.'),
          backgroundColor: AppColors.primary,
        ),
      );

      // "Eerste echt event" voor eigenaren: ze willen weten wanneer er een
      // boeking binnenkomt. Vraag nu om push-permissie (alleen de eerste
      // keer is er een dialoog; daarna no-op). Fire-and-forget.
      // ignore: unawaited_futures
      PluggoPush.instance.requestPermissionAndRegister();

      // Bouw een Charger-object van de zojuist ingevoegde rij. De insert
      // hierboven gaf alleen `id` terug (owner heeft geen SELECT-grant
      // meer op lat/lng sinds 0030), dus we halen de volledige rij nu op
      // via my_chargers() — dat draait als SECURITY DEFINER en levert
      // álle kolommen voor eigen palen. Als de refetch mislukt vallen we
      // terug op de form-values (die matchen wat we net inserted hebben).
      Map<String, dynamic> freshRow = <String, dynamic>{
        'id': chargerId,
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'price': price,
        'type': _selectedType,
        'available': true,
        'solar': _isSolar,
        'cable_included': _cableIncluded,
        'access_type': _accessType,
        'lat': coords.latitude,
        'lng': coords.longitude,
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'owner_id': userId,
        'owner_email': supabase.auth.currentUser?.email,
        'photo_urls': const <String>[],
      };
      try {
        final rows = await supabase
            .rpc('my_chargers')
            .eq('id', chargerId);
        if (rows is List && rows.isNotEmpty) {
          freshRow = Map<String, dynamic>.from(rows.first as Map);
        }
      } catch (_) {
        // Niet-fataal — form-values-fallback hierboven vangt dit op.
        // AvailabilityScreen gebruikt toch alleen charger.id.
      }
      // Owner heeft net z'n eigen paal aangemaakt — exacte locatie hoort
      // er bij. (Wordt direct doorgepushed naar AvailabilityScreen, niet
      // de publieke detail.)
      final newCharger = Charger.fromMap(freshRow, isExactLocation: true);

      if (!mounted) return;
      // pushReplacement: na opslaan in AvailabilityScreen pop't 'ie met `true`
      // door naar de oorspronkelijke aanroeper (Mijn palen / Home), die
      // dan z'n lijst verversen. AddChargerScreen verdwijnt dus uit de stack.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AvailabilityScreen(
            charger: newCharger,
            isInitialSetup: true,
          ),
        ),
      );
      return;
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
        // Bottom-padding incl. system inset zodat de submit-knop niet onder de
        // Android gesture/nav-bar valt (edge-to-edge, Android 15+).
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
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
            _AddressAutocompleteField(
              controller: _addressController,
              onSelected: (result) {
                setState(() => _selectedCoords = result.coords);
              },
              onChangedAfterSelection: () {
                if (_selectedCoords != null) {
                  setState(() => _selectedCoords = null);
                }
              },
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Kies je adres uit de lijst zodat we de paal exact op de '
                      'kaart kunnen zetten.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _label('Prijs per kWh'),
            _textField(
              controller: _priceController,
              hint: 'bijv. 0,35',
              icon: Icons.euro,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            priceFeedback(_priceController),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Text(
                    'Type aansluiting',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => showConnectorTypeInfo(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            _label('Kabel'),
            _cableSelector(
              value: _cableIncluded,
              onChanged: (v) => setState(() => _cableIncluded = v),
            ),
            const SizedBox(height: 20),
            _label('Toegang tot de plek'),
            _accessTypePicker(
              selected: _accessType,
              onChanged: (v) => setState(() => _accessType = v),
            ),
            const SizedBox(height: 20),
            freeVendInfo(),
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
// _AddressAutocompleteField
// ----------------------------------------------------------------------------
// Adresinvoer met live suggesties uit Google Places (alleen NL). User moet
// een adres uit de lijst kiezen — voorkomt typo's die palen niet-geocodeerbaar
// maken en dus onvindbaar op de kaart.
//
// - 250ms debounce zodat we niet bij elke keystroke een call doen
// - Sessie-token blijft hetzelfde tijdens typen, wordt vervangen na elke
//   selectie (Google rekent autocomplete + 1 details-call samen af als 1 sessie)
// - Bij wijziging na selectie: parent krijgt `onChangedAfterSelection`
//   callback zodat eerder opgeslagen lat/lng kan worden weggegooid
// ============================================================================
class _AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<PlaceDetailsResult> onSelected;
  final VoidCallback onChangedAfterSelection;

  const _AddressAutocompleteField({
    required this.controller,
    required this.onSelected,
    required this.onChangedAfterSelection,
  });

  @override
  State<_AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<_AddressAutocompleteField> {
  String _sessionToken = newPlacesSessionToken();
  List<PlacePrediction> _predictions = const [];
  bool _loading = false;
  bool _resolving = false;
  Timer? _debounce;
  bool _hasSelected = false;
  String? _selectedText;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    // Edit na selectie → de opgeslagen lat/lng matcht het adres niet meer.
    // Parent moet z'n state opschonen, anders slaan we straks een paal op
    // met coords van een ANDER adres dan wat in het veld staat.
    if (_hasSelected && value != _selectedText) {
      _hasSelected = false;
      widget.onChangedAfterSelection();
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (value.trim().length < 3) {
        if (mounted) setState(() => _predictions = const []);
        return;
      }
      if (mounted) setState(() => _loading = true);
      final preds =
          await placesAutocompleteNL(value, sessionToken: _sessionToken);
      if (!mounted) return;
      setState(() {
        _predictions = preds;
        _loading = false;
      });
    });
  }

  Future<void> _onPick(PlacePrediction p) async {
    if (_resolving) return;
    // Keyboard wegklappen zodat de bevestiging zichtbaar is zonder scrollen
    FocusScope.of(context).unfocus();
    setState(() => _resolving = true);
    try {
      final details =
          await placeDetails(p.placeId, sessionToken: _sessionToken);
      if (!mounted) return;
      widget.controller.text = details.formattedAddress;
      _hasSelected = true;
      _selectedText = details.formattedAddress;
      widget.onSelected(details);
      setState(() {
        _predictions = const [];
        _resolving = false;
        // Nieuwe sessie voor een eventuele tweede zoekopdracht. Volgens
        // Google's billing-regel: één token per autocomplete-sessie.
        _sessionToken = newPlacesSessionToken();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            onChanged: _onTextChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Begin te typen — kies je adres uit de lijst',
              prefixIcon: const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
              ),
              suffixIcon: (_loading || _resolving)
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_hasSelected
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                        )
                      : null),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_predictions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
              ],
            ),
            child: Column(
              children: List.generate(_predictions.length, (i) {
                final p = _predictions[i];
                final isFirst = i == 0;
                final isLast = i == _predictions.length - 1;
                return InkWell(
                  onTap: _resolving ? null : () => _onPick(p),
                  borderRadius: BorderRadius.vertical(
                    top: isFirst ? const Radius.circular(12) : Radius.zero,
                    bottom: isLast ? const Radius.circular(12) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.description,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
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
  late bool _cableIncluded;
  late String _accessType;

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
    _cableIncluded = c.cableIncluded;
    _accessType = c.accessType;
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
          content: Text('Prijs is geen geldig getal (bijv. 0,35)'),
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
        'cable_included': _cableIncluded,
        'access_type': _accessType,
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

      // .select() forceert dat de update een rij teruggeeft. Zonder .select()
      // returnt een RLS-rejected update succesvol met 0 rijen — silent fail.
      // Door .select() toe te voegen kunnen we expliciet checken én throwen.
      final updated = await supabase
          .from('chargers')
          .update(update)
          .eq('id', chargerId)
          .select('id');
      if (updated.isEmpty) {
        throw Exception(
          'Wijzigingen werden geweigerd (0 rijen aangepast). '
          'Mogelijk ben je niet meer eigenaar van deze paal.',
        );
      }

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
        // Bottom-padding incl. system inset zodat de submit-knop niet onder de
        // Android gesture/nav-bar valt (edge-to-edge, Android 15+).
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
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
              hint: 'bijv. 0,35',
              icon: Icons.euro,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            priceFeedback(_priceController),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Text(
                    'Type aansluiting',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => showConnectorTypeInfo(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            _label('Kabel'),
            _cableSelector(
              value: _cableIncluded,
              onChanged: (v) => setState(() => _cableIncluded = v),
            ),
            const SizedBox(height: 20),
            _label('Toegang tot de plek'),
            _accessTypePicker(
              selected: _accessType,
              onChanged: (v) => setState(() => _accessType = v),
            ),
            const SizedBox(height: 20),
            freeVendInfo(),
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

  // Heeft de huidige gebruiker een door de eigenaar BEVESTIGDE boeking?
  // Strenger dan _hasActiveBooking (die ook pending telt). Pas bij confirmed
  // krijgt de boeker de exacte locatie te zien — anders blijft het fuzzy
  // adres + fuzzy lat/lng staan. Zie migratie 0010.
  bool _hasConfirmedBooking = false;

  @override
  void initState() {
    super.initState();
    charger = widget.charger;
    _loadSlots();
    _checkBooking();
    _loadReviews();
    // Komt de gebruiker via de publieke kaart binnen op z'n eigen paal,
    // dan is widget.charger fuzzy. Owner → direct exact ophalen.
    // Voor confirmed bookers regelt _checkBooking de swap.
    if (_isOwner && !charger.isExactLocation) {
      _refreshCharger();
    }
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
          .select('id, status')
          .eq('charger_id', charger.id)
          .eq('user_id', userId)
          .not('status', 'in', '(cancelled,rejected)');
      if (!mounted) return;
      final rows = (data as List).cast<Map<String, dynamic>>();
      final hasActive = rows.isNotEmpty;
      final hasConfirmed = rows.any((r) => r['status'] == 'confirmed');
      setState(() {
        _hasActiveBooking = hasActive;
        _hasConfirmedBooking = hasConfirmed;
      });
      // Als we net hebben vastgesteld dat er een confirmed booking is en
      // we toonden tot nu toe fuzzy data, swap naar exact via een refresh.
      if (hasConfirmed && !charger.isExactLocation) {
        await _refreshCharger();
      }
    } catch (_) {
      // Bij fout houden we 'm gewoon op false
    }
  }

  Future<void> _refreshCharger() async {
    // Owners en confirmed bookers mogen de exacte locatie zien; iedereen
    // anders blijft op de fuzzy view. Zie migratie 0010 voor de server-
    // kant. RLS volgt — voor nu is dit een app-side guard.
    final mayShowExact = _isOwner || _hasConfirmedBooking;
    try {
      final data = await supabase
          .from(mayShowExact ? 'chargers' : 'chargers_public')
          .select()
          .eq('id', charger.id)
          .maybeSingle();
      if (data == null || !mounted) return;
      setState(() {
        charger = Charger.fromMap(data, isExactLocation: mayShowExact);
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
        // Bottom padding extra opgehoogd met de system inset (Android gesture
        // bar / 3-button nav). Zonder dit valt de "Boekingen open vanaf"-knop
        // gedeeltelijk achter de nav-bar in edge-to-edge mode (Android 15+).
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
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
                            // Wanneer we (nog) niet de exacte locatie tonen,
                            // even uitleggen waarom de paal op de kaart ~100m
                            // verschoven staat en het huisnummer ontbreekt.
                            if (!charger.isExactLocation) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Exact adres verschijnt na bevestigde boeking',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Compacte "Route"-knop rechts van het adres.
                      // Opent een bottom sheet met Apple Maps / Google Maps / kopiëren.
                      // Alleen tonen als we de exacte locatie kennen — anders
                      // zou de knop naar een fuzzy punt 100-200m verderop sturen.
                      if (charger.isExactLocation) ...[
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tag-rij: zonne-energie + Pionier-badge. Wrap zodat ze
                  // bij smalle schermen netjes onder elkaar gaan.
                  if (charger.solar || charger.ownerIsPioneer)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (charger.solar)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
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
                        if (charger.ownerIsPioneer)
                          const PioneerBadge(
                              size: PioneerBadgeSize.medium),
                      ],
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
                    // Owner ziet zijn eigen instelprijs; booker ziet de
                    // prijs incl. €0,03 servicefee — dat is wat 'ie betaalt.
                    label: _isOwner ? 'Jouw prijs' : 'Prijs',
                    value: _isOwner
                        ? '€${charger.price}/kWh'
                        : formatBookerPricePerKwhLabel(charger.price),
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
                    onTap: () => showConnectorTypeInfo(context),
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
            // === Praktisch-kaart (kabel + toegang) — altijd zichtbaar zodat
            // de boeker vóór z'n boeking weet wat hem te wachten staat ===
            _practicalCard(),
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

  // Kaart met praktische info (kabel + toegang) — altijd zichtbaar,
  // ook vóór de boeking, zodat een potentiële boeker weet of hij een
  // kabel mee moet brengen en hoe hij op de plek komt.
  Widget _practicalCard() {
    final accessLabel = kAccessTypeLabels[charger.accessType] ?? '—';
    final accessIcon = kAccessTypeIcons[charger.accessType] ?? Icons.help_outline;
    return Container(
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
            'Praktisch',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _practicalRow(
            icon: charger.cableIncluded
                ? Icons.cable_rounded
                : Icons.power_outlined,
            label: 'Kabel',
            value: charger.cableIncluded
                ? 'Met kabel — gewoon insteken'
                : 'Geen kabel — neem je eigen kabel mee',
          ),
          const SizedBox(height: 10),
          _practicalRow(
            icon: accessIcon,
            label: 'Toegang',
            value: accessLabel,
          ),
        ],
      ),
    );
  }

  Widget _practicalRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
      final updated = await supabase
          .from('reviews')
          .update({
            'owner_reply': text,
            'owner_replied_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', review.id)
          .select('id');
      if (updated.isEmpty) {
        throw Exception(
          'Reactie werd geweigerd. Mogelijk ben je niet meer eigenaar.',
        );
      }
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
  /// True wanneer dit scherm direct na het toevoegen van een nieuwe paal
  /// wordt geopend. Past de UI aan (andere titel, andere knop-tekst,
  /// expliciete waarschuwing dat de paal anders onzichtbaar blijft) en
  /// pop't bij opslaan met `true` zodat de aanroeper zijn lijst kan
  /// verversen — dezelfde return value als AddChargerScreen voorheen gaf.
  final bool isInitialSetup;
  const AvailabilityScreen({
    Key? key,
    required this.charger,
    this.isInitialSetup = false,
  }) : super(key: key);

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
        SnackBar(
          content: Text(
            widget.isInitialSetup
                ? 'Top — je paal staat nu open op de gekozen tijden!'
                : 'Beschikbaarheid opgeslagen!',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Bij initial-setup pop'en we met `true` zodat de Mijn-palen lijst
      // (die de oorspronkelijke push deed) z'n lijst kan verversen.
      Navigator.pop(context, widget.isInitialSetup ? true : null);
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
    final isSetup = widget.isInitialSetup;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Bij initial-setup laten we de back-arrow weg om te voorkomen dat
        // de eigenaar 'm wegklikt en denkt dat z'n paal vindbaar is. In
        // plaats daarvan een 'Later' tekstknop rechts die expliciet pop't
        // met true (paal is wel opgeslagen, alleen geen slots) zodat de
        // lijst sowieso refresht. Daar tonen we dan een waarschuwing.
        leading: isSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        automaticallyImplyLeading: !isSetup,
        title: Text(isSetup ? 'Wanneer is je paal open?' : 'Beschikbaarheid'),
        actions: [
          if (isSetup)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Later',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
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
                // Uitleg-banner — bij initial-setup expliciete waarschuwing
                // dat zonder dagen de paal niet vindbaar is in de zoekresultaten.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSetup
                          ? AppColors.warningSoft
                          : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isSetup
                              ? Icons.lightbulb_outline_rounded
                              : Icons.info_outline_rounded,
                          color: isSetup
                              ? AppColors.warning
                              : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isSetup
                                ? 'Bijna klaar! Zet hieronder de dagen aan waarop buren mogen laden. '
                                    'Zonder beschikbaarheid blijft je paal onzichtbaar in de app.'
                                : 'Stel in op welke dagen en tijden buren mogen laden.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isSetup
                                  ? AppColors.warningDark
                                  : AppColors.primaryDark,
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
                // Save-knop onderaan met veilige afstand. Bij initial-setup
                // tonen we eronder een tweede, secundaire knop "Doe ik later"
                // — anders blijven mensen die nog geen agenda paraat hebben
                // hangen op dit scherm zonder duidelijke uitweg. De paal staat
                // dan al wel in hun lijst (met een waarschuwingschip dat 'ie
                // nog niet boekbaar is) zodat het niet verdwijnt uit beeld.
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        SizedBox(
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
                                : Text(
                                    isSetup
                                        ? 'Klaar — paal activeren'
                                        : 'Opslaan',
                                  ),
                          ),
                        ),
                        if (isSetup) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Doe ik later — naar mijn palen',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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

/// Simpel value-object voor "deze paal is bezet tussen X en Y" — puur voor de
/// UI van BookingScreen. We slaan geen booker-identiteit op, want de boeker
/// hoeft alleen te weten DAT er iets staat, niet van wie.
class _BookedRange {
  final DateTime start; // lokaal
  final DateTime end; // lokaal
  const _BookedRange({required this.start, required this.end});
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _messageController = TextEditingController();

  AvailabilitySlot? _slotForSelectedDay;
  bool _loadingSlot = true;
  bool _submitting = false;

  // Bezet-blokken (pending + confirmed) voor de gekozen dag — worden naast de
  // beschikbaarheidwindow getoond zodat de boeker vooraf ziet welke uren al
  // vol zitten (fix task #283).
  List<_BookedRange> _bookedRangesForDay = [];
  bool _loadingBookings = true;

  @override
  void initState() {
    super.initState();
    _loadSlotForSelectedDay();
    _loadBookedRangesForDay();
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
    _loadBookedRangesForDay();
  }

  /// Haalt alle nog-actieve boekingen op die (deels) binnen de gekozen dag
  /// vallen. We filteren geannuleerde/geweigerde eruit — pending + confirmed
  /// tellen als "bezet". Ranges worden in lokale tijd bewaard voor makkelijk
  /// tonen; overlap-check verderop rekent ook lokaal.
  Future<void> _loadBookedRangesForDay() async {
    setState(() => _loadingBookings = true);
    try {
      final dayStartLocal = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final dayEndLocal = dayStartLocal.add(const Duration(days: 1));

      final data = await supabase
          .from('bookings')
          .select('start_time, end_time, status')
          .eq('charger_id', widget.charger.id)
          .not('status', 'in', '(cancelled,rejected)')
          .lt('start_time', dayEndLocal.toUtc().toIso8601String())
          .gt('end_time', dayStartLocal.toUtc().toIso8601String());

      if (!mounted) return;

      final ranges = (data as List).map((row) {
        final map = row as Map<String, dynamic>;
        return _BookedRange(
          start: DateTime.parse(map['start_time'] as String).toLocal(),
          end: DateTime.parse(map['end_time'] as String).toLocal(),
        );
      }).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      setState(() {
        _bookedRangesForDay = ranges;
        _loadingBookings = false;
      });
    } catch (_) {
      // Bewuste fail-open: als de fetch faalt, tonen we geen bezet-blokken
      // maar de server-side conflict-check bij _submit vangt 'm alsnog af.
      if (mounted) {
        setState(() {
          _bookedRangesForDay = [];
          _loadingBookings = false;
        });
      }
    }
  }

  /// Standaard overlap-test: [aStart,aEnd) overlapt met [bStart,bEnd) als
  /// aStart < bEnd EN aEnd > bStart. Zelfde regel als de server-check.
  bool _rangesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
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

    // Snelle client-side overlap-check op basis van de al ingeladen bezet-
    // blokken — voorkomt een round-trip als de boeker duidelijk een bezet
    // tijdvak kiest. De server-check verderop blijft leading (race-safety).
    for (final r in _bookedRangesForDay) {
      if (_rangesOverlap(startDT, endDT, r.start, r.end)) {
        final rs = _formatTimeForDisplay(
          TimeOfDay(hour: r.start.hour, minute: r.start.minute),
        );
        final re = _formatTimeForDisplay(
          TimeOfDay(hour: r.end.hour, minute: r.end.minute),
        );
        _showError(
          'Dit tijdvak overlapt met een bestaande boeking ($rs–$re). '
          'Kies een tijd buiten de bezette blokken.',
        );
        return;
      }
    }

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

      // -----------------------------------------------------------------
      // Account-pauze check: heeft deze boeker een betaalverzoek dat
      // langer dan `maxDaysOutstandingPayment` dagen openstaat?
      // Zo ja: nieuwe boeking weigeren tot openstaande factuur betaald is.
      // (Mitigeer-optie van het pay-after-charge model.)
      // -----------------------------------------------------------------
      final cutoff = DateTime.now()
          .toUtc()
          .subtract(Duration(days: maxDaysOutstandingPayment));
      final outstanding = await supabase
          .from('bookings')
          .select('id, payment_requested_at')
          .eq('user_id', userId)
          .not('payment_status', 'eq', 'paid')
          .not('payment_status', 'eq', 'refunded')
          .not('payment_requested_at', 'is', null)
          .lt('payment_requested_at', cutoff.toIso8601String())
          .limit(1);

      if ((outstanding as List).isNotEmpty) {
        if (!mounted) return;
        setState(() => _submitting = false);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Openstaande betaling'),
            content: Text(
              'Je hebt een betaalverzoek dat al langer dan '
              '$maxDaysOutstandingPayment dagen openstaat. '
              'Rond die betaling eerst af in "Mijn boekingen" '
              'voordat je een nieuwe paal boekt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Begrepen'),
              ),
            ],
          ),
        );
        return;
      }

      // -----------------------------------------------------------------
      // Voertuig-onboarding nudge (task #286): als de boeker nog geen
      // auto-info in z'n profiel heeft, vraag 'm om die eerst in te
      // vullen. Niet blocking — user mag "Later" kiezen en dan gaat de
      // boeking gewoon door. Doel: zoveel mogelijk boekers krijgen
      // ETA-tracking tijdens hun laadsessie (task #287).
      // -----------------------------------------------------------------
      try {
        final vehicleRow = await supabase
            .from('profiles')
            .select('vehicle_battery_capacity_kwh')
            .eq('id', userId)
            .maybeSingle();
        final hasBatteryInfo =
            vehicleRow != null &&
                vehicleRow['vehicle_battery_capacity_kwh'] != null;
        if (!hasBatteryInfo && mounted) {
          final goToProfile = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Vul je auto in?'),
              content: const Text(
                'We kunnen je "% vol" en resterende laadtijd tonen '
                'tijdens je sessie, maar dan hebben we even je auto '
                '(model + accu) nodig. Duurt 20 seconden.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Nu invullen'),
                ),
              ],
            ),
          );
          if (goToProfile == true) {
            if (!mounted) return;
            setState(() => _submitting = false);
            // Naar profielscherm; user kan daarna terug naar boeken
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditProfileScreen(),
              ),
            );
            // Boeking afbreken — user moet zelf opnieuw op "Boeken" tikken
            // zodat 'ie z'n keuzes bewust bevestigt.
            return;
          }
        }
      } catch (_) {
        // Silent fail: als de check zelf faalt (netwerk, RLS), gaan we
        // gewoon door met boeken. Nudge is nice-to-have, geen blocker.
      }

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

      // "Eerste echt event": de boeker heeft net een aanvraag gedaan en wil
      // weten wanneer de eigenaar accepteert. Vraag nu om push-permissie
      // (iOS toont z'n systeem-dialoog alleen de eerste keer; daarna is
      // dit een no-op). Fire-and-forget: mag de UI niet blokkeren.
      // ignore: unawaited_futures
      PluggoPush.instance.requestPermissionAndRegister();

      // Push naar de eigenaar — die wil meteen weten dat er een aanvraag is.
      // Fire-and-forget. Owner_id is altijd gezet in onze data; mocht 'ie ooit
      // null zijn (oude rij?) dan slaan we de push gewoon over.
      if (widget.charger.ownerId != null) {
        // ignore: unawaited_futures
        PluggoPush.sendTo(
          userId: widget.charger.ownerId!,
          title: 'Nieuwe boekingsaanvraag',
          body: '$userName wil ${widget.charger.name} reserveren',
          data: {
            'type': 'booking_request',
            'charger_id': widget.charger.id,
          },
        );
      }

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
    } catch (e, st) {
      // Fire-and-forget, maar wel loggen zodat we silent failures kunnen
      // debuggen (bv. ontbrekende Resend secret, ongeldig domein, etc.)
      debugPrint('send-email (owner new booking) failed: $e\n$st');
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
        // Bottom-padding incl. system inset zodat de "Bevestig reservering"-knop
        // niet onder de Android gesture/nav-bar valt (edge-to-edge, Android 15+).
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chargerSummaryCard(),
            const SizedBox(height: 12),
            // Prijs-info kaart: laat zien wat de boeker per kWh betaalt
            // én vermeldt expliciet de €0,40 mini-sessie fee zodat dat niet
            // pas bij de Stripe PaymentSheet zichtbaar wordt.
            _pricingInfoCard(),
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
          // Booker-facing — toon de all-in prijs (paalprijs + €0,03 servicefee).
          Text(
            '€${bookerPricePerKwh(widget.charger.price).toStringAsFixed(2).replaceAll('.', ',')}',
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

  /// Prijs-info kaartje. Maakt voor de boeker — vóór de boeking bevestigd
  /// wordt — duidelijk wat-ie per kWh betaalt en dat er bij sessies onder
  /// [smallSessionThresholdKwh] een eenmalige €${smallSessionFeeEur} fee
  /// bovenop komt. Voorkomt dat dit pas in de Stripe PaymentSheet opduikt.
  Widget _pricingInfoCard() {
    final allInPerKwh = bookerPricePerKwh(widget.charger.price);
    final allInStr =
        allInPerKwh.toStringAsFixed(2).replaceAll('.', ',');
    final feeStr =
        smallSessionFeeEur.toStringAsFixed(2).replaceAll('.', ',');
    final thresholdStr = smallSessionThresholdKwh % 1 == 0
        ? smallSessionThresholdKwh.toStringAsFixed(0)
        : smallSessionThresholdKwh.toStringAsFixed(1).replaceAll('.', ',');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Wat ga je betalen?',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _pricingRow(
            label: 'Tarief',
            value: '€$allInStr per kWh',
            sub: 'incl. €0,03 servicefee van Pluggo',
          ),
          const SizedBox(height: 6),
          _pricingRow(
            label: 'Mini-sessie fee',
            value: '€$feeStr',
            sub: 'eenmalig bij sessies onder $thresholdStr kWh '
                '— dekt de iDEAL-kosten',
          ),
          const SizedBox(height: 10),
          Text(
            'Je betaalt achteraf in de app (iDEAL, Apple Pay, Google Pay '
            'of kaart) op basis van de werkelijk geladen kWh die de '
            'eigenaar invult.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingRow({
    required String label,
    required String value,
    String? sub,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
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
        // Bezet-blokken voor deze dag (task #283) — direct onder de "beschikbaar"-
        // banner, boven de tijd-pickers, zodat de boeker vooraf ziet welke uren
        // al vol zitten voordat-ie een tijd kiest.
        _bookedSlotsCard(),
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

  /// Toont de al gereserveerde tijdvakken voor de geselecteerde dag. Geen
  /// booker-namen — puur "Bezet HH:MM–HH:MM" — zodat andere gebruikers'
  /// boekingen anoniem blijven.
  Widget _bookedSlotsCard() {
    if (_loadingBookings) return const SizedBox.shrink();
    if (_bookedRangesForDay.isEmpty) return const SizedBox.shrink();

    final dayStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));

    String rangeLabel(_BookedRange r) {
      // Clamp naar de dag zelf voor over-middernacht boekingen.
      final s = r.start.isBefore(dayStart) ? dayStart : r.start;
      final e = r.end.isAfter(dayEnd) ? dayEnd : r.end;
      final sLbl = _formatTimeForDisplay(
        TimeOfDay(hour: s.hour, minute: s.minute),
      );
      // Speciaalgeval: eind valt precies op 00:00 volgende dag → toon 24:00
      final eLbl = (e.year == dayEnd.year &&
              e.month == dayEnd.month &&
              e.day == dayEnd.day &&
              e.hour == 0 &&
              e.minute == 0)
          ? '24:00'
          : _formatTimeForDisplay(
              TimeOfDay(hour: e.hour, minute: e.minute),
            );
      return 'Bezet $sLbl – $eLbl';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_busy_rounded,
                color: AppColors.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Al gereserveerd op deze dag',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._bookedRangesForDay.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rangeLabel(r),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kies een tijdstip buiten deze blokken.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
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
  /// Charger-id's waarvoor minstens één availability_slot bestaat. Palen
  /// die hier NIET in zitten zijn effectief onzichtbaar voor boekers
  /// (geen openingstijden) — daar tonen we een waarschuwingschip.
  Set<String> _chargersWithSlots = {};

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
      // Sinds migratie 0030 heeft authenticated GEEN directe SELECT
      // meer op public.chargers.lat/lng — dat zou anders elke ingelogde
      // user in staat stellen om de huisadres-coords van iedere paal
      // op te vragen. Voor de owner-view (Mijn palen) gebruiken we
      // daarom de SECURITY DEFINER helper `my_chargers()`: die geeft
      // álle kolommen terug (incl. lat/lng) — maar alleen voor rijen
      // waar owner_id = auth.uid(). Zie task #241.
      final data = await supabase.rpc('my_chargers');
      // Mijn palen — owner ziet altijd exacte locatie.
      final list = (data as List)
          .map((m) => Charger.fromMap(
                m as Map<String, dynamic>,
                isExactLocation: true,
              ))
          .toList();

      // In één keer alle slots ophalen voor deze charger-ids; dan kunnen
      // we per tile zien of er minstens één slot bestaat. Dit is een
      // bewuste tweede query — een join via PostgREST kan ook, maar dit is
      // simpeler en de payload is verwaarloosbaar (alleen charger_id).
      final ids = list.map((c) => c.id).toList();
      Set<String> withSlots = {};
      if (ids.isNotEmpty) {
        try {
          final slotRows = await supabase
              .from('availability_slots')
              .select('charger_id')
              .inFilter('charger_id', ids);
          withSlots = (slotRows as List)
              .map((r) => (r as Map<String, dynamic>)['charger_id'] as String)
              .toSet();
        } catch (_) {
          // Niet-fataal — als de slots-query faalt tonen we gewoon geen
          // chip (oude gedrag). De palen-lijst zelf werkt nog wel.
        }
      }

      if (!mounted) return;
      setState(() {
        _chargers = list;
        _chargersWithSlots = withSlots;
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
    // Stripe-gate: zie home-flow voor uitleg (BTW-vragenlijst + Stripe KYC).
    final ok = await ensureStripeReadyOrPrompt(context);
    if (!ok) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddChargerScreen()),
    );
    if (added == true) _load();
  }

  Widget _chargerTile(Charger c) {
    final needsAvailability = !_chargersWithSlots.contains(c.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow,
        // Subtiele oranje rand als de paal nog niet boekbaar is — zo valt
        // 'ie op zonder dat de hele tile schreeuwt.
        border: needsAvailability
            ? Border.all(color: AppColors.warning.withOpacity(0.5), width: 1)
            : null,
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
                    // Waarschuwingschip onder de status-chips wanneer de paal
                    // geen openingstijden heeft. De paal lijkt anders 'open'
                    // (kolom available=true) terwijl boekers geen slot kunnen
                    // kiezen — dit voorkomt die misleiding.
                    if (needsAvailability) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 12,
                              color: AppColors.warningDark,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Stel beschikbaarheid in — paal is nog onzichtbaar',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warningDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with WidgetsBindingObserver {
  List<Booking> _bookings = [];
  bool _loading = true;
  // IDs van boekingen waar deze gebruiker al een review voor heeft achtergelaten —
  // gebruikt om "Schrijf review" vs. "Beoordeeld" badge te bepalen.
  Set<String> _reviewedBookingIds = {};

  // Voertuig-eigenschappen van de ingelogde user, uit `profiles`. Nodig voor
  // de LiveChargingCard (task #287): SoC-berekening en effective_kw.
  // Beide nullable — user hoeft geen voertuig te kiezen (kan ook later).
  double? _vehicleBatteryKwh;
  double? _vehicleMaxAcKw;

  // Dev-mode simulatie state: per booking-id de lopende tick-timer én de
  // transaction_id (nodig om tick + stop RPC's te vuren). Alleen relevant
  // in kDebugMode — in productie blijft deze map altijd leeg.
  final Map<String, _FakeSessionCtrl> _fakeSessions = {};

  @override
  void initState() {
    super.initState();
    // Luister naar lifecycle: als de app van background terugkeert (bijv.
    // na een betaling waarbij iDEAL kort naar de bank-app schakelde),
    // refreshen we de boekingen zodat payment_status meteen up-to-date is.
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop alle dev-mode fake-session timers (voorkomt Timer-leaks als user
    // Mijn Boekingen verlaat terwijl er nog een simulatie loopt). We laten
    // de sessie zelf in de DB doorlopen — een expliciete "Stop" moet de user
    // triggeren. Dit stopt alleen de client-side tick-loop.
    for (final ctrl in _fakeSessions.values) {
      ctrl.tickTimer?.cancel();
    }
    _fakeSessions.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _load();
    }
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

      // Voertuig-velden uit profiles (task #287): nodig voor de LiveCharging-
      // Card om SoC en ETA te berekenen. Falen we hier zachtjes — de widget
      // toont dan nul in plaats van % en ETA en fungeert alsnog.
      double? vBatteryKwh;
      double? vMaxAcKw;
      try {
        final profileRow = await supabase
            .from('profiles')
            .select('vehicle_battery_capacity_kwh, vehicle_max_ac_kw')
            .eq('id', userId)
            .maybeSingle();
        if (profileRow != null) {
          vBatteryKwh =
              (profileRow['vehicle_battery_capacity_kwh'] as num?)?.toDouble();
          vMaxAcKw = (profileRow['vehicle_max_ac_kw'] as num?)?.toDouble();
        }
      } catch (_) {
        // Silent fail — widget verbergt %/ETA-velden dan gewoon
      }

      if (!mounted) return;
      setState(() {
        _bookings = (data as List)
            .map((row) => Booking.fromMap(row as Map<String, dynamic>))
            .toList();
        _reviewedBookingIds = reviewedIds;
        _vehicleBatteryKwh = vBatteryKwh;
        _vehicleMaxAcKw = vMaxAcKw;
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
      // Onthouden VOOR de update, anders is booking.status al 'cancelled'
      // en snappen we niet meer of dit een pending-intrekking was of een
      // echte annulering — dat verandert de push-copy.
      final wasPending = booking.status == 'pending';

      final updated = await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', booking.id)
          .select('id');
      if (updated.isEmpty) {
        throw Exception(
          'Annulering werd geweigerd (0 rijen aangepast). '
          'Mogelijk is de boeking ondertussen al gewijzigd.',
        );
      }

      // Push naar de eigenaar — die had de aanvraag/boeking in z'n inbox
      // staan en wil weten dat die weer vrij is (voor het geval iemand
      // anders wacht op dat slot). Fire-and-forget; mag flow niet blokkeren.
      final ownerId = booking.charger?.ownerId;
      if (ownerId != null) {
        final chargerName = booking.charger?.name ?? 'je laadpaal';
        final bookerName = (booking.userName?.trim().isNotEmpty ?? false)
            ? booking.userName!.trim()
            : 'De boeker';
        // ignore: unawaited_futures
        PluggoPush.sendTo(
          userId: ownerId,
          title: wasPending ? 'Aanvraag ingetrokken' : 'Boeking geannuleerd',
          body: wasPending
              ? '$bookerName trok de aanvraag voor $chargerName in.'
              : '$bookerName heeft de boeking bij $chargerName geannuleerd.',
          data: {
            'type': 'booking_cancelled_by_booker',
            'booking_id': booking.id,
          },
        );
      }

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

  // ----------------------------------------------------------------
  // Boeking afrekenen via Stripe Connect — **Pad 2: Stripe Checkout**.
  //
  // Achtergrond: na 3 dagen vastlopen op een silent hang in flutter_stripe
  // 11.5.0 PaymentSheet (iOS 26.3.1 + FlutterSceneDelegate: presenting
  // view controller onvindbaar, sheet rendert onzichtbaar) zijn we
  // gepivoteerd naar Stripe-hosted Checkout via Safari.
  //
  // Flow:
  //   1. Bevestigingsdialog met breakdown (zelfde UX als voorheen).
  //   2. StripeService.createCheckoutSession → edge function
  //      'create-payment-stripe' valideert booking + owner.charges_enabled
  //      en maakt een Checkout Session aan met destination charge
  //      (payment_intent_data[application_fee_amount] + transfer_data).
  //   3. launchUrl(checkout_url, externalApplication) → opent Safari met
  //      checkout.stripe.com. Daar kiest gebruiker iDEAL/kaart/Apple Pay.
  //   4. Na betaling redirect Stripe naar stripe-checkout-return edge
  //      function → JS opent pluggo://stripe-return → gebruiker is terug
  //      in de app. (Werkt ook zonder deeplink — gebruiker kan handmatig
  //      terugswipen.)
  //   5. Ondertussen toont de app een "Wachten op betaling..." dialog en
  //      pollt elke 3s booking.payment_status (max 5 min). Webhook
  //      'checkout.session.completed' / 'payment_intent.succeeded' update
  //      de booking server-side; polling pikt dat op en sluit de dialog.
  //   6. Bij paid: success snackbar + _load() refresh. Bij timeout:
  //      vriendelijke "controleer je bookings later" snackbar.
  // ----------------------------------------------------------------
  bool _processingPayment = false;

  Future<void> _payForBooking(Booking booking) async {
    debugPrint('[PAY] _payForBooking START booking=${booking.id} processingPayment=$_processingPayment');
    // Pay-after-charge: het exacte bedrag is bekend uit total_amount_cents
    // dat door de owner is vastgezet bij het betaalverzoek. We gebruiken
    // bewust NIET kwh × current charger.price — die kan veranderd zijn na
    // het verzoek (bug #69), waardoor wat de booker ziet zou wijken van
    // wat Stripe daadwerkelijk charged.
    final kwh = booking.kwhConsumed;
    final exact = bookingPayableEuro(booking);
    if (kwh == null || exact == null || exact <= 0) {
      // Mag eigenlijk niet voorkomen — Betalen-knop hoort alleen te tonen
      // als awaitingPayment true is, en die check vereist payment_requested_at.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bedrag is nog niet bekend — wacht op de eigenaar'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Breakdown voor de booker:
    //   • Stroom (kWh × paalprijs) — gaat naar de host
    //   • Servicefee (kWh × €0,03)  — voor Pluggo
    //   • Mini-sessie fee €0,40    — alleen bij kWh < 10
    // Het bedrag dat al vastgelegd is (`exact`) is inclusief alle fees.
    final pricePerKwh = parseChargerPrice(booking.charger?.price ?? '0');
    final stroomDeel = kwh * pricePerKwh;
    final servicefeeDeel = kwh * bookerFeePerKwh;
    final smallFee = smallSessionFeeFor(kwh);
    final allInPerKwh = bookerPricePerKwh(booking.charger?.price ?? '0');
    final kwhStr = kwh.toStringAsFixed(2).replaceAll('.', ',');
    final allInStr = allInPerKwh.toStringAsFixed(2).replaceAll('.', ',');

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Boeking afrekenen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'De eigenaar heeft ingevuld dat je $kwhStr kWh hebt afgenomen '
              'à €$allInStr per kWh (incl. €0,03 servicefee).',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            _payRow('Totaal', formatEuroDouble(exact), bold: true),
            const SizedBox(height: 4),
            _payRow('Stroom (paalprijs)', formatEuroDouble(stroomDeel)),
            _payRow(
              'Pluggo servicefee (€0,03/kWh)',
              formatEuroDouble(servicefeeDeel),
            ),
            if (smallFee > 0)
              _payRow(
                'Mini-sessie fee (<10 kWh)',
                formatEuroDouble(smallFee),
              ),
            const SizedBox(height: 12),
            Text(
              'Je kunt betalen met iDEAL, Apple Pay, Google Pay of '
              'creditcard. De betaalpagina opent in Safari; je komt '
              'daarna automatisch terug in de app.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Naar betaling'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processingPayment = true);
    try {
      // 1. Vraag een Stripe Checkout Session aan via onze edge function.
      //    StripeService gooit StripeServiceException met een NL-bericht
      //    bij voorspelbare faal-paden (boeking al betaald, owner niet
      //    charges_enabled, etc.).
      final session = await StripeService.instance.createCheckoutSession(
        bookingId: booking.id,
      );
      debugPrint(
        '[PAY] got session: cs=${session.checkoutSessionId} url-prefix=${session.checkoutUrl.length > 40 ? session.checkoutUrl.substring(0, 40) : session.checkoutUrl} amount=${session.amountCents}c reused=${session.reused}',
      );

      // 2. Open de Checkout URL in externe Safari. externalApplication is
      //    BELANGRIJK — niet inAppWebView, want:
      //      • Apple Pay / Google Pay werkt alleen in echte Safari/Chrome
      //      • iDEAL-bank-redirects naar nl.icscards.app etc. werken alleen
      //        als de browser de universal-link kan oppakken
      //      • Stripe blokkeert Checkout in embedded webviews vanaf 2024
      //        (anti-fraud measure)
      debugPrint('[PAY] launching Checkout URL in external Safari…');
      final uri = Uri.parse(session.checkoutUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('[PAY] launchUrl returned false — geen browser kon de URL openen');
        throw StripeServiceException(
          'Kon de betaalpagina niet openen — werkt je browser?',
        );
      }
      debugPrint('[PAY] Safari opened — starting polling for booking status…');

      // 3. Wachtdialog terwijl we de booking status pollen. Gebruiker is
      //    nu in Safari; deze dialog zien ze pas als ze terugkeren naar
      //    de app (via pluggo:// deeplink of handmatig). Belangrijk dat
      //    de dialog NIET-dismissible is, anders kan een mis-tap de
      //    polling-loop afbreken vlak voor de webhook binnenkomt.
      bool dialogShown = false;
      bool dialogClosed = false;
      void closeDialog() {
        if (dialogShown && !dialogClosed && mounted) {
          dialogClosed = true;
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      // Fire-and-forget de dialog zodat 'ie naast de polling-await draait.
      // ignore: unawaited_futures
      Future<void>(() async {
        if (!mounted) return;
        dialogShown = true;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  'Wachten op je betaling...',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rond je betaling af in Safari. Je kunt deze dialog '
                  'open laten — we werken je boeking automatisch bij '
                  'zodra Stripe bevestigt.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  dialogClosed = true;
                  Navigator.of(ctx).pop();
                },
                child: const Text('Sluiten'),
              ),
            ],
          ),
        );
      });

      // 4. Poll booking.payment_status tot 'paid' of timeout. De webhook
      //    update de booking server-side; wij detecteren dat hier zodat
      //    de UI in sync komt. Max 5 minuten — typische Checkout flow
      //    duurt 30-90s (iDEAL bank-redirect is het langst).
      final paid = await StripeService.instance.waitForBookingPayment(
        bookingId: booking.id,
      );
      debugPrint('[PAY] polling klaar: paid=$paid');

      closeDialog();

      if (!mounted) return;
      if (paid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Betaling gelukt — bedankt!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _load();
      } else {
        // Geen 'paid' binnen 5 minuten. Kan zijn dat de gebruiker afhaakte
        // in Safari, of dat een iDEAL-betaling extra lang duurt (zeldzaam).
        // We refreshen één keer voor de zekerheid en laten een vriendelijk
        // bericht achter — geen "FOUT" snackbar want technisch is er niets
        // mislukt; de webhook kan nog komen.
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We zien je betaling nog niet — check je boekingen over een paar minuten.',
            ),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } on StripeServiceException catch (e) {
      debugPrint('[PAY] StripeServiceException: ${e.message} (status=${e.statusCode})');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Betalen mislukt: ${e.message}'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      debugPrint('[PAY] OTHER exception: $e\n$st');
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Betalen mislukt: $msg'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      debugPrint('[PAY] finally — resetting processingPayment');
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  // Klein hulpwidget voor het bedrag-overzicht in de bevestigingsdialog.
  Widget _payRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Boeker meldt een probleem met een lopende of aanstaande boeking.
  // Stuurt 1 mail naar de eigenaar (zodat die kan reageren) én 1 mail
  // naar info@pluggoapp.nl (zodat support kan bemiddelen). Geen DB-
  // record voor MVP — escalatie loopt via e-mail + chat.
  // ----------------------------------------------------------------
  Future<void> _reportProblem(Booking booking) async {
    final categories = <Map<String, String>>[
      {'value': 'charger_broken', 'label': 'De paal werkt niet'},
      {'value': 'spot_blocked', 'label': 'De parkeerplek is bezet'},
      {'value': 'no_access', 'label': 'Ik kan er niet bij (toegang)'},
      {'value': 'owner_no_response', 'label': 'De eigenaar reageert niet'},
      {'value': 'other', 'label': 'Iets anders'},
    ];
    String selected = 'charger_broken';
    final detailsCtrl = TextEditingController();

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Iets is mis?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We sturen je melding naar de eigenaar én naar Pluggo. '
                  'Als laden niet lukt kun je daarna eventueel je boeking '
                  'annuleren.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                ...categories.map(
                  (c) => RadioListTile<String>(
                    value: c['value']!,
                    groupValue: selected,
                    onChanged: (v) {
                      if (v != null) {
                        setLocalState(() => selected = v);
                      }
                    },
                    title: Text(
                      c['label']!,
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Toelichting (optioneel)',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuleer'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Verstuur',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldSend != true) return;

    final categoryLabel =
        categories.firstWhere((c) => c['value'] == selected)['label']!;
    final details = detailsCtrl.text.trim();

    // Fire-and-forget — de mails kunnen even duren. We tonen meteen feedback.
    _sendProblemReport(booking, categoryLabel, details);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Melding verstuurd. We nemen contact op als het te lang duurt.',
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Stuurt twee mails via de send-email edge function:
  // 1) naar de eigenaar (urgent, met details boeker)
  // 2) naar info@pluggoapp.nl (support log)
  Future<void> _sendProblemReport(
    Booking booking,
    String categoryLabel,
    String details,
  ) async {
    final ownerEmail = booking.charger?.ownerEmail;
    final chargerName = booking.charger?.name ?? 'de laadpaal';
    final chargerAddress = booking.charger?.address ?? '';
    final boekerNaam = booking.userName ??
        supabase.auth.currentUser?.email ??
        'Een boeker';
    final boekerEmail = supabase.auth.currentUser?.email ?? '';

    final datum =
        '${booking.startTime.day} ${_monthNames[booking.startTime.month]}';
    String two(int n) => n.toString().padLeft(2, '0');
    final start =
        '${two(booking.startTime.hour)}:${two(booking.startTime.minute)}';
    final eind =
        '${two(booking.endTime.hour)}:${two(booking.endTime.minute)}';

    final detailsBlok = details.isEmpty
        ? ''
        : '''
<div style="background:#FFF8E1;border-left:4px solid #F9A825;padding:14px 18px;margin:0 0 24px;border-radius:6px;">
  <p style="margin:0 0 4px;color:#7A5A00;font-size:13px;font-weight:600;">Toelichting van de boeker</p>
  <p style="margin:0;color:#333;font-size:14px;line-height:1.5;">$details</p>
</div>''';

    final adresRegel = chargerAddress.isEmpty
        ? ''
        : '<tr><td style="padding:6px 0;color:#666;">Adres</td><td style="padding:6px 0;font-weight:500;">$chargerAddress</td></tr>';

    // 1) Mail naar eigenaar
    if (ownerEmail != null && ownerEmail.isNotEmpty) {
      final ownerSubject = 'Probleem bij je laadpaal: $categoryLabel';
      final ownerHtml = '''
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#F5F5F5;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;">
  <div style="max-width:600px;margin:0 auto;background:#fff;padding:32px 24px;">
    <h1 style="margin:0 0 8px;color:#1976D2;font-size:24px;">Pluggo</h1>
    <p style="margin:0 0 24px;color:#666;font-size:14px;">Buren laden bij buren</p>

    <div style="background:#FFEBEE;border-left:4px solid #C62828;padding:16px 20px;margin:0 0 24px;border-radius:6px;">
      <p style="margin:0;color:#B71C1C;font-size:16px;font-weight:600;">$categoryLabel</p>
      <p style="margin:4px 0 0;color:#B71C1C;font-size:14px;">$boekerNaam meldt een probleem bij een actieve boeking op $chargerName.</p>
    </div>

    $detailsBlok

    <table style="width:100%;border-collapse:collapse;font-size:14px;color:#222;margin:0 0 24px;">
      <tr><td style="padding:6px 0;color:#666;width:90px;">Boeker</td><td style="padding:6px 0;font-weight:500;">$boekerNaam</td></tr>
      <tr><td style="padding:6px 0;color:#666;">Paal</td><td style="padding:6px 0;font-weight:500;">$chargerName</td></tr>
      $adresRegel
      <tr><td style="padding:6px 0;color:#666;">Datum</td><td style="padding:6px 0;font-weight:500;">$datum</td></tr>
      <tr><td style="padding:6px 0;color:#666;">Tijd</td><td style="padding:6px 0;font-weight:500;">$start – $eind</td></tr>
    </table>

    <p style="margin:0 0 8px;color:#444;font-size:14px;">Open Pluggo om direct met de boeker te chatten. Lukt het echt niet meer, annuleer de boeking dan zodat de boeker een ander tijdslot kan kiezen.</p>
    <hr style="border:none;border-top:1px solid #eee;margin:32px 0 16px;">
    <p style="margin:0;color:#999;font-size:12px;">Je ontvangt deze mail omdat een boeker een probleem heeft gemeld bij je laadpaal.</p>
  </div>
</body>
</html>
''';
      try {
        await supabase.functions.invoke('send-email', body: {
          'to': ownerEmail,
          'subject': ownerSubject,
          'html': ownerHtml,
        });
      } catch (e, st) {
        debugPrint('send-email (problem report → owner) failed: $e\n$st');
      }
    }

    // 2) Notificatie naar info@pluggoapp.nl voor support log
    final supportSubject = '[support] Probleem-melding: $categoryLabel';
    final supportHtml = '''
<div style="font-family:sans-serif;max-width:600px;color:#222;font-size:14px;line-height:1.5;">
  <h2 style="margin:0 0 12px;">Probleem-melding boeker</h2>
  <p style="margin:0;"><strong>Categorie:</strong> $categoryLabel</p>
  <p style="margin:6px 0 0;"><strong>Boeker:</strong> $boekerNaam${boekerEmail.isEmpty ? '' : ' ($boekerEmail)'}</p>
  <p style="margin:6px 0 0;"><strong>Paal:</strong> $chargerName${chargerAddress.isEmpty ? '' : ' — $chargerAddress'}</p>
  <p style="margin:6px 0 0;"><strong>Eigenaar e-mail:</strong> ${ownerEmail ?? 'onbekend'}</p>
  <p style="margin:6px 0 0;"><strong>Datum/tijd boeking:</strong> $datum, $start – $eind</p>
  <p style="margin:6px 0 0;"><strong>Booking ID:</strong> ${booking.id}</p>
  ${details.isEmpty ? '' : '<p style="margin:12px 0 0;"><strong>Toelichting:</strong><br>$details</p>'}
</div>
''';
    try {
      await supabase.functions.invoke('send-email', body: {
        'to': 'info@pluggoapp.nl',
        'subject': supportSubject,
        'html': supportHtml,
      });
    } catch (e, st) {
      debugPrint('send-email (problem report → support log) failed: $e\n$st');
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
            // Live laadschatting (task #287): inline widget die tijdens een
            // actieve OCPP-sessie verschijnt. Toont niks als er geen sessie
            // is (widget detecteert zelf). Prijs komt uit charger — bookerprijs
            // is inclusief service fee.
            if (booking.status == 'confirmed' && charger != null) ...[
              const SizedBox(height: 10),
              LiveChargingCard(
                bookingId: booking.id,
                chargerMaxKw: charger.maxPowerKw,
                vehicleBatteryKwh: _vehicleBatteryKwh,
                vehicleMaxAcKw: _vehicleMaxAcKw,
                startSocPct: booking.startSocPct,
                targetSocPct: booking.targetSocPct,
                pricePerKwh: bookerPricePerKwh(charger.price),
                onOpenProfile: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                  if (mounted) _load();
                },
              ),
            ],
            // OCPP start/stop (task #293): "Start laden nu" / "Stop laden nu"
            // voor palen die daadwerkelijk aan het CSMS gekoppeld zijn.
            //
            // Zichtbaar wanneer:
            //   - de boeking bevestigd is
            //   - de paal een OCPP-koppeling heeft (ocpp_charger_id != null)
            //   - het boekingsvenster nog niet definitief voorbij is
            //
            // De strakke tijdsvenster-controle (2 min early, 5 min late) doet
            // remote-start-session zelf; wij tonen 'm alleen ook tijdens de
            // sessie zodat "Stop laden nu" beschikbaar blijft tot de paal een
            // StopTransaction bevestigt. Voor niet-OCPP palen zit er
            // sowieso geen knop — die worden nog handmatig aan/uit gedaan.
            if (booking.status == 'confirmed' &&
                charger != null &&
                charger.ocppChargerId != null &&
                !isPast) ...[
              const SizedBox(height: 10),
              _OcppSessionControls(booking: booking),
            ],
            // Dev-mode "Simuleer sessie" — alleen in debug builds. Laat testers
            // de LiveChargingCard triggeren zonder fysieke paal (VPS #266 en
            // paal #273 zijn nog in aanbouw). Zie migratie 0024.
            if (kDebugMode &&
                booking.status == 'confirmed' &&
                !isPast) ...[
              const SizedBox(height: 8),
              _fakeSessionControls(booking),
            ],
            // Pay-after-charge: boeking is voorbij maar owner heeft
            // nog geen kWh ingevuld. Boeker wacht op afrekening.
            if (booking.awaitingKwhInput) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      size: 16,
                      color: Color(0xFFB07000),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Wachten op afrekening — de eigenaar gaat het '
                        'aantal afgenomen kWh invullen.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFB07000),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Betalen — owner heeft kWh ingevuld én betaalverzoek verstuurd.
            // Toon prominente CTA met exact bedrag. Verdwijnt zodra paid.
            if (booking.awaitingPayment) ...[
              const SizedBox(height: 12),
              if (booking.kwhConsumed != null) ...[
                Text(
                  '${booking.kwhConsumed!.toStringAsFixed(2).replaceAll('.', ',')} kWh '
                  '× €${bookerPricePerKwh(booking.charger?.price ?? '0').toStringAsFixed(2).replaceAll('.', ',')} '
                  'per kWh (incl. €0,03 servicefee)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processingPayment
                      ? null
                      : () => _payForBooking(booking),
                  icon: _processingPayment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.payment_rounded, size: 18),
                  label: Text(
                    _processingPayment
                        ? 'Bezig…'
                        : 'Betalen — ${formatEuroDouble(bookingPayableEuro(booking) ?? 0)}',
                  ),
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
              const SizedBox(height: 4),
              Text(
                booking.paymentStatus == 'pending'
                    ? "Betaling wordt verwerkt — je kunt 'm hier opnieuw afronden als 't onderbroken werd."
                    : booking.paymentStatus == 'failed'
                        ? 'Vorige betaalpoging mislukt. Probeer het opnieuw.'
                        : 'Rond de betaling binnen 7 dagen af, anders kun je tijdelijk geen nieuwe boekingen maken.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            // Betaald — kleine groene check-bevestiging
            if (booking.isPaid) ...[
              const SizedBox(height: 12),
              Container(
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
                      booking.totalAmountCents != null
                          ? 'Betaald · ${formatEuroCents(booking.totalAmountCents!)}'
                          : 'Betaald',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            // Actiebalk: Iets is mis? + Annuleer / Aanvraag intrekken.
            // Niet voor afgelopen/geannuleerde/geweigerde boekingen.
            if ((isUpcoming || isPending) && !isPast) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _reportProblem(booking),
                    icon: const Icon(Icons.report_outlined, size: 16),
                    label: const Text('Iets is mis?'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE0A030),
                      textStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
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
                ],
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

  // --------------------------------------------------------------------------
  // Dev-mode fake-session controls (task #287)
  //
  // Rendert één van drie states:
  //   1. "Simuleer sessie" knop — nog geen sessie loopt voor deze boeking
  //   2. "Stop simulatie" knop — sessie loopt (client-side ticker actief)
  //   3. Foutmelding onderin als een RPC-call faalt
  //
  // Alle logica praat met migratie 0024 RPCs (dev_start / dev_tick / dev_stop).
  // Ticker loopt elke 5s en voegt 150 Wh toe (~11 kW gemiddeld) — realistisch
  // voor een 11kW paal + 11kW auto scenario.
  // --------------------------------------------------------------------------
  Widget _fakeSessionControls(Booking booking) {
    final ctrl = _fakeSessions[booking.id];
    final isRunning = ctrl != null && ctrl.tickTimer != null;

    return Row(
      children: [
        Icon(
          isRunning
              ? Icons.stop_circle_outlined
              : Icons.play_circle_outline_rounded,
          size: 16,
          color: const Color(0xFF9E9E9E),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'DEV: ${isRunning ? 'Simulatie draait' : 'Geen live sessie'}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF9E9E9E),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        TextButton(
          onPressed: isRunning
              ? () => _stopFakeSession(booking.id)
              : () => _startFakeSession(booking.id),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: isRunning
                ? AppColors.danger
                : const Color(0xFF34C759),
            textStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(isRunning ? 'Stop simulatie' : 'Simuleer sessie'),
        ),
      ],
    );
  }

  Future<void> _startFakeSession(String bookingId) async {
    try {
      final result = await supabase
          .rpc('dev_start_fake_session', params: {'p_booking_id': bookingId});
      final txId = result is int ? result : (result as num).toInt();

      // Ticker registreren — vult meter_current_wh elke 5s met +15 Wh
      // (~11 kW gemiddeld). Rekensom: 11 kW · 5 s = 55.000 Ws = 15,28 Wh.
      // Realtime-subscribe in de widget pikt 't op.
      final timer = Timer.periodic(const Duration(seconds: 5), (_) async {
        try {
          await supabase.rpc(
            'dev_tick_fake_session',
            params: {'p_transaction_id': txId, 'p_add_wh': 15},
          );
        } catch (_) {
          // Silent — sessie is misschien handmatig gestopt in DB
        }
      });

      if (!mounted) return;
      setState(() {
        _fakeSessions[bookingId] =
            _FakeSessionCtrl(transactionId: txId, tickTimer: timer);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Simulatie start faalde: $e')),
      );
    }
  }

  Future<void> _stopFakeSession(String bookingId) async {
    final ctrl = _fakeSessions[bookingId];
    if (ctrl == null) return;
    ctrl.tickTimer?.cancel();
    try {
      await supabase.rpc(
        'dev_stop_fake_session',
        params: {'p_transaction_id': ctrl.transactionId},
      );
    } catch (_) {
      // Silent — als 'ie al gestopt is is dat OK
    }
    if (!mounted) return;
    setState(() {
      _fakeSessions.remove(bookingId);
    });
  }
}

/// Handle om een lopende dev-mode fake-session te tracken: transaction_id
/// (nodig voor tick + stop RPCs) + de Timer die elke X seconden een tick
/// vuurt. Cancel de Timer → tick-loop stopt (maar de sessie zelf loopt door
/// tot expliciete stop-RPC).
class _FakeSessionCtrl {
  _FakeSessionCtrl({required this.transactionId, required this.tickTimer});

  final int transactionId;
  Timer? tickTimer;
}

// ============================================================================
// _OcppSessionControls — task #293
//
// Toont op de boekingskaart één van twee knoppen, afhankelijk van of er op dit
// moment een actieve OCPP-sessie loopt voor de boeking:
//   • Geen actieve sessie → "Start laden nu"  (roept remote-start-session aan)
//   • Actieve sessie      → "Stop laden nu"   (roept remote-stop-session aan)
//
// De edge functions praten met de CSMS (Hetzner VPS #266) en die stuurt een
// RemoteStartTransaction / RemoteStopTransaction naar de fysieke paal. De
// paal accepteert of weigert; wij tonen die uitkomst als SnackBar.
//
// Realtime houdt de knop-state in sync: zodra de paal een StartTransaction /
// StopTransaction terugstuurt, verandert charging_sessions.status in de DB
// en flippen we de knop binnen ~1s. Belangrijk voor UX omdat er tussen
// "app zegt 'Accepted'" en "sessie loopt écht" nog een control-pilot-dans
// zit die enkele seconden kost.
//
// Zichtbaar alleen wanneer de parent besluit dat de context klopt (booking
// confirmed, charger heeft ocpp_charger_id, boekingsvenster nog niet
// verstreken). Deze widget doet zelf géén tijdsvenster-check — die zit in
// remote-start-session (2 min early, 5 min late) en zou hier alleen maar
// dubbelop-ruis geven.
// ============================================================================
class _OcppSessionControls extends StatefulWidget {
  const _OcppSessionControls({Key? key, required this.booking})
      : super(key: key);

  final Booking booking;

  @override
  State<_OcppSessionControls> createState() => _OcppSessionControlsState();
}

class _OcppSessionControlsState extends State<_OcppSessionControls> {
  final _supa = Supabase.instance.client;

  // Realtime-listener op charging_sessions gefilterd op booking_id. Bij elke
  // wijziging (INSERT bij StartTransaction, UPDATE bij StopTransaction /
  // meter-tick) herladen we de "is er een actieve sessie"-check.
  RealtimeChannel? _channel;

  bool _hasActive = false;
  bool _initialized = false; // false tot _loadActive() minstens één keer klaar is
  bool _busy = false; // knop in-flight — voorkomt dubbeltaps

  @override
  void initState() {
    super.initState();
    _loadActive();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _OcppSessionControls old) {
    super.didUpdateWidget(old);
    // Andere boeking rendert deze widget nu? Reset state + resubscribe.
    if (old.booking.id != widget.booking.id) {
      _channel?.unsubscribe();
      _channel = null;
      _hasActive = false;
      _initialized = false;
      _loadActive();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadActive() async {
    try {
      final row = await _supa
          .from('charging_sessions')
          .select('transaction_id, status')
          .eq('booking_id', widget.booking.id)
          .eq('status', 'in_progress')
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _hasActive = row != null;
        _initialized = true;
      });
    } catch (_) {
      if (!mounted) return;
      // Fout tijdens de check: laat de knop op "Start" staan als default
      // (leest natuurlijker dan een greyed-out knop en de edge function
      // slaat een dubbelstart alsnog af als er tóch al een sessie loopt).
      setState(() => _initialized = true);
    }
  }

  void _subscribe() {
    _channel = _supa
        .channel('ocpp_ctrl_${widget.booking.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'charging_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: widget.booking.id,
          ),
          callback: (_) {
            if (!mounted) return;
            // Simpelst en correct bij zowel INSERT (StartTransaction),
            // UPDATE (StopTransaction / meter-tick), als DELETE.
            _loadActive();
          },
        )
        .subscribe();
  }

  Future<void> _remoteStart() async {
    await _invokeRemote(
      fn: 'remote-start-session',
      okMsg: 'Laadopdracht verstuurd — de paal begint zo met laden.',
      declinedFallback:
          'De paal wees het startverzoek af. Probeer het opnieuw.',
      networkFallback: 'Kon niet starten — check je internetverbinding.',
    );
  }

  Future<void> _remoteStop() async {
    await _invokeRemote(
      fn: 'remote-stop-session',
      okMsg: 'Stop-opdracht verstuurd — sessie sluit zo af.',
      declinedFallback:
          'De paal wees het stopverzoek af. Probeer het opnieuw.',
      networkFallback: 'Kon niet stoppen — check je internetverbinding.',
    );
  }

  // Gedeelde invoke-flow: zowel remote-start als remote-stop retourneren
  // hetzelfde antwoord-schema { accepted, ocppResponse, reason?, error? }
  // en kunnen op precies dezelfde paden falen.
  Future<void> _invokeRemote({
    required String fn,
    required String okMsg,
    required String declinedFallback,
    required String networkFallback,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await _supa.functions.invoke(
        fn,
        body: {'booking_id': widget.booking.id},
      );

      // supabase_flutter gooit soms géén FunctionException bij non-2xx
      // (afhankelijk van SDK-versie) — check zelf ook de status. Ons
      // edge-functie-schema: 200 = accepted, 409 = declined (met reason),
      // 4xx/5xx overig = error (met error-message).
      final status = res.status ?? 0;
      final data = res.data;
      if (status >= 400) {
        if (!mounted) return;
        _toast(_reasonFrom(data) ?? declinedFallback);
        return;
      }

      final accepted = data is Map && data['accepted'] == true;
      if (!mounted) return;
      _toast(accepted ? okMsg : (_reasonFrom(data) ?? declinedFallback));
    } on FunctionException catch (e) {
      // Nieuwere supabase_flutter-versies gooien dit voor non-2xx. De
      // .details bevat de geparste response body — daar zit onze reason /
      // error in.
      if (!mounted) return;
      _toast(_reasonFrom(e.details) ?? declinedFallback);
    } catch (_) {
      if (!mounted) return;
      _toast(networkFallback);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Peuter een leesbaar bericht uit de edge-function response — we accepteren
  // zowel { reason: "..." } (409-pad, expliciete OCPP-rejection) als
  // { error: "..." } (400/500-pad).
  String? _reasonFrom(dynamic data) {
    if (data is Map) {
      final r = data['reason'];
      if (r is String && r.trim().isNotEmpty) return r;
      final e = data['error'];
      if (e is String && e.trim().isNotEmpty) return e;
    }
    return null;
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Zolang de eerste session-lookup nog loopt: reserveer alvast de ruimte
    // maar toon nog geen knop, om te voorkomen dat we per ongeluk "Start"
    // laten zien terwijl er al een sessie draait. Voelt korter dan het lijkt
    // (~200ms op WiFi).
    if (!_initialized) {
      return const SizedBox(height: 44);
    }

    final isStart = !_hasActive;
    final Color color = isStart ? AppColors.primary : AppColors.danger;
    final IconData icon =
        isStart ? Icons.play_arrow_rounded : Icons.stop_rounded;
    final String label = _busy
        ? 'Bezig…'
        : (isStart ? 'Start laden nu' : 'Stop laden nu');

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : (isStart ? _remoteStart : _remoteStop),
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18, color: color),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: color.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
  late final TextEditingController _ibanController;
  bool _saving = false;
  bool _loadingIban = true;

  // Huidige avatar-URL uit user_metadata (kan null zijn als niet gezet)
  String? _currentAvatarUrl;
  // Net geselecteerde foto die nog moet worden geüpload
  XFile? _pickedAvatar;

  // Pluggo Pionier-status — read-only, alleen door Pluggo zelf te wijzigen
  // (zie 0009_pioneer_status.sql trigger). Tonen we als een gouden banner
  // bovenaan het profiel voor de mensen die deze status hebben.
  bool _isPioneer = false;
  DateTime? _pioneerSince;

  // Voertuig-velden (task #286) — gaan naar profiles.vehicle_*.
  // Nodig voor Live ETA-berekening (task #287) en auto-stop op target-SoC
  // (task #289). Alle drie optioneel opslaan: user mag ze leeg laten,
  // maar dan valt de app terug op conservatieve schattingen op basis van
  // gemeten laadtempo.
  late final TextEditingController _vehicleModelController;
  late final TextEditingController _vehicleBatteryKwhController;
  late final TextEditingController _vehicleMaxAcKwController;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    final meta = user?.userMetadata;
    _nameController = TextEditingController(
      text: (meta?['full_name'] as String?) ?? '',
    );
    _ibanController = TextEditingController();
    _vehicleModelController = TextEditingController();
    _vehicleBatteryKwhController = TextEditingController();
    _vehicleMaxAcKwController = TextEditingController();
    _currentAvatarUrl = meta?['avatar_url'] as String?;
    // IBAN + Pionier-status + voertuig-velden staan in profiles — niet in
    // user_metadata. Async laden in één call.
    _loadProfileExtras();
  }

  Future<void> _loadProfileExtras() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingIban = false);
      return;
    }
    try {
      final row = await supabase
          .from('profiles')
          .select(
            'iban, is_pioneer, pioneer_since, '
            'vehicle_model, vehicle_battery_capacity_kwh, vehicle_max_ac_kw',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      if (row == null) {
        setState(() => _loadingIban = false);
        return;
      }
      final iban = row['iban'] as String?;
      final pioneer = row['is_pioneer'] as bool? ?? false;
      final since = row['pioneer_since'] as String?;
      final vehicleModel = row['vehicle_model'] as String?;
      // numeric-kolommen komen via Supabase soms als num (int/double) en
      // soms als String terug (afhankelijk van de decoder). Robuust parsen.
      final batteryKwh = _asDouble(row['vehicle_battery_capacity_kwh']);
      final maxAcKw = _asDouble(row['vehicle_max_ac_kw']);
      setState(() {
        if (iban != null && iban.isNotEmpty) {
          _ibanController.text = prettyIban(iban);
        }
        _isPioneer = pioneer;
        _pioneerSince = since != null ? DateTime.tryParse(since) : null;
        if (vehicleModel != null && vehicleModel.isNotEmpty) {
          _vehicleModelController.text = vehicleModel;
        }
        if (batteryKwh != null) {
          _vehicleBatteryKwhController.text = _prettyKwh(batteryKwh);
        }
        if (maxAcKw != null) {
          _vehicleMaxAcKwController.text = _prettyKwh(maxAcKw);
        }
        _loadingIban = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingIban = false);
    }
  }

  /// Robuust dubbel-parsen: Supabase geeft numeric-kolommen soms als int,
  /// soms als double, soms als String terug.
  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Format 77.0 → "77", 6.6 → "6.6" (geen trailing .0).
  String _prettyKwh(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  /// Parseert een user-input string als kWh-getal. Accepteert zowel komma
  /// als punt als decimaal-separator (NL-gebruikers typen vaak "7,4").
  /// Lege string of niet-parseable → null.
  double? _parseKwh(String raw) {
    final s = raw.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  /// Toont een bottom-sheet met de preset-lijst. Bij tap: vult model +
  /// capacity + AC-kW in de bijbehorende velden. Sentinel "Anders /
  /// handmatig" leegt alles zodat de user zelf kan typen.
  void _showVehiclePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Sleep-handle
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kies je auto',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zodat we je laadtijd en % vol goed kunnen schatten',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    // +1 voor "Anders / handmatig" sentinel bovenaan.
                    itemCount: kVehiclePresets.length + 1,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, i) {
                      // Eerste item = "Anders / handmatig" sentinel.
                      // Bovenaan i.p.v. onderaan zodat wie 'm nodig heeft
                      // niet 30+ items hoeft door te scrollen.
                      if (i == 0) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            'Anders / handmatig invullen',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Vul zelf model, accu en AC-vermogen in',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _vehicleModelController.clear();
                              _vehicleBatteryKwhController.clear();
                              _vehicleMaxAcKwController.clear();
                            });
                          },
                        );
                      }
                      final preset = kVehiclePresets[i - 1];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.directions_car_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          preset.model,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${_prettyKwh(preset.batteryCapacityKwh)} kWh · '
                          'max ${_prettyKwh(preset.maxAcKw)} kW AC',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _vehicleModelController.text = preset.model;
                            _vehicleBatteryKwhController.text =
                                _prettyKwh(preset.batteryCapacityKwh);
                            _vehicleMaxAcKwController.text =
                                _prettyKwh(preset.maxAcKw);
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }

  /// Gouden banner die alleen verschijnt bij Pluggo Pioniers.
  /// Toont de badge + een korte erkenning, en zo mogelijk "Pionier sinds …".
  Widget _pioneerBanner() {
    String? sinceLabel;
    if (_pioneerSince != null) {
      final local = _pioneerSince!.toLocal();
      sinceLabel = '${_monthNames[local.month]} ${local.year}';
    }
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6D6), Color(0xFFFDEAB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.pioneer.withOpacity(0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pioneer.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PioneerBadge(size: PioneerBadgeSize.large),
          const SizedBox(height: 10),
          Text(
            'Je bent een Pluggo Pionier',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.pioneerDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sinceLabel != null
                ? 'Pionier sinds $sinceLabel. Je paal krijgt voorrang in de '
                    'zoekresultaten binnen je postcode-gebied — bedankt dat '
                    'je er vroeg in geloofde.'
                : 'Je paal krijgt voorrang in de zoekresultaten binnen je '
                    'postcode-gebied — bedankt dat je er vroeg in geloofde.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.pioneerDark.withOpacity(0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ibanController.dispose();
    _vehicleModelController.dispose();
    _vehicleBatteryKwhController.dispose();
    _vehicleMaxAcKwController.dispose();
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

      // IBAN gaat naar de profiles-tabel (niet user_metadata): we hebben
      // 'm later in edge functions nodig om payouts te triggeren, en
      // willen 'm onder RLS-controle. Lege input = NULL opslaan.
      final ibanInput = _ibanController.text.trim();
      final ibanToSave =
          ibanInput.isEmpty ? null : normalizeIban(ibanInput);

      // Voertuig-velden (task #286). Alle drie optioneel: lege input = NULL.
      // Numeric-velden ondersteunen komma of punt als decimaal separator
      // (NL-gebruikers typen vaak "7,4" ipv "7.4").
      final vehicleModelInput = _vehicleModelController.text.trim();
      final vehicleModelToSave =
          vehicleModelInput.isEmpty ? null : vehicleModelInput;
      final batteryKwhToSave =
          _parseKwh(_vehicleBatteryKwhController.text);
      final maxAcKwToSave = _parseKwh(_vehicleMaxAcKwController.text);

      // Upsert: profielen worden normaal door handle_new_user-trigger
      // aangemaakt, maar voor de zekerheid upserten we hier toch.
      await supabase.from('profiles').upsert({
        'id': userId,
        'iban': ibanToSave,
        'vehicle_model': vehicleModelToSave,
        'vehicle_battery_capacity_kwh': batteryKwhToSave,
        'vehicle_max_ac_kw': maxAcKwToSave,
      });

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
                const SizedBox(height: 20),
                // Pluggo Pionier-banner — alleen zichtbaar voor wie deze
                // status heeft. Read-only — kan alleen door Pluggo zelf
                // gezet worden (zie 0009_pioneer_status.sql trigger).
                if (_isPioneer) _pioneerBanner(),
                if (_isPioneer) const SizedBox(height: 20),
                const SizedBox(height: 8),
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
                // IBAN — verplicht voor wie een paal aanbiedt, optioneel
                // voor wie alleen boekt. Validatie staat alleen aan zodra
                // er iets getypt is, zodat boekers het veld leeg mogen laten.
                Row(
                  children: [
                    Text(
                      'IBAN',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.account_balance_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ibanController,
                  textCapitalization: TextCapitalization.characters,
                  enabled: !_loadingIban,
                  // IbanInputFormatter strippt spaties, uppercaset, en zet
                  // automatisch elke 4 tekens een spatie. Cap op 18 chars
                  // (NL-IBAN-lengte). Geeft real-time "NL12 ABCD ..." UX
                  // zonder dat de gebruiker zelf spaties hoeft te typen.
                  inputFormatters: [IbanInputFormatter()],
                  decoration: InputDecoration(
                    hintText: _loadingIban
                        ? 'Laden…'
                        : 'NL12 ABCD 0123 4567 89',
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
                    if (v.isEmpty) return null; // optioneel
                    // isValidNlIban doet nu zowel structuur als mod-97
                    // checksum, dus dezelfde foutmelding dekt beide gevallen.
                    if (!isValidNlIban(v)) {
                      return 'Geen geldige Nederlandse IBAN';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Verplicht als je een laadpaal wilt aanbieden — '
                  'op deze rekening krijg je je aandeel uitbetaald '
                  '(je paalprijs minus €0,03/kWh servicefee).',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
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
                const SizedBox(height: 28),
                // ============================================
                // Voertuig — voor Live ETA-berekening (task #287)
                // en auto-stop bij target-SoC (task #289).
                // Preset-dropdown vult in één tap capacity + AC-kW
                // in, maar user mag alles overschrijven of leeg laten.
                // ============================================
                Row(
                  children: [
                    Text(
                      'Mijn auto',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.directions_car_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Nodig voor accurate laadtijd en % vol tijdens '
                  'een sessie. Je mag dit later ook invullen.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                // Model — tapbaar veld dat de picker opent
                Text(
                  'Model',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // TextFormField met readOnly=true zodat 't keyboard niet
                // opent maar de picker wél via onTap. De user kan alsnog
                // via onchange (na "Anders / handmatig") vrije tekst typen.
                TextFormField(
                  controller: _vehicleModelController,
                  readOnly: true,
                  onTap: _showVehiclePicker,
                  decoration: InputDecoration(
                    hintText: 'Kies je auto',
                    filled: true,
                    fillColor: AppColors.surface,
                    suffixIcon: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Twee getallen naast elkaar: batterij + max AC-vermogen
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Batterij-capaciteit
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accu (kWh)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _vehicleBatteryKwhController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              hintText: 'bijv. 77',
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
                              final v = _parseKwh(value ?? '');
                              if (value == null || value.trim().isEmpty) {
                                return null; // optioneel
                              }
                              if (v == null) return 'Ongeldig getal';
                              if (v < 5 || v > 250) return '5–250 kWh';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Max AC-vermogen
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Max AC (kW)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _vehicleMaxAcKwController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              hintText: 'bijv. 11',
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
                              final v = _parseKwh(value ?? '');
                              if (value == null || value.trim().isEmpty) {
                                return null; // optioneel
                              }
                              if (v == null) return 'Ongeldig getal';
                              // DB-constraint: > 0 en <= 43 kW.
                              if (v <= 0 || v > 43) return 'Max 43 kW';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
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
      final updated = await supabase
          .from('booker_reviews')
          .update({
            'booker_reply': text,
            'booker_replied_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', r.id)
          .select('id');
      if (updated.isEmpty) {
        throw Exception(
          'Reactie werd geweigerd. Mogelijk ben je niet meer de boeker.',
        );
      }
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
  // DAC7-status (task #263) — bepaalt of we een BSN/RSIN-banner tonen
  // bovenaan het inbox-scherm. `null` = nog geladen of niet van toepassing.
  Dac7Status? _dac7Status;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshDac7Status();
  }

  Future<void> _refreshDac7Status() async {
    final status = await fetchDac7StatusSilent();
    if (!mounted) return;
    setState(() => _dac7Status = status);
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
                  onRefresh: () async {
                    await _load();
                    await _refreshDac7Status();
                  },
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      // Task #263 — banner alleen zichtbaar als eigenaar tegen
                      // of over de DAC7-rapportagedrempel loopt zonder BSN/RSIN.
                      if (_dac7Status != null &&
                          _dac7Status!.needsAttention) ...[
                        Dac7Banner(
                          status: _dac7Status!,
                          onSubmitted: _refreshDac7Status,
                        ),
                        const SizedBox(height: 16),
                      ],
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
            // Confirmed + nog niet voorbij → eigenaar kan annuleren
            // (alleen als het echt niet door kan gaan; chat is voor losse opmerkingen)
            if (b.status == 'confirmed' && !isPast) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancelAsOwner(b),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Annuleer boeking'),
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
            // Pay-after-charge: na afloop moet de eigenaar het werkelijke
            // afgenomen kWh invullen, dan stuurt de app een betaalverzoek
            // naar de boeker.
            if (b.awaitingKwhInput) ...[
              const SizedBox(height: 12),
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
                          Icons.bolt_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Vul afgenomen kWh in',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lees het aantal kWh af op je laadpaal of in de app van je auto. '
                      'Daarna sturen we een betaalverzoek naar $bookerName.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _enterKwhForBooking(b),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Vul kWh in'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Owner heeft kWh ingevuld, wacht nu op betaling van boeker
            if (b.paymentRequestedAt != null && !b.isPaid && isPast) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      size: 16,
                      color: Color(0xFFB07000),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // We tonen het bedrag dat locked is op het
                            // moment van het betaalverzoek (total_amount_cents),
                            // niet de live kWh × current price — anders zou
                            // dit getal kunnen wijzigen als de owner achteraf
                            // de paalprijs aanpast (bug #69).
                            b.kwhConsumed != null && bookingPayableEuro(b) != null
                                ? 'Betaalverzoek verstuurd: '
                                    '${b.kwhConsumed!.toStringAsFixed(2).replaceAll('.', ',')} kWh × '
                                    '€${(bookingPayableEuro(b)! / b.kwhConsumed!).toStringAsFixed(2).replaceAll('.', ',')} '
                                    '= ${formatEuroDouble(bookingPayableEuro(b)!)}'
                                : 'Wachten op betaling',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB07000),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Boeker is nog niet betaald. Je krijgt je aandeel '
                            '(paalprijs − €0,03/kWh) uitbetaald zodra de betaling binnen is.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Boeker heeft betaald — owner kan zien dat het binnen is
            if (b.isPaid && isPast) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b.kwhConsumed != null && b.totalAmountCents != null
                            ? 'Betaald: ${formatEuroCents(b.totalAmountCents!)} '
                                '(${b.kwhConsumed!.toStringAsFixed(2).replaceAll('.', ',')} kWh)'
                            : 'Betaald',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
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

  // ----------------------------------------------------------------
  // Pay-after-charge: owner vult werkelijk afgenomen kWh in. We slaan
  // 't op in `bookings.kwh_consumed`, berekenen de bedragen, en zetten
  // payment_requested_at = now() zodat de boeker de Betalen-knop
  // krijgt. Daarna mailen we de boeker via de send-email edge function.
  // ----------------------------------------------------------------
  Future<void> _enterKwhForBooking(Booking b) async {
    // ----------------------------------------------------------------
    // Guard tegen dubbel-submit: de UI verbergt deze knop normaliter
    // zodra `kwh_consumed` gevuld is, maar tussen de eerste DB-update
    // en het volgende `_load()` is er een gat van een paar honderd ms
    // waarin de lokale `Booking b` nog `kwhConsumed == null` heeft.
    // Een tweede tap binnen dat venster zou de booking opnieuw met
    // een andere waarde overschrijven — terwijl de Stripe-betaling
    // al voor het eerste bedrag aangemaakt is.
    // We doen daarom een verse server-check vóór we de dialog tonen.
    // ----------------------------------------------------------------
    try {
      final freshRow = await supabase
          .from('bookings')
          .select('kwh_consumed, payment_requested_at, payment_status')
          .eq('id', b.id)
          .maybeSingle();
      if (freshRow != null) {
        final kwhAlreadySet = freshRow['kwh_consumed'] != null;
        final requestAlreadySent =
            freshRow['payment_requested_at'] != null;
        final ps = (freshRow['payment_status'] as String?) ?? 'unpaid';
        final paymentInFlight = ps == 'pending' || ps == 'paid';
        if (kwhAlreadySet || requestAlreadySent || paymentInFlight) {
          if (!mounted) return;
          final existingKwh = freshRow['kwh_consumed'];
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Betaalverzoek al verstuurd'),
              content: Text(
                existingKwh != null
                    ? 'Je hebt voor deze boeking al een betaalverzoek '
                          'verstuurd (${(existingKwh as num).toStringAsFixed(2).replaceAll('.', ',')} kWh). '
                          'Klopt dit niet? Neem contact op met support — '
                          'wij kunnen het bedrag aanpassen of de betaling '
                          'terugstorten.'
                    : 'Je hebt voor deze boeking al een betaalverzoek '
                          'verstuurd. Klopt dit niet? Neem contact op met '
                          'support.',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          // Refresh de lijst zodat de knop daadwerkelijk verdwijnt
          _load();
          return;
        }
      }
    } catch (_) {
      // Niet fataal — als de pre-check faalt, vallen we terug op het
      // oude gedrag. Beter de gebruiker doorlaten dan permanent blokkeren.
    }

    final kwhCtrl = TextEditingController();
    final pricePerKwh = parseChargerPrice(b.charger?.price ?? '0');
    final allInPerKwh = bookerPricePerKwh(b.charger?.price ?? '0');
    final hostNetPerKwh = hostNetPricePerKwh(b.charger?.price ?? '0');

    // Live preview-state in de dialog. previewKwh houden we apart bij
    // zodat we breakdowns in beide richtingen kunnen tonen.
    double? previewKwh;
    double? previewTotal; // wat de booker betaalt (incl. €0,03/kWh fee)
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void recompute() {
              final raw = kwhCtrl.text.trim().replaceAll(',', '.');
              final parsed = double.tryParse(raw);
              if (parsed == null) {
                previewKwh = null;
                previewTotal = null;
                errorText = raw.isEmpty ? null : 'Ongeldig getal';
              } else if (parsed <= 0) {
                previewKwh = null;
                previewTotal = null;
                errorText = 'Moet groter zijn dan 0';
              } else if (parsed > 200) {
                // Sanity check — een privé-paal levert geen 200 kWh in een sessie
                previewKwh = null;
                previewTotal = null;
                errorText = 'Te hoog — controleer je waarde';
              } else {
                previewKwh = parsed;
                previewTotal =
                    parsed * allInPerKwh + smallSessionFeeFor(parsed);
                errorText = null;
              }
              setLocal(() {});
            }

            final ownerShare = (previewKwh ?? 0) * hostNetPerKwh;
            final smallFee = smallSessionFeeFor(previewKwh ?? 0);

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Afgenomen kWh invullen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vul in hoeveel kWh ${b.userName ?? 'de boeker'} heeft '
                      'afgenomen. Lees dit af op je laadpaal of energiemeter.',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kwhCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => recompute(),
                      decoration: InputDecoration(
                        labelText: 'kWh afgenomen',
                        hintText: 'bv. 12,5',
                        suffixText: 'kWh',
                        errorText: errorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jouw paalprijs: €${pricePerKwh.toStringAsFixed(2).replaceAll('.', ',')} per kWh',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Boeker betaalt: €${allInPerKwh.toStringAsFixed(2).replaceAll('.', ',')} per kWh '
                            '(incl. €0,03 servicefee)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Jij ontvangt: €${hostNetPerKwh.toStringAsFixed(2).replaceAll('.', ',')} per kWh '
                            '(na €0,03 servicefee)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (previewTotal != null) ...[
                            _payRow(
                              'Totaal voor boeker',
                              formatEuroDouble(previewTotal!),
                              bold: true,
                            ),
                            const SizedBox(height: 2),
                            _payRow(
                              'Naar jou',
                              formatEuroDouble(ownerShare),
                            ),
                            _payRow(
                              'Pluggo servicefee (€0,06/kWh)',
                              formatEuroDouble(
                                (previewKwh ?? 0) * pluggoFeePerKwh,
                              ),
                            ),
                            if (smallFee > 0)
                              _payRow(
                                'Mini-sessie fee (<10 kWh)',
                                formatEuroDouble(smallFee),
                              ),
                          ] else
                            Text(
                              'Vul kWh in om het bedrag te berekenen',
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuleren'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: previewTotal == null
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Verstuur betaalverzoek'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final kwh = double.tryParse(kwhCtrl.text.trim().replaceAll(',', '.'));
    if (kwh == null || kwh <= 0) return;

    // Pricing-model (per mei 2026):
    //   booker betaalt = kWh × (paalprijs + €0,03) + €0,40 als kWh < 10
    //   pluggo houdt   = kWh × €0,06 + €0,40 als kWh < 10
    //   host ontvangt  = kWh × (paalprijs − €0,03)  — onafhankelijk van fee
    final smallFee = smallSessionFeeFor(kwh);
    final totalEuro = kwh * (pricePerKwh + bookerFeePerKwh) + smallFee;
    final totalCents = (totalEuro * 100).round();
    final feeCents =
        (kwh * pluggoFeePerKwh * 100).round() + (smallFee * 100).round();
    final ownerCents = totalCents - feeCents;

    try {
      // Belangrijk: we voegen .select() toe zodat Supabase de geüpdatete rij
      // teruggeeft. Zonder .select() returnt een RLS-rejected update óók
      // succesvol (met 0 rijen), waardoor we silent failures niet zagen
      // (bug: owner zag "Betaalverzoek verstuurd" terwijl DB ongewijzigd bleef).
      final updated = await supabase
          .from('bookings')
          .update({
            'kwh_consumed': kwh,
            'payment_requested_at': DateTime.now().toUtc().toIso8601String(),
            'total_amount_cents': totalCents,
            'service_fee_cents': feeCents,
            'owner_share_cents': ownerCents,
          })
          .eq('id', b.id)
          .select('id, kwh_consumed');

      if (updated.isEmpty) {
        throw Exception(
          'Update werd geweigerd (0 rijen aangepast). Mogelijk RLS-probleem '
          'of je bent niet meer eigenaar van deze paal.',
        );
      }

      // Best-effort: stuur boeker een email dat 'ie kan betalen.
      _sendPaymentRequestEmail(b, kwh, totalEuro);

      // Push naar de boeker — die moet weten dat er een betaalverzoek staat.
      // Fire-and-forget.
      // ignore: unawaited_futures
      PluggoPush.sendTo(
        userId: b.userId,
        title: 'Betaalverzoek voor je laadsessie',
        body:
            'De eigenaar heeft ${kwh.toStringAsFixed(1)} kWh ingevuld — '
            'open de app om ${formatEuroDouble(totalEuro)} te betalen.',
        data: {
          'type': 'payment_requested',
          'booking_id': b.id,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Betaalverzoek van ${formatEuroDouble(totalEuro)} verstuurd',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon kWh niet opslaan: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ----------------------------------------------------------------
  // Helper: kleine "label - value" rij voor de payment-preview.
  // ----------------------------------------------------------------
  Widget _payRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // Stuurt boeker een mail met het betaalverzoek na invullen kWh.
  // Hergebruikt de bestaande `send-email` edge function.
  // ----------------------------------------------------------------
  Future<void> _sendPaymentRequestEmail(
    Booking b,
    double kwh,
    double totalEuro,
  ) async {
    final to = b.userEmail;
    if (to == null || to.isEmpty) return;

    final chargerName = b.charger?.name ?? 'de laadpaal';
    final boekerNaam = b.userName?.split(' ').first ?? 'daar';
    // De prijs die we de booker tonen is de all-in prijs (paalprijs +
    // €0,03/kWh servicefee). totalEuro is al inclusief deze fee én eventuele
    // mini-sessie fee bij kWh < 10.
    final allInPerKwh = bookerPricePerKwh(b.charger?.price ?? '0');
    final smallFee = smallSessionFeeFor(kwh);
    final kwhStr = kwh.toStringAsFixed(2).replaceAll('.', ',');
    final priceStr = allInPerKwh.toStringAsFixed(2).replaceAll('.', ',');
    final totalStr = totalEuro.toStringAsFixed(2).replaceAll('.', ',');
    final stroomDeel = kwh * allInPerKwh;
    final stroomStr = stroomDeel.toStringAsFixed(2).replaceAll('.', ',');

    final subject = 'Je laadbeurt is klaar — betaal €$totalStr';

    final html = '''
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#F5F5F5;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;">
  <div style="max-width:600px;margin:0 auto;background:#fff;padding:32px 24px;">
    <h1 style="margin:0 0 8px;color:#00A87E;font-size:24px;">Pluggo</h1>
    <p style="margin:0 0 24px;color:#666;font-size:14px;">Buren laden bij buren</p>

    <h2 style="margin:0 0 16px;font-size:20px;color:#222;">Hoi $boekerNaam,</h2>

    <p style="margin:0 0 16px;color:#444;font-size:14px;">
      Je laadbeurt bij <strong>$chargerName</strong> is afgerond. De eigenaar
      heeft ingevuld dat je $kwhStr kWh hebt afgenomen.
    </p>

    <div style="background:#E6F7F0;border-left:4px solid #00A87E;padding:16px 20px;margin:24px 0;border-radius:6px;">
      <p style="margin:0;color:#005C44;font-size:14px;">
        $kwhStr kWh × €$priceStr per kWh (incl. €0,03 servicefee) = €$stroomStr
      </p>
      ${smallFee > 0 ? '''<p style="margin:4px 0 0;color:#005C44;font-size:14px;">
        Mini-sessie fee (sessie &lt;10 kWh): €0,40
      </p>''' : ''}
      <p style="margin:8px 0 0;color:#005C44;font-size:20px;font-weight:600;">
        Totaal: €$totalStr
      </p>
    </div>

    <p style="margin:0 0 8px;color:#444;font-size:14px;">
      Open de Pluggo-app om je boeking af te rekenen via iDEAL of een andere
      methode. De servicefee bedraagt €0,03/kWh${smallFee > 0 ? ' plus een eenmalige €0,40 mini-sessie fee omdat deze sessie onder de 10 kWh blijft' : ''} — de rest gaat naar de eigenaar.
    </p>

    <p style="margin:16px 0 0;color:#666;font-size:13px;">
      Tip: rond de betaling binnen 7 dagen af, anders kun je tijdelijk geen
      nieuwe boekingen meer maken.
    </p>

    <hr style="border:none;border-top:1px solid #eee;margin:32px 0 16px;">
    <p style="margin:0;color:#999;font-size:12px;">Je ontvangt deze mail omdat je een laadbeurt hebt gemaakt via Pluggo.</p>
  </div>
</body>
</html>
''';

    try {
      await supabase.functions.invoke(
        'send-email',
        body: {'to': to, 'subject': subject, 'html': html},
      );
    } catch (e, st) {
      debugPrint('send-email (payment request → booker) failed: $e\n$st');
    }
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
      // .select() verplicht zodat we silent RLS-fails detecteren —
      // zonder .select() retourneert een geweigerde update óók success.
      final updated = await supabase
          .from('bookings')
          .update({'status': accept ? 'confirmed' : 'rejected'})
          .eq('id', b.id)
          .select('id');
      if (updated.isEmpty) {
        throw Exception(
          'Update werd geweigerd (0 rijen aangepast). Mogelijk ben je niet '
          'meer eigenaar van deze paal of is de boeking ondertussen gewijzigd.',
        );
      }
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

      // 4) Push naar de boeker — die wil meteen weten of de aanvraag door is.
      // Fire-and-forget. b.userId is de boeker.
      final chargerName = b.charger?.name ?? 'de laadpaal';
      // ignore: unawaited_futures
      PluggoPush.sendTo(
        userId: b.userId,
        title: accept
            ? 'Boeking geaccepteerd'
            : 'Boeking afgewezen',
        body: accept
            ? 'Je reservering bij $chargerName is bevestigd.'
            : 'Helaas, je aanvraag voor $chargerName is afgewezen.',
        data: {
          'type': accept ? 'booking_confirmed' : 'booking_rejected',
          'booking_id': b.id,
        },
      );
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
    } catch (e, st) {
      debugPrint('send-email (decision → booker) failed: $e\n$st');
    }
  }

  // ----------------------------------------------------------------
  // Eigenaar annuleert een al-bevestigde boeking.
  // Vraagt om een optionele reden, zet status op 'cancelled' en mailt
  // de boeker via de send-email edge function.
  // ----------------------------------------------------------------
  Future<void> _cancelAsOwner(Booking b) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Boeking annuleren?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'De boeker krijgt direct bericht dat je deze boeking hebt '
              'geannuleerd. Doe dit alleen als het echt niet door kan gaan — '
              'voor losse opmerkingen kun je beter chatten.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Reden (optioneel, komt in de mail)',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Toch niet'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ja, annuleer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final reason = reasonCtrl.text.trim();
    try {
      final updated = await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', b.id)
          .select('id');
      if (updated.isEmpty) {
        throw Exception(
          'Annulering werd geweigerd (0 rijen aangepast). '
          'Mogelijk ben je niet meer eigenaar of is de boeking gewijzigd.',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Boeking geannuleerd. ${b.userName ?? "De boeker"} krijgt bericht.',
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
      // Fire-and-forget mail naar boeker
      _sendCancelEmailToBooker(b, reason.isEmpty ? null : reason);

      // Push naar de boeker — de mail komt binnen, maar een push is directer.
      // De reden nemen we bewust NIET in de body op: kan gevoelig zijn en
      // paste anders vaak toch niet in het notification-oppervlak.
      final chargerName = b.charger?.name ?? 'de laadpaal';
      // ignore: unawaited_futures
      PluggoPush.sendTo(
        userId: b.userId,
        title: 'Boeking geannuleerd',
        body:
            'De eigenaar heeft je reservering bij $chargerName geannuleerd. '
            'Bekijk de app voor details.',
        data: {
          'type': 'booking_cancelled_by_owner',
          'booking_id': b.id,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kon niet annuleren: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ----------------------------------------------------------------
  // Stuur de boeker een e-mail bij een door-eigenaar-annulering.
  // Gebruikt dezelfde send-email edge function (Resend) als de
  // accept/reject mail. Fire-and-forget.
  // ----------------------------------------------------------------
  Future<void> _sendCancelEmailToBooker(Booking b, String? reason) async {
    final to = b.userEmail;
    if (to == null || to.isEmpty) return;

    final chargerName = b.charger?.name ?? 'de laadpaal';
    final chargerAddress = b.charger?.address ?? '';
    final boekerNaam = b.userName?.split(' ').first ?? 'daar';

    final datum = _formatDateHeader(b.startTime);
    String two(int n) => n.toString().padLeft(2, '0');
    final start = '${two(b.startTime.hour)}:${two(b.startTime.minute)}';
    final eind = '${two(b.endTime.hour)}:${two(b.endTime.minute)}';

    final subject = 'Je boeking bij $chargerName is geannuleerd';

    final adresRegel = chargerAddress.isEmpty
        ? ''
        : '<tr><td style="padding:6px 0;color:#666;">Adres</td><td style="padding:6px 0;font-weight:500;">$chargerAddress</td></tr>';

    final redenBlok = (reason == null || reason.isEmpty)
        ? ''
        : '''
<div style="background:#FFF8E1;border-left:4px solid #F9A825;padding:14px 18px;margin:0 0 24px;border-radius:6px;">
  <p style="margin:0 0 4px;color:#7A5A00;font-size:13px;font-weight:600;">Reden van de eigenaar</p>
  <p style="margin:0;color:#333;font-size:14px;line-height:1.5;">$reason</p>
</div>''';

    final html = '''
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#F5F5F5;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;">
  <div style="max-width:600px;margin:0 auto;background:#fff;padding:32px 24px;">
    <h1 style="margin:0 0 8px;color:#1976D2;font-size:24px;">Pluggo</h1>
    <p style="margin:0 0 24px;color:#666;font-size:14px;">Buren laden bij buren</p>

    <h2 style="margin:0 0 16px;font-size:20px;color:#222;">Hoi $boekerNaam,</h2>

    <div style="background:#FFEBEE;border-left:4px solid #C62828;padding:16px 20px;margin:0 0 24px;border-radius:6px;">
      <p style="margin:0;color:#B71C1C;font-size:16px;font-weight:600;">Geannuleerd</p>
      <p style="margin:4px 0 0;color:#B71C1C;font-size:14px;">De eigenaar heeft je bevestigde boeking geannuleerd. Sorry voor het ongemak — kijk in de app voor een ander tijdslot of een andere paal in de buurt.</p>
    </div>

    $redenBlok

    <table style="width:100%;border-collapse:collapse;font-size:14px;color:#222;margin:0 0 24px;">
      <tr><td style="padding:6px 0;color:#666;width:90px;">Paal</td><td style="padding:6px 0;font-weight:500;">$chargerName</td></tr>
      $adresRegel
      <tr><td style="padding:6px 0;color:#666;">Datum</td><td style="padding:6px 0;font-weight:500;">$datum</td></tr>
      <tr><td style="padding:6px 0;color:#666;">Tijd</td><td style="padding:6px 0;font-weight:500;">$start – $eind</td></tr>
    </table>

    <p style="margin:0 0 8px;color:#444;font-size:14px;">Open de Pluggo-app om een ander moment of paal te kiezen.</p>
    <hr style="border:none;border-top:1px solid #eee;margin:32px 0 16px;">
    <p style="margin:0;color:#999;font-size:12px;">Je ontvangt deze mail omdat de eigenaar je boeking heeft geannuleerd.</p>
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
    } catch (e, st) {
      debugPrint('send-email (cancel → booker) failed: $e\n$st');
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
    } catch (e, st) {
      debugPrint('send-email (chat notification) failed: $e\n$st');
    }
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
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Column(
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
          if (onTap != null)
            Positioned(
              top: -2,
              right: -2,
              child: Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: tile,
    );
  }
}

/// Toont een bottom sheet met uitleg over de drie aansluiting-types
/// (Type 2, CCS, CHAdeMO). Aanroepbaar vanuit paal-toevoegen, paal-bewerken
/// en paal-detail.
void showConnectorTypeInfo(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Welke aansluiting heb ik?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _ConnectorRow(
              name: 'Type 2',
              description:
                  'De Europese standaard voor wisselstroom-laden. Vrijwel alle privé-laadpalen én vrijwel alle EV\'s in Nederland gebruiken Type 2.',
              isPrimary: true,
            ),
            const SizedBox(height: 12),
            _ConnectorRow(
              name: 'CCS',
              description:
                  'Voor snelladen met gelijkstroom (DC). Vooral te vinden bij publieke snellaadstations langs de snelweg, zelden bij thuispalen.',
            ),
            const SizedBox(height: 12),
            _ConnectorRow(
              name: 'CHAdeMO',
              description:
                  'Een oudere DC-snellaadstandaard, vooral op oudere Nissan- en Mitsubishi-modellen. Wordt langzaam uitgefaseerd.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Twijfel je? Kijk naar de stekker van je laadkabel — bijna elke Europese EV heeft Type 2.',
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConnectorRow extends StatelessWidget {
  final String name;
  final String description;
  final bool isPrimary;

  const _ConnectorRow({
    required this.name,
    required this.description,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
        ),
      ],
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
      // Als de gebruiker zijn email nog niet bevestigd heeft, geen ruwe
      // Supabase-error tonen maar het wachtscherm openen met resend-knop.
      // Supabase gebruikt code 'email_not_confirmed' (v2 GoTrue).
      final msg = e.message.toLowerCase();
      final unconfirmed = e.code == 'email_not_confirmed' ||
          msg.contains('email not confirmed') ||
          msg.contains('not confirmed');
      if (unconfirmed) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailVerificationPendingScreen(email: email),
          ),
        );
      } else {
        _showError(e.message);
      }
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
              // Vóór 7 juli: launch-banner zodat nieuwe downloaders zien
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
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError('Vul alle velden in');
      return;
    }
    if (password.length < 6) {
      _showError('Wachtwoord moet minimaal 6 tekens zijn');
      return;
    }
    // #305 — Rob D. maakte een typo bij signup en kon 't wachtwoord daarna
    // niet meer raden. Dubbele invoer + duidelijke error voorkomt dit
    // scenario. Tip erbij: verwijs naar het oog-icoontje zodat gebruikers
    // die 't nog niet zagen weten dat ze hun invoer kunnen verifiëren.
    if (password != confirmPassword) {
      _showError('De wachtwoorden komen niet overeen. Tip: druk op het oog-icoontje om je invoer te controleren.');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        // full_name komt terecht in raw_user_meta_data en wordt door onze
        // handle_new_user-trigger in de profiles-tabel gezet
        data: {'full_name': name},
      );
      if (!mounted) return;

      // Twee paden afhankelijk van Supabase "Confirm email" instelling:
      // 1) Confirm email AAN → res.session is null, user moet eerst de
      //    link in de bevestigingsmail klikken. We sturen 'm naar het
      //    "check je inbox"-scherm met resend-optie. Voorkomt fake/spam
      //    accounts.
      // 2) Confirm email UIT → res.session bestaat al, AuthGate pakt
      //    het op en navigeert naar HomeScreen. Fallback voor als we
      //    de toggle ooit uitzetten of in lokale dev.
      if (res.session == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationPendingScreen(email: email),
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
              // krijgen een seintje zodra Pluggo live gaat op 7 juli.
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
                  tooltip: _obscurePassword
                      ? 'Wachtwoord tonen'
                      : 'Wachtwoord verbergen',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 16),
              _fieldLabel('Wachtwoord bevestigen'),
              _authTextField(
                controller: _confirmPasswordController,
                hint: 'Typ hetzelfde wachtwoord nogmaals',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscureConfirmPassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  tooltip: _obscureConfirmPassword
                      ? 'Wachtwoord tonen'
                      : 'Wachtwoord verbergen',
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
// EmailVerificationPendingScreen
// ----------------------------------------------
// Toont na signup (of na een login-poging met een onbevestigd account) dat
// de gebruiker eerst op de link in zijn bevestigingsmail moet klikken.
// Heeft een resend-knop omdat de eerste mail vaak in spam belandt.
// Zonder deze stap kan iedereen oneindig fake accounts aanmaken met
// random emailadressen — kritiek voor abuse-preventie pre-launch.
// ============================================
class EmailVerificationPendingScreen extends StatefulWidget {
  final String email;
  const EmailVerificationPendingScreen({Key? key, required this.email})
      : super(key: key);

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  bool _resending = false;
  // Cooldown om resend-spam (en Supabase rate-limits) te voorkomen.
  // 60s sluit aan bij Supabase's default rate-limit op resend.
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldownSeconds -= 1);
      if (_cooldownSeconds <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (_resending || _cooldownSeconds > 0) return;
    setState(() => _resending = true);
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nieuwe bevestigingsmail verstuurd'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _startCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Er ging iets mis. Probeer het opnieuw.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
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
          // Pop terug naar de auth-root (login/signup), niet naar het
          // signup-formulier — gebruiker is daar al klaar mee.
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
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
                'We hebben een bevestigingsmail gestuurd naar\n${widget.email}.\n\n'
                'Klik op de link in de mail om je account te activeren. '
                'Kom daarna terug naar de app en log in.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tip: check ook je spam-folder.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.isFirst),
                  child: const Text('Terug naar inloggen'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (_resending || _cooldownSeconds > 0) ? null : _resend,
                child: Text(
                  _resending
                      ? 'Verzenden...'
                      : _cooldownSeconds > 0
                          ? 'Opnieuw versturen kan over ${_cooldownSeconds}s'
                          : 'Mail niet ontvangen? Opnieuw versturen',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: (_resending || _cooldownSeconds > 0)
                        ? AppColors.textSecondary
                        : AppColors.primary,
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
      // Supabase verstuurt een email met een verify-link. Na klik verifieert
      // Supabase de token en redirect naar `redirectTo` — onze eigen statische
      // reset-pagina op pluggoapp.nl die de nieuwe-wachtwoord-flow afhandelt
      // via supabase-js. Zonder deze parameter valt Supabase terug op de
      // default Site URL en landt de user op de homepage (waar niks met de
      // tokens gebeurt — bug die we op 15 juli 2026 zagen bij Rob D.).
      //
      // Deze URL moet ook in Supabase Dashboard → Auth → URL Configuration →
      // Redirect URLs staan als allowlist-entry, anders weigert Supabase de
      // redirect. Zie taak #304 en `docs/reset-password.html`.
      //
      // Later kunnen we hier een deep-link (pluggo://auth/reset) van maken —
      // zie taak #245. Deze web-pagina blijft dan fallback voor users die de
      // app niet geïnstalleerd hebben of op desktop klikken.
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://pluggoapp.nl/reset-password.html',
      );
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
      // .select() zodat een silent RLS-fail niet als success doorgaat —
      // dan zou de switch optisch geflipt blijven terwijl DB onveranderd is.
      final updated = await supabase
          .from('chargers')
          .update({'available': newValue})
          .eq('id', widget.charger.id)
          .select('id');
      if (updated.isEmpty) {
        throw Exception(
          'Wijziging werd geweigerd. Mogelijk ben je niet meer eigenaar.',
        );
      }
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
                          if (widget.charger.ownerIsPioneer) ...[
                            const SizedBox(width: 6),
                            const PioneerBadge(
                              size: PioneerBadgeSize.small,
                            ),
                          ],
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
                          // Eigen paal: toon eigen instelprijs.
                          // Andermans paal: toon de all-in prijs voor de booker
                          // (paalprijs + €0,03 servicefee).
                          Text(
                            widget.isOwner
                                ? '€${widget.charger.price}'
                                : '€${bookerPricePerKwh(widget.charger.price).toStringAsFixed(2).replaceAll('.', ',')}',
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

// ============================================================================
// DAC7 — BSN/RSIN drempelflow (task #263)
//
// EU-richtlijn 2021/514 (DAC7) verplicht platforms zoals Pluggo om jaarlijks
// aan de Belastingdienst te rapporteren welke paaleigenaren >=30 transacties
// OF >=EUR 2.000 aan payouts hebben gehad in het kalenderjaar. Rapportage
// vereist het TIN (BSN voor natuurlijke personen, RSIN voor rechtspersonen).
//
// Deze code is puur client-side UI + status-fetch. De echte state (drempel-
// tellers + gecrypteerde BSN-opslag) leeft in migratie 0032 + submit-tin
// edge function. Zie /supabase/migrations/0032_dac7_bsn_flow.sql.
//
// Wettelijk kader NL: art. 10c AWR + art. 8 Uitv.reg. WIB. Wij mogen (en
// moeten) BSN uitvragen zodra de drempel in zicht komt.
// ============================================================================

/// Uitkomst van de RPC dac7_status_for_owner() — bepaalt banner-state.
class Dac7Status {
  /// promptState is een van:
  ///   - not_required : nog ver van drempel, banner tonen niet
  ///   - early_warning: >=75% van drempel bereikt, vriendelijke banner
  ///   - required    : drempel bereikt EN geen BSN => payouts geblokkeerd
  ///   - provided    : BSN/RSIN is al aangeleverd
  final String promptState;

  /// Het jaar waarop de state betrekking heeft (kalender-jaar Europa/Amsterdam).
  final int reportingYear;

  /// Aantal transacties in dit jaar boven de fiscale timestamp.
  final int transactionCount;

  /// Totaal owner-payout bedrag in cents (na Pluggo-fee).
  final int totalAmountCents;

  /// Voorgestelde TIN-soort op basis van business_type — 'bsn' of 'rsin'.
  final String suggestedTinType;

  /// True zodra dac7_reporting_state.payouts_blocked_at gezet is.
  final bool payoutsBlocked;

  const Dac7Status({
    required this.promptState,
    required this.reportingYear,
    required this.transactionCount,
    required this.totalAmountCents,
    required this.suggestedTinType,
    required this.payoutsBlocked,
  });

  bool get needsAttention =>
      promptState == 'early_warning' || promptState == 'required';

  factory Dac7Status.fromMap(Map<String, dynamic> m) {
    return Dac7Status(
      promptState: (m['prompt_state'] as String?) ?? 'not_required',
      reportingYear: (m['reporting_year'] as num?)?.toInt() ??
          DateTime.now().year,
      transactionCount: (m['transaction_count'] as num?)?.toInt() ?? 0,
      totalAmountCents:
          (m['total_amount_cents'] as num?)?.toInt() ?? 0,
      suggestedTinType:
          (m['suggested_tin_type'] as String?) ?? 'bsn',
      // De RPC retourneert `payouts_blocked_at` (timestamptz). We converteren
      // naar boolean: aanwezig => geblokkeerd. Timestamp zelf hebben we in
      // de UI niet nodig, alleen ja/nee.
      payoutsBlocked: m['payouts_blocked_at'] != null,
    );
  }
}

/// Silent fetch — geen SnackBar-error, gewoon null teruggeven als er iets misgaat.
/// De banner-flow is best-effort; als DAC7-status niet ophaalbaar is willen we
/// de rest van het inbox-scherm niet blokkeren.
Future<Dac7Status?> fetchDac7StatusSilent() async {
  try {
    final data = await supabase.rpc('dac7_status_for_owner');
    if (data == null) return null;
    // De RPC retourneert een setof met exact 1 row.
    if (data is List && data.isNotEmpty) {
      return Dac7Status.fromMap(data.first as Map<String, dynamic>);
    }
    if (data is Map) {
      return Dac7Status.fromMap(data as Map<String, dynamic>);
    }
    return null;
  } catch (e) {
    debugPrint('fetchDac7StatusSilent failed: $e');
    return null;
  }
}


// ---------------------------------------------------------------------------
// Dac7Banner — compacte banner bovenaan de IncomingBookingsScreen.
//
// Twee varianten:
//   • early_warning → gele "iets voorbereiden" banner (Solar-tinten)
//   • required     → rode "actie vereist" banner (Danger-tinten). Blokkeert
//                    payouts server-side; hier alleen visueel accent + CTA.
// ---------------------------------------------------------------------------
class Dac7Banner extends StatelessWidget {
  final Dac7Status status;
  final VoidCallback onSubmitted;

  const Dac7Banner({
    Key? key,
    required this.status,
    required this.onSubmitted,
  }) : super(key: key);

  bool get _isBlocking => status.promptState == 'required';

  Color get _bg =>
      _isBlocking ? const Color(0xFFFEEBEB) : AppColors.warningSoft;
  Color get _border =>
      _isBlocking ? AppColors.danger : AppColors.warning;
  Color get _iconColor =>
      _isBlocking ? AppColors.danger : AppColors.warningDark;
  Color get _titleColor =>
      _isBlocking ? AppColors.danger : AppColors.warningDark;

  String get _title => _isBlocking
      ? 'Actie vereist: belastingnummer aanleveren'
      : 'Fiscale drempel bijna bereikt';

  String get _body {
    final tinLabel =
        status.suggestedTinType == 'rsin' ? 'RSIN' : 'BSN';
    final euro = (status.totalAmountCents / 100)
        .toStringAsFixed(2)
        .replaceAll('.', ',');
    if (_isBlocking) {
      return 'Je hebt de DAC7-rapportagedrempel bereikt '
          '(${status.transactionCount} boekingen of €$euro in ${status.reportingYear}). '
          'Volgens EU-richtlijn 2021/514 en art. 10c AWR moeten we je '
          '$tinLabel aanleveren aan de Belastingdienst. Nieuwe boekingen '
          'kunnen pas weer afgerekend worden zodra je je $tinLabel invult.';
    }
    return 'Je zit op ${status.transactionCount} boekingen / €$euro in ${status.reportingYear}. '
        'Bij overschrijding van de DAC7-drempel (30 boekingen of €2.000) '
        'moeten we je $tinLabel bij de Belastingdienst aanleveren. '
        'Alvast invullen voorkomt een tijdelijke payout-pauze.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withOpacity(0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _isBlocking
                    ? Icons.gpp_maybe_rounded
                    : Icons.info_outline_rounded,
                color: _iconColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _body,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isBlocking ? AppColors.danger : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Dac7TinPromptScreen(
                      suggestedTinType: status.suggestedTinType,
                      reportingYear: status.reportingYear,
                    ),
                  ),
                );
                if (result == true) onSubmitted();
              },
              child: Text(
                status.suggestedTinType == 'rsin'
                    ? 'RSIN invullen'
                    : 'BSN invullen',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dac7TinPromptScreen — formulier voor BSN/RSIN aanlevering.
//
// UX-vereisten (juridisch + productioneel):
//   • Duidelijke disclosure van grondslag (art. 10c AWR + DAC7).
//   • Uitleg dat Pluggo BSN encrypted opslaat, NIET plaintext.
//   • 11-proef live preview zodat gebruiker tikfouten zelf ziet.
//   • Format-hint: spaties/streepjes toegestaan, worden gestript.
//   • Onvoltooide submit blokkeert; alleen bij geldige 11-proef.
//
// Submitten gaat via de `submit-tin` edge function — die valideert
// nogmaals, encrypt met AES-256-GCM en zet payouts_blocked_at op null.
// ---------------------------------------------------------------------------
class Dac7TinPromptScreen extends StatefulWidget {
  final String suggestedTinType;
  final int reportingYear;

  const Dac7TinPromptScreen({
    Key? key,
    required this.suggestedTinType,
    required this.reportingYear,
  }) : super(key: key);

  @override
  State<Dac7TinPromptScreen> createState() => _Dac7TinPromptScreenState();
}

class _Dac7TinPromptScreenState extends State<Dac7TinPromptScreen> {
  late final TextEditingController _tinCtrl;
  late String _tinType;
  bool _submitting = false;
  String? _validationMsg;

  @override
  void initState() {
    super.initState();
    _tinCtrl = TextEditingController();
    _tinType = widget.suggestedTinType;
    _tinCtrl.addListener(_recomputeValidation);
  }

  @override
  void dispose() {
    _tinCtrl.dispose();
    super.dispose();
  }

  /// Elfproef: gewichten [9,8,7,6,5,4,3,2,-1], som mod 11 == 0.
  /// Werkt voor zowel BSN (natuurlijk persoon) als RSIN (rechtspersoon).
  bool _isValidElfproef(String digits) {
    if (digits.length != 9) return false;
    if (!RegExp(r'^\d{9}$').hasMatch(digits)) return false;
    // Eerste cijfer 0 mag niet — dan is het feitelijk 8-digit nummer
    // (Belastingdienst hanteert dit voor RSIN historisch wel eens, maar
    // voor DAC7-aanlevering vereisen we een 9-digit representatie).
    const weights = [9, 8, 7, 6, 5, 4, 3, 2, -1];
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(digits[i]) * weights[i];
    }
    return sum % 11 == 0;
  }

  String _stripped() => _tinCtrl.text.replaceAll(RegExp(r'[\s-]'), '');

  void _recomputeValidation() {
    final stripped = _stripped();
    setState(() {
      if (stripped.isEmpty) {
        _validationMsg = null;
      } else if (!RegExp(r'^\d+$').hasMatch(stripped)) {
        _validationMsg = 'Alleen cijfers (spaties/streepjes worden gestript)';
      } else if (stripped.length < 9) {
        _validationMsg = 'Nog ${9 - stripped.length} cijfers te gaan';
      } else if (stripped.length > 9) {
        _validationMsg = 'Te lang — een BSN/RSIN is 9 cijfers';
      } else if (!_isValidElfproef(stripped)) {
        _validationMsg = 'Elfproef klopt niet — check op tikfout';
      } else {
        _validationMsg = null;
      }
    });
  }

  bool get _canSubmit {
    final s = _stripped();
    return !_submitting && s.length == 9 && _isValidElfproef(s);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      final res = await supabase.functions.invoke(
        'submit-tin',
        body: {
          'tin': _stripped(),
          'tin_type': _tinType,
        },
      );
      final status = res.status ?? 0;
      if (status >= 400) {
        final msg = _errorMsgFrom(res.data) ??
            'Kon $_tinType niet opslaan (status $status)';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!mounted) return;
      final data = res.data;
      final last4 =
          (data is Map ? data['tin_last4'] as String? : null) ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bedankt — ${_tinType.toUpperCase()} eindigend op $last4 is veilig opgeslagen.',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Netwerkfout: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _errorMsgFrom(dynamic data) {
    if (data is Map) {
      final e = data['error'];
      if (e is String && e.isNotEmpty) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tinLabel = _tinType == 'rsin' ? 'RSIN' : 'BSN';
    final tinHelp = _tinType == 'rsin'
        ? 'Fiscaal nummer voor rechtspersonen (BV / stichting / VvE). '
            'Staat op je KvK-uittreksel of op post van de Belastingdienst.'
        : 'Je Burgerservicenummer — 9 cijfers, staat op je paspoort, '
            'ID-kaart of DigiD-post.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$tinLabel aanleveren'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wettelijke disclosure — MOET zichtbaar zijn voordat we
              // een BSN uitvragen. Grondslag: art. 10c AWR + Uitv.reg. WIB
              // + EU-richtlijn 2021/514 (DAC7). Zonder deze uitleg mag
              // Pluggo geen BSN vragen (privacy-verplichting AVG art. 13).
              _disclosureCard(),
              const SizedBox(height: 20),
              _tinTypeSelector(),
              const SizedBox(height: 20),
              Text(
                '$tinLabel invullen',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tinHelp,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 13, // 9 cijfers + 4 potentieel spaties/streepjes
                autofocus: true,
                style: GoogleFonts.robotoMono(
                  fontSize: 18,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  labelText: tinLabel,
                  hintText: '123 456 789',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  counterText: '',
                  errorText: _validationMsg,
                ),
              ),
              const SizedBox(height: 16),
              _securityCard(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor:
                        AppColors.textSecondary.withOpacity(0.3),
                  ),
                  onPressed: _canSubmit ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Veilig opslaan',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed:
                    _submitting ? null : () => Navigator.pop(context, false),
                child: const Text('Later — terug'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _disclosureCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.gavel_rounded,
                color: AppColors.primaryDark,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Waarom vragen we dit?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'EU-richtlijn 2021/514 (DAC7) verplicht Pluggo om over ${widget.reportingYear} '
            'aan de Nederlandse Belastingdienst te rapporteren welke '
            'paaleigenaren ≥30 boekingen of ≥€2.000 aan payouts hebben '
            'gehad. Rapportage vereist je BSN (particulier / eenmanszaak) '
            'of RSIN (BV / stichting / VvE).',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Grondslag: art. 10c AWR + art. 8 Uitv.reg. WIB. Zonder BSN/RSIN '
            'mogen we je payouts tijdelijk pauzeren totdat je aanlevert.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _tinTypeChip(
            value: 'bsn',
            label: 'BSN',
            sub: 'Particulier / eenmanszaak',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _tinTypeChip(
            value: 'rsin',
            label: 'RSIN',
            sub: 'BV / stichting / VvE',
          ),
        ),
      ],
    );
  }

  Widget _tinTypeChip({
    required String value,
    required String label,
    required String sub,
  }) {
    final selected = _tinType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => _tinType = value);
        _recomputeValidation();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _securityCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_moon_rounded,
            size: 18,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Je BSN/RSIN wordt AES-256-GCM versleuteld opgeslagen in onze '
              'database. Alleen ons rapportageproces richting de '
              'Belastingdienst kan de waarde ontsleutelen — niet Pluggo-medewerkers, '
              'niet ondersteuning en niet andere gebruikers. In de app tonen we '
              'alleen de laatste 4 cijfers ter bevestiging.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
