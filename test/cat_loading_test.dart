// 猫のローディングアニメーションの確認。
//
// 絵を画像で確認したい時は、次のように実行すると build/cat-preview-*.png に書き出す:
//   flutter test --dart-define=CAT_PREVIEWS=true test/cat_loading_test.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:poco/widgets/cat_loading.dart';

const bool _previews = bool.fromEnvironment('CAT_PREVIEWS');

Future<ui.Image> _render(double progress,
    {double width = 480, bool showStage = true}) {
  final size = Size(width, width * CatLoadingPainter.aspectRatio);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  CatLoadingPainter(progress: progress, showStage: showStage)
      .paint(canvas, size);
  return recorder
      .endRecording()
      .toImage(size.width.round(), size.height.round());
}

void main() {
  group('猫の動き', () {
    test('1周の終わりと始まりが同じ姿勢で、途切れずに繰り返せる', () {
      final start = CatMotion(0);
      final end = CatMotion(0.99999);
      expect(end.ballX, closeTo(start.ballX, 0.01));
      expect(end.ballAngle, closeTo(start.ballAngle, 0.01));
      expect((end.paw - start.paw).distance, lessThan(0.05));
      expect(end.tailSway, closeTo(start.tailSway, 0.05));
      expect(end.tailTip, closeTo(start.tailTip, 0.05));
      expect(end.excitement, closeTo(start.excitement, 0.01));
      expect(end.wiggle, closeTo(start.wiggle, 0.01));
      expect(end.eyeOpen, closeTo(start.eyeOpen, 0.01));
      expect(end.earFlick, closeTo(start.earFlick, 0.01));
      expect(end.breath, closeTo(start.breath, 0.01));
      expect(end.lean, closeTo(start.lean, 0.01));
    });

    test('途中で手や毛糸玉が飛んだりせず、なめらかに動く', () {
      const steps = 700; // 1周1.4秒を、60fpsより細かく刻む
      var previous = CatMotion(0);
      for (var i = 1; i <= steps; i++) {
        final current = CatMotion(i / steps);
        expect((current.paw - previous.paw).distance, lessThan(1.6),
            reason: '手が飛んだ: t=${i / steps}');
        expect((current.ballX - previous.ballX).abs(), lessThan(0.6),
            reason: '玉が飛んだ: t=${i / steps}');
        expect((current.tailTip - previous.tailTip).abs(), lessThan(0.6));
        expect((current.wiggle - previous.wiggle).abs(), lessThan(0.25));
        expect((current.lean - previous.lean).abs(), lessThan(0.12));
        previous = current;
      }
    });

    test('毛糸玉は手元から転がって戻り、はじく瞬間に手が玉に届いている', () {
      // はじく前は手元にある
      expect(CatMotion(0.05).ballX, CatMotion.ballRestX);
      // 遠くまで行って止まる
      expect(CatMotion(0.54).ballX,
          closeTo(CatMotion.ballRestX - CatMotion.ballTravel, 0.01));
      // 戻ってくる途中
      expect(CatMotion(0.80).away, inInclusiveRange(0.05, 0.95));
      // 当たる瞬間、手先は玉の右端のすぐそば
      final hit = CatMotion(0.14);
      final ballRightEdge = hit.ballX + CatMotion.ballRadius;
      expect((hit.paw.dx - ballRightEdge).abs(), lessThan(4));
      // 静止している時（1周の始まり）は、手を玉に添えている
      final rest = CatMotion(0);
      expect((rest.paw.dx - (rest.ballX + CatMotion.ballRadius)).abs(),
          lessThan(6));
    });

    testWidgets('どの時点でも描画でき、絵が変化している', (tester) async {
      await tester.runAsync(() async {
        final images = <List<int>>[];
        for (final progress in [0.0, 0.12, 0.3, 0.55, 0.8]) {
          final image = await _render(progress, width: 240);
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          images.add(bytes.buffer.asUint8List());
          image.dispose();
        }
        // 何も描かれていない（全部透明）ことがなく、時点ごとに違う絵になっている
        expect(images.first.any((value) => value != 0), isTrue);
        for (var i = 1; i < images.length; i++) {
          expect(images[i], isNot(equals(images.first)));
        }
      });
    });

    testWidgets('アニメーションを減らす設定では、静止した姿勢で表示する', (tester) async {
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Center(child: CatLoadingIndicator(size: 160)),
      ));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  if (_previews) {
    testWidgets('猫のプレビュー画像を書き出す', (tester) async {
      await tester.runAsync(() async {
        // 要所の姿勢を並べた一覧
        const moments = [
          0.0, 0.05, 0.09, 0.12, 0.14, 0.17, 0.22, 0.30,
          0.42, 0.54, 0.66, 0.74, 0.82, 0.88, 0.93, 0.97,
        ];
        const columns = 4;
        const width = 480.0;
        const height = width * CatLoadingPainter.aspectRatio;
        final rows = (moments.length / columns).ceil();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
            Rect.fromLTWH(0, 0, columns * (width + 12), rows * (height + 12)),
            Paint()..color = const Color(0xFFFFF8F6));
        for (var i = 0; i < moments.length; i++) {
          canvas.save();
          canvas.translate(
              (i % columns) * (width + 12) + 6, (i ~/ columns) * (height + 12) + 6);
          CatLoadingPainter(progress: moments[i])
              .paint(canvas, const Size(width, height));
          canvas.restore();
        }
        final sheet = await recorder.endRecording().toImage(
            (columns * (width + 12)).round(), (rows * (height + 12)).round());
        final data = await sheet.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/cat-preview-sheet.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());

        // 大きく1枚（静止の姿勢）
        final still = await _render(0, width: 960);
        final stillData = await still.toByteData(format: ui.ImageByteFormat.png);
        await File('build/cat-preview-still.png')
            .writeAsBytes(stillData!.buffer.asUint8List());

        // 動きの連番（つなげると1周の動画になる）
        final frames = Directory('build/cat-motion');
        if (frames.existsSync()) frames.deleteSync(recursive: true);
        frames.createSync(recursive: true);
        const count = 56; // 1.4秒 × 40fps
        for (var i = 0; i < count; i++) {
          final image = await _render(i / count, width: 480);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${frames.path}/frame-${i.toString().padLeft(3, '0')}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        }
      });
    });
  }
}
