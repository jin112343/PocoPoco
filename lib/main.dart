import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/subscription_provider.dart';
import 'services/theme_provider.dart';
import 'services/data_migration_service.dart';
import 'services/ads_initializer.dart';
import 'services/user_prefs_service.dart';
import 'widgets/cat_loading.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // iPadの場合は全方向を許可、iPhoneの場合は縦のみ
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (Platform.isIOS && views.isNotEmpty) {
    // デバイスの画面サイズでiPadかどうかを判定
    final data = views.first;
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

  // Google Mobile Adsの初期化はATT許可リクエスト後に行う
  // （InitializationScreen._initialize内で実行）

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
      // startLocaleを指定しない（指定すると初回起動が常に日本語になる）
      // デバイスのロケールを優先し、未対応言語は日本語にフォールバック
      fallbackLocale: const Locale('ja'),
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
      // 許可ダイアログはアプリが前面に出てからでないと表示されないため、
      // 表示が必要な場合だけ少し待ってから要求する
      await Future.delayed(const Duration(milliseconds: 800));
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
  // 読み込みがこの時間で終わらなければ、回し続けずに再試行を出す
  static const Duration _loadTimeout = Duration(seconds: 15);

  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 非同期処理の前にcontextへの参照を保存
    final subscriptionProvider = context.read<SubscriptionProvider>();

    try {
      await _loadAppData(subscriptionProvider).timeout(_loadTimeout);
    } catch (e, stackTrace) {
      debugPrint('InitializationScreen._initialize: 初期化エラー: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _loadFailed = true;
        });
      }
      return;
    }

    await _finishStartup(subscriptionProvider);
  }

  /// アプリの表示に必要なデータの読み込み
  Future<void> _loadAppData(SubscriptionProvider subscriptionProvider) async {
    // データマイグレーション処理
    final migrationSuccess = await DataMigrationService.migrate();
    if (!migrationSuccess) {
      throw StateError('データマイグレーションに失敗しました');
    }
    // データ整合性チェック
    await DataMigrationService.validateData();

    await UserPrefsService.load();

    // サブスクリプション状態の読み込みを待機
    await subscriptionProvider.loadStatus();
  }

  /// 読み込み後の処理（ストア監視・ATT・広告SDK）。失敗してもホームへ進む
  Future<void> _finishStartup(SubscriptionProvider subscriptionProvider) async {
    final navigator = Navigator.of(context);

    try {
      // ストアの購入イベント監視を開始（自動更新・復元の反映）
      subscriptionProvider.startStoreSync();

      // ATT許可リクエスト
      await requestTrackingPermissionIfNeeded();
    } catch (e, stackTrace) {
      debugPrint('InitializationScreen._finishStartup: $e\n$stackTrace');
    }

    // ATTの回答後に広告SDKを初期化する（同意フローとして正しい順序）。
    // 初期化の完了は待たずにホームへ進み、広告を読み込む側が完了を待つ
    unawaited(AdsInitializer.start());

    if (mounted) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
  }

  void _retry() {
    setState(() {
      _loadFailed = false;
    });
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFCE4EC),
      body: SafeArea(
        child: _loadFailed
            ? CatLoadFailedView(
                message: tr('startup_failed'),
                retryLabel: tr('retry'),
                onRetry: _retry,
                secondaryLabel: tr('continue_anyway'),
                onSecondary: () =>
                    _finishStartup(context.read<SubscriptionProvider>()),
              )
            : Center(
                child: CatLoadingMessage(message: tr('loading')),
              ),
      ),
    );
  }
}
