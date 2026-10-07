import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/crochet_project.dart';

/// プロジェクト保存の結果
enum SaveResult {
  /// 保存できた
  saved,

  /// 無料プランの保存上限に達していて新規保存できなかった
  limitReached,

  /// 書き込みに失敗した
  error,
}

/// プロジェクトの永続化サービス
///
/// プロジェクトは1件ずつ個別のキー（crochet_project_<id>）で保存する。
/// 旧形式（crochet_projects キーに全件をStringListで一括保存）は
/// 1目編むたびに全プロジェクトを再エンコードして書き戻すため、
/// 履歴が増えると保存が重くなる問題があった。
/// 旧形式のデータは読み込み時に自動的に個別キーへ移行する。
class StorageService {
  static const String _legacyProjectsKey = 'crochet_projects';
  static const String _corruptedProjectsKey = 'crochet_projects_corrupted';
  static const String _projectKeyPrefix = 'crochet_project_';
  static const String _lastOpenedProjectKey = 'last_opened_project_id';

  /// 無料プランで保存できるプロジェクト数
  static const int freeProjectLimit = 3;
  static SharedPreferences? _prefs;
  static final Random _random = Random();
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  // SharedPreferencesの初期化
  static Future<void> _initPrefs() async {
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (e, stackTrace) {
        _logger.e(
          'StorageService: SharedPreferences初期化失敗',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }
  }

  /// 旧形式（一括StringList）のデータが残っていれば個別キーへ移行する。
  /// バックアップ復元で旧形式キーが再登場するケースもここで吸収される。
  static Future<void>? _migrationInFlight;

  static Future<void> _migrateLegacyIfNeeded() async {
    final running = _migrationInFlight;
    if (running != null) return running;
    final migration = _migrateLegacy();
    _migrationInFlight = migration;
    try {
      await migration;
    } finally {
      _migrationInFlight = null;
    }
  }

  static Future<void> _migrateLegacy() async {
    final legacy = _prefs!.getStringList(_legacyProjectsKey);
    if (legacy == null) return;
    final corrupted = <String>{
      ...(_prefs!.getStringList(_corruptedProjectsKey) ?? const []),
    };
    try {
      for (final jsonString in legacy) {
        late String id;
        try {
          final map = jsonDecode(jsonString) as Map<String, dynamic>;
          id = map['id'] as String;
          if (id.isEmpty) throw const FormatException('Empty project ID');
        } catch (_) {
          corrupted.add(jsonString);
          continue;
        }
        final key = '$_projectKeyPrefix$id';
        if (!_prefs!.containsKey(key) &&
            !await _prefs!.setString(key, jsonString)) {
          throw StateError('Project migration write failed');
        }
      }
      if (corrupted.isNotEmpty &&
          !await _prefs!
              .setStringList(_corruptedProjectsKey, corrupted.toList())) {
        throw StateError('Corrupted project preservation failed');
      }
      // 元データは全件の保存成功後にだけ削除する。
      if (!await _prefs!.remove(_legacyProjectsKey)) {
        throw StateError('Legacy project cleanup failed');
      }
    } catch (_) {
      // SharedPreferencesは書き込み失敗でもメモリの値を更新するため、
      // 再試行時に「保存済み」と誤判定しないよう永続データから読み直す。
      await _prefs!.reload();
      rethrow;
    }
  }

  /// 保存済みプロジェクトのキー一覧を取得
  static Iterable<String> _projectKeys() {
    return _prefs!.getKeys().where((key) => key.startsWith(_projectKeyPrefix));
  }

  /// プロジェクト一覧を取得する（更新日の新しい順）。
  /// ストレージ自体が読めない場合は例外を投げる。空のリストを返すと
  /// 「データが消えた」ように見えてしまうため、画面側で再試行を出せるようにする。
  Future<List<CrochetProject>> loadProjects() async {
    await _initPrefs();
    await _migrateLegacyIfNeeded();

    final projects = <CrochetProject>[];
    for (final key in _projectKeys()) {
      final jsonString = _prefs!.getString(key);
      if (jsonString == null) continue;
      try {
        projects.add(CrochetProject.fromJson(jsonDecode(jsonString)));
      } catch (e, stackTrace) {
        // 解析に失敗してもデータ自体は個別キーに残るため消失しない
        _logger.e(
          'loadProjects: $key の解析に失敗（データは保持されます）',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    projects.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt;
      final bDate = b.updatedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    return projects;
  }

  // プロジェクト一覧を取得（失敗時は空のリスト）
  Future<List<CrochetProject>> getProjects() async {
    try {
      return await loadProjects();
    } catch (e, stackTrace) {
      _logger.e(
        'getProjects: プロジェクト一覧の取得に失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// プロジェクトを保存する（該当プロジェクトのみ書き込む）。
  /// 上限に達した場合と書き込み失敗を区別して返す。
  Future<SaveResult> save(CrochetProject project,
      {bool isPremium = false}) async {
    try {
      await _initPrefs();
      await _migrateLegacyIfNeeded();

      final key = '$_projectKeyPrefix${project.id}';
      final isNew = !_prefs!.containsKey(key);

      // 新規プロジェクトの場合のみ、プレミアムでない場合は保存制限をチェック
      if (isNew && !isPremium && _projectKeys().length >= freeProjectLimit) {
        return SaveResult.limitReached;
      }

      final toSave =
          isNew ? project : project.copyWith(updatedAt: DateTime.now());
      final json = jsonEncode(toSave.toJson());
      final success = await _prefs!.setString(key, json);
      return success ? SaveResult.saved : SaveResult.error;
    } catch (e, stackTrace) {
      _logger.e(
        'save: プロジェクト保存に失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return SaveResult.error;
    }
  }

  // プロジェクトを保存（保存できたかどうかだけを返す）
  Future<bool> saveProject(CrochetProject project,
      {bool isPremium = false}) async {
    return await save(project, isPremium: isPremium) == SaveResult.saved;
  }

  /// 削除したプロジェクトを元に戻す（削除の取り消し用）。
  /// 元々あったデータを戻すだけなので、保存上限の確認や更新日の変更はしない。
  Future<bool> restoreProject(CrochetProject project) async {
    try {
      await _initPrefs();
      return await _prefs!.setString(
        '$_projectKeyPrefix${project.id}',
        jsonEncode(project.toJson()),
      );
    } catch (e, stackTrace) {
      _logger.e(
        'restoreProject: プロジェクトの復元に失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// プロジェクトを複製する。編み方ボタン・メモ・目印・アイコンは引き継ぎ、
  /// 編み目の記録（カウント）だけを空にした新しいプロジェクトを返す。
  /// 保存できなかった場合はnull（[SaveResult] は [onResult] で受け取れる）。
  Future<CrochetProject?> duplicateProject(
    CrochetProject source, {
    required String title,
    bool isPremium = false,
    void Function(SaveResult result)? onResult,
  }) async {
    final copy = CrochetProject(
      id: generateProjectId(),
      title: title,
      createdAt: DateTime.now(),
      stitchHistory: [],
      currentRow: 1,
      currentStitchCount: 0,
      iconName: source.iconName,
      iconColor: source.iconColor,
      backgroundColor: source.backgroundColor,
      iconImagePath: source.iconImagePath,
      customStitches: List<dynamic>.of(source.customStitches),
      memo: source.memo,
      markers: source.markers.restartedFromFirstRow(),
    );
    final result = await save(copy, isPremium: isPremium);
    onResult?.call(result);
    return result == SaveResult.saved ? copy : null;
  }

  /// 最後に開いたプロジェクトのIDを記録する（「続きから」表示用）
  Future<void> setLastOpenedProjectId(String projectId) async {
    try {
      await _initPrefs();
      await _prefs!.setString(_lastOpenedProjectKey, projectId);
    } catch (e) {
      _logger.w('setLastOpenedProjectId: 記録に失敗: $e');
    }
  }

  /// 最後に開いたプロジェクトのID（なければnull）
  Future<String?> getLastOpenedProjectId() async {
    try {
      await _initPrefs();
      return _prefs!.getString(_lastOpenedProjectKey);
    } catch (e) {
      _logger.w('getLastOpenedProjectId: 取得に失敗: $e');
      return null;
    }
  }

  // プロジェクトを削除
  Future<bool> deleteProject(String projectId) async {
    try {
      await _initPrefs();
      await _migrateLegacyIfNeeded();

      return await _prefs!.remove('$_projectKeyPrefix$projectId');
    } catch (e, stackTrace) {
      _logger.e(
        'deleteProject: プロジェクト削除に失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // プロジェクトIDを生成
  String generateProjectId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // 同一ミリ秒内の生成でも衝突しないよう乱数を使用
    final random = _random.nextInt(1000000).toString().padLeft(6, '0');
    return '${timestamp}_$random';
  }
}
