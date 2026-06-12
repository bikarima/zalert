import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // رنگ‌های اصلی
  static const Color primary     = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF4A42CC);
  static const Color accent      = Color(0xFF00E5FF);

  // پس‌زمینه
  static const Color background  = Color(0xFF0A0A14);
  static const Color surface     = Color(0xFF13131F);
  static const Color card        = Color(0xFF1A1A2E);
  static const Color cardHover   = Color(0xFF1F1F35);

  // متن
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecond  = Color(0xFF8888AA);
  static const Color textHint    = Color(0xFF555570);

  // وضعیت
  static const Color green       = Color(0xFF00E676);
  static const Color greenDark   = Color(0xFF00C853);
  static const Color red         = Color(0xFFFF5252);
  static const Color redDark     = Color(0xFFD50000);
  static const Color orange      = Color(0xFFFFAB40);
  static const Color blue        = Color(0xFF40C4FF);

  // خطوط
  static const Color divider     = Color(0xFF1E1E30);
  static const Color border      = Color(0xFF2A2A40);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: surface,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: red),
      ),
      labelStyle: const TextStyle(color: textSecond),
      hintStyle: const TextStyle(color: textHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    dividerTheme: const DividerThemeData(color: divider, space: 1),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 8,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: textSecond,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSecond,
      indicatorColor: primary,
      dividerColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: card,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
