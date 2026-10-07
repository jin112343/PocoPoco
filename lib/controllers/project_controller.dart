import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/crochet_project.dart';
import '../models/crochet_stitch.dart';
import '../models/project_markers.dart';
import '../services/storage_service.dart';

/// 画面に表示する保存状態
enum SaveStatus {
  /// まだ保存するものがない（新規で未操作）
  none,

  /// 変更があり、自動保存の待機中または保存中
  pending,

  /// 最新の状態が保存済み
  saved,

  /// 保存に失敗した（再試行が必要）
  failed,

  /// 無料プランの保存上限のため保存できなかった
  limitReached,
}

/// 「元に戻す」用に取っておく編み目履歴の控え
class HistorySnapshot {
  HistorySnapshot._(this._entries);

  final List<Map<String, dynamic>> _entries;
}

/// 段完成の結果
class RowCompletion {
  const RowCompletion({required this.completedRow, required this.before});

  /// 編み終えた段
  final int completedRow;

  /// 段完成前の状態（取り消し用）
  final HistorySnapshot before;
}

/// カウンター画面1つ分の作品の状態と保存を受け持つ。
///
/// 編み目履歴の変更は必ずこのクラスのメソッドを通す。変更のたびに自動保存を
/// 予約するので、アプリが突然終了しても直前までの記録が残る。
/// 保存は常に「今の状態すべて」を書き込む（履歴の古い控えで上書きしない）。
class ProjectController extends ChangeNotifier {
  ProjectController({
    StorageService? storage,
    required bool Function() isPremium,
    this.autosaveDelay = const Duration(milliseconds: 800),
    this.maxAutosaveWait = const Duration(seconds: 4),
  })  : _storage = storage ?? StorageService(),
        _isPremium = isPremium;

  final StorageService _storage;
  final bool Function() _isPremium;

  /// 最後の操作からこの時間だけ待って自動保存する
  final Duration autosaveDelay;

  /// 操作が途切れなくても、この時間が経ったら自動保存する
  final Duration maxAutosaveWait;

  CrochetProject? _base;
  String _id = '';
  String _title = '';
  String _initialTitle = '';
  String _memo = '';
  ProjectMarkers _markers = ProjectMarkers.none;
  List<dynamic> _projectStitches = const [];
  DateTime _createdAt = DateTime.now();
  final List<Map<String, dynamic>> _history = [];

  bool _openedFromStorage = false;
  bool _persisted = false;
  bool _confirmed = false;
  bool _dirty = false;
  bool _disposed = false;
  int _revision = 0;
  SaveStatus _status = SaveStatus.none;
  Timer? _debounceTimer;
  Timer? _maxWaitTimer;
  Future<SaveResult>? _inFlight;

  // ---- 読み取り ----

  String get projectId => _id;
  String get title => _title;
  String get memo => _memo;
  ProjectMarkers get markers => _markers;

  /// 作品に保存されている編み方ボタンの設定（空の場合は基本の編み目を使う）
  List<dynamic> get projectStitches => _projectStitches;

  /// 編み目履歴（読み取り専用）
  List<Map<String, dynamic>> get history => UnmodifiableListView(_history);

  /// 変更のたびに増える番号
  int get revision => _revision;

  SaveStatus get saveStatus => _status;

  /// ストレージに保存済みの作品か
  bool get isPersisted => _persisted;

  /// 新規作成してから、まだ一度も「保存」を選んでいない作品か
  bool get isNewUnconfirmed => !_openedFromStorage && !_confirmed;

  /// 未保存の変更があるか
  bool get hasUnsavedChanges => _dirty;

  /// 現在の段（履歴が空なら1）
  int get currentRow =>
      _history.isEmpty ? 1 : (_history.last['row'] as int? ?? 1);

  /// 現在の段の目数
  int get currentStitchCount => _countStitches(currentRow);

  /// 全体の目数（段の開始マーカーは数えない）
  int get totalStitchCount =>
      _history.where((entry) => entry['position'] != 0).length;

  /// 最後に編んだ編み目（なければnull）
  dynamic get lastStitch {
    for (final entry in _history.reversed) {
      if (entry['position'] != 0) return entry['stitch'];
    }
    return null;
  }

  bool get canUndo => _history.isNotEmpty;
  bool get canCompleteRow => currentStitchCount > 0;
  bool get canReset => _history.isNotEmpty;

  /// 残す価値のある内容があるか（新規作品を空のまま保存しないための判定）
  bool get hasContent =>
      _history.isNotEmpty ||
      _memo.trim().isNotEmpty ||
      _title != _initialTitle ||
      _projectStitches.isNotEmpty ||
      !_markers.isEmpty;

  // ---- 初期化 ----

  /// 保存済みの作品を開く
  void loadExisting(CrochetProject project) {
    _base = project;
    _id = project.id;
    _title = project.title;
    _initialTitle = project.title;
    _memo = project.memo;
    _markers = project.markers;
    _projectStitches = List<dynamic>.of(project.customStitches);
    _createdAt = project.createdAt;
    _history
      ..clear()
      ..addAll(project.stitchHistory.map(Map<String, dynamic>.from));
    _openedFromStorage = true;
    _persisted = true;
    _confirmed = true;
    _dirty = false;
    _status = SaveStatus.saved;
    _revision++;
    unawaited(_storage.setLastOpenedProjectId(_id));
    _notify();
  }

  /// 新しい作品を始める
  void startNew({required String title}) {
    _base = null;
    _id = _storage.generateProjectId();
    _title = title;
    _initialTitle = title;
    _memo = '';
    _markers = ProjectMarkers.none;
    _projectStitches = const [];
    _createdAt = DateTime.now();
    _history.clear();
    _openedFromStorage = false;
    _persisted = false;
    _confirmed = false;
    _dirty = false;
    _status = SaveStatus.none;
    _revision++;
    _notify();
  }

  // ---- 編み目の操作 ----

  /// 現在の段に編み目を1つ追加する
  void addStitch(dynamic stitch) {
    final row = currentRow;
    _history.add({
      'row': row,
      'position': _countStitches(row) + 1,
      'timestamp': DateTime.now(),
      'stitch': _encodeStitch(stitch),
    });
    _changed();
  }

  /// 直前の操作（編み目の追加・段完成）を1つ取り消す
  bool removeLastStitch() {
    if (_history.isEmpty) return false;
    final last = _history.removeLast();
    if (last['isRowStart'] == true) {
      _renumberRows();
    }
    _changed();
    return true;
  }

  /// 現在の段を完成させ、次の段を始める（段に編み目がなければ何もしない）
  RowCompletion? completeRow() {
    if (!canCompleteRow) return null;
    final completedRow = currentRow;
    final before = _snapshot();
    final maxRow = _history
        .map((entry) => entry['row'] as int)
        .reduce((a, b) => a > b ? a : b);
    _history.add({
      'stitch': CrochetStitch.singleCrochet,
      'row': maxRow + 1,
      'position': 0,
      'timestamp': DateTime.now(),
      'isRowStart': true,
    });
    _changed();
    return RowCompletion(completedRow: completedRow, before: before);
  }

  /// 指定した段を削除し、段番号を詰める。削除前の状態を返す（段がなければnull）
  HistorySnapshot? removeRow(int row) {
    if (!_history.any((entry) => entry['row'] == row)) return null;
    final before = _snapshot();
    _history.removeWhere((entry) => entry['row'] == row);
    _renumberRows();
    _changed();
    return before;
  }

  /// すべての編み目を消す。消す前の状態を返す
  HistorySnapshot resetAll() {
    final before = _snapshot();
    _history.clear();
    _changed();
    return before;
  }

  /// [snapshot] の時点に編み目履歴を戻す
  void restore(HistorySnapshot snapshot) {
    _history
      ..clear()
      ..addAll(snapshot._entries.map(Map<String, dynamic>.from));
    _changed();
  }

  // ---- 作品情報の変更 ----

  void setTitle(String title) {
    if (title == _title) return;
    _title = title;
    _changed();
  }

  void setMemo(String memo) {
    if (memo == _memo) return;
    _memo = memo;
    _changed();
  }

  void setMarkers(ProjectMarkers markers) {
    if (markers == _markers) return;
    _markers = markers;
    _changed();
  }

  /// 編み方ボタンの設定を変更する
  void setProjectStitches(List<dynamic> stitches) {
    _projectStitches = List<dynamic>.of(stitches);
    _changed();
  }

  // ---- 保存 ----

  /// 今の状態から保存用の作品データを作る
  CrochetProject buildProject() {
    final history = _history.map(Map<String, dynamic>.from).toList();
    final base = _base;
    if (base != null) {
      // アイコン画像などカウンター画面で扱わない項目は元の値を引き継ぐ
      return base.copyWith(
        title: _title,
        updatedAt: DateTime.now(),
        stitchHistory: history,
        currentRow: currentRow,
        currentStitchCount: currentStitchCount,
        customStitches: List<dynamic>.of(_projectStitches),
        memo: _memo,
        markers: _markers,
      );
    }
    return CrochetProject(
      id: _id,
      title: _title,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      stitchHistory: history,
      currentRow: currentRow,
      currentStitchCount: currentStitchCount,
      iconName: 'work',
      iconColor: '0xFF000000',
      backgroundColor: '0xFFFFFFFF',
      customStitches: List<dynamic>.of(_projectStitches),
      memo: _memo,
      markers: _markers,
    );
  }

  /// ユーザーが「保存」を選んだときの保存。変更がなくても書き込む
  Future<SaveResult> saveNow() async {
    _dirty = true;
    final result = await _save();
    if (result == SaveResult.saved) {
      _confirmed = true;
      _notify();
    }
    return result;
  }

  /// 未保存の変更があればすぐに保存する（アプリが裏に回る時・画面を閉じる時）
  Future<void> flush() async {
    if (_dirty) {
      await _save();
    } else if (_inFlight != null) {
      await _inFlight;
    }
  }

  /// 新規作品を保存せずに閉じる。自動保存済みのデータがあれば削除する
  Future<void> discardNew() async {
    _cancelTimers();
    while (_inFlight != null) {
      await _inFlight;
    }
    _cancelTimers();
    if (_persisted) {
      await _storage.deleteProject(_id);
      _persisted = false;
    }
    _dirty = false;
    _status = SaveStatus.none;
    _notify();
  }

  @override
  void dispose() {
    _cancelTimers();
    _disposed = true;
    super.dispose();
  }

  // ---- 内部処理 ----

  int _countStitches(int row) => _history
      .where((entry) => entry['row'] == row && entry['position'] != 0)
      .length;

  HistorySnapshot _snapshot() =>
      HistorySnapshot._(_history.map(Map<String, dynamic>.from).toList());

  /// 履歴に入れる形に変換する（カスタム編み目はJSONにできるMapで持つ）
  dynamic _encodeStitch(dynamic stitch) {
    if (stitch is CustomStitch) {
      return stitch.toJson();
    }
    return stitch;
  }

  /// 段番号を1から順に振り直す
  void _renumberRows() {
    final rows = _history.map((entry) => entry['row'] as int).toSet().toList()
      ..sort();
    final mapping = <int, int>{
      for (var i = 0; i < rows.length; i++) rows[i]: i + 1,
    };
    for (final entry in _history) {
      entry['row'] = mapping[entry['row']];
    }
  }

  void _changed() {
    _revision++;
    _dirty = true;
    if (!_persisted && !hasContent) {
      // 新規作品を空に戻しただけなら、保存するものはない
      _cancelTimers();
      _dirty = false;
      _status = SaveStatus.none;
    } else {
      _status = SaveStatus.pending;
      _scheduleAutosave();
    }
    _notify();
  }

  void _scheduleAutosave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(autosaveDelay, _autosave);
    // 連続して操作し続けても、一定時間ごとには必ず保存する
    _maxWaitTimer ??= Timer(maxAutosaveWait, _autosave);
  }

  void _autosave() {
    _cancelTimers();
    if (_disposed || !_dirty) return;
    unawaited(_save());
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _maxWaitTimer?.cancel();
    _maxWaitTimer = null;
  }

  Future<SaveResult> _save() async {
    // 実行中の保存があれば終わるのを待ってから、最新の状態を書き込む
    while (_inFlight != null) {
      await _inFlight;
    }
    _cancelTimers();
    if (!_dirty && _persisted) return SaveResult.saved;

    final write = _write();
    _inFlight = write;
    try {
      return await write;
    } finally {
      _inFlight = null;
    }
  }

  Future<SaveResult> _write() async {
    final revisionAtStart = _revision;
    final wasPersisted = _persisted;
    SaveResult result;
    try {
      result = await _storage.save(buildProject(), isPremium: _isPremium());
    } catch (_) {
      result = SaveResult.error;
    }

    switch (result) {
      case SaveResult.saved:
        _persisted = true;
        if (!wasPersisted) {
          unawaited(_storage.setLastOpenedProjectId(_id));
        }
        if (_revision == revisionAtStart) {
          _dirty = false;
          _status = SaveStatus.saved;
        } else {
          // 保存中に操作があったので、続けてもう一度保存する
          _dirty = true;
          _status = SaveStatus.pending;
          if (!_disposed) _scheduleAutosave();
        }
      case SaveResult.limitReached:
        _status = SaveStatus.limitReached;
      case SaveResult.error:
        _status = SaveStatus.failed;
    }
    _notify();
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
