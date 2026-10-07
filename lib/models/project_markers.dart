/// 繰り返し編みの目印設定（プロジェクトごと）
///
/// - 「◯段ごとに確認」: [checkEveryRows]
/// - 「この模様をあと◯回」: [repeatRows] 段で1模様、[repeatTotal] 回くり返す
///
/// 段番号は編み目履歴の「現在の段」（1始まり）を基準にする。
class ProjectMarkers {
  const ProjectMarkers({
    this.checkEveryRows,
    this.repeatRows,
    this.repeatTotal,
    this.repeatStartRow = 1,
  });

  /// 目印なし
  static const ProjectMarkers none = ProjectMarkers();

  /// 設定できる値の上限
  static const int maxValue = 999;

  /// 何段ごとに確認するか（nullは未設定）
  final int? checkEveryRows;

  /// 1模様あたりの段数（nullは未設定）
  final int? repeatRows;

  /// 模様をくり返す回数（nullは未設定）
  final int? repeatTotal;

  /// 模様を編み始める段
  final int repeatStartRow;

  bool get hasCheck => (checkEveryRows ?? 0) > 0;

  bool get hasRepeat => (repeatRows ?? 0) > 0 && (repeatTotal ?? 0) > 0;

  bool get isEmpty => !hasCheck && !hasRepeat;

  /// [row] 段目が確認の段かどうか
  bool isCheckRow(int row) =>
      hasCheck && row > 0 && row % checkEveryRows! == 0;

  /// [row] 段目から次の確認の段まであと何段か（確認の段にいる場合は0）
  int rowsUntilCheck(int row) {
    if (!hasCheck || row <= 0) return 0;
    final remainder = row % checkEveryRows!;
    return remainder == 0 ? 0 : checkEveryRows! - remainder;
  }

  /// [row] 段目を編んでいる時点での模様くり返しの進み具合（未設定ならnull）
  RepeatProgress? repeatProgressAt(int row) {
    if (!hasRepeat) return null;
    final rows = repeatRows!;
    final total = repeatTotal!;

    if (row < repeatStartRow) {
      return RepeatProgress(
        current: 0,
        total: total,
        rowInRepeat: 0,
        rowsPerRepeat: rows,
        startRow: repeatStartRow,
      );
    }

    final offset = row - repeatStartRow;
    final finishedRepeats = offset ~/ rows;
    if (finishedRepeats >= total) {
      return RepeatProgress(
        current: total,
        total: total,
        rowInRepeat: rows,
        rowsPerRepeat: rows,
        startRow: repeatStartRow,
        isFinished: true,
      );
    }
    return RepeatProgress(
      current: finishedRepeats + 1,
      total: total,
      rowInRepeat: offset % rows + 1,
      rowsPerRepeat: rows,
      startRow: repeatStartRow,
    );
  }

  /// [row] 段目が模様の1段目（＝新しい回の始まり）なら、その回数を返す
  int? repeatNumberStartingAt(int row) {
    final progress = repeatProgressAt(row);
    if (progress == null || !progress.isInProgress) return null;
    return progress.rowInRepeat == 1 ? progress.current : null;
  }

  /// [row] 段目を編み終えた時点で、ちょうど完了した模様の回数を返す
  /// （その段が模様の最終段でなければnull）
  int? repeatCompletedByRow(int row) {
    if (!hasRepeat || row < repeatStartRow) return null;
    final finishedRows = row - repeatStartRow + 1;
    if (finishedRows % repeatRows! != 0) return null;
    final count = finishedRows ~/ repeatRows!;
    return count <= repeatTotal! ? count : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'checkEveryRows': checkEveryRows,
      'repeatRows': repeatRows,
      'repeatTotal': repeatTotal,
      'repeatStartRow': repeatStartRow,
    };
  }

  /// 旧データ（キーなし）や不正な値は「目印なし」として扱う
  factory ProjectMarkers.fromJson(Object? json) {
    if (json is! Map) return none;
    int? positive(Object? value) {
      if (value is! num) return null;
      final v = value.toInt();
      return (v > 0 && v <= maxValue) ? v : null;
    }

    return ProjectMarkers(
      checkEveryRows: positive(json['checkEveryRows']),
      repeatRows: positive(json['repeatRows']),
      repeatTotal: positive(json['repeatTotal']),
      repeatStartRow: positive(json['repeatStartRow']) ?? 1,
    );
  }

  /// 複製した作品用: 設定は引き継ぎ、模様の開始段だけ1段目に戻す
  ProjectMarkers restartedFromFirstRow() {
    return ProjectMarkers(
      checkEveryRows: checkEveryRows,
      repeatRows: repeatRows,
      repeatTotal: repeatTotal,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectMarkers &&
      other.checkEveryRows == checkEveryRows &&
      other.repeatRows == repeatRows &&
      other.repeatTotal == repeatTotal &&
      other.repeatStartRow == repeatStartRow;

  @override
  int get hashCode =>
      Object.hash(checkEveryRows, repeatRows, repeatTotal, repeatStartRow);
}

/// 模様くり返しの進み具合
class RepeatProgress {
  const RepeatProgress({
    required this.current,
    required this.total,
    required this.rowInRepeat,
    required this.rowsPerRepeat,
    required this.startRow,
    this.isFinished = false,
  });

  /// いま何回目か（1始まり）。開始前は0、完了後は [total]
  final int current;

  /// 全部で何回くり返すか
  final int total;

  /// 模様の中の何段目か（1始まり）。開始前は0
  final int rowInRepeat;

  /// 1模様あたりの段数
  final int rowsPerRepeat;

  /// 模様を編み始める段
  final int startRow;

  /// 全回数を編み終えたか
  final bool isFinished;

  /// まだ開始段に達していない
  bool get isNotStarted => current == 0 && !isFinished;

  bool get isInProgress => !isNotStarted && !isFinished;

  /// 編んでいる途中の回を含めて「あと何回」か
  int get remaining {
    if (isFinished) return 0;
    if (isNotStarted) return total;
    return total - current + 1;
  }
}
