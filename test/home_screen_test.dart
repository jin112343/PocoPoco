import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poco/screens/crochet_counter_screen.dart';
import 'package:poco/screens/home_screen.dart';
import 'package:poco/services/storage_service.dart';
import 'package:poco/widgets/cat_loading.dart';

import 'test_helpers.dart';

Future<void> _openHome(WidgetTester tester) async {
  setScreen(tester, size: const Size(390, 844));
  await pumpWithApp(tester, const HomeScreen());
  // 一覧の読み込みを待つ
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// プロジェクトの「︙」→「編集」メニューを開く
Future<void> _openEditMenu(WidgetTester tester, String projectId) async {
  await tester.tap(find.byKey(ValueKey('project_menu_$projectId')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('編集'));
  await tester.pumpAndSettle();
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}

void main() {
  final storage = StorageService();

  setUpAll(setUpTestEnvironment);
  setUp(clearStoredData);

  group('再開しやすさ', () {
    testWidgets('最後に開いた作品を「続きから」として一番上に出す', (tester) async {
      await storage.save(buildProject(
        id: 'old',
        title: 'マフラー',
        rows: const [10, 10, 4],
        memo: '4号針・並太\nゲージ20目',
      ));
      await storage.save(buildProject(id: 'new', title: '帽子'));
      await storage.setLastOpenedProjectId('old');

      await _openHome(tester);

      final card = find.byKey(const ValueKey('resume_card'));
      expect(card, findsOneWidget);
      Finder inCard(Finder finder) =>
          find.descendant(of: card, matching: finder);
      expect(inCard(find.text('続きから編む')), findsOneWidget);
      expect(inCard(find.text('マフラー')), findsOneWidget);
      // 段数・目数、直前の編み方、メモがその場で分かる
      expect(inCard(find.text('3段目 4目')), findsOneWidget);
      expect(inCard(find.text('直前の編み方: 細編み')), findsOneWidget);
      expect(inCard(find.textContaining('4号針・並太')), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('「再開する」でその作品のカウンター画面が開く', (tester) async {
      await storage.save(buildProject(id: 'p1', rows: const [3, 2]));
      await storage.setLastOpenedProjectId('p1');
      await _openHome(tester);

      await tester.tap(find.byKey(const ValueKey('resume_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CrochetCounterScreen), findsOneWidget);
      expect(find.text('マフラー'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('最後に開いた作品が削除済みなら、最新の作品を出す', (tester) async {
      await storage.save(buildProject(id: 'p1', title: '靴下'));
      await storage.setLastOpenedProjectId('deleted');
      await _openHome(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('resume_card')),
          matching: find.text('靴下'),
        ),
        findsOneWidget,
      );
      await _finish(tester);
    });

    testWidgets('作品がない時は「続きから」を出さない', (tester) async {
      await _openHome(tester);
      expect(find.byKey(const ValueKey('resume_card')), findsNothing);
      expect(find.text('プロジェクトがありません'), findsOneWidget);
      await _finish(tester);
    });
  });

  group('複製', () {
    testWidgets('編集メニューから複製すると、カウント0の新しい作品ができる', (tester) async {
      await storage.save(buildProject(
        id: 'p1',
        title: '靴下',
        rows: const [5, 4],
        memo: '中細・3号針',
      ));
      await _openHome(tester);

      await _openEditMenu(tester, 'p1');
      await tester.tap(find.byKey(const ValueKey('duplicate_project_tile')));
      await tester.pumpAndSettle();

      // 名前の初期値は「元の名前 のコピー」。好きな名前に変えられる
      expect(find.text('靴下 のコピー'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('duplicate_title_field')), '靴下（左）');
      await tester.tap(find.byKey(const ValueKey('duplicate_confirm_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final projects = await storage.loadProjects();
      expect(projects, hasLength(2));
      final copy = projects.firstWhere((p) => p.title == '靴下（左）');
      expect(copy.stitchHistory, isEmpty);
      expect(copy.currentRow, 1);
      expect(copy.memo, '中細・3号針');
      // 元の作品はそのまま
      final source = projects.firstWhere((p) => p.id == 'p1');
      expect(source.stitchHistory.length, 10);

      expect(find.text('「靴下（左）」を作成しました'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('無料プランの上限に達している時は、複製せず案内を出す', (tester) async {
      for (var i = 0; i < 3; i++) {
        await storage.save(buildProject(id: 'p$i', title: '作品$i'));
      }
      await _openHome(tester);

      await _openEditMenu(tester, 'p0');
      await tester.tap(find.byKey(const ValueKey('duplicate_project_tile')));
      await tester.pumpAndSettle();

      expect(find.text('保存上限に達しました'), findsOneWidget);
      expect((await storage.loadProjects()).length, 3);
      await tester.tap(find.text('キャンセル'));
      await _finish(tester);
    });
  });

  group('削除の取り消し', () {
    testWidgets('メニューから削除しても「元に戻す」で復元できる', (tester) async {
      await storage.save(buildProject(id: 'p1', title: '帽子', rows: const [3, 2]));
      await storage.save(buildProject(id: 'p2', title: '靴下'));
      await _openHome(tester);

      await _openEditMenu(tester, 'p1');
      await tester.tap(find.byKey(const ValueKey('delete_project_tile')));
      await tester.pumpAndSettle();
      // 削除前に確認がある
      expect(find.text('編みものを削除'), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('delete_project_confirm_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect((await storage.loadProjects()).map((p) => p.id), ['p2']);
      expect(find.text('編みものを削除しました'), findsOneWidget);

      await tester.tap(find.text('元に戻す'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final projects = await storage.loadProjects();
      expect(projects.map((p) => p.id), containsAll(['p1', 'p2']));
      final restored = projects.firstWhere((p) => p.id == 'p1');
      expect(restored.title, '帽子');
      expect(restored.stitchHistory.length, 6);
      expect(find.text('帽子'), findsWidgets);
      await _finish(tester);
    });

    testWidgets('スワイプ削除も確認があり、「元に戻す」で復元できる', (tester) async {
      await storage.save(buildProject(id: 'p1', title: '帽子'));
      await storage.save(buildProject(id: 'p2', title: '靴下'));
      await _openHome(tester);

      // 一覧のカード（「続きから」カードではない方）を左へスワイプ
      await tester.drag(find.byKey(const Key('p1')), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('編みものを削除'), findsOneWidget);
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));

      expect((await storage.loadProjects()).map((p) => p.id), ['p2']);

      await tester.tap(find.text('元に戻す'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect((await storage.loadProjects()).length, 2);
      await _finish(tester);
    });
  });

  group('読み込み表示', () {
    testWidgets('失敗時は猫を止めて再試行ボタンを出す', (tester) async {
      var retried = 0;
      setScreen(tester, size: const Size(390, 844));
      await pumpWithApp(
        tester,
        Scaffold(
          body: CatLoadFailedView(
            message: 'プロジェクトの読み込みに失敗しました',
            retryLabel: '再試行',
            onRetry: () => retried++,
          ),
        ),
      );

      expect(find.text('プロジェクトの読み込みに失敗しました'), findsOneWidget);
      // アニメーションが止まっている（回し続けない）
      expect(tester.hasRunningAnimations, isFalse);

      await tester.tap(find.byKey(const ValueKey('retry_button')));
      expect(retried, 1);
    });

    testWidgets('読み込み中は猫のアニメーションが動く', (tester) async {
      setScreen(tester, size: const Size(390, 844));
      await pumpWithApp(
        tester,
        const Scaffold(body: Center(child: CatLoadingIndicator())),
      );
      expect(tester.hasRunningAnimations, isTrue);

      // 読み込みが終わってウィジェットが外れたら、すぐに止まる
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('端末で「視差効果を減らす」が有効なら動かさない', (tester) async {
      setScreen(tester, size: const Size(390, 844));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpWithApp(
        tester,
        const Scaffold(body: Center(child: CatLoadingIndicator())),
      );
      expect(find.byType(CatLoadingIndicator), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
