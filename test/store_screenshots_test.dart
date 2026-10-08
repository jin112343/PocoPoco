// ストア掲載用スクリーンショットの書き出し（実際のアプリ画面を各言語で描いて、見出しを載せる）。
//
// 実行例:
//   flutter test --dart-define=STORE_SHOTS=true \
//     --dart-define=STORE_TEXT_DIR=/path/to/store \
//     [--dart-define=STORE_LOCALES=ja,fr-FR] [--dart-define=STORE_TARGET=ios|ipad|play] \
//     test/store_screenshots_test.dart
//
// STORE_TEXT_DIR には、ストアの言語コードごとの <code>.json（見出し cap1〜cap5 を含む）を置く。
// 出力先: build/store_shots/<target>/<code>/<番号>.png
// 文字はこのMacのシステムフォントで描く（通常のテスト実行では何もしない）。

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:poco/l10n/app_locales.dart';
import 'package:poco/models/crochet_project.dart';
import 'package:poco/models/crochet_stitch.dart';
import 'package:poco/models/premium_stitches.dart';
import 'package:poco/models/project_markers.dart';
import 'package:poco/screens/crochet_counter_screen.dart';
import 'package:poco/screens/home_screen.dart';
import 'package:poco/screens/stitch_customization_screen.dart';
import 'package:poco/services/stitch_settings_service.dart';
import 'package:poco/services/storage_service.dart';
import 'package:poco/services/subscription_provider.dart';
import 'package:poco/services/theme_provider.dart';

import 'script_fonts.dart';
import 'test_helpers.dart';

const bool _enabled = bool.fromEnvironment('STORE_SHOTS');
const String _textDir = String.fromEnvironment('STORE_TEXT_DIR');
const String _onlyLocales = String.fromEnvironment('STORE_LOCALES');
const String _target = String.fromEnvironment('STORE_TARGET', defaultValue: 'ios');

/// 書き出す画像の大きさ（論理サイズ × 倍率 = ピクセル）と、中に描く端末画面の大きさ
const _targets = <String, ({Size canvas, double pixelRatio, Size device, double radius})>{
  // iPhone 6.9インチ: 1320×2868
  'ios': (canvas: Size(440, 956), pixelRatio: 3, device: Size(390, 844), radius: 44),
  // iPad 13インチ: 2064×2752
  'ipad': (canvas: Size(1032, 1376), pixelRatio: 2, device: Size(834, 1112), radius: 30),
  // Google Play（9:16）: 1080×1920
  'play': (canvas: Size(360, 640), pixelRatio: 3, device: Size(390, 780), radius: 40),
};

/// ストアの言語コード → アプリの言語
Locale _appLocale(String storeCode) {
  const special = {
    'zh-Hans': Locale('zh'),
    'zh-Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    'zh-CN': Locale('zh'),
    'zh-TW': Locale('zh', 'TW'),
    'zh-HK': Locale('zh', 'HK'),
    'pt-PT': Locale('pt', 'PT'),
    'no': Locale('nb'),
    'no-NO': Locale('nb'),
    'iw-IL': Locale('he'),
    'rm': Locale('de'),
  };
  final found = special[storeCode];
  if (found != null) return found;
  return Locale(storeCode.split('-').first);
}

ThemeData _appTheme(Locale locale) => ThemeData(
      // アプリ本体（main.dart）のライトテーマと同じ配色
      primarySwatch: Colors.pink,
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFCE4EC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFEC407A),
        foregroundColor: Colors.white,
      ),
      fontFamily: 'ShotText',
      fontFamilyFallback: scriptFontFallbackFor(locale),
    );

/// 見本の作品（名前の長い編み目も含め、実際に編んだ記録らしい内容）
CrochetProject _project(
    {required String id,
    required String title,
    int rows = 3,
    String memo = '',
    bool withMarkers = false}) {
  CustomStitch premium(String nameJa) {
    final entry = premiumStitchCatalog.firstWhere((s) => s['nameJa'] == nameJa);
    return CustomStitch(
        nameJa: entry['nameJa']!, nameEn: entry['nameEn']!, imagePath: entry['image']);
  }

  final stitches = <dynamic>[
    ...StitchSettingsService.getDefaultStitches(),
    premium('輪の作り目'),
    premium('長編み表引き上げ編み'),
    premium('松編み（長編み5目）'),
  ];
  // 段ごとの編み方（編み目の番号）
  const patterns = [
    [0, 0, 0, 2, 2, 2, 2, 2, 2],
    [0, 4, 4, 4, 0, 4, 4, 4, 2],
    [0, 4, 7, 4, 8, 4, 7, 4, 2, 2, 4, 4],
    [0, 2, 2, 4, 4, 2, 2],
  ];
  final history = <Map<String, dynamic>>[];
  final base = DateTime(2026, 10, 1, 9);
  var tick = 0;
  for (var row = 1; row <= rows; row++) {
    if (row > 1) {
      history.add({
        'stitch': CrochetStitch.singleCrochet,
        'row': row,
        'position': 0,
        'timestamp': base.add(Duration(seconds: tick++)),
        'isRowStart': true,
      });
    }
    final pattern = patterns[(row - 1) % patterns.length];
    for (var position = 1; position <= pattern.length; position++) {
      history.add({
        'stitch': stitches[pattern[position - 1]],
        'row': row,
        'position': position,
        'timestamp': base.add(Duration(seconds: tick++)),
      });
    }
  }
  return CrochetProject(
    id: id,
    title: title,
    createdAt: base,
    updatedAt: base.add(const Duration(days: 5, hours: 3)),
    stitchHistory: history,
    currentRow: rows,
    currentStitchCount: patterns[(rows - 1) % patterns.length].length,
    memo: memo,
    markers: withMarkers
        ? const ProjectMarkers(
            checkEveryRows: 10, repeatRows: 4, repeatTotal: 6, repeatStartRow: 1)
        : ProjectMarkers.none,
    customStitches: stitches,
  );
}

/// 見出しと端末画面を1枚にまとめる
class _ShotCanvas extends StatelessWidget {
  const _ShotCanvas({
    required this.caption,
    required this.locale,
    required this.spec,
    required this.child,
  });

  final String caption;
  final Locale locale;
  final ({Size canvas, double pixelRatio, Size device, double radius}) spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canvas = spec.canvas;
    final unit = canvas.width / 440; // iPhone用の配置を基準にした倍率
    final rtl = const {'ar', 'he', 'fa', 'ur'}.contains(locale.languageCode);
    final captionHeight = canvas.height * (canvas.height / canvas.width > 2 ? 0.19 : 0.2);
    // 端末全体が見えるよう、幅と高さの両方に収まる大きさにする
    final bottomMargin = 26 * unit;
    final widthScale = canvas.width * 0.86 / spec.device.width;
    final heightScale =
        (canvas.height - captionHeight - bottomMargin) / spec.device.height;
    final scale = widthScale < heightScale ? widthScale : heightScale;
    final deviceWidth = spec.device.width * scale;
    final radius = BorderRadius.circular(spec.radius * scale);

    return Directionality(
      textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: SizedBox.fromSize(
        size: canvas,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE9E1), Color(0xFFFFC7D9)],
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                // やわらかい光の円（購入画面のイラストと同じ雰囲気）
                Positioned(
                  left: -canvas.width * 0.25,
                  top: canvas.height * 0.32,
                  child: _Glow(size: canvas.width * 0.9, opacity: 0.30),
                ),
                Positioned(
                  right: -canvas.width * 0.2,
                  top: -canvas.width * 0.25,
                  child: _Glow(size: canvas.width * 0.75, opacity: 0.34),
                ),
                Positioned(
                  left: 22 * unit,
                  right: 22 * unit,
                  top: 0,
                  height: captionHeight,
                  child: Center(
                    child: Text(
                      caption,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: TextStyle(
                        fontFamily: 'ShotText',
                        fontFamilyFallback: scriptFontFallbackFor(locale),
                        fontSize: 29 * unit,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3A2430),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: (canvas.width - deviceWidth) / 2,
                  top: captionHeight,
                  width: deviceWidth,
                  height: spec.device.height * scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x55A0505A),
                          blurRadius: 36 * unit,
                          offset: Offset(0, 16 * unit),
                        ),
                      ],
                    ),
                    child: Container(
                      // 端末の縁
                      padding: EdgeInsets.all(5 * scale),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B1F26),
                        borderRadius: radius,
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular((spec.radius - 5) * scale),
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox.fromSize(size: spec.device, child: child),
                        ),
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

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

/// 端末の上端（時刻・電波・電池）
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 10, 26, 0),
            child: Row(
              children: const [
                Text('9:41',
                    style: TextStyle(
                        fontFamily: 'ShotText',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none)),
                Spacer(),
                Icon(Icons.signal_cellular_alt, color: Colors.white, size: 17),
                SizedBox(width: 5),
                Icon(Icons.wifi, color: Colors.white, size: 17),
                SizedBox(width: 5),
                Icon(Icons.battery_full, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  if (!_enabled) {
    test('ストア用スクリーンショットの書き出しは STORE_SHOTS=true の時だけ行う', () {});
    return;
  }

  final spec = _targets[_target]!;
  final textDir = Directory(_textDir);
  final codes = [
    for (final file in textDir.listSync().whereType<File>())
      if (file.path.endsWith('.json') && !file.uri.pathSegments.last.startsWith('_'))
        file.uri.pathSegments.last.replaceAll('.json', ''),
  ]..sort();
  final wanted = _onlyLocales.isEmpty ? codes : _onlyLocales.split(',');
  final sampleNames = File('${textDir.path}/_samples.json').existsSync()
      ? jsonDecode(File('${textDir.path}/_samples.json').readAsStringSync())
          as Map<String, dynamic>
      : <String, dynamic>{};

  setUpAll(() async {
    await setUpTestEnvironment();
    await loadScriptFonts();
  });

  setUp(clearStoredData);

  for (final code in wanted) {
    testWidgets('ストア用スクリーンショット $_target $code', (tester) async {
      final texts = jsonDecode(File('${textDir.path}/$code.json').readAsStringSync())
          as Map<String, dynamic>;
      final locale = _appLocale(code);
      final names = (sampleNames[code] as List?)?.cast<String>() ??
          (sampleNames['en-US'] as List?)?.cast<String>() ??
          const ['Scarf', 'Baby blanket', 'Hat'];
      final outDir = Directory('build/store_shots/$_target/$code')
        ..createSync(recursive: true);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = spec.canvas;
      addTearDown(tester.view.reset);

      // 記号の画像を先に読み込む（テスト内では画像の読み込みが完了しないため）
      await tester.pumpWidget(const SizedBox.shrink());
      final bootContext = tester.element(find.byType(SizedBox));
      await tester.runAsync(() async {
        for (final path in {
          for (final stitch in CrochetStitch.values)
            if (stitch.imagePath != null) stitch.imagePath!,
          for (final entry in premiumStitchCatalog) entry['image']!,
        }) {
          await precacheImage(AssetImage(path), bootContext);
        }
      });

      final subscription = SubscriptionProvider();
      await subscription.setPremium(true,
          subscriptionId: 'yearly_sub',
          expiryDate: DateTime.now().add(const Duration(days: 30)));
      final boundaryKey = GlobalKey();
      final statusBarHeight = _target == 'ipad' ? 28.0 : 50.0;

      Future<void> show(String caption, Widget screen) async {
        rootBundle.clear();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: EasyLocalization(
              key: UniqueKey(),
              supportedLocales: appSupportedLocales,
              path: 'assets/lang',
              assetLoader: const AppLangAssetLoader(),
              fallbackLocale: appFallbackLocale,
              useFallbackTranslations: true,
              startLocale: locale,
              saveLocale: false,
              child: MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: subscription),
                  ChangeNotifierProvider(create: (_) => ThemeProvider()),
                ],
                child: Builder(
                  builder: (context) => _ShotCanvas(
                    caption: caption,
                    locale: locale,
                    spec: spec,
                    child: MediaQuery(
                      data: MediaQueryData(
                        size: spec.device,
                        devicePixelRatio: 3,
                        padding: EdgeInsets.only(
                            top: statusBarHeight, bottom: _target == 'ipad' ? 20 : 30),
                        viewPadding: EdgeInsets.only(
                            top: statusBarHeight, bottom: _target == 'ipad' ? 20 : 30),
                      ),
                      child: Stack(
                        children: [
                          MaterialApp(
                            debugShowCheckedModeBanner: false,
                            theme: _appTheme(locale),
                            home: screen,
                            localizationsDelegates: context.localizationDelegates,
                            supportedLocales: context.supportedLocales,
                            locale: context.locale,
                          ),
                          _StatusBar(height: statusBarHeight),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(seconds: 1));
      }

      var index = 0;
      Future<void> capture() async {
        await tester.pump(const Duration(milliseconds: 600));
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: spec.pixelRatio);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          index++;
          await File('${outDir.path}/${index.toString().padLeft(2, '0')}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> tapKey(String key) async {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.pump();
        await tester.tap(finder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }

      // 1. 記録画面: ワンタップで数える
      await show(texts['cap1'] as String,
          CrochetCounterScreen(project: _project(id: 'p1', title: names[0])));
      await capture();

      // 2. 段ごとの記録（メモの画面）
      await show(texts['cap2'] as String,
          CrochetCounterScreen(project: _project(id: 'p1', title: names[0])));
      await tapKey('notes_chip');
      await capture();

      // 3. ホーム: 続きから再開
      final storage = StorageService();
      await storage.save(_project(id: 'p1', title: names[0], rows: 3));
      await storage.save(_project(id: 'p2', title: names[1], rows: 2));
      await storage.save(_project(id: 'p3', title: names[2], rows: 4));
      await storage.setLastOpenedProjectId('p1');
      await show(texts['cap3'] as String, const HomeScreen());
      await capture();

      // 4. 編み方ボタンの追加（プレミアムの編み目）
      await show(
        texts['cap4'] as String,
        StitchCustomizationScreen(
          projectStitches: StitchSettingsService.getDefaultStitches(),
          onProjectStitchesChanged: (_) async {},
        ),
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await capture();

      // 5. 目印（確認する段・繰り返し）
      await show(
          texts['cap5'] as String,
          CrochetCounterScreen(
              project: _project(
                  id: 'p1', title: names[0], rows: 4, withMarkers: true)));
      final markerChip = find.byKey(const ValueKey('marker_check_chip'));
      await tester.tap(markerChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await capture();

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 12));
      subscription.dispose();
    });
  }
}
