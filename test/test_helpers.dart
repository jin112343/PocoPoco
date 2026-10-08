import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poco/l10n/app_locales.dart';
import 'package:poco/models/crochet_project.dart';
import 'package:poco/models/crochet_stitch.dart';
import 'package:poco/services/subscription_provider.dart';
import 'package:poco/services/theme_provider.dart';

/// テスト全体で1度だけ行う準備（プラグインの代役など）
Future<void> setUpTestEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  PackageInfo.setMockInitialValues(
    appName: 'poco',
    packageName: 'com.example.poco',
    version: '0.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // 広告SDK: 何も読み込まれない（広告なし）状態として応答する
  messenger.setMockMessageHandler(
    'plugins.flutter.io/google_mobile_ads',
    (message) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
  );

  // ドキュメントディレクトリ
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => '/tmp/poco_test_documents',
  );

  // ATT（トラッキング許可）: 回答済みとして扱う
  messenger.setMockMethodCallHandler(
    const MethodChannel('app_tracking_transparency'),
    (call) async => 2,
  );
}

/// 保存データを空に戻す（各テストの前に呼ぶ）
Future<void> clearStoredData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

/// 多言語・課金状態のProviderを付けて [home] を表示する
Future<SubscriptionProvider> pumpWithApp(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('ja'),
  SubscriptionProvider? subscription,
  ThemeData? theme,
}) async {
  // 前のテストで読み込んだアセット（翻訳・画像）の控えを捨てる。
  // 残っていると、終了済みのテストに紐づいた読み込み待ちが終わらなくなる
  rootBundle.clear();

  final subscriptionProvider = subscription ?? SubscriptionProvider();
  await tester.pumpWidget(
    EasyLocalization(
      // テストごとに作り直す（前のテストの言語設定を引き継がない）
      key: UniqueKey(),
      // アプリ本体と同じ言語の一覧・読み込み方を使う
      supportedLocales: appSupportedLocales,
      path: 'assets/lang',
      assetLoader: const AppLangAssetLoader(),
      fallbackLocale: appFallbackLocale,
      useFallbackTranslations: true,
      startLocale: locale,
      saveLocale: false,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: subscriptionProvider),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            home: home,
            theme: theme,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
          ),
        ),
      ),
    ),
  );
  // 翻訳ファイルの読み込みを待つ
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return subscriptionProvider;
}

/// 画面サイズと文字サイズを指定する（テスト終了時に元へ戻す）
void setScreen(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// テスト用の作品データ。[rows] は各段の目数
CrochetProject buildProject({
  String id = 'p1',
  String title = 'マフラー',
  List<int> rows = const [3],
  String memo = '',
  List<dynamic> customStitches = const [],
  DateTime? updatedAt,
}) {
  final history = <Map<String, dynamic>>[];
  final base = DateTime(2026, 1, 1, 9);
  var tick = 0;
  for (var r = 0; r < rows.length; r++) {
    final row = r + 1;
    if (row > 1) {
      history.add({
        'stitch': CrochetStitch.singleCrochet,
        'row': row,
        'position': 0,
        'timestamp': base.add(Duration(seconds: tick++)),
        'isRowStart': true,
      });
    }
    for (var position = 1; position <= rows[r]; position++) {
      history.add({
        'stitch': CrochetStitch.singleCrochet,
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
    updatedAt: updatedAt,
    stitchHistory: history,
    currentRow: rows.isEmpty ? 1 : rows.length,
    currentStitchCount: rows.isEmpty ? 0 : rows.last,
    memo: memo,
    customStitches: customStitches,
  );
}

/// 切れている・はみ出している文字を集める
List<String> unreadableTexts(WidgetTester tester) {
  // メモの抜粋は、長い分を意図して省略している（全文はメモの画面で読める）
  final excerpts = {
    // 画面外に用意されている行も含めて探す
    for (final element in find
        .descendant(
            of: find.byKey(const ValueKey('memo_preview'), skipOffstage: false),
            matching: find.byType(RichText, skipOffstage: false),
            skipOffstage: false)
        .evaluate())
      element.renderObject,
  };
  final found = <String>{};
  void visit(RenderObject object) {
    if (object is RenderParagraph &&
        object.hasSize &&
        !excerpts.contains(object)) {
      final text = object.text.toPlainText().replaceAll('\n', '⏎');
      if (object.didExceedMaxLines) {
        found.add('省略: $text');
      } else if (object.textSize.width > object.size.width + 0.5 ||
          object.textSize.height > object.size.height + 0.5) {
        found.add('はみ出し: $text');
      }
    }
    object.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return found.toList()..sort();
}
