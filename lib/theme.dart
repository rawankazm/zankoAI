import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_provider.dart';

class ZankoColors {
  static const Color primary = Color(0xFF7C3AED);
  static const Color accent = Color(0xFFA855F7);
  static const Color background = Color(0xFFF8F8FC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF777777);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF3B30);

  // Premium iOS 18 Dark Mode Colors
  static const Color darkBackground = Color(0xFF0C0B14);
  static const Color darkCard = Color(0xFF161524);
  static const Color darkCardSecondary = Color(0xFF1E1C30);
  static const Color darkTextPrimary = Color(0xFFF8F8FC);
  static const Color darkTextSecondary = Color(0xFFA0A0B2);
}

class ZankoRadius {
  static const double card = 28.0;
  static const double button = 22.0;
  static const double input = 24.0;
  static const double floatingButton = 32.0;
  static const double smallIcon = 18.0;
}

class ZankoShadows {
  static final List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF7C3AED).withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 10),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 10,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> floating = [
    BoxShadow(
      color: const Color(0xFF7C3AED).withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> glow = [
    BoxShadow(
      color: const Color(0xFFA855F7).withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

class ZankoTheme {
  static ThemeData getLightTheme(AppThemeType type, {String? languageFontFamily}) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ));

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: languageFontFamily,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: ZankoColors.primary,
        onPrimary: Colors.white,
        secondary: ZankoColors.accent,
        onSecondary: Colors.white,
        error: ZankoColors.error,
        onError: Colors.white,
        surface: ZankoColors.card,
        onSurface: ZankoColors.textPrimary,
        surfaceContainerHighest: ZankoColors.background,
        onSurfaceVariant: ZankoColors.textSecondary,
      ),
      scaffoldBackgroundColor: ZankoColors.background,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: ZankoColors.textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: ZankoColors.textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: ZankoColors.textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: ZankoColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: ZankoColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: ZankoColors.textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ZankoColors.textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ZankoColors.textPrimary,
        ),
      ).apply(fontFamily: languageFontFamily),
      appBarTheme: AppBarTheme(
        backgroundColor: ZankoColors.background.withOpacity(0.85),
        foregroundColor: ZankoColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ZankoColors.textPrimary,
        ).copyWith(fontFamily: languageFontFamily),
        iconTheme: const IconThemeData(color: ZankoColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: ZankoColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZankoRadius.card),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZankoColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZankoRadius.button),
          ),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600).copyWith(fontFamily: languageFontFamily),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZankoColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZankoRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZankoRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZankoRadius.input),
          borderSide: const BorderSide(color: ZankoColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.inter(fontSize: 15, color: ZankoColors.textSecondary).copyWith(fontFamily: languageFontFamily),
      ),
    );
  }

  static ThemeData getDarkTheme(AppThemeType type, {String? languageFontFamily}) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: languageFontFamily,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: ZankoColors.primary,
        onPrimary: Colors.white,
        secondary: ZankoColors.accent,
        onSecondary: Colors.white,
        error: ZankoColors.error,
        onError: Colors.white,
        surface: ZankoColors.darkCard,
        onSurface: ZankoColors.darkTextPrimary,
        surfaceContainerHighest: ZankoColors.darkBackground,
        onSurfaceVariant: ZankoColors.darkTextSecondary,
      ),
      scaffoldBackgroundColor: ZankoColors.darkBackground,
    );

    return base.copyWith(
      dialogBackgroundColor: ZankoColors.darkCard,
      dialogTheme: DialogThemeData(
        backgroundColor: ZankoColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: ZankoColors.darkTextPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: ZankoColors.darkTextPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: ZankoColors.darkTextPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: ZankoColors.darkTextPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: ZankoColors.darkTextPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: ZankoColors.darkTextPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ZankoColors.darkTextSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ZankoColors.darkTextPrimary,
        ),
      ).apply(fontFamily: languageFontFamily),
      appBarTheme: AppBarTheme(
        backgroundColor: ZankoColors.darkBackground.withOpacity(0.9),
        foregroundColor: ZankoColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ZankoColors.darkTextPrimary,
        ).copyWith(fontFamily: languageFontFamily),
        iconTheme: const IconThemeData(color: ZankoColors.darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: ZankoColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZankoRadius.card),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZankoColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZankoRadius.button),
          ),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600).copyWith(fontFamily: languageFontFamily),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZankoColors.darkCardSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZankoRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZankoRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZankoRadius.input),
          borderSide: const BorderSide(color: ZankoColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.inter(fontSize: 15, color: ZankoColors.darkTextSecondary).copyWith(fontFamily: languageFontFamily),
      ),
    );
  }
}
