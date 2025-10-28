import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
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
        _logger.i('BackupService: SharedPreferences初期化成功');
      } catch (e, stackTrace) {
        _logger.e(
          'BackupService: SharedPreferences初期化失敗',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }
  }

  // すべてのデータをバックアップ
  static Future<Map<String, dynamic>> createBackup() async {
    try {
      _logger.i('=== バックアップ作成開始 ===');
      await _initPrefs();

      final backup = <String, dynamic>{
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'data': {},
      };

      // すべてのキーをバックアップ
      final keys = _prefs!.getKeys();
      _logger.i('createBackup: バックアップするキー数=${keys.length}');

      for (final key in keys) {
        try {
          final value = _prefs!.get(key);
          if (value != null) {
            if (value is String) {
              backup['data'][key] = {'type': 'string', 'value': value};
            } else if (value is int) {
              backup['data'][key] = {'type': 'int', 'value': value};
            } else if (value is double) {
              backup['data'][key] = {'type': 'double', 'value': value};
            } else if (value is bool) {
              backup['data'][key] = {'type': 'bool', 'value': value};
            } else if (value is List<String>) {
              backup['data'][key] = {'type': 'stringList', 'value': value};
            }
            _logger.d('createBackup: キー=$key をバックアップ');
          }
        } catch (e, stackTrace) {
          _logger.e(
            'createBackup: キー=$key のバックアップに失敗',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      _logger.i('=== バックアップ作成完了 ===');
      return backup;
    } catch (e, stackTrace) {
      _logger.e(
        'createBackup: バックアップ作成失敗',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // バックアップをファイルに保存してシェア
  static Future<bool> exportBackup() async {
    try {
      _logger.i('=== バックアップエクスポート開始 ===');
      final backup = await createBackup();
      final jsonString = jsonEncode(backup);

      // 一時ファイルに保存
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${directory.path}/pocopoco_backup_$timestamp.json');
      await file.writeAsString(jsonString);

      _logger.i('exportBackup: ファイル保存成功 path=${file.path}');

      // ファイルをシェア
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'PocoPocoバックアップ',
        text: 'PocoPocoのデータバックアップファイルです',
      );

      _logger.i('exportBackup: シェア結果=${result.status}');
      _logger.i('=== バックアップエクスポート完了 ===');
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'exportBackup: バックアップエクスポート失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // バックアップから復元
  static Future<bool> restoreBackup(String jsonString) async {
    try {
      _logger.i('=== バックアップ復元開始 ===');
      await _initPrefs();

      final backup = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = backup['version'] as int;
      final timestamp = backup['timestamp'] as String;
      final data = backup['data'] as Map<String, dynamic>;

      _logger.i('restoreBackup: version=$version timestamp=$timestamp');
      _logger.i('restoreBackup: 復元するキー数=${data.length}');

      // バージョンチェック
      if (version != 1) {
        _logger.w('restoreBackup: 未対応のバックアップバージョン=$version');
        return false;
      }

      // データを復元
      int successCount = 0;
      int failureCount = 0;

      for (final entry in data.entries) {
        final key = entry.key;
        final valueData = entry.value as Map<String, dynamic>;
        final type = valueData['type'] as String;
        final value = valueData['value'];

        try {
          bool success = false;
          switch (type) {
            case 'string':
              success = await _prefs!.setString(key, value as String);
              break;
            case 'int':
              success = await _prefs!.setInt(key, value as int);
              break;
            case 'double':
              success = await _prefs!.setDouble(key, value as double);
              break;
            case 'bool':
              success = await _prefs!.setBool(key, value as bool);
              break;
            case 'stringList':
              success = await _prefs!
                  .setStringList(key, List<String>.from(value as List));
              break;
            default:
              _logger.w('restoreBackup: 未知の型=$type key=$key');
          }

          if (success) {
            successCount++;
            _logger.d('restoreBackup: キー=$key 復元成功');
          } else {
            failureCount++;
            _logger.w('restoreBackup: キー=$key 復元失敗');
          }
        } catch (e, stackTrace) {
          failureCount++;
          _logger.e(
            'restoreBackup: キー=$key の復元に失敗',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      _logger.i(
          'restoreBackup: 復元完了 成功=$successCount 失敗=$failureCount');
      _logger.i('=== バックアップ復元完了 ===');
      return failureCount == 0;
    } catch (e, stackTrace) {
      _logger.e(
        'restoreBackup: バックアップ復元失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // バックアップファイルの検証
  static Future<bool> validateBackupFile(String jsonString) async {
    try {
      _logger.i('=== バックアップファイル検証開始 ===');
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;

      // 必須フィールドのチェック
      if (!backup.containsKey('version') ||
          !backup.containsKey('timestamp') ||
          !backup.containsKey('data')) {
        _logger.w('validateBackupFile: 必須フィールドが不足');
        return false;
      }

      final version = backup['version'];
      if (version is! int) {
        _logger.w('validateBackupFile: バージョンが不正');
        return false;
      }

      if (version != 1) {
        _logger.w('validateBackupFile: 未対応のバージョン=$version');
        return false;
      }

      final data = backup['data'];
      if (data is! Map<String, dynamic>) {
        _logger.w('validateBackupFile: データ形式が不正');
        return false;
      }

      _logger.i('validateBackupFile: バックアップファイルは有効');
      _logger.i('=== バックアップファイル検証完了 ===');
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'validateBackupFile: バックアップファイル検証失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
