import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_provider.dart';
import '../../../theme.dart';

class ZankoColors {
  static const Color primary = Color(0xFF0EA5E9);
  static const Color accent = Color(0xFF38BDF8);
  static const Color background = Color(0xFFF0F8FF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF3B30);

  // Ocean Blue Dark Mode Colors
  static const Color darkBackground = Color(0xFF0A0F1E);
  static const Color darkCard = Color(0xFF0F1D35);
  static const Color darkCardSecondary = Color(0xFF162236);
  static const Color darkTextPrimary = Color(0xFFF0F8FF);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Gradient colors
  static const Color gradientStart = Color(0xFF0EA5E9);
  static const Color gradientEnd = Color(0xFF6366F1);
}

class ZankoGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [ZankoColors.gradientStart, ZankoColors.gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryVertical = LinearGradient(
    colors: [ZankoColors.gradientStart, ZankoColors.gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCard = LinearGradient(
    colors: [Color(0xFF0F1D35), Color(0xFF162236)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
      color: const Color(0xFF0EA5E9).withOpacity(0.10),
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
      color: const Color(0xFF0EA5E9).withOpacity(0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> glow = [
    BoxShadow(
      color: const Color(0xFF38BDF8).withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> gradientButton = [
    BoxShadow(
      color: const Color(0xFF0EA5E9).withOpacity(0.4),
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];
}

/// Returns a TextStyle that uses [languageFontFamily] as primary font
/// and Plus Jakarta Sans as the Latin fallback.
TextStyle _ts({
  required double size,
  required FontWeight weight,
  required Color color,
  String? languageFontFamily,
  double? letterSpacing,
}) {
  if (languageFontFamily != null) {
    // Kurdish / Arabic: use native font, PJS as fallback for Latin chars
    return TextStyle(
      fontFamily: languageFontFamily,
      fontFamilyFallback: ['Plus Jakarta Sans'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
  // English: use Plus Jakarta Sans
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
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
      fontFamily: languageFontFamily ?? GoogleFonts.plusJakartaSans().fontFamily,
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
      textTheme: base.textTheme.copyWith(
        displayLarge: _ts(size: 34, weight: FontWeight.w800, color: ZankoColors.textPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.6),
        displayMedium: _ts(size: 28, weight: FontWeight.w700, color: ZankoColors.textPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.4),
        titleLarge: _ts(size: 22, weight: FontWeight.w700, color: ZankoColors.textPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.3),
        titleMedium: _ts(size: 17, weight: FontWeight.w600, color: ZankoColors.textPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.2),
        bodyLarge: _ts(size: 17, weight: FontWeight.w400, color: ZankoColors.textPrimary, languageFontFamily: languageFontFamily),
        bodyMedium: _ts(size: 15, weight: FontWeight.w400, color: ZankoColors.textPrimary, languageFontFamily: languageFontFamily),
        bodySmall: _ts(size: 13, weight: FontWeight.w500, color: ZankoColors.textSecondary, languageFontFamily: languageFontFamily),
        labelLarge: _ts(size: 15, weight: FontWeight.w600, color: ZankoColors.textPrimary, languageFontFamily: languageFontFamily),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ZankoColors.background.withOpacity(0.85),
        foregroundColor: ZankoColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: _ts(size: 17, weight: FontWeight.w600, color: ZankoColors.textPrimary, languageFontFamily: languageFontFamily),
        iconTheme: const IconThemeData(color: ZankoColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: ZankoColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZankoRadius.card)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZankoColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZankoRadius.button)),
          textStyle: _ts(size: 16, weight: FontWeight.w700, color: Colors.white, languageFontFamily: languageFontFamily),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZankoColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: const BorderSide(color: ZankoColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: _ts(size: 15, weight: FontWeight.w400, color: ZankoColors.textSecondary, languageFontFamily: languageFontFamily),
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
      fontFamily: languageFontFamily ?? GoogleFonts.plusJakartaSans().fontFamily,
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
      textTheme: base.textTheme.copyWith(
        displayLarge: _ts(size: 34, weight: FontWeight.w800, color: ZankoColors.darkTextPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.6),
        displayMedium: _ts(size: 28, weight: FontWeight.w700, color: ZankoColors.darkTextPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.4),
        titleLarge: _ts(size: 22, weight: FontWeight.w700, color: ZankoColors.darkTextPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.3),
        titleMedium: _ts(size: 17, weight: FontWeight.w600, color: ZankoColors.darkTextPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.2),
        bodyLarge: _ts(size: 17, weight: FontWeight.w400, color: ZankoColors.darkTextPrimary, languageFontFamily: languageFontFamily),
        bodyMedium: _ts(size: 15, weight: FontWeight.w400, color: ZankoColors.darkTextPrimary, languageFontFamily: languageFontFamily),
        bodySmall: _ts(size: 13, weight: FontWeight.w500, color: ZankoColors.darkTextSecondary, languageFontFamily: languageFontFamily),
        labelLarge: _ts(size: 15, weight: FontWeight.w600, color: ZankoColors.darkTextPrimary, languageFontFamily: languageFontFamily),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ZankoColors.darkBackground.withOpacity(0.9),
        foregroundColor: ZankoColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: _ts(size: 17, weight: FontWeight.w600, color: ZankoColors.darkTextPrimary, languageFontFamily: languageFontFamily),
        iconTheme: const IconThemeData(color: ZankoColors.darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: ZankoColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZankoRadius.card)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZankoColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZankoRadius.button)),
          textStyle: _ts(size: 16, weight: FontWeight.w700, color: Colors.white, languageFontFamily: languageFontFamily),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZankoColors.darkCardSecondary,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: const BorderSide(color: ZankoColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: _ts(size: 15, weight: FontWeight.w400, color: ZankoColors.darkTextSecondary, languageFontFamily: languageFontFamily),
      ),
    );
  }
}

/// Reusable gradient button — Ocean Blue (#0EA5E9 → #6366F1)
class ZankoGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double borderRadius;

  const ZankoGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 52,
    this.borderRadius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed != null ? ZankoGradients.primary : const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF94A3B8)]),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: onPressed != null ? ZankoShadows.gradientButton : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
