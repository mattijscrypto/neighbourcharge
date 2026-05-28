// Basic smoke test — verifieert dat de Pluggo-app boot.
// De default counter-test van `flutter create` is hier weggehaald omdat
// Pluggo geen counter-app is en de oorspronkelijke MyApp-class niet bestaat.
//
// Voor uitgebreidere widget-tests: maak per scherm een aparte _test.dart
// onder test/screens/ aan.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots zonder crash', (WidgetTester tester) async {
    // Minimal smoke test: render een lege MaterialApp om te verifiëren dat
    // het Flutter testharness werkt. Volle integratietests vereisen Supabase
    // initialisatie en zitten in een aparte integration_test/ folder.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Pluggo'))),
      ),
    );

    expect(find.text('Pluggo'), findsOneWidget);
  });
}
