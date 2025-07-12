import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crochet_stitch.dart';

class StitchSettingsService {
  static const String _globalStitchesKey = 'global_stitches';
  static SharedPreferences? _prefs;

  // SharedPreferencesの初期化
  static Future<void> _initPrefs() async {
    if (_prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
        print('StitchSettingsService: SharedPreferences初期化成功');
      } catch (e) {
        print('StitchSettingsService: SharedPreferences初期化失敗: $e');
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
                'name': stitch.name,
              };
            } else if (stitch is CustomStitch) {
              return {
                'type': 'custom',
                'name': stitch.name,
                'nameJa': stitch.nameJa,
                'nameEn': stitch.nameEn,
                'imagePath': stitch.imagePath,
                'color': stitch.color.value,
                'isOval': stitch.isOval,
              };
            }
            return null;
          })
          .where((item) => item != null)
          .toList();

      final success =
          await _prefs!.setString(_globalStitchesKey, jsonEncode(stitchesJson));
      print('グローバル編み目設定保存: $success');
      return success;
    } catch (e) {
      print('グローバル編み目設定保存エラー: $e');
      return false;
    }
  }

  // グローバル編み目設定を取得
  static Future<List<dynamic>> getGlobalStitches() async {
    try {
      await _initPrefs();

      final stitchesJsonString = _prefs!.getString(_globalStitchesKey);
      if (stitchesJsonString == null) {
        print('グローバル編み目設定なし、デフォルトを返す');
        return getDefaultStitches();
      }

      final stitchesJson = jsonDecode(stitchesJsonString) as List;
      final stitches = stitchesJson.map((stitchJson) {
        final stitchData = Map<String, dynamic>.from(stitchJson);
        if (stitchData['type'] == 'enum') {
          final stitchName = stitchData['name'] as String;
          try {
            return CrochetStitch.values.firstWhere(
              (stitch) => stitch.name == stitchName,
              orElse: () => CrochetStitch.singleCrochet,
            );
          } catch (e) {
            print('CrochetStitch変換エラー: $stitchName, エラー: $e');
            return CrochetStitch.singleCrochet;
          }
        } else if (stitchData['type'] == 'custom') {
          return CustomStitch(
            nameJa:
                stitchData['nameJa'] as String? ?? stitchData['name'] as String,
            nameEn:
                stitchData['nameEn'] as String? ?? stitchData['name'] as String,
            imagePath: stitchData['imagePath'] as String?,
            color: Color(stitchData['color'] as int),
            isOval: stitchData['isOval'] as bool? ?? false,
          );
        }
        return CrochetStitch.singleCrochet; // デフォルト
      }).toList();

      print('グローバル編み目設定取得: ${stitches.length}個');
      print('取得した編み目リスト:');
      for (int i = 0; i < stitches.length; i++) {
        final stitch = stitches[i];
        if (stitch is CrochetStitch) {
          print(
              '  $i: ${(stitch as CrochetStitch).name} (${stitch.runtimeType})');
        } else if (stitch is CustomStitch) {
          print(
              '  $i: ${(stitch as CustomStitch).name} (${stitch.runtimeType})');
        } else {
          print('  $i: 不明な型 (${stitch.runtimeType})');
        }
      }
      return stitches;
    } catch (e) {
      print('グローバル編み目設定取得エラー: $e');
      return getDefaultStitches();
    }
  }
}
