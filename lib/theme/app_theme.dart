import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

class AppTheme {
  // ═══ الألوان الأساسية ═══
  static const Color primary = Color(0xFF6C63FF);
  static const Color accent = Color(0xFF4ECDC4);

  // ═══ Dark ═══
  static const Color bgDark = Color(0xFF0F0F1A);
  static const Color cardDark = Color(0xFF1B1B2E);
  static const Color textDark = Color(0xFFEFEFFF);
  static const Color subDark = Color(0xFF9E9EB8);

  // ═══ Light ═══
  static const Color bgLight = Color(0xFFF5F5FA);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF1A1A2E);
  static const Color subLight = Color(0xFF6E6E85);

  // ═══ Aliases ═══
  static const Color bg = bgDark;
  static const Color card = cardDark;
  static const Color text = textDark;
  static const Color sub = subDark;

  // ═══ الحصول على الثيم حسب النوع ═══
  static ThemeData byType(AppThemeType type) {
    switch (type) {
      case AppThemeType.dark:
        return dark();
      case AppThemeType.light:
        return light();
      case AppThemeType.amoled:
        return _custom(
          bg: const Color(0xFF000000),
          card: const Color(0xFF0A0A0A),
          text: const Color(0xFFEFEFFF),
          sub: const Color(0xFF9E9EB8),
          primary: const Color(0xFF6C63FF),
          accent: const Color(0xFF4ECDC4),
          isDark: true,
        );
      case AppThemeType.ocean:
        return _custom(
          bg: const Color(0xFF0A1628),
          card: const Color(0xFF15263E),
          text: const Color(0xFFE0F2FE),
          sub: const Color(0xFF7DD3FC),
          primary: const Color(0xFF0EA5E9),
          accent: const Color(0xFF06B6D4),
          isDark: true,
        );
      case AppThemeType.sunset:
        return _custom(
          bg: const Color(0xFF1F0D08),
          card: const Color(0xFF341712),
          text: const Color(0xFFFFF1E6),
          sub: const Color(0xFFFBBF24),
          primary: const Color(0xFFF97316),
          accent: const Color(0xFFEF4444),
          isDark: true,
        );
      case AppThemeType.forest:
        return _custom(
          bg: const Color(0xFF0A1F17),
          card: const Color(0xFF14312A),
          text: const Color(0xFFE6FFF5),
          sub: const Color(0xFF6EE7B7),
          primary: const Color(0xFF10B981),
          accent: const Color(0xFF059669),
          isDark: true,
        );
      case AppThemeType.rose:
        return _custom(
          bg: const Color(0xFF1F0A18),
          card: const Color(0xFF351228),
          text: const Color(0xFFFFE6F0),
          sub: const Color(0xFFF9A8D4),
          primary: const Color(0xFFEC4899),
          accent: const Color(0xFFDB2777),
          isDark: true,
        );
    }
  }

  static ThemeData dark() => _custom(
        bg: bgDark,
        card: cardDark,
        text: textDark,
        sub: subDark,
        primary: primary,
        accent: accent,
        isDark: true,
      );

  static ThemeData light() => _custom(
        bg: bgLight,
        card: cardLight,
        text: textLight,
        sub: subLight,
        primary: primary,
        accent: accent,
        isDark: false,
      );

  static ThemeData _custom({
    required Color bg,
    required Color card,
    required Color text,
    required Color sub,
    required Color primary,
    required Color accent,
    required bool isDark,
  }) {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: isDark
          ? ColorScheme.dark(primary: primary, secondary: accent, surface: card)
          : ColorScheme.light(primary: primary, secondary: accent, surface: card),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: TextStyle(
            color: text, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(color: card),
      drawerTheme: DrawerThemeData(backgroundColor: card),
      dialogTheme: DialogThemeData(backgroundColor: card),
      bottomNavigationBarTheme:
          BottomNavigationBarThemeData(backgroundColor: card),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: text),
      iconTheme: IconThemeData(color: text),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: text.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(primary),
        trackColor: WidgetStateProperty.all(primary.withValues(alpha: 0.5)),
      ),
    );
  }
}
