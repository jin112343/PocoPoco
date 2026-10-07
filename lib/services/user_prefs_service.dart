import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 操作まわりの軽いユーザー設定
class UserPrefsService {
  static const String _leftHandedKey = 'left_handed_layout';

  /// 左手で操作しやすいボタン配置にするか（既定は右手向け）
  static final ValueNotifier<bool> leftHanded = ValueNotifier<bool>(false);

  /// 保存済みの設定を読み込む（起動時に呼ぶ）
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      leftHanded.value = prefs.getBool(_leftHandedKey) ?? false;
    } catch (e) {
      debugPrint('UserPrefsService.load: 設定の読み込みに失敗: $e');
    }
  }

  static Future<void> setLeftHanded(bool value) async {
    leftHanded.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_leftHandedKey, value);
    } catch (e) {
      debugPrint('UserPrefsService.setLeftHanded: 設定の保存に失敗: $e');
    }
  }
}
