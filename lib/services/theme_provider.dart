import 'package:flutter/material.dart';

enum AppThemeType { blueGlass, emeraldForest, sunsetViolet, midnightGold }

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppThemeType _activeTheme = AppThemeType.blueGlass;

  ThemeMode get themeMode => _themeMode;
  AppThemeType get activeTheme => _activeTheme;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setAppTheme(AppThemeType themeType) {
    _activeTheme = themeType;
    notifyListeners();
  }
}
