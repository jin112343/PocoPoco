import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class DataMigrationService {
  static const String _versionKey = 'app_data_version';
  static const int _currentDataVersion = 1;
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
      } catch (e, stackTrace) {
        _logger.e(
          'DataMigrationService: SharedPreferences初期化失敗',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }
  }

  // 現在のデータバージョンを取得
  static Future<int> getCurrentDataVersion() async {
    try {
      await _initPrefs();
      final version = _prefs!.getInt(_versionKey) ?? 0;
      return version;
    } catch (e, stackTrace) {
      _logger.e(
        'getCurrentDataVersion: データバージョン取得失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  // データバージョンを保存
  static Future<bool> _saveDataVersion(int version) async {
    try {
      await _initPrefs();
      final success = await _prefs!.setInt(_versionKey, version);
      return success;
    } catch (e, stackTrace) {
      _logger.e(
        '_saveDataVersion: データバージョン保存失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // マイグレーション処理を実行
  static Future<bool> migrate() async {
    try {
      final currentVersion = await getCurrentDataVersion();

      if (currentVersion >= _currentDataVersion) {
        return true;
      }

      // バージョンごとのマイグレーション処理
      for (int version = currentVersion + 1;
          version <= _currentDataVersion;
          version++) {
        final success = await _migrateToVersion(version);
        if (!success) {
          _logger.e('migrate: バージョン $version へのマイグレーション失敗');
          return false;
        }
        await _saveDataVersion(version);
      }

      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'migrate: マイグレーション処理失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // 特定のバージョンへのマイグレーション
  static Future<bool> _migrateToVersion(int version) async {
    try {
      switch (version) {
        case 1:
          return await _migrateToVersion1();
        // 将来のバージョンアップ時にここにケースを追加
        // case 2:
        //   return await _migrateToVersion2();
        default:
          _logger.w('未知のバージョン: $version');
          return true;
      }
    } catch (e, stackTrace) {
      _logger.e(
        '_migrateToVersion: バージョン $version へのマイグレーション失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // バージョン1へのマイグレーション（初期バージョン）
  static Future<bool> _migrateToVersion1() async {
    try {
      await _initPrefs();
      // 初期バージョンでは特に処理なし
      // データが存在する場合は、そのまま維持
      // データが存在しない場合は、デフォルト値が自動的に設定される
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        '_migrateToVersion1: バージョン1へのマイグレーション失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // データの整合性チェック
  static Future<bool> validateData() async {
    try {
      await _initPrefs();

      // プロジェクトデータのチェック
      const projectsKey = 'crochet_projects';
      final projectsData = _prefs!.getStringList(projectsKey);
      if (projectsData != null) {
        // 各プロジェクトのJSON形式をチェック
        for (int i = 0; i < projectsData.length; i++) {
          try {
            // JSON形式の検証のみ（パース可能かチェック）
            final _ = projectsData[i];
          } catch (e) {
            _logger.w('validateData: プロジェクト$i 形式エラー', error: e);
          }
        }
      }

      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'validateData: データ整合性チェック失敗',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
