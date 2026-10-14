// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Light — Rose & Amethyst Romance (متناسق مع ثنائي المحبة V2.0)
  static const Color pearlWhite = Color(0xFFFFF7F9);
  static const Color dustyRose = Color(0xFFF43F5E);
  static const Color champagneGold = Color(0xFFF59E0B);
  static const Color surfaceRose = Color(0xFFFDF2F8);
  static const Color deepMauve = Color(0xFF9333EA);
  static const Color darkText = Color(0xFF1F2937);
  static const Color lightText = Color(0xFF6B7280);
  static const Color softTaupe = Color(0xFF9CA3AF);
  static const Color white = Color(0xFFFFFFFF);

  // Dark — Velvet Night Mode (وضع السهرة الليلي الدافئ)
  static const Color darkBg = Color(0xFF13091C);
  static const Color darkSurface = Color(0xFF1E102A);
  static const Color darkCard = Color(0xFF2D193F);
  static const Color darkRoseAccent = Color(0xFFFB7185);
  static const Color darkPurpleAccent = Color(0xFFC084FC);
  static const Color darkText2 = Color(0xFFFDF2F8);
  static const Color darkLightText = Color(0xFFCBD5E1);

  // Semantic Colors
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color shadow = Color(0x26F43F5E);

  // Legacy aliases for backward compatibility
  static const Color primaryPink = dustyRose;
  static const Color lightPink = surfaceRose;
  static const Color secondaryPurple = deepMauve;
  static const Color goldAccent = champagneGold;
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      surface: AppColors.pearlWhite,
      onSurface: AppColors.darkText,
      surfaceContainerHighest: AppColors.surfaceRose,
      primary: AppColors.dustyRose,
      onPrimary: AppColors.white,
      secondary: AppColors.champagneGold,
      onSecondary: AppColors.white,
      tertiary: AppColors.deepMauve,
      onTertiary: AppColors.white,
      outline: AppColors.lightText,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.pearlWhite,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.darkText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppColors.darkText,
      ),
    ),
    textTheme: _buildTextTheme(
      AppColors.darkText,
      AppColors.lightText,
      AppColors.dustyRose,
    ),
    elevatedButtonTheme: _elevatedButtonTheme(AppColors.dustyRose),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.white.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppColors.dustyRose.withValues(alpha: 0.18)),
      ),
    ),
    inputDecorationTheme: _inputDecorationTheme(
      accent: AppColors.dustyRose,
      fillColor: AppColors.surfaceRose,
      textColor: AppColors.darkText,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkText,
      contentTextStyle: GoogleFonts.cairo(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    iconTheme: const IconThemeData(color: AppColors.dustyRose),
    dividerTheme: DividerThemeData(
      color: AppColors.dustyRose.withValues(alpha: 0.14),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.darkBg,
      onSurface: AppColors.darkText2,
      surfaceContainerHighest: AppColors.darkSurface,
      primary: AppColors.darkRoseAccent,
      onPrimary: AppColors.white,
      secondary: AppColors.champagneGold,
      onSecondary: AppColors.white,
      tertiary: AppColors.darkPurpleAccent,
      onTertiary: AppColors.white,
      outline: AppColors.darkLightText,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.darkBg,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.darkText2,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppColors.darkText2,
      ),
    ),
    textTheme: _buildTextTheme(
      AppColors.darkText2,
      AppColors.darkLightText,
      AppColors.darkRoseAccent,
    ),
    elevatedButtonTheme: _elevatedButtonTheme(AppColors.dustyRose),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.darkCard.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: AppColors.darkRoseAccent.withValues(alpha: 0.28),
        ),
      ),
    ),
    inputDecorationTheme: _inputDecorationTheme(
      accent: AppColors.darkRoseAccent,
      fillColor: AppColors.darkSurface,
      textColor: AppColors.darkText2,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkCard,
      contentTextStyle: GoogleFonts.cairo(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    iconTheme: const IconThemeData(color: AppColors.darkRoseAccent),
    dividerTheme: DividerThemeData(
      color: AppColors.darkRoseAccent.withValues(alpha: 0.2),
    ),
  );

  static TextTheme _buildTextTheme(
    Color primary,
    Color secondary,
    Color accent,
  ) => TextTheme(
    displayLarge: GoogleFonts.cairo(
      fontSize: 40,
      fontWeight: FontWeight.w900,
      color: accent,
    ),
    headlineLarge: GoogleFonts.cairo(
      fontSize: 28,
      fontWeight: FontWeight.w900,
      color: primary,
    ),
    headlineMedium: GoogleFonts.cairo(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: primary,
    ),
    titleLarge: GoogleFonts.cairo(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: primary,
    ),
    bodyLarge: GoogleFonts.cairo(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    bodyMedium: GoogleFonts.cairo(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: secondary,
    ),
    bodySmall: GoogleFonts.cairo(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: secondary,
    ),
    labelLarge: GoogleFonts.cairo(
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
      color: accent,
    ),
  );

  static ElevatedButtonThemeData _elevatedButtonTheme(Color accent) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: AppColors.white,
          elevation: 2,
          shadowColor: accent.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  static InputDecorationTheme _inputDecorationTheme({
    required Color accent,
    required Color fillColor,
    required Color textColor,
  }) => InputDecorationTheme(
    filled: true,
    fillColor: fillColor,
    hintStyle: GoogleFonts.cairo(
      color: textColor.withValues(alpha: 0.55),
      fontSize: 13,
    ),
    labelStyle: GoogleFonts.cairo(
      color: accent,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accent.withValues(alpha: 0.22)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accent.withValues(alpha: 0.25), width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accent, width: 1.8),
    ),
    prefixIconColor: accent,
  );
}
