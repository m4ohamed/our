// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Our Love Story';
  static const String appVersion = '2.0.0';

  // Firestore Collection Names
  static const String firestoreEventsCollection = 'timeline_events';
  static const String firestoreMediaCollection = 'media_files';
  static const String firestoreSurpriseCollection = 'surprise_messages';
  static const String firestoreCoupleDoc = 'couple_shared_state';
  static const String firestoreRoomsCollection = 'couples_rooms_v2';
  static const String firestoreCouponsCollection = 'love_coupons';
  static const String firestoreNotificationsCollection = 'couple_notifications';

  // Cloudinary Configuration (Unsigned Upload - Free Tier without Credit Card)
  static const String defaultCloudinaryCloudName = '';
  static const String defaultCloudinaryUploadPreset = 'our_love_story_unsigned';
  static const String cloudinaryFolder = 'our_love_story';

  // OneSignal Push Notifications Configuration
  static const String defaultOneSignalAppId = '';
  static const String defaultOneSignalRestApiKey = '';

  // Hive Box Names (Offline Cache)
  static const String eventsBoxName = 'timeline_events';
  static const String mediaBoxName = 'media_files';
  static const String settingsBoxName = 'app_settings';

  // Settings & State Keys
  static const String keyMusicEnabled = 'music_enabled';
  static const String keyMusicVolume = 'music_volume';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyAnimationsEnabled = 'animations_enabled';
  static const String keyThemeMode = 'theme_mode';
  static const String keyPinEnabled = 'pin_enabled';
  static const String keyPinHash = 'pin_hash';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyLanguage = 'language';
  static const String keyDemoEventsSeeded = 'demo_events_seeded';
  static const String keyDemoMediaSeeded = 'demo_media_seeded';
  static const String keyCustomSurpriseMessages = 'custom_surprise_messages';
  static const String keySavedSurpriseMessages = 'saved_surprise_messages';
  static const String keyCloudinaryCloudName = 'cloudinary_cloud_name';
  static const String keyCloudinaryUploadPreset = 'cloudinary_upload_preset';
  static const String keyOneSignalAppId = 'onesignal_app_id';
  static const String keyOneSignalRestApiKey = 'onesignal_rest_api_key';
  static const String keyMyPartnerRole = 'my_partner_role'; // 'p1' (محمد) or 'p2' (سارة)
  static const String keyCouplesNightState = 'couples_night_v2_state';
  static const String keyLoveCoupons = 'love_coupons_list';

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
  static const double glassOpacity = 0.88;
  static const double glassBlur = 14.0;

  // Audio Assets
  static const String romanticIntro = 'audio/romantic_intro.mp3';
  static const String loveMessage = 'audio/love_message.mp3';
  static const String weddingCelebration = 'audio/wedding_celebration.mp3';
}
