import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  AppTheme._();

  // ── رنگ‌های مشترک ─────────────────────────────────────────────────
  static const Color primary     = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF4A42CC);
  static const Color accent      = Color(0xFF00E5FF);
  static const Color green       = Color(0xFF00E676);
  static const Color greenDark   = Color(0xFF00C853);
  static const Color red         = Color(0xFFFF5252);
  static const Color orange      = Color(0xFFFFAB40);
  static const Color blue        = Color(0xFF40C4FF);

  // ── Dark Colors ────────────────────────────────────────────────────
  static const Color darkBg      = Color(0xFF0A0A14);
  static const Color darkSurface = Color(0xFF13131F);
  static const Color darkCard    = Color(0xFF1A1A2E);
  static const Color darkBorder  = Color(0xFF2A2A40);
  static const Color darkDivider = Color(0xFF1E1E30);
  static const Color darkText    = Color(0xFFFFFFFF);
  static const Color darkTextSec = Color(0xFF8888AA);
  static const Color darkTextHint= Color(0xFF555570);

  // ── Light Colors ───────────────────────────────────────────────────
  static const Color lightBg      = Color(0xFFF5F5FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard    = Color(0xFFFFFFFF);
  static const Color lightBorder  = Color(0xFFE0E0F0);
  static const Color lightDivider = Color(0xFFEEEEF8);
  static const Color lightText    = Color(0xFF1A1A2E);
  static const Color lightTextSec = Color(0xFF666688);
  static const Color lightTextHint= Color(0xFFAAAAAA);

  // ── helper: از context میگیره ─────────────────────────────────────
  static Color bg(BuildContext ctx)       => _d(ctx) ? darkBg       : lightBg;
  static Color surface(BuildContext ctx)  => _d(ctx) ? darkSurface  : lightSurface;
  static Color card(BuildContext ctx)     => _d(ctx) ? darkCard      : lightCard;
  static Color border(BuildContext ctx)   => _d(ctx) ? darkBorder    : lightBorder;
  static Color divider(BuildContext ctx)  => _d(ctx) ? darkDivider   : lightDivider;
  static Color text(BuildContext ctx)     => _d(ctx) ? darkText      : lightText;
  static Color textSec(BuildContext ctx)  => _d(ctx) ? darkTextSec   : lightTextSec;
  static Color textHint(BuildContext ctx) => _d(ctx) ? darkTextHint  : lightTextHint;

  static bool _d(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  // ── backward compat (برای کدهای قدیمی که context ندارن) ─────────
  static const Color background  = darkBg;
  static const Color surface_    = darkSurface;
  static const Color card_       = darkCard;
  static const Color border_     = darkBorder;
  static const Color divider_    = darkDivider;
  static const Color textPrimary = darkText;
  static const Color textSecond  = darkTextSec;
  static const Color textHint_   = darkTextHint;

  // ── Dark Theme ─────────────────────────────────────────────────────
  static ThemeData get dark => _build(Brightness.dark);

  // ── Light Theme ────────────────────────────────────────────────────
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg      = isDark ? darkBg      : lightBg;
    final surface = isDark ? darkSurface : lightSurface;
    final cardC   = isDark ? darkCard    : lightCard;
    final borderC = isDark ? darkBorder  : lightBorder;
    final textC   = isDark ? darkText    : lightText;
    final textSec = isDark ? darkTextSec : lightTextSec;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        secondary: accent,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textC,
        error: red,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textC,
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: textC),
      ),
      cardTheme: CardThemeData(
        color: cardC,
        elevation: isDark ? 0 : 2,
        shadowColor: isDark ? Colors.transparent : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: borderC, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: borderC),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: borderC),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: red),
        ),
        labelStyle: TextStyle(color: textSec, fontSize: 13.sp),
        hintStyle: TextStyle(
            color: isDark ? darkTextHint : lightTextHint, fontSize: 13.sp),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 50.h),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r)),
          elevation: 0,
          textStyle: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      dividerTheme: DividerThemeData(
          color: isDark ? darkDivider : lightDivider, space: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardC,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardC,
        contentTextStyle: TextStyle(color: textC, fontSize: 13.sp),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r)),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : null),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? primary.withOpacity(0.4)
                : null),
      ),
    );
  }
}
