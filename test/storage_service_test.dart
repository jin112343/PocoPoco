import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poco/models/crochet_project.dart';
import 'package:poco/models/crochet_stitch.dart';
import 'package:poco/models/project_markers.dart';
import 'package:poco/services/storage_service.dart';

import 'test_helpers.dart';

void main() {
  final storage = StorageService();

  setUpAll(setUpTestEnvironment);
  setUp(clearStoredData);

  group('作品データの保存形式', () {
    test('メモと目印を保存して読み込める', () async {
      final project = buildProject(memo: '4号針・並太').copyWith(
        markers: const ProjectMarkers(checkEveryRows: 10),
      );
      expect(await storage.save(project), SaveResult.saved);

      final loaded = (await storage.loadProjects()).single;
      expect(loaded.memo, '4号針・並太');
      expect(loaded.markers, const ProjectMarkers(checkEveryRows: 10));
      expect(loaded.stitchHistory.length, 3);
    });

    test('メモ・目印がない旧バージョンのデータも読み込める', () {
      final oldJson = buildProject().toJson()
        ..remove('memo')
        ..remove('markers');
      final project =
          CrochetProject.fromJson(jsonDecode(jsonEncode(oldJson)));
      expect(project.memo, '');
      expect(project.markers, ProjectMarkers.none);
      expect(project.title, 'マフラー');
    });

    test('最後に編んだ編み目は段の開始マーカーを除いて求める', () {
      // 2段目を始めた直後（マーカーが末尾）でも、直前の編み目を返す
      final project = buildProject(rows: const [2, 0]);
      expect(project.stitchHistory.last['position'], 0);
      expect(project.lastStitch, CrochetStitch.singleCrochet);
      expect(buildProject(rows: const []).lastStitch, isNull);
    });
  });

  group('保存上限', () {
    test('無料プランは4つ目の新規保存ができない', () async {
      for (var i = 0; i < 3; i++) {
        expect(await storage.save(buildProject(id: 'p$i')), SaveResult.saved);
      }
      expect(
          await storage.save(buildProject(id: 'p3')), SaveResult.limitReached);
      expect((await storage.loadProjects()).length, 3);
    });

    test('上限に達していても既存の作品は上書き保存できる', () async {
      for (var i = 0; i < 3; i++) {
        await storage.save(buildProject(id: 'p$i'));
      }
      final result =
          await storage.save(buildProject(id: 'p1', title: '靴下'));
      expect(result, SaveResult.saved);
    });

    test('プレミアムは上限なし', () async {
      for (var i = 0; i < 5; i++) {
        expect(await storage.save(buildProject(id: 'p$i'), isPremium: true),
            SaveResult.saved);
      }
    });

    test('プレミアム解約後も、保存済みの作品はすべて残り編集できる', () async {
      for (var i = 0; i < 5; i++) {
        await storage.save(buildProject(id: 'p$i'), isPremium: true);
      }
      // 解約後（isPremium: false）
      expect((await storage.loadProjects()).length, 5);
      expect(
        await storage.save(buildProject(id: 'p4', rows: const [3, 2])),
        SaveResult.saved,
      );
      expect(await storage.save(buildProject(id: 'new')),
          SaveResult.limitReached);
      expect((await storage.loadProjects()).length, 5);
    });
  });

  group('削除の取り消し', () {
    test('削除した作品を同じ内容で元に戻せる', () async {
      final project = buildProject(rows: const [3, 2], memo: 'メモ');
      await storage.save(project);
      final saved = (await storage.loadProjects()).single;

      expect(await storage.deleteProject(saved.id), isTrue);
      expect(await storage.loadProjects(), isEmpty);

      expect(await storage.restoreProject(saved), isTrue);
      final restored = (await storage.loadProjects()).single;
      expect(restored.id, saved.id);
      expect(restored.memo, 'メモ');
      expect(restored.stitchHistory.length, saved.stitchHistory.length);
      expect(restored.currentRow, 2);
    });
  });

  group('複製', () {
    test('編み方ボタン・メモ・目印は引き継ぎ、カウントだけ0から始まる', () async {
      const custom = CustomStitch(
        nameJa: 'うね編み',
        nameEn: 'Wave Stitch',
        imagePath: 'assets/images/うね編み.png',
      );
      final source = buildProject(
        rows: const [5, 4],
        memo: '靴下（右）',
        customStitches: const [CrochetStitch.chain, custom],
      ).copyWith(
        iconName: 'star',
        markers: const ProjectMarkers(
            checkEveryRows: 10, repeatRows: 4, repeatTotal: 5, repeatStartRow: 7),
      );
      await storage.save(source, isPremium: true);

      final copy = await storage.duplicateProject(source,
          title: '靴下（左）', isPremium: true);

      expect(copy, isNotNull);
      final projects = await storage.loadProjects();
      expect(projects.length, 2);
      final loaded = projects.firstWhere((p) => p.id == copy!.id);
      expect(loaded.id, isNot(source.id));
      expect(loaded.title, '靴下（左）');
      expect(loaded.stitchHistory, isEmpty);
      expect(loaded.currentRow, 1);
      expect(loaded.currentStitchCount, 0);
      expect(loaded.memo, '靴下（右）');
      expect(loaded.iconName, 'star');
      expect(loaded.customStitches.length, 2);
      expect(loaded.customStitches.first, CrochetStitch.chain);
      expect((loaded.customStitches.last as CustomStitch).nameJa, 'うね編み');
      expect(loaded.markers.checkEveryRows, 10);
      expect(loaded.markers.repeatRows, 4);
      expect(loaded.markers.repeatStartRow, 1);
    });

    test('無料プランの上限に達している時は複製できない', () async {
      for (var i = 0; i < 3; i++) {
        await storage.save(buildProject(id: 'p$i'));
      }
      SaveResult? result;
      final copy = await storage.duplicateProject(
        buildProject(id: 'p0'),
        title: 'コピー',
        onResult: (r) => result = r,
      );
      expect(copy, isNull);
      expect(result, SaveResult.limitReached);
      expect((await storage.loadProjects()).length, 3);
    });
  });

  group('最後に開いた作品', () {
    test('記録して取り出せる（作品一覧には混ざらない）', () async {
      expect(await storage.getLastOpenedProjectId(), isNull);
      await storage.save(buildProject(id: 'p1'));
      await storage.setLastOpenedProjectId('p1');
      expect(await storage.getLastOpenedProjectId(), 'p1');
      expect((await storage.loadProjects()).length, 1);
    });
  });

  test('保存データは作品ごとのキーに書き込まれる', () async {
    await storage.save(buildProject(id: 'abc'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('crochet_project_abc'), isTrue);
  });
}
