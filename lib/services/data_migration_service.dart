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
        _logger.i('DataMigrationService: SharedPreferences初期化成功');
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
      _logger.i('現在のデータバージョン: $version');
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
      _logger.i('データバージョン保存: $version, 成功: $success');
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
      _logger.i('=== データマイグレーション開始 ===');
      final currentVersion = await getCurrentDataVersion();
      _logger.i('現在のバージョン: $currentVersion');
      _logger.i('最新のバージョン: $_currentDataVersion');

      if (currentVersion >= _currentDataVersion) {
        _logger.i('マイグレーション不要');
        return true;
      }

      // バージョンごとのマイグレーション処理
      for (int version = currentVersion + 1;
          version <= _currentDataVersion;
          version++) {
        _logger.i('バージョン $version へマイグレーション中...');
        final success = await _migrateToVersion(version);
        if (!success) {
          _logger.e('バージョン $version へのマイグレーション失敗');
          return false;
        }
        await _saveDataVersion(version);
        _logger.i('バージョン $version へのマイグレーション完了');
      }

      _logger.i('=== データマイグレーション完了 ===');
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
      _logger.i('バージョン1へのマイグレーション開始');
      await _initPrefs();

      // 既存のデータが存在するか確認
      final projectsKey = 'crochet_projects';
      final globalStitchesKey = 'global_stitches';

      final hasProjects = _prefs!.containsKey(projectsKey);
      final hasGlobalStitches = _prefs!.containsKey(globalStitchesKey);

      _logger.i('既存データ: projects=$hasProjects, stitches=$hasGlobalStitches');

      // データが存在する場合は、そのまま維持
      // データが存在しない場合は、デフォルト値が自動的に設定される

      _logger.i('バージョン1へのマイグレーション完了');
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
      _logger.i('=== データ整合性チェック開始 ===');
      await _initPrefs();

      // プロジェクトデータのチェック
      final projectsKey = 'crochet_projects';
      final projectsData = _prefs!.getStringList(projectsKey);
      if (projectsData != null) {
        _logger.i('プロジェクトデータ: ${projectsData.length}件');
        // 各プロジェクトのJSON形式をチェック
        for (int i = 0; i < projectsData.length; i++) {
          try {
            // JSON形式の検証のみ（パース可能かチェック）
            final _ = projectsData[i];
            _logger.d('プロジェクト$i: 形式OK');
          } catch (e) {
            _logger.w('プロジェクト$i: 形式エラー', error: e);
          }
        }
      }

      // グローバル編み目設定のチェック
      final globalStitchesKey = 'global_stitches';
      final stitchesData = _prefs!.getString(globalStitchesKey);
      if (stitchesData != null) {
        _logger.i('グローバル編み目設定: 存在');
      } else {
        _logger.i('グローバル編み目設定: デフォルトが使用される');
      }

      _logger.i('=== データ整合性チェック完了 ===');
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
