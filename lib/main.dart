import 'package:flutter/material.dart';
import 'screens/crochet_counter_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const CrochetCounterScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
