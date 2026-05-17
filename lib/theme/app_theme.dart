// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Light — Ethereal Romance
  static const Color pearlWhite = Color(0xFFFDFCFB);
  static const Color dustyRose = Color(0xFFF1878E);
  static const Color champagneGold = Color(0xFFE1B162);
  static const Color surfaceRose = Color(0xFFFCEFEF);
  static const Color deepMauve = Color(0xFF7D5C7E);
  static const Color darkText = Color(0xFF331012);
  static const Color lightText = Color(0xFF663A3B);
  static const Color softTaupe = Color(0xFFA68E8E);
  static const Color white = Color(0xFFFFFFFF);

  // Dark — Midnight Romance
  static const Color darkBg = Color(0xFF1A0A0B);
  static const Color darkSurface = Color(0xFF2A1215);
  static const Color darkCard = Color(0xFF3D1A1E);
  static const Color darkText2 = Color(0xFFF5E6E8);
  static const Color darkLightText = Color(0xFFD4A0A5);

  // Semantic Colors
  static const Color error = Color(0xFFE57373);
  static const Color success = Color(0xFF81C784);
  static const Color warning = Color(0xFFFFB74D);
  static const Color shadow = Color(0x42000000); // black26

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
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.dustyRose,
      brightness: Brightness.light,
      surface: AppColors.pearlWhite,
      onSurface: AppColors.darkText,
      surfaceContainerHighest: AppColors.surfaceRose,
      primary: AppColors.dustyRose,
      onPrimary: AppColors.white,
      secondary: AppColors.champagneGold,
      onSecondary: AppColors.white,
      tertiary: AppColors.deepMauve,
      onTertiary: AppColors.white,
      outline: AppColors.softTaupe,
    ),
    scaffoldBackgroundColor: AppColors.pearlWhite,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.darkText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.notoSerif(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
      ),
    ),
    textTheme: _buildTextTheme(AppColors.darkText, AppColors.lightText),
    elevatedButtonTheme: _elevatedButtonTheme,
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.white.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: _inputDecorationTheme(AppColors.dustyRose),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    iconTheme: const IconThemeData(color: AppColors.dustyRose),
    dividerTheme: DividerThemeData(
      color: AppColors.softTaupe.withValues(alpha: 0.2),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.dustyRose,
      brightness: Brightness.dark,
      surface: AppColors.darkBg,
      onSurface: AppColors.darkText2,
      surfaceContainerHighest: AppColors.darkSurface,
      primary: AppColors.dustyRose,
      onPrimary: AppColors.white,
      secondary: AppColors.champagneGold,
      onSecondary: AppColors.white,
      tertiary: AppColors.deepMauve,
      onTertiary: AppColors.white,
      outline: AppColors.darkLightText,
    ),
    scaffoldBackgroundColor: AppColors.darkBg,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.darkText2,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.notoSerif(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText2,
      ),
    ),
    textTheme: _buildTextTheme(AppColors.darkText2, AppColors.darkLightText),
    elevatedButtonTheme: _elevatedButtonTheme,
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.darkCard.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: _inputDecorationTheme(AppColors.dustyRose),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    iconTheme: const IconThemeData(color: AppColors.dustyRose),
    dividerTheme: DividerThemeData(
      color: AppColors.darkLightText.withValues(alpha: 0.2),
    ),
  );

  static TextTheme _buildTextTheme(Color primary, Color secondary) => TextTheme(
    displayLarge: GoogleFonts.dancingScript(
      fontSize: 48,
      fontWeight: FontWeight.bold,
      color: AppColors.dustyRose,
    ),
    headlineLarge: GoogleFonts.notoSerif(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: primary,
    ),
    headlineMedium: GoogleFonts.notoSerif(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    bodyLarge: GoogleFonts.manrope(
      fontSize: 16,
      color: primary,
      letterSpacing: 0.2,
    ),
    bodyMedium: GoogleFonts.manrope(fontSize: 14, color: secondary),
    bodySmall: GoogleFonts.manrope(fontSize: 12, color: secondary),
    labelLarge: GoogleFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
      color: AppColors.dustyRose,
    ),
  );

  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dustyRose,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );

  static InputDecorationTheme _inputDecorationTheme(Color accent) =>
      InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: accent.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: accent),
        prefixIconColor: accent,
      );
}
