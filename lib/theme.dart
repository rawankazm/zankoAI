import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_provider.dart';

class ZankoColors {
  static Color _primary = const Color(0xFF10B981);
  static Color _accent = const Color(0xFF10B981);
  static Color _background = const Color(0xFFF8FAFC);
  static Color _darkBackground = const Color(0xFF0F172A);
  static Color _darkCard = const Color(0xFF1E293B);
  static Color _darkCardSecondary = const Color(0xFF243044);
  static Color _gradientStart = const Color(0xFF10B981);
  static Color _gradientEnd = const Color(0xFF10B981);

  static Color get primary => _primary;
  static Color get accent => _accent;
  static Color get background => _background;
  static Color get darkBackground => _darkBackground;
  static Color get darkCard => _darkCard;
  static Color get darkCardSecondary => _darkCardSecondary;
  static Color get gradientStart => _gradientStart;
  static Color get gradientEnd => _gradientEnd;

  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  static void updatePalette(ThemeColorsData colors) {
    _primary = colors.primary;
    _accent = colors.accent;
    _background = colors.background;
    _darkBackground = colors.darkBackground;
    _darkCard = colors.darkCard;
    _darkCardSecondary = colors.darkCardSecondary;
    _gradientStart = colors.gradientColors.isNotEmpty ? colors.gradientColors.first : colors.primary;
    _gradientEnd = colors.gradientColors.length > 1 ? colors.gradientColors.last : colors.accent;
  }
}

class ZankoGradients {
  static LinearGradient get primary => LinearGradient(
    colors: [ZankoColors.gradientStart, ZankoColors.gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient get primaryVertical => LinearGradient(
    colors: [ZankoColors.gradientStart, ZankoColors.gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get darkCard => LinearGradient(
    colors: [ZankoColors.darkCard, ZankoColors.darkCardSecondary],
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
  static List<BoxShadow> get card => [
    BoxShadow(
      color: ZankoColors.primary.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get floating => [
    BoxShadow(
      color: ZankoColors.primary.withValues(alpha: 0.15),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get glow => [
    BoxShadow(
      color: ZankoColors.primary.withValues(alpha: 0.4),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> get gradientButton => [
    BoxShadow(
      color: ZankoColors.primary.withValues(alpha: 0.35),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Returns a TextStyle that uses [languageFontFamily] as primary font (defaults to DroidKufi).
TextStyle _ts({
  required double size,
  required FontWeight weight,
  required Color color,
  String? languageFontFamily,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: languageFontFamily ?? 'DroidKufi',
    fontFamilyFallback: const ['DroidKufi', 'Plus Jakarta Sans'],
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

class ThemeColorsData {
  final Color primary;
  final Color accent;
  final Color background;
  final Color card;
  final Color darkBackground;
  final Color darkCard;
  final Color darkCardSecondary;
  final Color darkTextPrimary;
  final Color darkTextSecondary;
  final List<Color> gradientColors;

  const ThemeColorsData({
    required this.primary,
    required this.accent,
    required this.background,
    required this.card,
    required this.darkBackground,
    required this.darkCard,
    required this.darkCardSecondary,
    required this.darkTextPrimary,
    required this.darkTextSecondary,
    required this.gradientColors,
  });
}

class ZankoTheme {
  static ThemeColorsData getColors(AppThemeType type) {
    switch (type) {
      case AppThemeType.royalBlue:
        return const ThemeColorsData(
          primary: Color(0xFF2563EB),
          accent: Color(0xFF38BDF8),
          background: Color(0xFFF0F7FF),
          card: Color(0xFFFFFFFF),
          darkBackground: Color(0xFF0B1120),
          darkCard: Color(0xFF151E33),
          darkCardSecondary: Color(0xFF1E293B),
          darkTextPrimary: Color(0xFFF8FAFC),
          darkTextSecondary: Color(0xFF94A3B8),
          gradientColors: [Color(0xFF2563EB), Color(0xFF0284C7)],
        );
      default:
        return const ThemeColorsData(
          primary: Color(0xFF10B981),
          accent: Color(0xFF10B981),
          background: Color(0xFFF8FAFC),
          card: Color(0xFFFFFFFF),
          darkBackground: Color(0xFF0F172A),
          darkCard: Color(0xFF1E293B),
          darkCardSecondary: Color(0xFF243044),
          darkTextPrimary: Color(0xFFF8FAFC),
          darkTextSecondary: Color(0xFF94A3B8),
          gradientColors: [Color(0xFF10B981), Color(0xFF10B981)],
        );
    }
  }

  static ThemeData getLightTheme(AppThemeType type, {String? languageFontFamily}) {
    final colors = getColors(type);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ));

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: languageFontFamily ?? 'DroidKufi',
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: colors.primary,
        onPrimary: Colors.white,
        secondary: colors.accent,
        onSecondary: Colors.white,
        error: ZankoColors.error,
        onError: Colors.white,
        surface: colors.card,
        onSurface: ZankoColors.textPrimary,
        surfaceContainerHighest: colors.background,
        onSurfaceVariant: ZankoColors.textSecondary,
      ),
      scaffoldBackgroundColor: colors.background,
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
        backgroundColor: colors.background.withValues(alpha: 0.85),
        foregroundColor: ZankoColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: _ts(size: 17, weight: FontWeight.w600, color: ZankoColors.textPrimary, languageFontFamily: languageFontFamily),
        iconTheme: const IconThemeData(color: ZankoColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZankoRadius.card)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
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
        fillColor: colors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide(color: colors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: _ts(size: 15, weight: FontWeight.w400, color: ZankoColors.textSecondary, languageFontFamily: languageFontFamily),
      ),
    );
  }

  static ThemeData getDarkTheme(AppThemeType type, {String? languageFontFamily}) {
    final colors = getColors(type);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: languageFontFamily ?? 'DroidKufi',
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: colors.primary,
        onPrimary: Colors.white,
        secondary: colors.accent,
        onSecondary: Colors.white,
        error: ZankoColors.error,
        onError: Colors.white,
        surface: colors.darkCard,
        onSurface: colors.darkTextPrimary,
        surfaceContainerHighest: colors.darkBackground,
        onSurfaceVariant: colors.darkTextSecondary,
      ),
      scaffoldBackgroundColor: colors.darkBackground,
    );

    return base.copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: colors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: _ts(size: 34, weight: FontWeight.w800, color: colors.darkTextPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.6),
        displayMedium: _ts(size: 28, weight: FontWeight.w700, color: colors.darkTextPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.4),
        titleLarge: _ts(size: 22, weight: FontWeight.w700, color: colors.darkTextPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.3),
        titleMedium: _ts(size: 17, weight: FontWeight.w600, color: colors.darkTextPrimary, languageFontFamily: languageFontFamily, letterSpacing: -0.2),
        bodyLarge: _ts(size: 17, weight: FontWeight.w400, color: colors.darkTextPrimary, languageFontFamily: languageFontFamily),
        bodyMedium: _ts(size: 15, weight: FontWeight.w400, color: colors.darkTextPrimary, languageFontFamily: languageFontFamily),
        bodySmall: _ts(size: 13, weight: FontWeight.w500, color: colors.darkTextSecondary, languageFontFamily: languageFontFamily),
        labelLarge: _ts(size: 15, weight: FontWeight.w600, color: colors.darkTextPrimary, languageFontFamily: languageFontFamily),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.darkBackground.withValues(alpha: 0.9),
        foregroundColor: colors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: _ts(size: 17, weight: FontWeight.w600, color: colors.darkTextPrimary, languageFontFamily: languageFontFamily),
        iconTheme: IconThemeData(color: colors.darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZankoRadius.card)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
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
        fillColor: colors.darkCardSecondary,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZankoRadius.input), borderSide: BorderSide(color: colors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: _ts(size: 15, weight: FontWeight.w400, color: colors.darkTextSecondary, languageFontFamily: languageFontFamily),
      ),
    );
  }
}

/// Reusable gradient button — Sunset Coral & Rose (#F97316 → #E11D48)
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
