// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Light — Rose & Amethyst Romance
  static const Color pearlWhite = Color(0xFFFFF7F9);
  static const Color dustyRose = Color(0xFFF43F5E);
  static const Color primaryRoseDark = Color(0xFFE11D48);
  static const Color dustyRoseSoft = Color(0xFFFFE4E6);
  static const Color champagneGold = Color(0xFFF59E0B);
  static const Color champagneGoldSoft = Color(0xFFFEF3C7);
  static const Color surfaceRose = Color(0xFFFDF2F8);
  static const Color deepMauve = Color(0xFF9333EA);
  static const Color secondaryPurpleLight = Color(0xFFA855F7);
  static const Color secondaryPurpleDark = Color(0xFF7E22CE);
  static const Color deepMauveSoft = Color(0xFFF3E8FF);
  static const Color darkText = Color(0xFF1F2937);
  static const Color lightText = Color(0xFF6B7280);
  static const Color softTaupe = Color(0xFF9CA3AF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Dark — Velvet Night Mode (وضع السهرة الليلي الدافئ)
  static const Color darkBg = Color(0xFF13091C);
  static const Color darkSurface = Color(0xFF1E102A);
  static const Color darkCard = Color(0xFF2D193F);
  static const Color darkSubtle = Color(0xFF39204F);
  static const Color darkRoseAccent = Color(0xFFFB7185);
  static const Color darkPurpleAccent = Color(0xFFC084FC);
  static const Color darkText2 = Color(0xFFFDF2F8);
  static const Color darkLightText = Color(0xFFCBD5E1);

  // Studio Dark Surfaces
  static const Color studioCanvasBg = Color(0xFF14080A);
  static const Color studioClipBg1 = Color(0xFF7D5C7E);
  static const Color studioClipBg2 = Color(0xFF2A1215);

  // Semantic Colors
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color pinkVibrant = Color(0xFFEC4899);
  static const Color shadow = Color(0x26F43F5E);

  // Wheel & Studio Palette
  static const List<Color> wheelPalette = [
    dustyRose,
    deepMauve,
    pinkVibrant,
    infoBlue,
    success,
    champagneGold,
    white,
    black,
  ];

  // Legacy aliases for backward compatibility
  static const Color primaryPink = dustyRose;
  static const Color lightPink = surfaceRose;
  static const Color secondaryPurple = deepMauve;
  static const Color goldAccent = champagneGold;
}

class AppTheme {
  AppTheme._();

  // ─── Semantic Dynamic Theme Helpers (تمنع استخدام أي ألوان ثابتة في الشاشات) ───

  static Color transparent(BuildContext context) =>
      Theme.of(context).colorScheme.surface.withValues(alpha: 0);

  static Color successColor(BuildContext context) => AppColors.success;

  static Color warningColor(BuildContext context) => AppColors.warning;

  static Color errorColor(BuildContext context) =>
      Theme.of(context).colorScheme.error;

  static Color cardSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkCard : AppColors.white;
  }

  static Color subtleSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkSubtle : AppColors.surfaceRose;
  }

  static List<Color> pageGradientColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const [
            AppColors.darkBg,
            AppColors.darkSurface,
            AppColors.darkCard,
          ]
        : const [
            AppColors.dustyRoseSoft,
            AppColors.surfaceRose,
            AppColors.deepMauveSoft,
          ];
  }

  static List<Color> confettiPalette(BuildContext context) => const [
    AppColors.dustyRose,
    AppColors.deepMauve,
    AppColors.success,
    AppColors.champagneGold,
    AppColors.pinkVibrant,
  ];

  static List<Color> speedPadGradient({required bool isSecondPartner}) =>
      isSecondPartner
          ? const [AppColors.secondaryPurpleLight, AppColors.secondaryPurpleDark]
          : const [AppColors.dustyRose, AppColors.primaryRoseDark];

  static List<Color> studioCardGradient(int cardColorValue) => [
    Color(cardColorValue),
    AppColors.studioClipBg1,
    AppColors.studioClipBg2,
  ];

  static List<Color> studioPalette() => AppColors.wheelPalette;

  static Color fromCode(int code) => Color(code);

  // Centralized integer color codes for serializable models (RewardWheelItem, SpeedEvents)
  static const int rewardRoseCode = 0xFFF43F5E;
  static const int rewardPurpleCode = 0xFF9333EA;
  static const int rewardPinkCode = 0xFFEC4899;
  static const int rewardBlueCode = 0xFF3B82F6;
  static const int rewardGreenCode = 0xFF10B981;
  static const int rewardAmberCode = 0xFFF59E0B;
  static const int dangerRedCode = 0xFFEF4444;

  static const List<int> rewardColorCodes = [
    rewardRoseCode,
    rewardPurpleCode,
    rewardGreenCode,
    rewardBlueCode,
    rewardAmberCode,
    rewardPinkCode,
  ];

  static const Color white = AppColors.white;
  static const Color black = AppColors.black;
  static const Color transparentColor = Color(0x00000000);
  static const Color primaryRose = AppColors.dustyRose;
  static const Color primaryRoseDark = AppColors.primaryRoseDark;
  static const Color secondaryPurple = AppColors.deepMauve;
  static const Color secondaryPurpleLight = AppColors.secondaryPurpleLight;
  static const Color secondaryPurpleDark = AppColors.secondaryPurpleDark;
  static const Color emeraldGreen = AppColors.success;
  static const Color amberGold = AppColors.warning;
  static const Color dangerRed = AppColors.error;
  static const Color studioCanvasBg = AppColors.studioCanvasBg;
  static const Color studioClipBg1 = AppColors.studioClipBg1;
  static const Color studioClipBg2 = AppColors.studioClipBg2;

  // ─── Light & Dark ThemeData ────────────────────────────────────────────────

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      surface: AppColors.pearlWhite,
      onSurface: AppColors.darkText,
      surfaceContainerHighest: AppColors.surfaceRose,
      primary: AppColors.dustyRose,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.dustyRoseSoft,
      onPrimaryContainer: AppColors.darkText,
      secondary: AppColors.champagneGold,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.champagneGoldSoft,
      onSecondaryContainer: AppColors.darkText,
      tertiary: AppColors.deepMauve,
      onTertiary: AppColors.white,
      tertiaryContainer: AppColors.deepMauveSoft,
      onTertiaryContainer: AppColors.darkText,
      outline: AppColors.lightText,
      error: AppColors.error,
      onError: AppColors.white,
      scrim: AppColors.black,
      shadow: AppColors.shadow,
    ),
    scaffoldBackgroundColor: AppColors.pearlWhite,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.pearlWhite.withValues(alpha: 0),
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
        color: AppColors.white,
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
      primaryContainer: AppColors.darkCard,
      onPrimaryContainer: AppColors.darkText2,
      secondary: AppColors.champagneGold,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.darkSubtle,
      onSecondaryContainer: AppColors.darkText2,
      tertiary: AppColors.darkPurpleAccent,
      onTertiary: AppColors.white,
      tertiaryContainer: AppColors.darkSubtle,
      onTertiaryContainer: AppColors.darkText2,
      outline: AppColors.darkLightText,
      error: AppColors.error,
      onError: AppColors.white,
      scrim: AppColors.black,
      shadow: AppColors.black,
    ),
    scaffoldBackgroundColor: AppColors.darkBg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBg.withValues(alpha: 0),
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
        color: AppColors.white,
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
