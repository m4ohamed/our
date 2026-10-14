// lib/core/services/firebase_online_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة تهيئة الاتصال السحابي المباشر (Firebase & Cloud Firestore)
/// تدعم القراءة التلقائية من ملف google-services.json المضاف من المستخدم،
/// كما توفر إعدادات اتصال احتياطية مدمجة لضمان عمل التطبيق أونلاين فوراً على جميع المنصات.
class FirebaseOnlineService {
  FirebaseOnlineService._();

  static const String keyCustomApiKey = 'fb_custom_api_key';
  static const String keyCustomProjectId = 'fb_custom_project_id';
  static const String keyCustomAppId = 'fb_custom_app_id';
  static const String keyCustomMessagingSenderId = 'fb_custom_sender_id';
  static const String keyCustomStorageBucket = 'fb_custom_storage_bucket';

  // إعدادات Firebase الاحتياطية المدمجة (تُستخدم تلقائياً على الويب أو في حال عدم وجود google-services.json)
  static const FirebaseOptions fallbackFirebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyDZ3eHUwVZnQHEEd7L14ANz6Mvn7Bb_Ajw',
    authDomain: 'storm1-78acf.firebaseapp.com',
    databaseURL:
        'https://storm1-78acf-default-rtdb.europe-west1.firebasedatabase.app',
    projectId: 'storm1-78acf',
    storageBucket: 'storm1-78acf.firebasestorage.app',
    messagingSenderId: '135452049816',
    appId: '1:135452049816:web:86eb398a87b54174fa6bed',
    measurementId: 'G-SJ2ZGTNVFQ',
  );

  /// تهيئة Firebase وإرجاع كائن Cloud Firestore نشط وجاهز للمزامنة الفورية
  static Future<FirebaseFirestore?> initialize(SharedPreferences prefs) async {
    // 1. إذا أدخل المستخدم إعدادات مشروع مخصصة من داخل شاشة الإعدادات، نستخدمها أولاً
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
                  '135452049816',
              storageBucket:
                  prefs.getString(keyCustomStorageBucket)?.trim() ??
                  '$customProjectId.appspot.com',
            ),
          );
        }
        return _configureFirestore();
      } catch (_) {}
    }

    // 2. المحاولة القياسية عبر ملف google-services.json الموجود في android/app/
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return _configureFirestore();
    } catch (_) {
      // 3. في حال التشغيل على الويب/سطح المكتب أو قبل نسخ google-services.json، نفعّل الخيار الاحتياطي المدمج
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
