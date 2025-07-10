import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crochet_project.dart';

class StorageService {
  static const String _projectsKey = 'crochet_projects';
  static SharedPreferences? _prefs;

  // SharedPreferencesの初期化
  static Future<void> _initPrefs() async {
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
        print('SharedPreferences初期化成功');
      } catch (e) {
        print('SharedPreferences初期化失敗: $e');
        rethrow;
      }
    }
  }

  // プロジェクト一覧を取得
  Future<List<CrochetProject>> getProjects() async {
    try {
      await _initPrefs();
      final projectsJson = _prefs!.getStringList(_projectsKey) ?? [];
      print('保存されたプロジェクト数: ${projectsJson.length}');

      final projects = <CrochetProject>[];
      for (int i = 0; i < projectsJson.length; i++) {
        try {
          final json = projectsJson[i];
          print('プロジェクト$i JSON解析開始');
          final project = CrochetProject.fromJson(jsonDecode(json));
          projects.add(project);
          print('プロジェクト$i 解析成功: ${project.title}');
        } catch (e) {
          print('プロジェクト$i の解析に失敗: $e');
          print('JSON: ${projectsJson[i]}');
        }
      }

      projects.sort((a, b) =>
          b.updatedAt?.compareTo(a.updatedAt ?? a.createdAt) ??
          b.createdAt.compareTo(a.createdAt));
      print('プロジェクト一覧取得完了: ${projects.length}件');
      return projects;
    } catch (e) {
      print('プロジェクト一覧の取得に失敗: $e');
      return [];
    }
  }

  // プロジェクトを保存
  Future<bool> saveProject(CrochetProject project) async {
    try {
      print('プロジェクト保存開始: ${project.title}');
      await _initPrefs();

      final projects = await getProjects();

      // 既存のプロジェクトを更新するか新しいプロジェクトを追加
      final existingIndex = projects.indexWhere((p) => p.id == project.id);
      if (existingIndex >= 0) {
        print('既存プロジェクトを更新: ${project.title}');
        projects[existingIndex] = project.copyWith(updatedAt: DateTime.now());
      } else {
        print('新規プロジェクトを追加: ${project.title}');
        projects.add(project);
      }

      // JSONに変換して保存
      final projectsJson = <String>[];
      for (int i = 0; i < projects.length; i++) {
        try {
          final p = projects[i];
          print('プロジェクト$i JSON変換開始: ${p.title}');
          final json = jsonEncode(p.toJson());
          projectsJson.add(json);
          print('プロジェクト$i JSON変換成功: ${p.title}');
        } catch (e) {
          print('プロジェクト$i JSON変換失敗: ${projects[i].title}, エラー: $e');
          return false;
        }
      }

      final success = await _prefs!.setStringList(_projectsKey, projectsJson);
      print('保存結果: $success, プロジェクト数: ${projectsJson.length}');
      return success;
    } catch (e) {
      print('プロジェクトの保存に失敗: $e');
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
      print('プロジェクトの削除に失敗: $e');
      return false;
    }
  }

  // プロジェクトIDを生成
  String generateProjectId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
