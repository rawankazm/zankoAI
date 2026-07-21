import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_provider.dart';

class ZankoTheme {
  // ─── Apple-inspired Color Palette ───────────────────────────────────────────
  static const Color _appleBlue       = Color(0xFF007AFF);
  static const Color _appleIndigo     = Color(0xFF5856D6);
  static const Color _applePurple     = Color(0xFFAF52DE);
  static const Color _appleGreen      = Color(0xFF34C759);
  static const Color _appleGold       = Color(0xFFFF9500);
  static const Color _applePink       = Color(0xFFFF2D55);

  static const Color _lightBg         = Color(0xFFF2F2F7);
  static const Color _lightSurface    = Color(0xFFFFFFFF);
  static const Color _lightLabel      = Color(0xFF000000);
  static const Color _lightSecLabel   = Color(0xFF8E8E93);

  static const Color _darkBg          = Color(0xFF000000);
  static const Color _darkSurface     = Color(0xFF1C1C1E);
  static const Color _darkSurface2    = Color(0xFF2C2C2E);
  static const Color _darkLabel       = Color(0xFFFFFFFF);

  static Color getPrimaryColor(AppThemeType type) {
    switch (type) {
      case AppThemeType.blueGlass:      return _appleBlue;
      case AppThemeType.emeraldForest:  return _appleGreen;
      case AppThemeType.sunsetViolet:   return _appleIndigo;
      case AppThemeType.midnightGold:   return _appleGold;
    }
  }

  static Color getAccentColor(AppThemeType type) {
    switch (type) {
      case AppThemeType.blueGlass:      return _appleIndigo;
      case AppThemeType.emeraldForest:  return _appleBlue;
      case AppThemeType.sunsetViolet:   return _applePurple;
      case AppThemeType.midnightGold:   return _applePink;
    }
  }

  // ─── Light Theme ─────────────────────────────────────────────────────────────
  static ThemeData getLightTheme(AppThemeType type) {
    final primary = getPrimaryColor(type);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ));

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: getAccentColor(type),
        onSecondary: Colors.white,
        error: _applePink,
        onError: Colors.white,
        surface: _lightSurface,
        onSurface: _lightLabel,
        surfaceContainerHighest: _lightBg,
        onSurfaceVariant: _lightSecLabel,
      ),
      scaffoldBackgroundColor: _lightBg,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:  GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: _lightLabel),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: _lightLabel),
        titleLarge:    GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: _lightLabel),
        titleMedium:   GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: _lightLabel),
        bodyLarge:     GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w400, color: _lightLabel),
        bodyMedium:    GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: _lightLabel),
        bodySmall:     GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: _lightSecLabel),
        labelLarge:    GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _lightLabel),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightSurface.withOpacity(0.92),
        foregroundColor: primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: _lightLabel,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: primary),
        actionsIconTheme: IconThemeData(color: primary),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(fontSize: 15, color: _lightSecLabel),
        hintStyle: GoogleFonts.inter(fontSize: 15, color: _lightSecLabel),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: _lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E5EA),
        thickness: 0.5,
        space: 0,
        indent: 16,
        endIndent: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primary : const Color(0xFFE5E5EA)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightSurface.withOpacity(0.95),
        selectedItemColor: primary,
        unselectedItemColor: _lightSecLabel,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF323232),
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightBg,
        selectedColor: primary.withOpacity(0.15),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 24,
      ),
    );
  }

  // ─── Dark Theme ───────────────────────────────────────────────────────────────
  static ThemeData getDarkTheme(AppThemeType type) {
    final primary = getPrimaryColor(type);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    final bg      = type == AppThemeType.midnightGold ? const Color(0xFF0D0D0D) : _darkBg;
    final surface = type == AppThemeType.midnightGold ? const Color(0xFF1A1A1A) : _darkSurface;
    final surface2= type == AppThemeType.midnightGold ? const Color(0xFF252525) : _darkSurface2;

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: type == AppThemeType.midnightGold ? Colors.black : Colors.white,
        secondary: getAccentColor(type),
        onSecondary: Colors.white,
        error: _applePink,
        onError: Colors.white,
        surface: surface,
        onSurface: _darkLabel,
        surfaceContainerHighest: surface2,
        onSurfaceVariant: const Color(0xFF8E8E93),
      ),
      scaffoldBackgroundColor: bg,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:  GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: _darkLabel),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: _darkLabel),
        titleLarge:    GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: _darkLabel),
        titleMedium:   GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: _darkLabel),
        bodyLarge:     GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w400, color: _darkLabel),
        bodyMedium:    GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: _darkLabel),
        bodySmall:     GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: const Color(0xFF8E8E93)),
        labelLarge:    GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _darkLabel),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withOpacity(0.92),
        foregroundColor: primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: _darkLabel,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: primary),
        actionsIconTheme: IconThemeData(color: primary),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: type == AppThemeType.midnightGold ? Colors.black : Colors.white,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF8E8E93)),
        hintStyle: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF8E8E93)),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.08),
        thickness: 0.5,
        space: 0,
        indent: 16,
        endIndent: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primary : const Color(0xFF3A3A3C)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface.withOpacity(0.95),
        selectedItemColor: primary,
        unselectedItemColor: const Color(0xFF8E8E93),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: type == AppThemeType.midnightGold ? Colors.black : Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        selectedColor: primary.withOpacity(0.25),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _darkLabel),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
    );
  }
}
