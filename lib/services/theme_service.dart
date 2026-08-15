import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeService — синглтон управления темой приложения (light/dark/system).
class ThemeService extends ChangeNotifier {
  static const String _key = 'vetvoice_theme_mode';
  static const String _dbInfoKey = 'vetvoice_db_info';

  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  String? _databaseInfo;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  String? get databaseInfo => _databaseInfo;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
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
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final value = mode.toString().split('.').last;
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    await _prefs?.setString(_key, value);
    notifyListeners();
  }

  Future<void> setDatabaseInfo(String info) async {
    _databaseInfo = info;
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    await _prefs?.setString(_dbInfoKey, info);
    notifyListeners();
  }
}
