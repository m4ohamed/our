import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';

/// خدمة تهيئة الاتصال السحابي المباشر (Firebase & Cloud Firestore)
/// متوافقة مع مشروع Firebase الخاص بك (our-love-story-2026) وملف google-services.json
class FirebaseOnlineService {
  FirebaseOnlineService._();

  static const String keyCustomApiKey = 'fb_custom_api_key';
  static const String keyCustomProjectId = 'fb_custom_project_id';
  static const String keyCustomAppId = 'fb_custom_app_id';
  static const String keyCustomMessagingSenderId = 'fb_custom_sender_id';
  static const String keyCustomStorageBucket = 'fb_custom_storage_bucket';

  // إعدادات مشروعك الرسمي المستخرجة من ملف google-services.json الخاص بك (our-love-story-2026)
  static const FirebaseOptions fallbackFirebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyAGIFsIe5FktSreMyQQ1tCp4gD9GktBXDQ',
    projectId: 'our-love-story-2026',
    storageBucket: 'our-love-story-2026.firebasestorage.app',
    messagingSenderId: '160425672499',
    appId: '1:160425672499:android:9e47e5aac6bdba5f0e0846',
  );

  /// تهيئة Firebase وإرجاع كائن Cloud Firestore نشط وجاهز للمزامنة الفورية
  static Future<FirebaseFirestore?> initialize(SharedPreferences prefs) async {
    final customProjectId = prefs.getString(keyCustomProjectId)?.trim() ?? '';
    final customApiKey = prefs.getString(keyCustomApiKey)?.trim() ?? '';
    final customAppId = prefs.getString(keyCustomAppId)?.trim() ?? '';

    if (customProjectId.isNotEmpty &&
        customApiKey.isNotEmpty &&
        customAppId.isNotEmpty) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: customApiKey,
              projectId: customProjectId,
              appId: customAppId,
              messagingSenderId:
                  prefs.getString(keyCustomMessagingSenderId)?.trim() ??
                  '160425672499',
              storageBucket:
                  prefs.getString(keyCustomStorageBucket)?.trim() ??
                  '$customProjectId.firebasestorage.app',
            ),
          );
        }
        return _configureFirestore();
      } catch (_) {}
    }

    // المحاولة القياسية عبر DefaultFirebaseOptions المتوافقة مع جميع المنصات
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return _configureFirestore();
    } catch (_) {
      // المحاولة الاحتياطية عبر ملف إعدادات المنصة الأصلي (مثل google-services.json)
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
        return _configureFirestore();
      } catch (_) {
        // في حال فشل كل ما سبق نستخدم fallbackFirebaseOptions
        try {
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp(options: fallbackFirebaseOptions);
          }
          return _configureFirestore();
        } catch (_) {
          return null;
        }
      }
    }
  }

  static FirebaseFirestore _configureFirestore() {
    final firestore = FirebaseFirestore.instance;
    try {
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}
    return firestore;
  }
}
