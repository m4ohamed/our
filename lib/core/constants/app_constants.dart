// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Our Love Story';
  static const String appVersion = '1.0.0';

  // Hive Box Names
  static const String eventsBoxName = 'timeline_events';
  static const String mediaBoxName = 'media_files';
  static const String settingsBoxName = 'app_settings';

  // Settings Keys
  static const String keyMusicEnabled = 'music_enabled';
  static const String keyMusicVolume = 'music_volume';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyAnimationsEnabled = 'animations_enabled';
  static const String keyThemeMode = 'theme_mode';
  static const String keyPinEnabled = 'pin_enabled';
  static const String keyPinHash = 'pin_hash';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyLanguage = 'language';

  // Dates
  static final DateTime coupleStartDate = DateTime(2025, 1, 31);
  static final DateTime weddingDate = DateTime(2025, 9, 17);
  static final DateTime babyExpectedDate = DateTime(2026, 8, 21);

  // Couple Info
  static const String partner1Name = 'محمد';
  static const String partner2Name = 'سارة';
  static const String coupleName = 'محمد ❤️ سارة';
  static const String babyName = 'معاذ';
  static const String weddingVenue = 'نادي المقاولون العرب';
  static const String weddingTime = '3:00 مساءً';

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 300);
  static const Duration mediumAnimation = Duration(milliseconds: 600);
  static const Duration longAnimation = Duration(milliseconds: 1000);

  // UI
  static const double cardBorderRadius = 24.0;
  static const double smallBorderRadius = 12.0;
  static const double pagePadding = 24.0;
  static const double glassOpacity = 0.65;
  static const double glassBlur = 12.0;

  // Audio Assets
  static const String romanticIntro = 'audio/romantic_intro.mp3';
  static const String loveMessage = 'audio/love_message.mp3';
  static const String weddingCelebration = 'audio/wedding_celebration.mp3';
}
