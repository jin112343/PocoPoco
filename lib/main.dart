import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/subscription_provider.dart';
import 'services/data_migration_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // 画面の向きを縦表示のみに制限
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // SharedPreferencesの初期化
    await SharedPreferences.getInstance();
  } catch (e) {
  }

  try {
    // Google Mobile Adsの初期化
    await MobileAds.instance.initialize();
  } catch (e) {
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
        create: (_) => SubscriptionProvider(),
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
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: tr('app_title'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
      ),
      home: const InitializationScreen(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
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
    try {
      // データマイグレーション処理
      final migrationSuccess = await DataMigrationService.migrate();
      if (migrationSuccess) {
        // データ整合性チェック
        await DataMigrationService.validateData();
      }

      // サブスクリプション状態の読み込みを待機
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await subscriptionProvider.loadStatus();

      // トライアル期間の状態をチェック
      await subscriptionProvider.checkTrialStatus();

      // トライアル期間終了処理をチェック
      await subscriptionProvider.handleTrialExpiration();

      // 定期的にサブスクリプションの有効性をチェック（1時間ごと）
      _schedulePeriodicSubscriptionCheck(subscriptionProvider);

      // ATT許可リクエスト（少し遅延）
      await Future.delayed(const Duration(milliseconds: 500));
      await requestTrackingPermissionIfNeeded();

      // 最小表示時間を確保（スプラッシュが一瞬で消えないように）
      await Future.delayed(const Duration(milliseconds: 500));

      // HomeScreenに遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    } catch (e) {
      // エラーが発生してもHomeScreenに遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    }
  }

  void _schedulePeriodicSubscriptionCheck(SubscriptionProvider provider) {
    Future.delayed(const Duration(hours: 1), () {
      if (mounted) {
        provider.loadStatus();
        provider.checkTrialStatus();
        provider.handleTrialExpiration();
        _schedulePeriodicSubscriptionCheck(provider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
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
                    color: Colors.black.withOpacity(0.1),
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
                color: Colors.grey.shade600,
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
