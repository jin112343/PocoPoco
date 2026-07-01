import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeSetting {
  system,
  light,
  dark,
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeModeSetting _themeModeSetting = ThemeModeSetting.system;

  ThemeModeSetting get themeModeSetting => _themeModeSetting;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      _themeModeSetting = ThemeModeSetting.values[themeIndex];
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeModeSetting mode) async {
    _themeModeSetting = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, mode.index);
    } catch (e) {
      debugPrint('Failed to save theme: $e');
    }
  }

  ThemeMode get themeMode {
    switch (_themeModeSetting) {
      case ThemeModeSetting.system:
        return ThemeMode.system;
      case ThemeModeSetting.light:
        return ThemeMode.light;
      case ThemeModeSetting.dark:
        return ThemeMode.dark;
    }
  }
}
