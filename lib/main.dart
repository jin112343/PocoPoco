import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SharedPreferencesの初期化
  try {
    await SharedPreferences.getInstance();
    print('SharedPreferences初期化完了');
  } catch (e) {
    print('SharedPreferences初期化エラー: $e');
  }

  await MobileAds.instance.initialize();
  runApp(const CrochetCounterApp());
}

class CrochetCounterApp extends StatelessWidget {
  const CrochetCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'かぎ針編みカウンター',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
