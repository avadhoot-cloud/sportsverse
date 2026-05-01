import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Elite Curator Design System Theme Extension
class EliteTheme extends ThemeExtension<EliteTheme> {
  // Core Colors
  final Color primary;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerLowest;
  final Color accent;
  final Color royalAccent;
  
  // State Colors
  final Color disabledBackground;
  final Color disabledText;
  final Color errorBackground;
  final Color errorBorder;
  final Color errorText;

  // Typography
  final TextStyle display1;
  final TextStyle display2;
  final TextStyle headline;
  final TextStyle subhead;
  final TextStyle body;
  final TextStyle caption;

  // Spacing & Layout
  final double gridUnit = 8.0;
  final double mobileMargin = 24.0;
  final double desktopMargin = 48.0;
  final double maxContentWidth = 840.0;
  final double cardRadius = 32.0;
  final double cardPadding = 24.0;

  const EliteTheme({
    required this.primary,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerLowest,
    required this.accent,
    required this.royalAccent,
    required this.disabledBackground,
    required this.disabledText,
    required this.errorBackground,
    required this.errorBorder,
    required this.errorText,
    required this.display1,
    required this.display2,
    required this.headline,
    required this.subhead,
    required this.body,
    required this.caption,
  });

  // Missing properties added for backward compatibility with older screens
  Color get error => errorText;
  Color get secondaryText => disabledText; // Or another appropriate color
  Color get text => primary;
  TextStyle get heading => headline;
  TextStyle get subtitle => subhead;

  /// The standard, locked-down Elite Curator Theme
  factory EliteTheme.standard() {
    return EliteTheme(
      primary: const Color(0xFF001F3F), // Deep Navy
      surface: const Color(0xFFF9F9FE), // Base Canvas
      surfaceContainer: const Color(0xFFEDEDF2), // Cool Grey
      surfaceContainerLowest: const Color(0xFFFFFFFF), // Pure White Cards
      accent: const Color(0xFFD2F000), // Lime
      royalAccent: const Color(0xFFC5A059), // Elegant Soft Gold
      disabledBackground: const Color(0xFFE2E2E7),
      disabledText: const Color(0xFF94A3B8),
      errorBackground: const Color(0xFFFFF5F5),
      errorBorder: const Color(0xFFFFCDD2),
      errorText: const Color(0xFFDC2626), // High-intensity Red
      
      display1: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w900, // Black
        color: const Color(0xFF001F3F),
        letterSpacing: -0.04 * 32, // -0.04em
      ),
      display2: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w800, // ExtraBold
        color: const Color(0xFF001F3F),
        letterSpacing: -0.02 * 24, // -0.02em
      ),
      headline: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700, // Bold
        color: const Color(0xFF001F3F),
        letterSpacing: -0.01 * 18, // -0.01em
      ),
      subhead: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600, // Semibold
        color: const Color(0xFF001F3F),
        letterSpacing: 0.05 * 14, // +0.05em
      ),
      body: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400, // Regular
        color: const Color(0xFF001F3F),
        height: 1.6,
      ),
      caption: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500, // Medium
        color: const Color(0xFF001F3F),
        letterSpacing: 0.05 * 12, // +0.05em
      ),
    );
  }

  @override
  ThemeExtension<EliteTheme> copyWith() {
    // We do not intend for the theme to be dynamically mutated for now.
    return this;
  }

  @override
  ThemeExtension<EliteTheme> lerp(ThemeExtension<EliteTheme>? other, double t) {
    if (other is! EliteTheme) return this;
    return EliteTheme(
      primary: Color.lerp(primary, other.primary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerLowest: Color.lerp(surfaceContainerLowest, other.surfaceContainerLowest, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      royalAccent: Color.lerp(royalAccent, other.royalAccent, t)!,
      disabledBackground: Color.lerp(disabledBackground, other.disabledBackground, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      errorBackground: Color.lerp(errorBackground, other.errorBackground, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      display1: TextStyle.lerp(display1, other.display1, t)!,
      display2: TextStyle.lerp(display2, other.display2, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      subhead: TextStyle.lerp(subhead, other.subhead, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
    );
  }

  /// Convenience getter for the theme in the build context
  static EliteTheme of(BuildContext context) {
    return Theme.of(context).extension<EliteTheme>() ?? EliteTheme.standard();
  }
}

/// A helper class to get standard global ThemeData based on EliteTheme
class EliteThemeData {
  static ThemeData getThemeData() {
    final elite = EliteTheme.standard();
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: elite.surface,
      primaryColor: elite.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: elite.primary,
        surface: elite.surface,
        primary: elite.primary,
        secondary: elite.accent,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      extensions: [elite],
      
      // Override default material styling to prevent it from leaking through
      appBarTheme: AppBarTheme(
        backgroundColor: elite.surface,
        foregroundColor: elite.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: elite.display2,
      ),
      
      // We will build custom buttons, but we kill default padding/elevation here just in case
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
    );
  }
}
