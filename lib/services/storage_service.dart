import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/crochet_project.dart';

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
  static Future<void> _migrateLegacyIfNeeded() async {
    final legacy = _prefs!.getStringList(_legacyProjectsKey);
    if (legacy == null) return;

    _logger.i('旧形式のプロジェクトデータを個別キーへ移行します: ${legacy.length}件');
    final corrupted = <String>[
      ...(_prefs!.getStringList(_corruptedProjectsKey) ?? const []),
    ];

    for (final jsonString in legacy) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        final id = map['id'] as String;
        final key = '$_projectKeyPrefix$id';
        // 個別キーが既に存在する場合は上書きしない（個別キー側が最新）
        if (!_prefs!.containsKey(key)) {
          await _prefs!.setString(key, jsonString);
        }
      } catch (e) {
        // 解析できないデータは消さずに退避して保全する
        _logger.w('_migrateLegacyIfNeeded: 解析不能なプロジェクトを退避します: $e');
        corrupted.add(jsonString);
      }
    }

    if (corrupted.isNotEmpty) {
      await _prefs!.setStringList(_corruptedProjectsKey, corrupted);
    }
    await _prefs!.remove(_legacyProjectsKey);
    _logger.i('旧形式データの移行が完了しました');
  }

  /// 保存済みプロジェクトのキー一覧を取得
  static Iterable<String> _projectKeys() {
    return _prefs!
        .getKeys()
        .where((key) => key.startsWith(_projectKeyPrefix));
  }

  // プロジェクト一覧を取得
  Future<List<CrochetProject>> getProjects() async {
    try {
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
            'getProjects: $key の解析に失敗（データは保持されます）',
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
    } catch (e, stackTrace) {
      _logger.e(
        'getProjects: プロジェクト一覧の取得に失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // プロジェクトを保存（該当プロジェクトのみ書き込む）
  Future<bool> saveProject(CrochetProject project,
      {bool isPremium = false}) async {
    try {
      await _initPrefs();
      await _migrateLegacyIfNeeded();

      final key = '$_projectKeyPrefix${project.id}';
      final isNew = !_prefs!.containsKey(key);

      // 新規プロジェクトの場合のみ、プレミアムでない場合は保存制限をチェック
      if (isNew && !isPremium && _projectKeys().length >= 3) {
        return false;
      }

      final toSave =
          isNew ? project : project.copyWith(updatedAt: DateTime.now());
      final json = jsonEncode(toSave.toJson());
      return await _prefs!.setString(key, json);
    } catch (e, stackTrace) {
      _logger.e(
        'saveProject: プロジェクト保存に失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
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
