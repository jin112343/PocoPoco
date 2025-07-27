// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'package:poco/main.dart';
import 'package:poco/services/subscription_provider.dart';

void main() {
  testWidgets('Crochet counter app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [
          Locale('ja'),
          Locale('en'),
          Locale('ko'),
          Locale('es'),
          Locale('de'),
        ],
        path: 'assets/lang',
        fallbackLocale: const Locale('ja'),
        startLocale: const Locale('ja'),
        child: ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(),
          child: const MyApp(),
        ),
      ),
    );

    // Verify that the app title is displayed.
    expect(find.text('かぎ針編みカウンター'), findsOneWidget);

    // Verify that the initial row number is displayed.
    expect(find.text('1'), findsOneWidget);

    // Verify that the initial stitch count is displayed.
    expect(find.text('0目'), findsOneWidget);
  });
}
