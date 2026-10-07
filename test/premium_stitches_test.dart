import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poco/models/crochet_project.dart';
import 'package:poco/models/crochet_stitch.dart';
import 'package:poco/models/premium_stitches.dart';
import 'package:poco/screens/stitch_customization_screen.dart';
import 'package:poco/services/stitch_settings_service.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(setUpTestEnvironment);
  setUp(clearStoredData);

  group('プレミアム編み目の一覧', () {
    test('すべての編み目に名前と、実在する記号画像がある', () {
      for (final stitch in premiumStitchCatalog) {
        expect(stitch['nameJa'], isNotEmpty);
        expect(stitch['nameEn'], isNotEmpty);
        final image = stitch['image']!;
        expect(image, startsWith('assets/images/'));
        final file = File(image);
        expect(file.existsSync(), isTrue, reason: '画像がありません: $image');
        expect(file.lengthSync(), greaterThan(0), reason: image);
      }
    });

    test('日本語名が重複していない（作品データは日本語名で編み目を識別する）', () {
      final names = premiumStitchCatalog.map((s) => s['nameJa']).toList();
      expect(names.toSet().length, names.length);
    });

    test('引き上げ編み・輪編み用・ピコットなどが含まれている', () {
      final names = premiumStitchCatalog.map((s) => s['nameJa']).toSet();
      expect(
        names,
        containsAll([
          '細編み表引き上げ編み',
          '細編み裏引き上げ編み',
          '中長編み表引き上げ編み',
          '中長編み裏引き上げ編み',
          '長編み表引き上げ編み',
          '長編み裏引き上げ編み',
          '輪の作り目',
          'すじ編み',
          '鎖3目の引き抜きピコット',
          '鎖3目の細編みピコット',
          '松編み（長編み5目）',
          '長編み4目編み入れる',
          '長編み4目一度',
          '中長編み2目の玉編み',
          '長編み2目の玉編み',
          '長々編み１目交差',
          '長編み１目左上交差',
          '長編みクロス編み',
          '長々編みクロス編み',
          '細編みリング編み',
          '長編みリング編み',
        ]),
      );
      expect(premiumStitchCatalog.length, greaterThanOrEqualTo(55));
    });

    test('以前からある編み目は、名前も画像もそのまま（保存済みの作品が読める）', () {
      final byName = {
        for (final s in premiumStitchCatalog) s['nameJa']: s['image'],
      };
      expect(byName['うね編み'], 'assets/images/うね編み.png');
      expect(byName['長編み３目の玉編み目'], 'assets/images/長編み３目の玉編み目.png');
      expect(byName['立ち上がり'], 'assets/images/tachiagari.png');
      expect(byName['中長編み５目のパプコーン編み'], 'assets/images/hdc_5_popcorn.png');
      // 一覧の先頭は以前と同じ並び
      expect(premiumStitchCatalog.first['nameJa'], 'うね編み');
    });
  });

  group('作品データとの互換', () {
    test('新しい編み目で編んだ記録を保存して読み戻せる', () {
      final catalogEntry = premiumStitchCatalog
          .firstWhere((s) => s['nameJa'] == '長編み表引き上げ編み');
      final stitch = CustomStitch(
        nameJa: catalogEntry['nameJa']!,
        nameEn: catalogEntry['nameEn']!,
        imagePath: catalogEntry['image'],
      );
      final project = CrochetProject(
        id: 'p1',
        title: 'アラン模様',
        createdAt: DateTime(2026, 10, 7),
        stitchHistory: [
          {
            'row': 1,
            'position': 1,
            'timestamp': DateTime(2026, 10, 7),
            'stitch': stitch.toJson(),
          },
        ],
        currentRow: 1,
        currentStitchCount: 1,
        customStitches: [CrochetStitch.chain, stitch],
      );

      final restored = CrochetProject.fromJson(
          jsonDecode(jsonEncode(project.toJson())) as Map<String, dynamic>);

      final button = restored.customStitches.last as CustomStitch;
      expect(button.nameJa, '長編み表引き上げ編み');
      expect(button.imagePath, 'assets/images/dc_front_post.png');
      final recorded = restored.stitchHistory.single['stitch'] as CustomStitch;
      expect(recorded.nameJa, '長編み表引き上げ編み');
      expect(recorded.imagePath, 'assets/images/dc_front_post.png');
    });

    test('画像パスが欠けたデータでも、名前から記号画像を補える', () {
      expect(CustomStitch.lookupImagePath('輪の作り目'),
          'assets/images/magic_ring.png');
      expect(CustomStitch.lookupImagePath('うね編み'), 'assets/images/うね編み.png');
      expect(CustomStitch.lookupImagePath('存在しない編み目'), isNull);

      final restored = CustomStitch.fromJson({
        'type': 'custom',
        'name': 'Magic Ring',
        'nameJa': '輪の作り目',
        'nameEn': 'Magic Ring',
        'imagePath': '',
        'color': 0xFFE91E63,
      });
      expect(restored.imagePath, 'assets/images/magic_ring.png');
    });
  });

  group('編み方ボタン編集画面', () {
    testWidgets('追加ダイアログから新しいプレミアム編み目を選んで追加できる', (tester) async {
      setScreen(tester, size: const Size(390, 844));
      List<dynamic>? saved;
      await pumpWithApp(
        tester,
        StitchCustomizationScreen(
          projectStitches: StitchSettingsService.getDefaultStitches(),
          onProjectStitchesChanged: (stitches) =>
              saved = List<dynamic>.of(stitches),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // プレミアム編み目の一覧（2つ目のグリッド）をスクロールして探す
      final premiumGrid = find.byType(GridView).last;
      final target = find.text('輪の作り目');
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.descendant(
            of: premiumGrid, matching: find.byType(Scrollable)),
      );
      await tester.tap(target);
      await tester.pumpAndSettle();

      await tester.tap(find.text('追加 (1)'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      final added = saved!.last as CustomStitch;
      expect(added.nameJa, '輪の作り目');
      expect(added.nameEn, 'Magic Ring');
      expect(added.imagePath, 'assets/images/magic_ring.png');
      // 基本の6種類はそのまま残る
      expect(saved!.whereType<CrochetStitch>().length, 6);
      expect(find.text('輪の作り目'), findsOneWidget);
    });
  });
}
