import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poco/models/crochet_project.dart';
import 'package:poco/models/crochet_stitch.dart';
import 'package:poco/screens/crochet_counter_screen.dart';
import 'package:poco/services/storage_service.dart';
import 'package:poco/services/subscription_provider.dart';
import 'package:poco/services/user_prefs_service.dart';

import 'test_helpers.dart';

/// カウンター画面を「開く」ボタンから開くための土台（戻る動作を確認するため）
class _Launcher extends StatelessWidget {
  const _Launcher({this.project});

  final CrochetProject? project;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('launch'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CrochetCounterScreen(project: project),
            ),
          ),
          child: const Text('launch'),
        ),
      ),
    );
  }
}

const _iphone = Size(390, 844);
const _smallPhone = Size(360, 640);

final _rowNumber = find.byKey(const ValueKey('counter_row'));
final _stitchNumber = find.byKey(const ValueKey('counter_stitches'));
final _undoButton = find.byKey(const ValueKey('undo_button'));
final _completeButton = find.byKey(const ValueKey('complete_row_button'));
final _resetButton = find.byKey(const ValueKey('reset_button'));
Finder _stitchButton(int index) => find.byKey(ValueKey('stitch_button_$index'));

String _plainText(WidgetTester tester, Finder finder) {
  final richText = tester.widget<RichText>(
    find.descendant(of: finder, matching: find.byType(RichText)).first,
  );
  return richText.text.toPlainText();
}

Future<SubscriptionProvider> _openCounter(
  WidgetTester tester, {
  CrochetProject? project,
  Size size = _iphone,
  double textScale = 1.0,
  Locale locale = const Locale('ja'),
  SubscriptionProvider? subscription,
}) async {
  setScreen(tester, size: size, textScale: textScale);
  final provider = await pumpWithApp(
    tester,
    _Launcher(project: project),
    locale: locale,
    subscription: subscription,
  );
  await tester.tap(find.byKey(const ValueKey('launch')));
  await tester.pumpAndSettle();
  return provider;
}

/// 残っているタイマー（自動保存・スナックバー）を消化する
Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}

void main() {
  final storage = StorageService();

  setUpAll(setUpTestEnvironment);
  setUp(() async {
    await clearStoredData();
    UserPrefsService.leftHanded.value = false;
  });

  group('現在の段数・目数の表示', () {
    testWidgets('大きな数字で表示され、編み目を追加すると増える', (tester) async {
      await _openCounter(tester);

      expect(_plainText(tester, _rowNumber), '1段目');
      expect(_plainText(tester, _stitchNumber), '0目');

      await tester.tap(_stitchButton(2));
      await tester.tap(_stitchButton(2));
      await tester.pump();

      expect(_plainText(tester, _stitchNumber), '2目');

      // 数字は一目で読める大きさ（周りの文字の倍以上）
      final richText = tester.widget<RichText>(
        find.descendant(of: _stitchNumber, matching: find.byType(RichText)),
      );
      final sizes = <double>[];
      richText.text.visitChildren((span) {
        final size = span.style?.fontSize;
        if (size != null) sizes.add(size);
        return true;
      });
      expect(sizes.reduce((a, b) => a > b ? a : b), greaterThanOrEqualTo(40));

      await _finish(tester);
    });

    testWidgets('英語では Row / sts の並びで表示する', (tester) async {
      await _openCounter(tester, locale: const Locale('en'));
      expect(_plainText(tester, _rowNumber), 'Row 1');
      expect(_plainText(tester, _stitchNumber), '0 sts');
      await _finish(tester);
    });

    for (final scale in [1.0, 1.5, 2.0, 3.0]) {
      testWidgets('文字サイズ×$scale でも小さい画面で数字とボタンが隠れない', (tester) async {
        await _openCounter(tester, size: _smallPhone, textScale: scale);
        expect(tester.takeException(), isNull);

        // 3桁の段数・目数でも収まること
        final screen = Offset.zero & _smallPhone;
        for (final finder in [
          _rowNumber,
          _stitchNumber,
          _undoButton,
          _completeButton,
          _resetButton,
          _stitchButton(0),
          _stitchButton(5),
        ]) {
          final rect = tester.getRect(finder);
          expect(screen.contains(rect.topLeft), isTrue, reason: '$finder');
          expect(
            screen.contains(rect.bottomRight - const Offset(0.1, 0.1)),
            isTrue,
            reason: '$finder',
          );
          expect(finder.hitTestable(), findsOneWidget, reason: '$finder');
        }

        // 実際に押せること
        await tester.tap(_stitchButton(5));
        await tester.pump();
        expect(_plainText(tester, _stitchNumber), '1目');
        await tester.tap(_completeButton);
        await tester.pump();
        expect(_plainText(tester, _rowNumber), '2段目');
        expect(tester.takeException(), isNull);

        await _finish(tester);
      });
    }

    for (final entry in {
      'iPad縦': const Size(768, 1024),
      'iPad横（左右分割）': const Size(1024, 768),
      '大きいiPad横': const Size(1366, 1024),
    }.entries) {
      testWidgets('${entry.key}でも数字とボタンがすべて画面内に収まる', (tester) async {
        await _openCounter(
          tester,
          project: buildProject(rows: const [12, 8]),
          size: entry.value,
          textScale: 1.5,
        );
        expect(tester.takeException(), isNull);

        final screen = Offset.zero & entry.value;
        for (final finder in [
          _rowNumber,
          _stitchNumber,
          _undoButton,
          _completeButton,
          _resetButton,
          _stitchButton(0),
          _stitchButton(5),
        ]) {
          final rect = tester.getRect(finder);
          expect(screen.contains(rect.topLeft), isTrue, reason: '$finder');
          expect(
            screen.contains(rect.bottomRight - const Offset(0.1, 0.1)),
            isTrue,
            reason: '$finder',
          );
          expect(finder.hitTestable(), findsOneWidget, reason: '$finder');
        }
        expect(_plainText(tester, _rowNumber), '2段目');

        await tester.tap(_stitchButton(3));
        await tester.pump();
        expect(_plainText(tester, _stitchNumber), '9目');
        expect(tester.takeException(), isNull);
        await _finish(tester);
      });
    }

    testWidgets('段数・目数が3桁になってもはみ出さない', (tester) async {
      final project = buildProject(rows: [...List.filled(119, 1), 120]);
      await _openCounter(
        tester,
        project: project,
        size: _smallPhone,
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(_plainText(tester, _rowNumber), '120段目');
      expect(_plainText(tester, _stitchNumber), '120目');

      final display = tester.getRect(_rowNumber);
      expect(display.left, greaterThanOrEqualTo(0));
      expect(tester.getRect(_stitchNumber).right,
          lessThanOrEqualTo(_smallPhone.width));
      await _finish(tester);
    });
  });

  group('片手で押しやすい配置', () {
    testWidgets('編み方ボタンは十分大きく、操作ボタンとは離れている', (tester) async {
      await _openCounter(tester);

      final stitchButton = tester.getRect(_stitchButton(0));
      expect(stitchButton.height, greaterThanOrEqualTo(80));
      expect(stitchButton.width, greaterThanOrEqualTo(100));

      // 編み方ボタンの一番下と「段完成」の間に、指1本ぶん以上の間隔がある
      final lowestStitchButton = tester.getRect(_stitchButton(5));
      final complete = tester.getRect(_completeButton);
      expect(complete.top - lowestStitchButton.bottom, greaterThanOrEqualTo(28));

      // 「1つ戻す」「段完成」は大きい
      expect(complete.height, greaterThanOrEqualTo(56));
      expect(tester.getRect(_undoButton).height, greaterThanOrEqualTo(56));
      await _finish(tester);
    });

    testWidgets('リセットは段完成の反対側の端に離して置く（右手向け）', (tester) async {
      await _openCounter(tester);

      final reset = tester.getRect(_resetButton);
      final undo = tester.getRect(_undoButton);
      final complete = tester.getRect(_completeButton);

      expect(reset.right, lessThan(undo.left));
      expect(undo.right, lessThan(complete.left));
      // リセットと隣のボタンの間は、他のボタン同士より広く空ける
      expect(undo.left - reset.right, greaterThan(complete.left - undo.right));
      // リセットは目立たせない（主要ボタンより小さい）
      expect(reset.width, lessThan(undo.width));
      await _finish(tester);
    });

    testWidgets('左手向けの設定にすると左右が入れ替わる', (tester) async {
      UserPrefsService.leftHanded.value = true;
      await _openCounter(tester);

      final reset = tester.getRect(_resetButton);
      final undo = tester.getRect(_undoButton);
      final complete = tester.getRect(_completeButton);

      expect(complete.right, lessThan(undo.left));
      expect(undo.right, lessThan(reset.left));
      await _finish(tester);
    });

    testWidgets('読み上げ機能でも、ボタンの名前と押す操作が伝わる', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openCounter(tester);
      await tester.tap(_stitchButton(0));
      await tester.pump();

      expect(
        tester.getSemantics(_stitchButton(0)),
        isSemantics(label: '鎖編み', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(_completeButton),
        isSemantics(label: '段完成', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(_undoButton),
        isSemantics(label: '1つ戻す', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(_resetButton),
        isSemantics(label: 'リセット', isButton: true, hasTapAction: true),
      );
      // 現在の段数・目数はひとまとまりで読み上げられる
      expect(find.bySemanticsLabel('1段目 1目'), findsOneWidget);

      await _finish(tester);
      semantics.dispose();
    });

    testWidgets('メモやタイトルの入力でキーボードが出ても、裏の画面配置は変わらない',
        (tester) async {
      await _openCounter(tester);
      final before = [
        tester.getRect(_rowNumber),
        tester.getRect(_stitchButton(0)),
        tester.getRect(_completeButton),
      ];

      // キーボードが画面の下4割を覆う
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        [
          tester.getRect(_rowNumber),
          tester.getRect(_stitchButton(0)),
          tester.getRect(_completeButton),
        ],
        before,
      );
      await _finish(tester);
    });

    testWidgets('画面が極端に低くなっても例外にならず、操作ボタンまでスクロールできる',
        (tester) async {
      await _openCounter(tester, project: buildProject(rows: const [3, 2]));
      // 分割画面などで高さが足りなくなった状態に切り替える
      tester.view.physicalSize = const Size(390, 420);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_plainText(tester, _rowNumber), '2段目');

      await tester.ensureVisible(_completeButton);
      await tester.pumpAndSettle();
      expect(_completeButton.hitTestable(), findsOneWidget);

      // 元の高さに戻しても問題ない
      tester.view.physicalSize = _iphone;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_completeButton.hitTestable(), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('無料プランでは広告の高さを先に確保し、ボタン位置が後から動かない',
        (tester) async {
      await _openCounter(tester);
      // 画面下端とボタンの間に、バナー広告（50pt）ぶんの領域が最初からある
      final complete = tester.getRect(_completeButton);
      expect(_iphone.height - complete.bottom, greaterThanOrEqualTo(50));
      await _finish(tester);
    });
  });

  group('間違えた操作から戻す', () {
    testWidgets('1つ戻すで直前の編み目を取り消せる', (tester) async {
      await _openCounter(tester);
      await tester.tap(_stitchButton(0));
      await tester.tap(_stitchButton(1));
      await tester.pump();
      expect(_plainText(tester, _stitchNumber), '2目');

      await tester.tap(_undoButton);
      await tester.pump();
      expect(_plainText(tester, _stitchNumber), '1目');
      await _finish(tester);
    });

    testWidgets('段完成は「元に戻す」で取り消せる', (tester) async {
      await _openCounter(tester);
      await tester.tap(_stitchButton(2));
      await tester.tap(_stitchButton(2));
      await tester.pump();

      await tester.tap(_completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_plainText(tester, _rowNumber), '2段目');
      expect(find.text('1段目が完成 → 2段目へ'), findsOneWidget);

      await tester.tap(find.text('元に戻す'));
      await tester.pump();
      expect(_plainText(tester, _rowNumber), '1段目');
      expect(_plainText(tester, _stitchNumber), '2目');
      await _finish(tester);
    });

    testWidgets('リセットは確認があり、直後なら「元に戻す」で取り消せる', (tester) async {
      await _openCounter(tester, project: buildProject(rows: const [3, 2]));
      expect(_plainText(tester, _rowNumber), '2段目');

      await tester.tap(_resetButton);
      await tester.pumpAndSettle();
      // 確認ダイアログでキャンセルすれば何も消えない
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(_plainText(tester, _rowNumber), '2段目');

      await tester.tap(_resetButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reset_confirm_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_plainText(tester, _rowNumber), '1段目');
      expect(_plainText(tester, _stitchNumber), '0目');
      expect(find.text('リセットしました'), findsOneWidget);

      await tester.tap(find.text('元に戻す'));
      await tester.pump();
      expect(_plainText(tester, _rowNumber), '2段目');
      expect(_plainText(tester, _stitchNumber), '2目');

      // 取り消した内容が保存されていること
      await _finish(tester);
      final saved = (await storage.loadProjects()).single;
      expect(saved.currentRow, 2);
      expect(saved.stitchHistory.length, 6);
    });

    testWidgets('画面を閉じたら「元に戻す」の案内は前の画面に残らない', (tester) async {
      final project = buildProject(rows: const [3]);
      await storage.save(project);
      await _openCounter(tester, project: project);

      await tester.tap(_completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('元に戻す'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(CrochetCounterScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('元に戻す'), findsNothing);
      // 段完成そのものは保存されている
      expect((await storage.loadProjects()).single.currentRow, 2);
      await _finish(tester);
    });

    testWidgets('取り消しの案内は操作ボタンに重ならない', (tester) async {
      await _openCounter(tester);
      await tester.tap(_stitchButton(0));
      await tester.pump();
      await tester.tap(_completeButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 案内の本体（余白を除いた見えている部分）は編み方ボタンより上に出る
      final snackBar = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(snackBar.bottom,
          lessThanOrEqualTo(tester.getRect(_stitchButton(0)).top));
      // 案内が出ている間も続けて編み目を押せる
      expect(_stitchButton(0).hitTestable(), findsOneWidget);
      expect(_completeButton.hitTestable(), findsOneWidget);
      await _finish(tester);
    });
  });

  group('保存の安心感', () {
    testWidgets('操作すると「保存中」→ 新規作品は「自動保存済み」になる', (tester) async {
      await _openCounter(tester);
      expect(find.text('保存済み'), findsNothing);

      await tester.tap(_stitchButton(0));
      await tester.pump();
      expect(find.text('保存中…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('自動保存済み'), findsOneWidget);
      expect((await storage.loadProjects()).single.currentStitchCount, 1);
      await _finish(tester);
    });

    testWidgets('保存済みの作品は開いた時点で「保存済み」', (tester) async {
      final project = buildProject(rows: const [3]);
      await storage.save(project);
      await _openCounter(tester, project: project);
      expect(find.text('保存済み'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('アプリが裏に回った瞬間（着信・ホームボタン）に保存する', (tester) async {
      final project = buildProject(rows: const [3]);
      await storage.save(project);
      await _openCounter(tester, project: project);

      await tester.tap(_stitchButton(0));
      await tester.pump();
      // 自動保存の待ち時間が過ぎる前に、アプリが非アクティブになる
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect((await storage.loadProjects()).single.currentStitchCount, 4);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _finish(tester);
    });

    testWidgets('保存済みの作品は、確認なしで戻るだけで保存される', (tester) async {
      final project = buildProject(rows: const [3]);
      await storage.save(project);
      await _openCounter(tester, project: project);

      await tester.tap(_stitchButton(0));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CrochetCounterScreen), findsNothing);
      expect((await storage.loadProjects()).single.currentStitchCount, 4);
      await _finish(tester);
    });

    testWidgets('新規作品で「保存しない」を選ぶと、自動保存分も残らない', (tester) async {
      await _openCounter(tester);
      await tester.tap(_stitchButton(0));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(await storage.loadProjects(), hasLength(1));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dont_save_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CrochetCounterScreen), findsNothing);
      expect(await storage.loadProjects(), isEmpty);
      await _finish(tester);
    });

    testWidgets('新規作品で「保存」を選ぶと、名前を付けて保存できる', (tester) async {
      await _openCounter(tester);
      await tester.tap(_stitchButton(0));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_dialog_save_button')));
      await tester.pumpAndSettle();

      // 名前が初期値のままなので、名前の入力を求める
      await tester.enterText(
          find.byKey(const ValueKey('project_title_field')), '靴下');
      await tester.tap(find.byKey(const ValueKey('project_title_save_button')));
      await tester.pumpAndSettle();

      // 無料プランは保存後に動画広告の案内が出る
      await tester.tap(find.byKey(const ValueKey('no_thanks_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CrochetCounterScreen), findsNothing);
      final saved = (await storage.loadProjects()).single;
      expect(saved.title, '靴下');
      expect(saved.currentStitchCount, 1);
      await _finish(tester);
    });

    testWidgets('何も編まずに戻る時は、確認も保存もしない', (tester) async {
      await _openCounter(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CrochetCounterScreen), findsNothing);
      expect(await storage.loadProjects(), isEmpty);
      await _finish(tester);
    });

    testWidgets('保存上限で保存できない時は「未保存」と表示し、タップで案内する',
        (tester) async {
      for (var i = 0; i < 3; i++) {
        await storage.save(buildProject(id: 'p$i'));
      }
      await _openCounter(tester);
      await tester.tap(_stitchButton(0));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text('未保存（保存上限）'), findsOneWidget);
      await tester.tap(find.text('未保存（保存上限）'));
      await tester.pumpAndSettle();
      expect(find.text('保存上限に達しました'), findsOneWidget);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      await _finish(tester);
    });
  });

  group('くり返し編みの目印', () {
    testWidgets('「◯段ごとに確認」を設定すると、残り段数と確認の段が分かる',
        (tester) async {
      await _openCounter(tester, project: buildProject(rows: const [2]));
      await storage.save(buildProject(rows: const [2]));

      await tester.tap(find.byKey(const ValueKey('marker_add_chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marker_check_switch')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('marker_check_every_field')),
          matching: find.byType(TextField),
        ),
        '2',
      );
      await tester.tap(find.byKey(const ValueKey('markers_save_button')));
      await tester.pumpAndSettle();

      // 1段目: 次の確認（2段目）まであと1段
      expect(find.text('確認まであと1段'), findsOneWidget);

      // 1段目を完成 → 2段目は確認の段
      await tester.tap(_completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('この段で確認（2段ごと）'), findsOneWidget);
      expect(find.byKey(const ValueKey('row_check_flag_2')), findsOneWidget);

      // 2段目を編み終えると、確認ポイントの通知が出る
      await tester.tap(_stitchButton(0));
      await tester.pump();
      await tester.tap(_completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('確認ポイントです（2段ごと）'),
        findsOneWidget,
      );

      // 設定は作品と一緒に保存される
      await _finish(tester);
      expect((await storage.loadProjects()).single.markers.checkEveryRows, 2);
    });

    testWidgets('模様のくり返しは「◯回目・あと◯回」で表示される', (tester) async {
      await _openCounter(tester, project: buildProject(rows: const [2]));

      await tester.tap(find.byKey(const ValueKey('marker_add_chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marker_repeat_switch')));
      await tester.pumpAndSettle();
      Future<void> enter(String key, String value) => tester.enterText(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(TextField),
            ),
            value,
          );
      await enter('marker_repeat_rows_field', '1');
      await enter('marker_repeat_total_field', '3');
      await enter('marker_repeat_start_field', '1');
      await tester.tap(find.byKey(const ValueKey('markers_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('模様 1/3回目・あと3回'), findsOneWidget);

      await tester.tap(_completeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('模様 2/3回目・あと2回'), findsOneWidget);
      expect(find.textContaining('模様 1/3回 完了・あと2回'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('不正な値では保存できず、入力の誤りを示す', (tester) async {
      await _openCounter(tester);
      await tester.tap(find.byKey(const ValueKey('marker_add_chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('marker_check_switch')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('marker_check_every_field')),
          matching: find.byType(TextField),
        ),
        '0',
      );
      await tester.tap(find.byKey(const ValueKey('markers_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('1〜999の数字を入力してください'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('marker_add_chip')), findsOneWidget);
      await _finish(tester);
    });
  });

  group('メモ・編み方をその場で確認', () {
    testWidgets('メモを書くと画面と保存データに反映され、段ごとの編み方も見られる',
        (tester) async {
      final project = buildProject(rows: const [3, 2]);
      await storage.save(project);
      await _openCounter(tester, project: project);

      await tester.tap(find.byKey(const ValueKey('notes_chip')));
      await tester.pumpAndSettle();

      // 段ごとの編み方（同じ編み目はまとめて表示）
      expect(find.text('細編み×3'), findsOneWidget);
      expect(find.text('細編み×2'), findsOneWidget);
      // 作品全体で使った編み方と回数
      expect(find.text('細編み ×5'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('memo_field')), '4号針・並太\nゲージ20目');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // メモの1行目がカウンター画面に出る（次に開いた時も見つけやすい）
      expect(find.text('4号針・並太'), findsOneWidget);

      await _finish(tester);
      expect((await storage.loadProjects()).single.memo, '4号針・並太\nゲージ20目');
    });
  });

  group('解約・購入復元で作品データを失わない', () {
    const custom = CustomStitch(
      nameJa: 'うね編み',
      nameEn: 'Wave Stitch',
      imagePath: 'assets/images/うね編み.png',
    );

    testWidgets('解約しても編み目の記録とボタン設定は残り、再加入で元に戻る',
        (tester) async {
      final project = buildProject(
        rows: const [3],
        customStitches: const [CrochetStitch.chain, custom],
      );
      await storage.save(project, isPremium: true);

      final subscription = SubscriptionProvider();
      await subscription.setPremium(true,
          subscriptionId: 'monthly_sub',
          expiryDate: DateTime.now().add(const Duration(days: 30)));
      await _openCounter(tester, project: project, subscription: subscription);

      // プレミアム中はカスタムしたボタン（2つ）
      expect(find.text('うね編み'), findsOneWidget);
      expect(find.text('長編み'), findsNothing);

      // 解約（プレミアム終了）
      await subscription.setPremium(false);
      await tester.pumpAndSettle();

      // 基本の編み目の表示に戻るが、記録はそのまま
      expect(find.text('長編み'), findsOneWidget);
      expect(find.text('うね編み'), findsNothing);
      expect(_plainText(tester, _stitchNumber), '3目');

      // 解約後に編み進めて保存しても、作品のボタン設定は上書きされない
      await tester.tap(_stitchButton(2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      var saved = (await storage.loadProjects()).single;
      expect(saved.currentStitchCount, 4);
      expect(saved.customStitches.length, 2);
      expect((saved.customStitches.last as CustomStitch).nameJa, 'うね編み');

      // 再加入・購入復元でボタン設定が元に戻る
      await subscription.setPremium(true,
          subscriptionId: 'monthly_sub',
          expiryDate: DateTime.now().add(const Duration(days: 30)));
      await tester.pumpAndSettle();
      expect(find.text('うね編み'), findsOneWidget);
      expect(_plainText(tester, _stitchNumber), '4目');

      await _finish(tester);
      saved = (await storage.loadProjects()).single;
      expect(saved.stitchHistory.length, 4);
    });
  });
}
