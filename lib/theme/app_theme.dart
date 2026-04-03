import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Ethereal Romance Palette
  static const Color pearlWhite = Color(0xFFFDFCFB);
  static const Color dustyRose = Color(0xFFF1878E);
  static const Color champagneGold = Color(0xFFE1B162);
  static const Color surfaceRose = Color(0xFFFCEFEF);
  static const Color deepMauve = Color(0xFF7D5C7E);
  static const Color darkText = Color(0xFF331012);
  static const Color lightText = Color(0xFF663A3B);
  static const Color softTaupe = Color(0xFFA68E8E);
  static const Color white = Color(0xFFFFFFFF);

  // Legacy mappings for compatibility (can be removed later)
  static const Color primaryPink = dustyRose;
  static const Color lightPink = surfaceRose;
  static const Color secondaryPurple = deepMauve;
  static const Color goldAccent = champagneGold;
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.dustyRose,
      surface: AppColors.pearlWhite,
      primary: AppColors.dustyRose,
      secondary: AppColors.champagneGold,
      tertiary: AppColors.deepMauve,
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
    textTheme: TextTheme(
      displayLarge: GoogleFonts.dancingScript(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: AppColors.dustyRose,
      ),
      headlineLarge: GoogleFonts.notoSerif(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
      ),
      headlineMedium: GoogleFonts.notoSerif(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        color: AppColors.darkText,
        letterSpacing: 0.2,
      ),
      bodyMedium: GoogleFonts.manrope(fontSize: 14, color: AppColors.lightText),
      labelLarge: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppColors.dustyRose,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
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
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.white.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
