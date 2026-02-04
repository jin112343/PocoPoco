import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/subscription_provider.dart';
import 'services/theme_provider.dart';
import 'services/data_migration_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // iPadの場合は全方向を許可、iPhoneの場合は縦のみ
  if (Platform.isIOS) {
    // デバイスの画面サイズでiPadかどうかを判定
    final data = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = data.physicalSize / data.devicePixelRatio;
    final shortestSide = size.shortestSide;

    // iPadの場合（shortest sideが600以上）
    if (shortestSide >= 600) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // iPhoneの場合は縦のみ
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  } else {
    // Android等は縦のみ
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  try {
    // Firebaseの初期化
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  try {
    // SharedPreferencesの初期化
    await SharedPreferences.getInstance();
  } catch (e) {
    // 初期化失敗は致命的ではないため、エラーを無視
    debugPrint('SharedPreferences initialization failed: $e');
  }

  try {
    // Google Mobile Adsの初期化
    await MobileAds.instance.initialize();
  } catch (e) {
    // 初期化失敗は致命的ではないため、エラーを無視
    debugPrint('MobileAds initialization failed: $e');
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
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

// ATT許可リクエスト関数（適切なタイミングで呼び出し）
Future<void> requestTrackingPermissionIfNeeded() async {
  try {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      // 少し遅延を入れてから許可を要求
      await Future.delayed(const Duration(milliseconds: 500));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    // トラッキング許可リクエスト失敗は致命的ではないため、エラーを無視
    debugPrint('ATT request failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: tr('app_title'),
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.pink,
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFFCE4EC),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFEC407A),
              foregroundColor: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.pink,
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF1A1A1A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFAD1457),
              foregroundColor: Colors.white,
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFF2D2D2D),
            ),
            listTileTheme: const ListTileThemeData(
              iconColor: Colors.white70,
              textColor: Colors.white,
            ),
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIconColor: Colors.white70,
              suffixIconColor: Colors.white70,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: const OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFEC407A), width: 2),
              ),
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Color(0xFFEC407A),
              selectionColor: Color(0x40EC407A),
              selectionHandleColor: Color(0xFFEC407A),
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white),
              bodySmall: TextStyle(color: Colors.white70),
              titleLarge: TextStyle(color: Colors.white),
              titleMedium: TextStyle(color: Colors.white),
              titleSmall: TextStyle(color: Colors.white),
              labelLarge: TextStyle(color: Colors.white),
              labelMedium: TextStyle(color: Colors.white),
              labelSmall: TextStyle(color: Colors.white70),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF2D2D2D),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              contentTextStyle: TextStyle(color: Colors.white),
            ),
            popupMenuTheme: const PopupMenuThemeData(
              color: Color(0xFF2D2D2D),
              textStyle: TextStyle(color: Colors.white),
            ),
          ),
          themeMode: themeProvider.themeMode,
          home: const InitializationScreen(),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
        );
      },
    );
  }
}

// 初期化画面（ローディング画面）
class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 非同期処理の前にcontextへの参照を保存
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final navigator = Navigator.of(context);

    try {
      // データマイグレーション処理
      final migrationSuccess = await DataMigrationService.migrate();
      if (migrationSuccess) {
        // データ整合性チェック
        await DataMigrationService.validateData();
      }

      // サブスクリプション状態の読み込みを待機
      await subscriptionProvider.loadStatus();

      // ATT許可リクエスト（少し遅延）
      await Future.delayed(const Duration(milliseconds: 300));
      await requestTrackingPermissionIfNeeded();

      // HomeScreenに遷移
      if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    } catch (e) {
      // エラーが発生してもHomeScreenに遷移
      if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFCE4EC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // アプリアイコン
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/icon_1024.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // ローディングインジケーター
            const CircularProgressIndicator(
              color: Color(0xFFEC407A),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            // ローディングテキスト
            Text(
              '読み込み中...',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TestHomePage extends StatelessWidget {
  const TestHomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
