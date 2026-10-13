import 'package:flutter/material.dart';
import 'package:ruya/services/settings_service.dart';
import 'package:ruya/utils/constants.dart';
import 'package:ruya/models/themes/app_theme_mode_enum.dart';
import 'package:ruya/theme/app_style.dart';

class ThemeNotifier with ChangeNotifier {
  late Color _themeColor;
  late bool _isDynamicEnabled;
  final SettingsService _settingsService;
  AppThemeMode _themeMode = AppThemeMode.system;
  AppThemeMode get themeMode => _themeMode;
  AppStyle _style = AppStyle.piksel;
  AppStyle get style => _style;

  ThemeNotifier(this._settingsService) {
    _themeColor = seedColor;
    _isDynamicEnabled = false;
    loadAllThemeSettings();
  }

  Color get themeColor => _themeColor;
  bool get isDynamicEnabled => _isDynamicEnabled;

  Future<void> setColor(Color color) async {
    _themeColor = color;
    await _settingsService.setThemeColor(color);
    notifyListeners();
  }

  Future<void> setDynamicThemeEnabled(bool isEnabled) async {
    _isDynamicEnabled = isEnabled;
    await _settingsService.setDynamicColorEnabled(isEnabled);
    notifyListeners();
  }

  Future<void> setStyle(AppStyle style) async {
    _style = style;
    await _settingsService.setAppStyle(style);
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _settingsService.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> loadAllThemeSettings() async {
    _themeColor = _settingsService.themeColor;
    _isDynamicEnabled = _settingsService.isDynamicThemeEnabled;
    _themeMode = _settingsService.themeMode;
    _style = _settingsService.appStyle;
    notifyListeners();
  }
}