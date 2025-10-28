import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/crochet_project.dart';

class StorageService {
  static const String _projectsKey = 'crochet_projects';
  static SharedPreferences? _prefs;
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
        _logger.i('StorageService: SharedPreferences初期化成功');
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

  // プロジェクト一覧を取得
  Future<List<CrochetProject>> getProjects() async {
    try {
      await _initPrefs();
      final projectsJson = _prefs!.getStringList(_projectsKey) ?? [];
      _logger.i('getProjects: 保存されたプロジェクト数=${projectsJson.length}');

      final projects = <CrochetProject>[];
      for (int i = 0; i < projectsJson.length; i++) {
        try {
          final json = projectsJson[i];
          _logger.d('getProjects: プロジェクト$i JSON解析開始');
          final project = CrochetProject.fromJson(jsonDecode(json));
          projects.add(project);
          _logger.d('getProjects: プロジェクト$i 解析成功 title=${project.title}');
        } catch (e, stackTrace) {
          _logger.e(
            'getProjects: プロジェクト$i の解析に失敗',
            error: e,
            stackTrace: stackTrace,
          );
          _logger.d('getProjects: 失敗したJSON=${projectsJson[i]}');
        }
      }

      projects.sort((a, b) =>
          b.updatedAt?.compareTo(a.updatedAt ?? a.createdAt) ??
          b.createdAt.compareTo(a.createdAt));
      _logger.i('getProjects: プロジェクト一覧取得完了 count=${projects.length}');
      for (int i = 0; i < projects.length; i++) {
        _logger.d('getProjects:   $i: ${projects[i].title} id=${projects[i].id}');
      }
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

  // プロジェクトを保存
  Future<bool> saveProject(CrochetProject project,
      {bool isPremium = false}) async {
    try {
      _logger.i('=== saveProject: プロジェクト保存開始 ===');
      _logger.i('saveProject: title=${project.title} id=${project.id} isPremium=$isPremium');
      await _initPrefs();

      final projects = await getProjects();

      // 既存のプロジェクトを更新するか新しいプロジェクトを追加
      final existingIndex = projects.indexWhere((p) => p.id == project.id);

      if (existingIndex >= 0) {
        projects[existingIndex] = project.copyWith(updatedAt: DateTime.now());
      } else {
        // 新規プロジェクトの場合のみ、プレミアムでない場合は保存制限をチェック
        if (!isPremium && projects.length >= 3) {
          return false;
        }
        projects.add(project);
      }

      // JSONに変換して保存
      final projectsJson = <String>[];
      for (int i = 0; i < projects.length; i++) {
        try {
          final p = projects[i];
          final json = jsonEncode(p.toJson());
          projectsJson.add(json);
        } catch (e) {
          return false;
        }
      }

      final success = await _prefs!.setStringList(_projectsKey, projectsJson);
      return success;
    } catch (e) {
      return false;
    }
  }

  // プロジェクトを削除
  Future<bool> deleteProject(String projectId) async {
    try {
      await _initPrefs();
      final projects = await getProjects();

      projects.removeWhere((project) => project.id == projectId);

      final projectsJson = projects.map((p) => jsonEncode(p.toJson())).toList();

      return await _prefs!.setStringList(_projectsKey, projectsJson);
    } catch (e) {
      return false;
    }
  }

  // プロジェクト一覧を保存
  Future<bool> saveProjects(List<CrochetProject> projects,
      {bool isPremium = false}) async {
    try {
      await _initPrefs();

      // プレミアムでない場合は保存制限をチェック
      if (!isPremium && projects.length > 3) {
        return false;
      }

      // JSONに変換して保存
      final projectsJson = <String>[];
      for (int i = 0; i < projects.length; i++) {
        try {
          final p = projects[i];
          final json = jsonEncode(p.toJson());
          projectsJson.add(json);
        } catch (e) {
          return false;
        }
      }

      final success = await _prefs!.setStringList(_projectsKey, projectsJson);
      return success;
    } catch (e) {
      return false;
    }
  }

  // プロジェクトIDを生成
  String generateProjectId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    final uuid = '${timestamp}_$random';
    return uuid;
  }
}
