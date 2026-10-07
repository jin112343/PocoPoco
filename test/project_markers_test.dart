import 'package:flutter_test/flutter_test.dart';
import 'package:poco/models/project_markers.dart';

void main() {
  group('◯段ごとに確認', () {
    const markers = ProjectMarkers(checkEveryRows: 10);

    test('確認の段は設定した段数の倍数', () {
      expect(markers.isCheckRow(10), isTrue);
      expect(markers.isCheckRow(20), isTrue);
      expect(markers.isCheckRow(9), isFalse);
      expect(markers.isCheckRow(11), isFalse);
    });

    test('次の確認までの残り段数', () {
      expect(markers.rowsUntilCheck(1), 9);
      expect(markers.rowsUntilCheck(7), 3);
      expect(markers.rowsUntilCheck(10), 0);
      expect(markers.rowsUntilCheck(11), 9);
    });

    test('未設定なら目印なし', () {
      expect(ProjectMarkers.none.isEmpty, isTrue);
      expect(ProjectMarkers.none.isCheckRow(10), isFalse);
      expect(ProjectMarkers.none.repeatProgressAt(5), isNull);
    });
  });

  group('模様のくり返し', () {
    // 3段目から、4段1模様を5回
    const markers =
        ProjectMarkers(repeatRows: 4, repeatTotal: 5, repeatStartRow: 3);

    test('開始前', () {
      final progress = markers.repeatProgressAt(2)!;
      expect(progress.isNotStarted, isTrue);
      expect(progress.remaining, 5);
    });

    test('1回目の途中は「あと5回」', () {
      final progress = markers.repeatProgressAt(3)!;
      expect(progress.current, 1);
      expect(progress.rowInRepeat, 1);
      expect(progress.remaining, 5);
    });

    test('3回目の途中は「あと3回」', () {
      // 3〜6段=1回目, 7〜10段=2回目, 11〜14段=3回目
      final progress = markers.repeatProgressAt(12)!;
      expect(progress.current, 3);
      expect(progress.rowInRepeat, 2);
      expect(progress.remaining, 3);
    });

    test('最後の回は「あと1回」、編み終えたら完了', () {
      expect(markers.repeatProgressAt(22)!.remaining, 1);
      final done = markers.repeatProgressAt(23)!;
      expect(done.isFinished, isTrue);
      expect(done.remaining, 0);
    });

    test('模様の1段目だけ「◯回目」の印が付く', () {
      expect(markers.repeatNumberStartingAt(3), 1);
      expect(markers.repeatNumberStartingAt(4), isNull);
      expect(markers.repeatNumberStartingAt(7), 2);
      expect(markers.repeatNumberStartingAt(23), isNull);
    });

    test('模様の最終段を編み終えると、その回が完了', () {
      expect(markers.repeatCompletedByRow(5), isNull);
      expect(markers.repeatCompletedByRow(6), 1);
      expect(markers.repeatCompletedByRow(10), 2);
      expect(markers.repeatCompletedByRow(22), 5);
      // 全回数を終えた後の段では通知しない
      expect(markers.repeatCompletedByRow(26), isNull);
    });
  });

  group('保存形式', () {
    test('JSONに変換して元に戻せる', () {
      const markers = ProjectMarkers(
          checkEveryRows: 10, repeatRows: 4, repeatTotal: 5, repeatStartRow: 3);
      expect(ProjectMarkers.fromJson(markers.toJson()), markers);
    });

    test('旧データや不正な値は目印なしになる', () {
      expect(ProjectMarkers.fromJson(null), ProjectMarkers.none);
      expect(ProjectMarkers.fromJson('x'), ProjectMarkers.none);
      expect(
        ProjectMarkers.fromJson({'checkEveryRows': -1, 'repeatRows': 'a'}),
        ProjectMarkers.none,
      );
    });

    test('複製用: 設定は引き継ぎ、開始段だけ1段目に戻る', () {
      const markers = ProjectMarkers(
          checkEveryRows: 10, repeatRows: 4, repeatTotal: 5, repeatStartRow: 9);
      final restarted = markers.restartedFromFirstRow();
      expect(restarted.checkEveryRows, 10);
      expect(restarted.repeatRows, 4);
      expect(restarted.repeatTotal, 5);
      expect(restarted.repeatStartRow, 1);
    });
  });
}
