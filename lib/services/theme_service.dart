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
  // v1.16: синглтон. Раньше main.dart и settings_screen.dart создавали
  // РАЗНЫЕ инстансы — переключение темы из настроек не доходило до
  // MaterialApp, а radio показывал не текущий режим.
  ThemeService._internal();
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;

  static const String _key = 'vetvoice_theme_mode';
  static const String _dbInfoKey = 'vetvoice_db_info';

  SharedPreferences? _prefs;
  // v1.16: дефолт light, а не system — тёмная тема недоведена (захардкоженные
  // светлые поверхности дают белый-на-сером); выбрать dark можно в настройках
  ThemeMode _themeMode = ThemeMode.light;
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
        _themeMode = ThemeMode.light;
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
