import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/crochet_stitch.dart';

class StitchSettingsService {
  static const String _globalStitchesKey = 'global_stitches';
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
        _logger.i('StitchSettingsService: SharedPreferences初期化成功');
      } catch (e, stackTrace) {
        _logger.e(
          'StitchSettingsService: SharedPreferences初期化失敗',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }
  }

  // デフォルトの編み目リストを取得
  static List<dynamic> getDefaultStitches() {
    return [
      CrochetStitch.chain,
      CrochetStitch.slipStitch,
      CrochetStitch.singleCrochet,
      CrochetStitch.halfDoubleCrochet,
      CrochetStitch.doubleCrochet,
      CrochetStitch.trebleCrochet,
    ];
  }

  // グローバル編み目設定を保存
  static Future<bool> saveGlobalStitches(List<dynamic> stitches) async {
    try {
      await _initPrefs();

      final stitchesJson = stitches
          .map((stitch) {
            if (stitch is CrochetStitch) {
              return {
                'type': 'enum',
                'name': stitch.nameEn, // 識別子として英語名を使用
                'nameJa': stitch.nameJa,
                'nameEn': stitch.nameEn,
              };
            } else if (stitch is CustomStitch) {
              return {
                'type': 'custom',
                'name': stitch.nameEn, // 識別子として英語名を使用
                'nameJa': stitch.nameJa,
                'nameEn': stitch.nameEn,
                'imagePath': stitch.imagePath,
                'color': stitch.color.toARGB32(),
                'isOval': stitch.isOval,
              };
            }
            return null;
          })
          .where((item) => item != null)
          .toList();

      final success =
          await _prefs!.setString(_globalStitchesKey, jsonEncode(stitchesJson));
      _logger.i('saveGlobalStitches: グローバル編み目設定保存 success=$success');
      return success;
    } catch (e, stackTrace) {
      _logger.e(
        'saveGlobalStitches: グローバル編み目設定保存エラー',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // グローバル編み目設定を取得
  static Future<List<dynamic>> getGlobalStitches() async {
    try {
      await _initPrefs();

      final stitchesJsonString = _prefs!.getString(_globalStitchesKey);
      if (stitchesJsonString == null) {
        return getDefaultStitches();
      }

      final stitchesJson = jsonDecode(stitchesJsonString) as List;
      // 要素単位でパースし、壊れた要素だけスキップする
      // （全体をcatchで潰すと1件の不正データでユーザー設定全体が消えたように見える）
      final stitches = <dynamic>[];
      for (final stitchJson in stitchesJson) {
        try {
          final stitchData = Map<String, dynamic>.from(stitchJson);
          if (stitchData['type'] == 'enum') {
            final stitchName = stitchData['name'] as String;
            final stitchNameEn = stitchData['nameEn'] as String? ?? stitchName;
            stitches.add(CrochetStitch.values.firstWhere(
              (stitch) =>
                  stitch.nameEn == stitchNameEn || stitch.nameJa == stitchName,
              orElse: () => CrochetStitch.singleCrochet,
            ));
          } else if (stitchData['type'] == 'custom') {
            // imagePathが空文字列の場合はnullとして扱う
            final imagePathRaw = stitchData['imagePath'] as String?;
            var imagePath = (imagePathRaw == null || imagePathRaw.isEmpty)
                ? null
                : imagePathRaw;

            final nameJa =
                stitchData['nameJa'] as String? ?? stitchData['name'] as String;
            // imagePathがnullの場合、編み目名から画像パスを復元
            imagePath ??= CustomStitch.lookupImagePath(nameJa);

            stitches.add(CustomStitch(
              nameJa: nameJa,
              nameEn: stitchData['nameEn'] as String? ??
                  stitchData['name'] as String,
              imagePath: imagePath,
              // colorが欠落していてもデフォルト色で復元する
              color: Color(stitchData['color'] as int? ?? 0xFFE91E63),
              isOval: stitchData['isOval'] as bool? ?? false,
            ));
          } else {
            stitches.add(CrochetStitch.singleCrochet); // デフォルト
          }
        } catch (e) {
          _logger.w('getGlobalStitches: 編み目1件の解析に失敗、スキップします: $e');
        }
      }

      if (stitches.isEmpty) {
        return getDefaultStitches();
      }
      return stitches;
    } catch (e) {
      _logger.e('getGlobalStitches: 編み目設定の読み込みに失敗: $e');
      return getDefaultStitches();
    }
  }
}
