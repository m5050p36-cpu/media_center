import 'package:flutter/material.dart';

class AppTheme {
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

  // ─── Aliases للتوافق مع الكود الحالي ───
  static const Color bg = bgDark;
  static const Color card = cardDark;
  static const Color text = textDark;
  static const Color sub = subDark;

  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: bgDark,
        primaryColor: primary,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: accent,
          surface: cardDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: textDark),
          titleTextStyle: TextStyle(
              color: textDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        cardTheme: const CardThemeData(color: cardDark),
        drawerTheme: const DrawerThemeData(backgroundColor: cardDark),
        dialogTheme: const DialogThemeData(backgroundColor: cardDark),
        bottomNavigationBarTheme:
            const BottomNavigationBarThemeData(backgroundColor: cardDark),
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
          fillColor: cardDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        listTileTheme: const ListTileThemeData(iconColor: textDark),
        iconTheme: const IconThemeData(color: textDark),
      );

  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: bgLight,
        primaryColor: primary,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: accent,
          surface: cardLight,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgLight,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: textLight),
          titleTextStyle: TextStyle(
              color: textLight, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        cardTheme: const CardThemeData(color: cardLight),
        drawerTheme: const DrawerThemeData(backgroundColor: cardLight),
        dialogTheme: const DialogThemeData(backgroundColor: cardLight),
        bottomNavigationBarTheme:
            const BottomNavigationBarThemeData(backgroundColor: cardLight),
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
          fillColor: cardLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        listTileTheme: const ListTileThemeData(iconColor: textLight),
        iconTheme: const IconThemeData(color: textLight),
      );
}
