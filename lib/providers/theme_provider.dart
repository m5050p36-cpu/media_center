import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType {
  dark,      // الافتراضي
  light,     // نهاري
  amoled,    // أسود كامل
  ocean,     // أزرق محيطي
  sunset,    // غروب
  forest,    // غابة
  rose,      // وردي
}

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_type_v2';
  AppThemeType _type = AppThemeType.dark;

  AppThemeType get type => _type;
  bool get isDark => _type != AppThemeType.light;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v != null) {
      _type = AppThemeType.values.firstWhere(
        (t) => t.name == v,
        orElse: () => AppThemeType.dark,
      );
    }
    notifyListeners();
  }

  Future<void> setTheme(AppThemeType type) async {
    _type = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, type.name);
    notifyListeners();
  }

  /// للتوافق مع الكود القديم
  ThemeMode get mode => _type == AppThemeType.light
      ? ThemeMode.light
      : ThemeMode.dark;

  Future<void> toggle() async {
    await setTheme(_type == AppThemeType.light
        ? AppThemeType.dark
        : AppThemeType.light);
  }

  String get label {
    switch (_type) {
      case AppThemeType.dark: return 'داكن';
      case AppThemeType.light: return 'نهاري';
      case AppThemeType.amoled: return 'AMOLED';
      case AppThemeType.ocean: return 'محيطي';
      case AppThemeType.sunset: return 'غروب';
      case AppThemeType.forest: return 'غابة';
      case AppThemeType.rose: return 'وردي';
    }
  }

  Color get accentColor {
    switch (_type) {
      case AppThemeType.dark: return const Color(0xFF6C63FF);
      case AppThemeType.light: return const Color(0xFF6C63FF);
      case AppThemeType.amoled: return const Color(0xFF6C63FF);
      case AppThemeType.ocean: return const Color(0xFF0EA5E9);
      case AppThemeType.sunset: return const Color(0xFFF97316);
      case AppThemeType.forest: return const Color(0xFF10B981);
      case AppThemeType.rose: return const Color(0xFFEC4899);
    }
  }
}
