// 実機・シミュレータ上でアプリを通しで動かす結合テスト。
//
// 実行例:
//   flutter test integration_test/app_flow_test.dart -d <デバイスID>
//
// 注意: 作品データを追加・削除するため、作品が1つもない端末でのみ実行できる
// （すでに作品がある場合は、データを守るために何もせず失敗する）。

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poco/main.dart' as app;
import 'package:poco/screens/crochet_counter_screen.dart';
import 'package:poco/screens/home_screen.dart';
import 'package:poco/screens/settings_screen.dart';
import 'package:poco/screens/upgrade_screen.dart';

/// `--dart-define=VERIFY_HOLDS=true` を付けると、各チェックポイントで少し待つ
/// （外部から画面を撮影したり、アプリを強制終了したりして確認するため）。
const bool _holds = bool.fromEnvironment('VERIFY_HOLDS');

const String _projectKeyPrefix = 'crochet_project_';
const String _title = 'テストマフラー';
const String _copyTitle = 'テストマフラー（2つ目）';

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
  Duration hold = const Duration(seconds: 3),
}) async {
  await _pumpFor(tester, const Duration(milliseconds: 400));
  // ignore: avoid_print
  print('::CHECKPOINT::$name');
  if (_holds) await _pumpFor(tester, hold);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
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

int _stitchCount(Map<String, dynamic> project) => (project['stitchHistory'] as List)
    .where((entry) => (entry as Map)['position'] != 0)
    .length;

Future<void> _openEditMenu(WidgetTester tester, String projectId) async {
  final menu = _key('project_menu_$projectId');
  await _waitFor(tester, menu);
  await tester.ensureVisible(menu);
  await tester.pump(const Duration(milliseconds: 300));
  await _tap(tester, menu);
  await _tap(tester, find.text('編集'));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 実際の利用時と同じようにアニメーションや広告の読み込みを進める
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('編む→保存→再開→複製→削除の取り消しまで通しで動く', (tester) async {
    final initial = await _storedProjects();
    if (initial.isNotEmpty) {
      fail('このテストは作品データを追加・削除します。'
          '作品が1つもない端末（シミュレータ等）で実行してください。');
    }

    // ---- 起動: 猫のローディング → ホーム ----
    app.main();
    await _waitFor(tester, find.byType(HomeScreen));

    // 表示言語を日本語に固定する
    await tester.element(find.byType(HomeScreen)).setLocale(const Locale('ja'));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('プロジェクトがありません'), findsOneWidget);
    await _checkpoint(tester, 'home_empty');

    // ---- 新しい作品を編む ----
    await _tap(tester, find.byType(FloatingActionButton));
    await _waitFor(tester, find.byType(CrochetCounterScreen));
    await _pumpFor(tester, const Duration(seconds: 2));
    await _checkpoint(tester, 'counter_empty');
    expect(_plainText(tester, 'counter_row'), '1段目');
    expect(_plainText(tester, 'counter_stitches'), '0目');

    for (var i = 0; i < 5; i++) {
      await _tap(tester, _key('stitch_button_2')); // 細編み
    }
    await _tap(tester, _key('stitch_button_0')); // 鎖編み
    await _tap(tester, _key('stitch_button_0'));
    expect(_plainText(tester, 'counter_stitches'), '7目');

    // 自動保存される
    await _waitFor(tester, find.text('自動保存済み'));
    expect((await _storedProjects()).values.map(_stitchCount), [7]);
    await _checkpoint(tester, 'counter_stitches');

    // ---- 1つ戻す ----
    await _tap(tester, _key('undo_button'));
    expect(_plainText(tester, 'counter_stitches'), '6目');
    await _tap(tester, _key('stitch_button_0'));
    expect(_plainText(tester, 'counter_stitches'), '7目');

    // ---- 段完成と、その取り消し ----
    await _tap(tester, _key('complete_row_button'));
    await _waitFor(tester, find.text('元に戻す'));
    expect(_plainText(tester, 'counter_row'), '2段目');
    await _checkpoint(tester, 'row_completed_snackbar');
    await _tap(tester, find.text('元に戻す'));
    expect(_plainText(tester, 'counter_row'), '1段目');
    expect(_plainText(tester, 'counter_stitches'), '7目');

    await _tap(tester, _key('complete_row_button'));
    for (var i = 0; i < 3; i++) {
      await _tap(tester, _key('stitch_button_4')); // 長編み
    }
    expect(_plainText(tester, 'counter_row'), '2段目');
    expect(_plainText(tester, 'counter_stitches'), '3目');

    // ---- くり返しの目印（2段ごとに確認）----
    await _tap(tester, _key('marker_add_chip'));
    await _tap(tester, _key('marker_check_switch'));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    await tester.enterText(
      find.descendant(
        of: _key('marker_check_every_field'),
        matching: find.byType(TextField),
      ),
      '2',
    );
    await _checkpoint(tester, 'markers_dialog');
    await _tap(tester, _key('markers_save_button'));
    await _waitFor(tester, find.text('この段で確認（2段ごと）'));

    // ---- メモ・編み方 ----
    await _tap(tester, _key('notes_chip'));
    await _waitFor(tester, _key('memo_field'));
    await _pumpFor(tester, const Duration(milliseconds: 600));
    // 段ごとの編み方（同じ編み目はまとめて表示）
    expect(find.text('細編み×5 → 鎖編み×2'), findsOneWidget);
    expect(find.text('長編み×3'), findsOneWidget);
    await _checkpoint(tester, 'notes_sheet');
    await tester.enterText(_key('memo_field'), '4号針・並太（ピンク）\nゲージ 20目24段');
    await _pumpFor(tester, const Duration(milliseconds: 800));
    await _checkpoint(tester, 'notes_sheet_typing');
    await _tap(tester, find.byIcon(Icons.close));
    await _waitUntilGone(tester, _key('memo_field'));
    expect(find.text('4号針・並太（ピンク）'), findsOneWidget);

    // ---- リセットと、その取り消し ----
    await _tap(tester, _key('reset_button'));
    await _tap(tester, _key('reset_confirm_button'));
    await _waitFor(tester, find.text('リセットしました'));
    expect(_plainText(tester, 'counter_row'), '1段目');
    expect(_plainText(tester, 'counter_stitches'), '0目');
    await _checkpoint(tester, 'reset_snackbar');
    await _tap(tester, find.text('元に戻す'));
    expect(_plainText(tester, 'counter_row'), '2段目');
    expect(_plainText(tester, 'counter_stitches'), '3目');
    await _pumpFor(tester, const Duration(seconds: 6));

    // 文字サイズを変えた時の見え方を外部から確認するための待ち
    await _checkpoint(tester, 'counter_main', hold: const Duration(seconds: 16));

    // ---- 戻る: 新規作品は保存するか確認され、名前を付けて保存 ----
    await _tap(tester, find.byIcon(Icons.arrow_back));
    await _tap(tester, _key('save_dialog_save_button'));
    await _waitFor(tester, _key('project_title_field'));
    await tester.enterText(_key('project_title_field'), _title);
    await _tap(tester, _key('project_title_save_button'));
    // 無料プランでは保存後に動画広告の案内が出る
    await _tap(tester, _key('no_thanks_button'));
    await _waitFor(tester, _key('resume_card'));
    await _waitUntilGone(tester, find.byType(CrochetCounterScreen));

    var projects = await _storedProjects();
    expect(projects.length, 1);
    final projectId = projects.keys.single;
    expect(projects[projectId]!['title'], _title);
    expect(projects[projectId]!['currentRow'], 2);
    expect(_stitchCount(projects[projectId]!), 10);
    expect(projects[projectId]!['memo'], '4号針・並太（ピンク）\nゲージ 20目24段');

    // ---- ホーム: 続きからカード ----
    final resumeCard = _key('resume_card');
    expect(find.descendant(of: resumeCard, matching: find.text(_title)),
        findsOneWidget);
    expect(find.descendant(of: resumeCard, matching: find.text('2段目 3目')),
        findsOneWidget);
    expect(
        find.descendant(
            of: resumeCard, matching: find.text('直前の編み方: 長編み')),
        findsOneWidget);
    await _checkpoint(tester, 'home_resume');

    // ---- 複製 ----
    await _openEditMenu(tester, projectId);
    await _tap(tester, _key('duplicate_project_tile'));
    await _waitFor(tester, _key('duplicate_title_field'));
    await tester.enterText(_key('duplicate_title_field'), _copyTitle);
    await _tap(tester, _key('duplicate_confirm_button'));
    await _waitFor(tester, find.text('「$_copyTitle」を作成しました'));
    await _checkpoint(tester, 'home_duplicated');

    projects = await _storedProjects();
    expect(projects.length, 2);
    final copyId = projects.keys.firstWhere((id) => id != projectId);
    expect(projects[copyId]!['title'], _copyTitle);
    expect(_stitchCount(projects[copyId]!), 0);
    expect(projects[copyId]!['currentRow'], 1);
    expect(projects[copyId]!['memo'], projects[projectId]!['memo']);
    expect((projects[copyId]!['markers'] as Map)['checkEveryRows'], 2);
    // 元の作品はそのまま
    expect(_stitchCount(projects[projectId]!), 10);

    // ---- 削除と、その取り消し ----
    await _openEditMenu(tester, copyId);
    await _tap(tester, _key('delete_project_tile'));
    await _tap(tester, _key('delete_project_confirm_button'));
    await _waitFor(tester, find.text('編みものを削除しました'));
    expect((await _storedProjects()).keys, [projectId]);
    await _checkpoint(tester, 'home_deleted_snackbar');
    await _tap(tester, find.text('元に戻す'));
    await _waitFor(tester, _key('project_menu_$copyId'));
    expect((await _storedProjects()).length, 2);

    // もう一度削除して、今度は取り消さない
    await _openEditMenu(tester, copyId);
    await _tap(tester, _key('delete_project_tile'));
    await _tap(tester, _key('delete_project_confirm_button'));
    await _waitFor(tester, find.text('編みものを削除しました'));
    await _waitUntilGone(tester, find.text('編みものを削除しました'));
    expect((await _storedProjects()).keys, [projectId]);

    // ---- 設定: 左手向けの配置 ----
    await _tap(tester, find.byIcon(Icons.settings));
    await _waitFor(tester, find.byType(SettingsScreen));
    await _tap(tester, _key('left_handed_switch'));
    await _checkpoint(tester, 'settings_left_handed');
    await _tap(tester, find.byIcon(Icons.arrow_back));
    await _waitUntilGone(tester, find.byType(SettingsScreen));

    await _tap(tester, _key('resume_button'));
    await _waitFor(tester, find.byType(CrochetCounterScreen));
    await _pumpFor(tester, const Duration(seconds: 2));
    // 保存した内容のまま再開できている
    expect(_plainText(tester, 'counter_row'), '2段目');
    expect(_plainText(tester, 'counter_stitches'), '3目');
    expect(find.text('4号針・並太（ピンク）'), findsOneWidget);
    expect(find.text('保存済み'), findsOneWidget);
    // 左手向け: 段完成が左端、リセットが右端
    final complete = tester.getRect(_key('complete_row_button'));
    final undo = tester.getRect(_key('undo_button'));
    final reset = tester.getRect(_key('reset_button'));
    expect(complete.right, lessThan(undo.left));
    expect(undo.right, lessThan(reset.left));
    await _checkpoint(tester, 'counter_left_handed');

    // 保存済みの作品は、確認なしで戻れる
    await _tap(tester, find.byIcon(Icons.arrow_back));
    await _waitUntilGone(tester, find.byType(CrochetCounterScreen));
    expect(find.byType(AlertDialog), findsNothing);

    // 右手向けに戻す
    await _tap(tester, find.byIcon(Icons.settings));
    await _waitFor(tester, find.byType(SettingsScreen));
    await _tap(tester, _key('left_handed_switch'));

    // ---- プレミアムの説明画面 ----
    await _tap(tester, find.text('プレミアムプラン'));
    await _waitFor(tester, find.byType(UpgradeScreen));
    await _pumpFor(tester, const Duration(seconds: 4));
    final dataSafetyNote = _key('data_safety_note');
    if (dataSafetyNote.evaluate().isNotEmpty) {
      await tester.ensureVisible(dataSafetyNote);
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('解約しても作品は消えません'), findsOneWidget);
      await _checkpoint(tester, 'upgrade_data_safety');

      final restoreButton = _key('restore_purchases_button');
      await tester.ensureVisible(restoreButton);
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(restoreButton, findsOneWidget);
      await _checkpoint(tester, 'upgrade_restore');
    } else {
      // ストアが使えない環境（Playストア未ログインのエミュレータ等）
      // ignore: avoid_print
      print('::INFO::store_unavailable');
      await _checkpoint(tester, 'upgrade_store_unavailable');
    }
    Navigator.of(tester.element(find.byType(UpgradeScreen))).pop();
    await _waitUntilGone(tester, find.byType(UpgradeScreen));
    await _tap(tester, find.byIcon(Icons.arrow_back));
    await _waitUntilGone(tester, find.byType(SettingsScreen));

    // ---- 再開して編み足す（このあと外部からアプリを強制終了して確認する）----
    await _tap(tester, _key('resume_button'));
    await _waitFor(tester, find.byType(CrochetCounterScreen));
    for (var i = 0; i < 4; i++) {
      await _tap(tester, _key('stitch_button_2'));
    }
    expect(_plainText(tester, 'counter_stitches'), '7目');
    // 保存ボタンも戻るボタンも押さずに、自動保存だけで記録される
    await _waitFor(tester, find.text('保存済み'));
    projects = await _storedProjects();
    expect(_stitchCount(projects[projectId]!), 14);
    expect(projects[projectId]!['currentStitchCount'], 7);
    await _checkpoint(tester, 'ready_to_kill',
        hold: const Duration(seconds: 40));
  });
}
