import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

enum AppThemeType {
  sunsetAmber,
  royalBlue,
  emeraldForest,
  deepPurple,
  midnightGold,
}

class ThemePaletteInfo {
  final AppThemeType type;
  final String name;
  final String englishName;
  final Color primaryColor;
  final Color accentColor;
  final bool isVipOnly;
  final String icon;

  const ThemePaletteInfo({
    required this.type,
    required this.name,
    required this.englishName,
    required this.primaryColor,
    required this.accentColor,
    this.isVipOnly = false,
    required this.icon,
  });
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  AppThemeType _activeTheme = AppThemeType.royalBlue;

  static const List<ThemePaletteInfo> availableThemes = [
    ThemePaletteInfo(
      type: AppThemeType.royalBlue,
      name: 'Academic Blue & Gold (زانکۆیی)',
      englishName: 'Academic Blue & Gold',
      primaryColor: Color(0xFF035EC2),
      accentColor: Color(0xFFE4D27D),
      icon: '🎓',
    ),
  ];

  ThemeProvider() {
    ZankoColors.updatePalette(ZankoTheme.getColors(_activeTheme));
    _loadThemeFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  AppThemeType get activeTheme => _activeTheme;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemePaletteInfo get currentPalette {
    return availableThemes.firstWhere(
      (t) => t.type == _activeTheme,
      orElse: () => availableThemes.first,
    );
  }

  Color get primaryColor => currentPalette.primaryColor;
  Color get accentColor => currentPalette.accentColor;

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }

    final savedThemeStr = prefs.getString('active_theme_type');
    if (savedThemeStr != null) {
      for (final t in AppThemeType.values) {
        if (t.name == savedThemeStr) {
          _activeTheme = t;
          break;
        }
      }
    }
    ZankoColors.updatePalette(ZankoTheme.getColors(_activeTheme));
    notifyListeners();
  }

  Future<void> toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isOn);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', mode == ThemeMode.dark);
  }

  Future<void> setAppTheme(AppThemeType themeType) async {
    _activeTheme = themeType;
    ZankoColors.updatePalette(ZankoTheme.getColors(themeType));
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_theme_type', themeType.name);
  }
}
