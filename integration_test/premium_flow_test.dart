// 実機・シミュレータ上で、購入画面と新しいプレミアム編み目を通しで確認する結合テスト。
//
// 実行例:
//   flutter test integration_test/premium_flow_test.dart -d <デバイスID>
//
// 注意: 確認のため一時的にプレミアムの状態へ切り替え、作品を1つ作って最後に削除する
// （購入はしない）。作品が1つもない、無料プランの端末でのみ実行できる
// （すでに作品がある場合は、データを守るために何もせず失敗する）。

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poco/main.dart' as app;
import 'package:poco/screens/crochet_counter_screen.dart';
import 'package:poco/screens/home_screen.dart';
import 'package:poco/screens/settings_screen.dart';
import 'package:poco/screens/stitch_customization_screen.dart';
import 'package:poco/screens/upgrade_screen.dart';
import 'package:poco/services/subscription_provider.dart';
import 'package:poco/widgets/paywall_widgets.dart';

/// `--dart-define=VERIFY_HOLDS=true` を付けると、各チェックポイントで少し待つ
/// （外部から画面を撮影して確認するため）。
const bool _holds = bool.fromEnvironment('VERIFY_HOLDS');

const String _projectKeyPrefix = 'crochet_project_';
const String _title = '新しい編み目のテスト';

// 追加して編む、新しいプレミアム編み目（名前と記号の画像）
const Map<String, String> _newStitches = {
  '輪の作り目': 'assets/images/magic_ring.png',
  '長編み表引き上げ編み': 'assets/images/dc_front_post.png',
  '松編み（長編み5目）': 'assets/images/dc_5_shell.png',
};

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('画面に現れませんでした: $finder');
}

Future<void> _waitUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('画面から消えませんでした: $finder');
}

/// 確認用の目印を出力する
Future<void> _checkpoint(
  WidgetTester tester,
  String name, {
  Duration settle = const Duration(milliseconds: 400),
  Duration hold = const Duration(seconds: 3),
}) async {
  await _pumpFor(tester, settle);
  // ignore: avoid_print
  print('::CHECKPOINT::$name');
  if (_holds) await _pumpFor(tester, hold);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 150));
}

Finder _key(String key) => find.byKey(ValueKey(key));

String _plainText(WidgetTester tester, String key) {
  final richText = tester.widget<RichText>(
    find.descendant(of: _key(key), matching: find.byType(RichText)).first,
  );
  return richText.text.toPlainText();
}

/// 保存されている作品（id → JSON）
Future<Map<String, Map<String, dynamic>>> _storedProjects() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return {
    for (final key in prefs.getKeys())
      if (key.startsWith(_projectKeyPrefix))
        key.substring(_projectKeyPrefix.length):
            jsonDecode(prefs.getString(key)!) as Map<String, dynamic>,
  };
}

/// 画面の中に収まっているか
bool _isOnScreen(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return rect.top >= 0 && rect.bottom <= size.height;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 実際の利用時と同じようにアニメーションを進める
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('購入画面の表示と、新しいプレミアム編み目の追加・記録が通しで動く', (tester) async {
    if ((await _storedProjects()).isNotEmpty) {
      fail('このテストは作品データを追加・削除します。'
          '作品が1つもない端末（シミュレータ等）で実行してください。');
    }

    app.main();
    await _waitFor(tester, find.byType(HomeScreen));
    // 表示言語を日本語に固定する
    await tester.element(find.byType(HomeScreen)).setLocale(const Locale('ja'));
    await _pumpFor(tester, const Duration(seconds: 1));

    final subscription = Provider.of<SubscriptionProvider>(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );
    if (subscription.isPremium) {
      fail('このテストはプレミアムの状態を一時的に切り替えます。無料プランの端末で実行してください。');
    }

    try {
      // ---- 購入画面（無料プラン）----
      await _tap(tester, find.byIcon(Icons.settings));
      await _waitFor(tester, find.byType(SettingsScreen));
      await _tap(tester, find.text('プレミアムプラン'));
      await _waitFor(tester, find.byType(UpgradeScreen));
      // 開いた直後: 猫が毛糸玉を転がし、特典が上から順に現れている途中
      await _checkpoint(tester, 'paywall_opening',
          settle: const Duration(milliseconds: 200),
          hold: const Duration(seconds: 1));
      await _pumpFor(tester, const Duration(seconds: 4));
      expect(find.text('Poco Premium'), findsOneWidget);
      expect(find.byType(PaywallHero), findsOneWidget);
      expect(find.byType(PaywallBenefitCard), findsNWidgets(3));
      expect(find.text('3作品まで'), findsOneWidget);
      expect(find.text('60種類以上'), findsOneWidget);
      // 料金の読み込みが終わるのを待つ（ストアが応答しない時は15秒で打ち切られる）
      await _waitUntilGone(tester, find.byType(PaywallPlanSkeleton));
      await _checkpoint(tester, 'paywall_top');

      // イラストをタップすると、猫がもう一度毛糸玉を転がす
      await tester.tap(find.byType(PaywallHero));
      await _checkpoint(tester, 'paywall_hero_replay',
          settle: const Duration(milliseconds: 500),
          hold: const Duration(seconds: 1));
      await _pumpFor(tester, const Duration(seconds: 3));

      // 下へスクロールすると、残りの特典とプランが現れる
      final scroll = _key('paywall_scroll');
      await tester.drag(scroll, const Offset(0, -340));
      await _checkpoint(tester, 'paywall_benefits',
          settle: const Duration(milliseconds: 1800));

      final yearly = _key('plan_yearly_sub');
      if (yearly.evaluate().isNotEmpty) {
        await _tap(tester, _key('plan_monthly_sub'));
        expect(find.text('月額プランで続ける'), findsOneWidget);
        await _checkpoint(tester, 'paywall_monthly_selected');
        await _tap(tester, yearly);
        expect(find.text('年間プランで続ける'), findsOneWidget);
        await _checkpoint(tester, 'paywall_plans');
      } else {
        // ストアから料金を取得できない環境（ストア未設定のシミュレータ等）:
        // 画面下に原因と再試行が見えていて、購入ボタンは押せない
        // ignore: avoid_print
        print('::INFO::store_unavailable');
        final retry = _key('retry_store_button');
        expect(retry, findsOneWidget);
        expect(_isOnScreen(tester, retry), isTrue);
        expect(
            tester
                .widget<FilledButton>(_key('purchase_selected_plan'))
                .onPressed,
            isNull);
        await tester.drag(scroll, const Offset(0, -420));
        await _checkpoint(tester, 'paywall_store_unavailable');
      }

      await tester.ensureVisible(_key('data_safety_note'));
      expect(find.text('解約しても作品は消えません'), findsOneWidget);
      expect(_key('restore_purchases_button'), findsOneWidget);
      await _checkpoint(tester, 'paywall_data_safety');
      await _tap(tester, _key('close_paywall_button'));
      await _waitUntilGone(tester, find.byType(UpgradeScreen));

      // ---- 購入画面（プレミアム利用中）----
      await subscription.setPremium(true,
          subscriptionId: 'yearly_sub',
          expiryDate: DateTime.now().add(const Duration(days: 1)));
      await _tap(tester, find.text('プレミアムプラン'));
      await _waitFor(tester, find.byType(UpgradeScreen));
      await _pumpFor(tester, const Duration(seconds: 3));
      expect(find.text('ご利用中のプラン: 年間プラン'), findsOneWidget);
      expect(find.text('プレミアムをご利用中'), findsOneWidget);
      expect(
          tester.widget<FilledButton>(_key('purchase_selected_plan')).onPressed,
          isNull);
      await _checkpoint(tester, 'paywall_premium');
      await _tap(tester, _key('close_paywall_button'));
      await _waitUntilGone(tester, find.byType(UpgradeScreen));
      await _tap(tester, find.byIcon(Icons.arrow_back));
      await _waitUntilGone(tester, find.byType(SettingsScreen));

      // ---- 新しいプレミアム編み目を追加する ----
      await _tap(tester, find.byType(FloatingActionButton));
      await _waitFor(tester, find.byType(CrochetCounterScreen));
      await _pumpFor(tester, const Duration(seconds: 2));
      await _tap(tester, find.byTooltip('編み目をカスタマイズ'));
      await _waitFor(tester, find.byType(StitchCustomizationScreen));
      await _tap(tester, find.byIcon(Icons.add));
      await _waitFor(tester, find.text('プレミアム編み目を選択'));
      await _pumpFor(tester, const Duration(milliseconds: 600));
      final premiumList = find.descendant(
          of: find.byType(GridView).last, matching: find.byType(Scrollable));
      for (final name in _newStitches.keys) {
        final target = find.text(name);
        await tester.scrollUntilVisible(target, 120, scrollable: premiumList);
        await _pumpFor(tester, const Duration(milliseconds: 300));
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 200));
      }
      await _checkpoint(tester, 'stitch_dialog');
      await _tap(tester, find.text('追加 (${_newStitches.length})'));
      await _waitUntilGone(tester, find.text('プレミアム編み目を選択'));
      for (final name in _newStitches.keys) {
        expect(find.text(name), findsOneWidget);
      }
      await tester.ensureVisible(find.text(_newStitches.keys.last));
      await _checkpoint(tester, 'stitch_list');
      await _tap(tester, find.byIcon(Icons.arrow_back));
      await _waitUntilGone(tester, find.byType(StitchCustomizationScreen));
      await _pumpFor(tester, const Duration(seconds: 2));

      // ---- 追加した編み目で編む（基本の6種類のあとに並ぶ）----
      await _tap(tester, _key('stitch_button_6'));
      await _tap(tester, _key('stitch_button_6'));
      await _tap(tester, _key('stitch_button_7'));
      await _tap(tester, _key('stitch_button_8'));
      expect(_plainText(tester, 'counter_stitches'), '4目');
      await _waitFor(tester, find.text('自動保存済み'));
      await _checkpoint(tester, 'counter_new_stitches');

      // 編み目の名前と記号の画像が、作品に記録されている
      var projects = await _storedProjects();
      expect(projects.length, 1);
      final projectId = projects.keys.single;
      final recorded = [
        for (final entry in projects[projectId]!['stitchHistory'] as List)
          if ((entry as Map)['position'] != 0) entry['stitch'] as Map,
      ];
      final names = _newStitches.keys.toList();
      expect([for (final stitch in recorded) stitch['nameJa']],
          [names[0], names[0], names[1], names[2]]);
      expect([for (final stitch in recorded) stitch['imagePath']],
          [for (final stitch in recorded) _newStitches[stitch['nameJa']]]);

      // ---- 後片付け: 名前を付けて保存し、ホームから削除する ----
      await _tap(tester, find.byIcon(Icons.arrow_back));
      await _tap(tester, _key('save_dialog_save_button'));
      await _waitFor(tester, _key('project_title_field'));
      await tester.enterText(_key('project_title_field'), _title);
      await _tap(tester, _key('project_title_save_button'));
      await _waitUntilGone(tester, find.byType(CrochetCounterScreen));
      await _waitFor(tester, _key('resume_card'));
      await _checkpoint(tester, 'home_saved');

      await _tap(tester, _key('project_menu_$projectId'));
      await _tap(tester, find.text('編集'));
      await _tap(tester, _key('delete_project_tile'));
      await _tap(tester, _key('delete_project_confirm_button'));
      await _waitFor(tester, find.text('編みものを削除しました'));
      projects = await _storedProjects();
      expect(projects, isEmpty);
    } finally {
      // プレミアムの状態を元（無料プラン）に戻す
      await subscription.setPremium(false);
    }
    await _checkpoint(tester, 'done');
  });
}
