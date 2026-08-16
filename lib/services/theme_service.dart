// ThemeService — управление темой приложения (light/dark/system).
//
// Использует SharedPreferences для сохранения выбора.
// ChangeNotifier — UI пересобирается автоматически при смене темы.
//
// Использование в main.dart:
//   final themeService = ThemeService();
//   await themeService.init();
//   MaterialApp(
//     theme: AppTheme.lightTheme,
//     darkTheme: AppTheme.darkTheme,
//     themeMode: themeService.themeMode,
//   )
//
// В SettingsScreen:
//   ThemeService().setThemeMode(ThemeMode.dark);

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _key = 'vetvoice_theme_mode';
  static const String _dbInfoKey = 'vetvoice_db_info';

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  String? _databaseInfo;

  ThemeMode get themeMode => _themeMode;
  String? get databaseInfo => _databaseInfo;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString(_key);
    switch (saved) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        _themeMode = ThemeMode.system;
    }
    _databaseInfo = _prefs?.getString(_dbInfoKey);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final value = mode.toString().split('.').last;
    await _prefs?.setString(_key, value);
    notifyListeners();
  }

  Future<void> setDatabaseInfo(String info) async {
    _databaseInfo = info;
    await _prefs?.setString(_dbInfoKey, info);
    notifyListeners();
  }
}
