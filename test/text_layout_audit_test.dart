// 文字のはみ出し・見切れの点検。
//
// 主な画面を、対応しているすべての言語 × 小さい画面・大きい文字で表示し、
//  - レイアウトのはみ出し（黄色と黒の縞）が起きないこと
//  - 「…」で切れたり、枠からはみ出して読めない文字がないこと
// を確かめる。長くて収まらない文字は AutoScrollText（自動で横に流す）で読めるようにする。
//
// 画面の見た目も確認したい時は、次のように実行すると build/layout-preview-*.png に書き出す:
//   flutter test --dart-define=LAYOUT_PREVIEWS=true test/text_layout_audit_test.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poco/models/crochet_project.dart';
import 'package:poco/models/crochet_stitch.dart';
import 'package:poco/models/premium_stitches.dart';
import 'package:poco/screens/crochet_counter_screen.dart';
import 'package:poco/screens/home_screen.dart';
import 'package:poco/screens/settings_screen.dart';
import 'package:poco/screens/stitch_customization_screen.dart';
import 'package:poco/services/stitch_settings_service.dart';
import 'package:poco/services/storage_service.dart';
import 'package:poco/services/subscription_provider.dart';
import 'package:poco/widgets/auto_scroll_text.dart';

import 'script_fonts.dart';
import 'test_helpers.dart';

const bool _previews = bool.fromEnvironment('LAYOUT_PREVIEWS');

/// すべての画面サイズで確かめる言語
const _fullLanguages = ['ja', 'en', 'ko', 'es', 'de'];

/// 一部の言語だけ確かめたい時: --dart-define=LAYOUT_LANGUAGES=fr,ar
const String _onlyLanguages = String.fromEnvironment('LAYOUT_LANGUAGES');

/// 訳のファイルがある言語（assets/lang/<名前>.json）
List<String> _allLanguages() {
  final names = [
    for (final file in Directory('assets/lang').listSync().whereType<File>())
      if (file.path.endsWith('.json'))
        file.uri.pathSegments.last.replaceAll('.json', ''),
  ]..sort();
  final rest = names.where((name) => !_fullLanguages.contains(name));
  final all = [..._fullLanguages, ...rest];
  if (_onlyLanguages.isEmpty) return all;
  final wanted = _onlyLanguages.split(',');
  return all.where(wanted.contains).toList();
}

/// 翻訳ファイルの名前から、表示に使う言語を決める
Locale _localeFor(String language) => switch (language) {
      'zh-Hant' => const Locale('zh', 'TW'),
      'pt-PT' => const Locale('pt', 'PT'),
      _ => Locale(language),
    };

/// 画面の大きさと文字サイズの組み合わせ
const _devices = <String, ({Size size, double textScale})>{
  // iPhone SE（第1世代）相当のいちばん小さい画面
  'w320': (size: Size(320, 568), textScale: 1.0),
  // iPhone SE（第2・3世代）/ iPhone 8 相当
  'w375': (size: Size(375, 667), textScale: 1.0),
  // 文字サイズを大きめにしている場合
  'w375-large': (size: Size(375, 667), textScale: 1.35),
  'w430': (size: Size(430, 932), textScale: 1.0),
};

/// 追加した言語は、条件の厳しい「いちばん小さい画面」と「大きい文字」で確かめる
const _tightDevices = ['w320', 'w375-large'];

/// 名前の長い編み目を含む作品
CrochetProject _project({String id = 'p1', String title = 'アラン模様のカーディガン'}) {
  CustomStitch premium(String nameJa) {
    final entry = premiumStitchCatalog.firstWhere((s) => s['nameJa'] == nameJa);
    return CustomStitch(
      nameJa: entry['nameJa']!,
      nameEn: entry['nameEn']!,
      imagePath: entry['image'],
    );
  }

  final stitches = <dynamic>[
    ...StitchSettingsService.getDefaultStitches(),
    premium('中長編み表引き上げ編み'),
    premium('鎖3目の引き抜きピコット'),
    premium('変わり玉編み目＜中長編み3目＞'),
  ];
  final history = <Map<String, dynamic>>[];
  final base = DateTime(2026, 1, 1, 9);
  var tick = 0;
  for (var row = 1; row <= 3; row++) {
    if (row > 1) {
      history.add({
        'stitch': CrochetStitch.singleCrochet,
        'row': row,
        'position': 0,
        'timestamp': base.add(Duration(seconds: tick++)),
        'isRowStart': true,
      });
    }
    for (var position = 1; position <= 9; position++) {
      history.add({
        'stitch': stitches[(position + row) % stitches.length],
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
    stitchHistory: history,
    currentRow: 3,
    currentStitchCount: 9,
    memo: '4号針・並太（ピンク）\nゲージ 20目24段',
    customStitches: stitches,
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_previews) return;
  // ダイアログなども含めて、画面全体を画像にする
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/layout-preview-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await setUpTestEnvironment();
    // 実際に近い文字幅で確かめるため、既定の書体名で日本語フォントを読み込む
    // （読み込まないと、テストではすべての文字が正方形で描かれる）
    await loadScriptFonts();
    for (final family in ['Roboto', 'NotoSansJP']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf'));
      await loader.load();
    }
  });

  setUp(clearStoredData);

  /// 記号の画像を先に読み込む（プレビュー画像に記号を写すため）
  Future<void> precacheStitchImages(WidgetTester tester) async {
    if (!_previews) return;
    await tester.pumpWidget(const SizedBox.shrink());
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() async {
      for (final path in {
        for (final stitch in CrochetStitch.values)
          if (stitch.imagePath != null) stitch.imagePath!,
        for (final entry in premiumStitchCatalog) entry['image']!,
      }) {
        await precacheImage(AssetImage(path), context);
      }
    });
  }

  Future<SubscriptionProvider> premiumProvider() async {
    final provider = SubscriptionProvider();
    await provider.setPremium(true,
        subscriptionId: 'yearly_sub',
        expiryDate: DateTime.now().add(const Duration(days: 30)));
    return provider;
  }

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    required String language,
    required ({Size size, double textScale}) device,
    SubscriptionProvider? subscription,
  }) async {
    setScreen(tester, size: device.size, textScale: device.textScale);
    await precacheStitchImages(tester);
    final locale = _localeFor(language);
    await pumpWithApp(
      tester,
      screen,
      locale: locale,
      subscription: subscription,
      // 日本語のフォントに無い文字（各国の文字、欧文の記号付き文字）は、その文字用のフォントで描く
      theme: ThemeData(
        fontFamily: _fullLanguages.contains(language) ? null : scriptTextFamily,
        fontFamilyFallback: scriptFontFallbackFor(locale),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// 画面を閉じて、残っているタイマーを消化する
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 12));
  }

  void expectReadable(WidgetTester tester, String where) {
    expect(tester.takeException(), isNull, reason: '$where: レイアウトがはみ出しています');
    expect(unreadableTexts(tester), isEmpty, reason: '$where: 読めない文字があります');
  }

  for (final language in _allLanguages()) {
    for (final MapEntry(key: deviceName, value: device) in _devices.entries) {
      if (!_fullLanguages.contains(language) &&
          !_tightDevices.contains(deviceName)) {
        continue;
      }
      final label = '$language $deviceName';

      testWidgets('$label: 編み目を追加するダイアログ', (tester) async {
        await open(
          tester,
          StitchCustomizationScreen(
            projectStitches: const [
              CrochetStitch.chain,
              CrochetStitch.slipStitch
            ],
            onProjectStitchesChanged: (_) async {},
          ),
          language: language,
          device: device,
          subscription: await premiumProvider(),
        );
        expectReadable(tester, '編み方ボタン編集');
        await _capture(tester, 'customize-$language-$deviceName');

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expectReadable(tester, '追加ダイアログ（先頭）');
        await _capture(tester, 'add-dialog-$language-$deviceName');

        // 一覧の途中と末尾も確かめる
        final list = find
            .descendant(
                of: find.byKey(const ValueKey('add_stitch_list')),
                matching: find.byType(Scrollable))
            .first;
        final position = tester.state<ScrollableState>(list).position;
        for (final fraction in [0.35, 0.7, 1.0]) {
          position.jumpTo(position.maxScrollExtent * fraction);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expectReadable(tester, '追加ダイアログ（${(fraction * 100).round()}%）');
        }
        await _capture(tester, 'add-dialog-end-$language-$deviceName');
        await close(tester);
      });

      testWidgets('$label: 記録画面', (tester) async {
        await open(
          tester,
          CrochetCounterScreen(project: _project()),
          language: language,
          device: device,
          subscription: await premiumProvider(),
        );
        await tester.pump(const Duration(seconds: 1));
        expectReadable(tester, '記録画面');
        await _capture(tester, 'counter-$language-$deviceName');

        await tester.tap(find.byKey(const ValueKey('notes_chip')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expectReadable(tester, 'メモと編み方の記録');
        await _capture(tester, 'notes-$language-$deviceName');
        await close(tester);
      });

      testWidgets('$label: 目印の設定', (tester) async {
        await open(
          tester,
          CrochetCounterScreen(project: _project()),
          language: language,
          device: device,
          subscription: await premiumProvider(),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byKey(const ValueKey('marker_add_chip')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expectReadable(tester, '目印の設定');
        // 両方の目印を有効にした状態（入力欄がすべて出る）
        for (final key in ['marker_check_switch', 'marker_repeat_switch']) {
          final toggle = find.byKey(ValueKey(key));
          await tester.ensureVisible(toggle);
          await tester.pump();
          await tester.tap(toggle);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        expectReadable(tester, '目印の設定（すべて有効）');
        await _capture(tester, 'markers-$language-$deviceName');
        await close(tester);
      });

      testWidgets('$label: ホーム', (tester) async {
        final storage = StorageService();
        await storage.save(_project());
        await storage.save(_project(
            id: 'p2', title: 'とても長い名前の作品：春色のモチーフつなぎブランケット（友人の出産祝い用）'));
        await storage.save(_project(id: 'p3', title: 'Hat'));
        await open(tester, const HomeScreen(),
            language: language, device: device);
        await tester.pump(const Duration(seconds: 1));
        expectReadable(tester, 'ホーム');
        await _capture(tester, 'home-$language-$deviceName');

        // 作品のメニュー → 編集
        final menu = find.byKey(const ValueKey('project_menu_p1'));
        await tester.ensureVisible(menu);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(menu);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expectReadable(tester, '作品のメニュー');
        await tester.tap(find.byType(PopupMenuItem<String>).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expectReadable(tester, '作品の編集');
        await _capture(tester, 'home-edit-$language-$deviceName');
        await close(tester);
      });

      testWidgets('$label: 設定', (tester) async {
        await open(tester, const SettingsScreen(),
            language: language, device: device);
        await tester.pump(const Duration(seconds: 1));
        expectReadable(tester, '設定');
        await _capture(tester, 'settings-$language-$deviceName');
        await close(tester);
      });
    }
  }

  group('AutoScrollText', () {
    Future<void> pumpText(WidgetTester tester, String text,
        {double width = 80, int maxLines = 2, bool reduceMotion = false}) {
      return tester.pumpWidget(MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: width,
              child: AutoScrollText(text,
                  maxLines: maxLines,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'NotoSansJP', fontSize: 12)),
            ),
          ),
        ),
      ));
    }

    testWidgets('収まる文字は流さず、そのまま表示する', (tester) async {
      await pumpText(tester, '細編み');
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(unreadableTexts(tester), isEmpty);
      // 2行に折り返せば収まる場合も流さない
      await pumpText(tester, '長編み表引き上げ編み');
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(unreadableTexts(tester), isEmpty);
    });

    testWidgets('収まらない文字は、端まで流して先頭へ戻ることを繰り返す', (tester) async {
      await pumpText(tester, 'Half Double Crochet Three Stitch Puff Stitch');
      await tester.pump();
      final scrollable = find.byType(Scrollable);
      expect(scrollable, findsOneWidget);
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, 0);
      expect(unreadableTexts(tester), isEmpty);

      // 少し止まってから流れ始め、端まで行く
      await tester.pump(const Duration(milliseconds: 1400));
      expect(position.pixels, 0);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 1));
      expect(position.pixels, greaterThan(0));
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);

      // 止まったあと先頭へ戻り、また流れ始める
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(seconds: 1));
      expect(position.pixels, greaterThan(0));

      // 画面から外すと止まる（タイマーを残さない）
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('右から左の画面でも、文字そのものの先頭から流し始める', (tester) async {
      Future<AxisDirection> directionFor(String text) async {
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 80,
              child: AutoScrollText(text,
                  style: const TextStyle(fontFamily: 'ShotText', fontSize: 12)),
            ),
          ),
        ));
        await tester.pump();
        final direction = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .axisDirection;
        await tester.pumpWidget(const SizedBox.shrink());
        return direction;
      }

      // 英語・日本語の作品名は左端（先頭）から、アラビア語は右端から
      expect(await directionFor('Half Double Crochet Puff Stitch'),
          AxisDirection.right);
      expect(await directionFor('3. アラン模様のカーディガン（友人の出産祝い）'), AxisDirection.right);
      expect(await directionFor('غرزة العمود المزدوج البارزة من الأمام'),
          AxisDirection.left);
    });

    testWidgets('アニメーションを減らす設定では流さず、省略して表示する', (tester) async {
      await pumpText(tester, 'Half Double Crochet Three Stitch Puff Stitch',
          reduceMotion: true);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
