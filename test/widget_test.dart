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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poco/main.dart';
import 'package:poco/services/subscription_provider.dart';
import 'package:poco/services/theme_provider.dart';

void main() {
  setUpAll(() async {
    // テスト用にSharedPreferencesを初期化
    SharedPreferences.setMockInitialValues({});
    // EasyLocalizationの初期化
    WidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
  });

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
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: const MyApp(),
        ),
      ),
    );

    // EasyLocalizationが非同期でロードされるため、複数回pumpする
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 初期画面はInitializationScreen（ローディング画面）
    // ローディングインジケーターまたはローディングテキストが表示されることを確認
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('読み込み中...'), findsOneWidget);
  });
}
