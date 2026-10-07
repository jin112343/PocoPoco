import 'package:flutter_test/flutter_test.dart';

import 'package:poco/controllers/project_controller.dart';
import 'package:poco/models/crochet_project.dart';
import 'package:poco/models/crochet_stitch.dart';
import 'package:poco/models/project_markers.dart';
import 'package:poco/services/storage_service.dart';

import 'test_helpers.dart';

/// 保存が失敗するストレージ（[failing] をfalseにすると成功するようになる）
class _FlakyStorage extends StorageService {
  bool failing = true;
  int attempts = 0;

  @override
  Future<SaveResult> save(CrochetProject project,
      {bool isPremium = false}) async {
    attempts++;
    if (failing) return SaveResult.error;
    return super.save(project, isPremium: isPremium);
  }
}

void main() {
  final storage = StorageService();
  const stitch = CrochetStitch.singleCrochet;

  setUpAll(setUpTestEnvironment);
  setUp(clearStoredData);

  ProjectController newController({
    StorageService? storage,
    bool premium = false,
  }) {
    final controller = ProjectController(
      storage: storage,
      isPremium: () => premium,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group('編み目の操作', () {
    testWidgets('追加・段完成で現在の段と目数が変わる', (tester) async {
      final controller = newController()..startNew(title: '新しい編みもの');
      expect(controller.currentRow, 1);
      expect(controller.currentStitchCount, 0);
      expect(controller.canCompleteRow, isFalse);

      controller
        ..addStitch(stitch)
        ..addStitch(stitch)
        ..addStitch(stitch);
      expect(controller.currentRow, 1);
      expect(controller.currentStitchCount, 3);

      final completion = controller.completeRow();
      expect(completion!.completedRow, 1);
      expect(controller.currentRow, 2);
      expect(controller.currentStitchCount, 0);
      // 段の開始マーカーは全体の目数に数えない
      expect(controller.totalStitchCount, 3);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('1つ戻す: 編み目も段完成も1つずつ戻せる', (tester) async {
      final controller = newController()..startNew(title: '新しい編みもの');
      controller
        ..addStitch(stitch)
        ..addStitch(stitch)
        ..completeRow()
        ..addStitch(stitch);
      expect(controller.currentRow, 2);
      expect(controller.currentStitchCount, 1);

      controller.removeLastStitch(); // 2段目の1目
      expect(controller.currentRow, 2);
      expect(controller.currentStitchCount, 0);

      controller.removeLastStitch(); // 段完成の取り消し
      expect(controller.currentRow, 1);
      expect(controller.currentStitchCount, 2);

      controller
        ..removeLastStitch()
        ..removeLastStitch();
      expect(controller.canUndo, isFalse);
      expect(controller.removeLastStitch(), isFalse);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('段の削除は番号を詰め、取り消しで完全に元へ戻る', (tester) async {
      final controller = newController()
        ..loadExisting(buildProject(rows: const [3, 2, 4]));

      final before = controller.removeRow(2);
      expect(before, isNotNull);
      expect(controller.currentRow, 2);
      expect(controller.currentStitchCount, 4);
      expect(controller.totalStitchCount, 7);

      controller.restore(before!);
      expect(controller.currentRow, 3);
      expect(controller.currentStitchCount, 4);
      expect(controller.totalStitchCount, 9);
      expect(
        controller.history.where((e) => e['row'] == 2 && e['position'] != 0),
        hasLength(2),
      );

      expect(controller.removeRow(99), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('リセットは取り消しで元に戻せる', (tester) async {
      final controller = newController()
        ..loadExisting(buildProject(rows: const [3, 2]));

      final before = controller.resetAll();
      expect(controller.currentRow, 1);
      expect(controller.totalStitchCount, 0);

      controller.restore(before);
      expect(controller.currentRow, 2);
      expect(controller.currentStitchCount, 2);
      expect(controller.totalStitchCount, 5);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('段完成の取り消しで、段完成前の状態に戻る', (tester) async {
      final controller = newController()..startNew(title: '新しい編みもの');
      controller
        ..addStitch(stitch)
        ..addStitch(stitch);
      final completion = controller.completeRow()!;
      expect(controller.currentRow, 2);

      controller.restore(completion.before);
      expect(controller.currentRow, 1);
      expect(controller.currentStitchCount, 2);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('自動保存', () {
    testWidgets('操作のあと、何もしなくても保存される', (tester) async {
      final controller = newController()..startNew(title: '新しい編みもの');
      expect(controller.saveStatus, SaveStatus.none);

      controller.addStitch(stitch);
      expect(controller.saveStatus, SaveStatus.pending);
      expect(await storage.loadProjects(), isEmpty);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(controller.saveStatus, SaveStatus.saved);
      final saved = (await storage.loadProjects()).single;
      expect(saved.currentStitchCount, 1);
      expect(saved.stitchHistory.length, 1);
    });

    testWidgets('連続して操作し続けても、途中で保存される', (tester) async {
      final controller = newController()..startNew(title: '新しい編みもの');
      // 0.5秒おきに10秒間タップし続ける（待ち時間0.8秒が一度も空かない）
      for (var i = 0; i < 20; i++) {
        controller.addStitch(stitch);
        await tester.pump(const Duration(milliseconds: 500));
      }
      final saved = await storage.loadProjects();
      expect(saved, hasLength(1));
      expect(saved.single.stitchHistory.length, greaterThanOrEqualTo(8));

      await tester.pump(const Duration(seconds: 5));
      expect((await storage.loadProjects()).single.stitchHistory.length, 20);
    });

    testWidgets('アプリが裏に回る時は待たずにすぐ保存する', (tester) async {
      final controller = newController()
        ..loadExisting(buildProject(rows: const [3]));
      await storage.save(buildProject(rows: const [3]));

      controller.addStitch(stitch);
      await controller.flush();

      expect(controller.saveStatus, SaveStatus.saved);
      expect((await storage.loadProjects()).single.currentStitchCount, 4);
    });

    testWidgets('何も編んでいない新規作品は保存しない', (tester) async {
      final controller = newController()..startNew(title: '新しい編みもの');
      controller.addStitch(stitch);
      controller.removeLastStitch();
      await tester.pump(const Duration(seconds: 5));

      expect(controller.hasContent, isFalse);
      expect(controller.saveStatus, SaveStatus.none);
      expect(await storage.loadProjects(), isEmpty);
    });

    testWidgets('新規作品を保存しないで閉じると、自動保存分も消える', (tester) async {
      final controller = newController()..startNew(title: '新しい編みもの');
      controller.addStitch(stitch);
      await tester.pump(const Duration(seconds: 2));
      expect(await storage.loadProjects(), hasLength(1));
      expect(controller.isNewUnconfirmed, isTrue);

      await controller.discardNew();
      expect(await storage.loadProjects(), isEmpty);
      await tester.pump(const Duration(seconds: 5));
      expect(await storage.loadProjects(), isEmpty);
    });

    testWidgets('「保存」を選んだ新規作品は確定済みになる', (tester) async {
      final controller = newController()..startNew(title: '新しい編みもの');
      controller.addStitch(stitch);
      expect(controller.isNewUnconfirmed, isTrue);

      expect(await controller.saveNow(), SaveResult.saved);
      expect(controller.isNewUnconfirmed, isFalse);
      expect(controller.saveStatus, SaveStatus.saved);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('保存の失敗', () {
    testWidgets('失敗したら未保存として示し、再試行で保存できる', (tester) async {
      final flaky = _FlakyStorage();
      final controller = newController(storage: flaky)
        ..loadExisting(buildProject(rows: const [3]));

      controller.addStitch(stitch);
      await tester.pump(const Duration(seconds: 2));
      expect(controller.saveStatus, SaveStatus.failed);
      expect(controller.hasUnsavedChanges, isTrue);

      // 回復後に再試行（保存状態表示のタップ・画面を閉じる時に呼ばれる）
      flaky.failing = false;
      await controller.flush();
      expect(controller.saveStatus, SaveStatus.saved);
      expect(controller.hasUnsavedChanges, isFalse);
      expect((await storage.loadProjects()).single.currentStitchCount, 4);
    });

    testWidgets('失敗後は、次の操作でもう一度保存を試みる', (tester) async {
      final flaky = _FlakyStorage();
      final controller = newController(storage: flaky)
        ..loadExisting(buildProject(rows: const [3]));

      controller.addStitch(stitch);
      await tester.pump(const Duration(seconds: 2));
      final attemptsAfterFailure = flaky.attempts;
      expect(controller.saveStatus, SaveStatus.failed);

      flaky.failing = false;
      controller.addStitch(stitch);
      await tester.pump(const Duration(seconds: 2));
      expect(flaky.attempts, greaterThan(attemptsAfterFailure));
      expect(controller.saveStatus, SaveStatus.saved);
    });

    testWidgets('無料プランの上限に達している時は上限として示す', (tester) async {
      for (var i = 0; i < 3; i++) {
        await storage.save(buildProject(id: 'p$i'));
      }
      final controller = newController()..startNew(title: '新しい編みもの');
      controller.addStitch(stitch);
      await tester.pump(const Duration(seconds: 2));

      expect(controller.saveStatus, SaveStatus.limitReached);
      expect((await storage.loadProjects()).length, 3);
    });
  });

  group('作品データを失わない', () {
    testWidgets('編み方ボタンを変更しても、編んだ記録は古い状態で上書きされない',
        (tester) async {
      // 3目の状態で保存されている作品を開く
      final original = buildProject(rows: const [3]);
      await storage.save(original, isPremium: true);
      final controller = newController(premium: true)..loadExisting(original);

      // 5目追加して保存
      for (var i = 0; i < 5; i++) {
        controller.addStitch(stitch);
      }
      await controller.saveNow();
      expect((await storage.loadProjects()).single.currentStitchCount, 8);

      // そのあと編み方ボタンを変更する
      controller.setProjectStitches(const [
        CrochetStitch.chain,
        CustomStitch(nameJa: 'うね編み', nameEn: 'Wave Stitch'),
      ]);
      await tester.pump(const Duration(seconds: 2));

      // 追加した5目が消えていないこと
      final saved = (await storage.loadProjects()).single;
      expect(saved.currentStitchCount, 8);
      expect(saved.stitchHistory.length, 8);
      expect(saved.customStitches.length, 2);
    });

    testWidgets('保存してもアイコン写真・色・作成日が消えない', (tester) async {
      final original = buildProject(rows: const [3]).copyWith(
        iconName: 'star',
        iconColor: '0xFF2196F3',
        backgroundColor: '0xFFE3F2FD',
        iconImagePath: 'icon_p1_123.jpg',
      );
      await storage.save(original);
      final controller = newController()..loadExisting(original);

      controller.addStitch(stitch);
      await controller.flush();

      final saved = (await storage.loadProjects()).single;
      expect(saved.iconImagePath, 'icon_p1_123.jpg');
      expect(saved.iconName, 'star');
      expect(saved.iconColor, '0xFF2196F3');
      expect(saved.backgroundColor, '0xFFE3F2FD');
      expect(saved.createdAt, original.createdAt);
    });

    testWidgets('メモ・目印・タイトルも自動保存される', (tester) async {
      final original = buildProject(rows: const [3]);
      await storage.save(original);
      final controller = newController()..loadExisting(original);

      controller
        ..setTitle('帽子')
        ..setMemo('6号針')
        ..setMarkers(const ProjectMarkers(checkEveryRows: 5));
      await tester.pump(const Duration(seconds: 2));

      final saved = (await storage.loadProjects()).single;
      expect(saved.title, '帽子');
      expect(saved.memo, '6号針');
      expect(saved.markers.checkEveryRows, 5);
      expect(saved.stitchHistory.length, 3);
    });

    testWidgets('カスタム編み目を編んだ記録も保存・再読み込みできる', (tester) async {
      const custom = CustomStitch(
        nameJa: 'うね編み',
        nameEn: 'Wave Stitch',
        imagePath: 'assets/images/うね編み.png',
      );
      final controller = newController(premium: true)
        ..startNew(title: '新しい編みもの');
      controller
        ..addStitch(custom)
        ..addStitch(stitch);
      await controller.saveNow();

      final saved = (await storage.loadProjects()).single;
      expect(saved.stitchHistory.length, 2);
      expect((saved.stitchHistory.first['stitch'] as CustomStitch).nameJa,
          'うね編み');
      expect(saved.stitchHistory.last['stitch'], CrochetStitch.singleCrochet);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
