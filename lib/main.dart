import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/subscription_provider.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // 画面の向きを縦表示のみに制限
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  print('=== アプリ起動開始 ===');

  try {
    // SharedPreferencesの初期化
    await SharedPreferences.getInstance();
    print('SharedPreferences初期化完了');
  } catch (e) {
    print('SharedPreferences初期化エラー: $e');
  }

  try {
    // Google Mobile Adsの初期化
    await MobileAds.instance.initialize();
    print('Google Mobile Ads初期化完了');
  } catch (e) {
    print('Google Mobile Ads初期化エラー: $e');
  }

  runApp(
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
        create: (_) {
          final provider = SubscriptionProvider();
          // アプリ起動時にサブスクリプション状態を読み込み
          provider.loadStatus().then((_) {
            // 定期的にサブスクリプションの有効性をチェック（1時間ごと）
            Future.delayed(const Duration(hours: 1), () {
              provider.loadStatus();
            });
          });
          return provider;
        },
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('=== MyApp build ===');
    return MaterialApp(
      title: tr('app_title'),
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}

class TestHomePage extends StatelessWidget {
  const TestHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    print('=== TestHomePage build ===');
    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: const Text('かぎ針編みカウンター'),
        backgroundColor: Colors.pink,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.pink,
            ),
            SizedBox(height: 20),
            Text(
              'アプリが正常に動作しています！',
              style: TextStyle(
                fontSize: 24,
                color: Colors.pink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
