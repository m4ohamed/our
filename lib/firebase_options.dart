// File generated for our-love-story-2026 Firebase project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAGIFsIe5FktSreMyQQ1tCp4gD9GktBXDQ',
    appId: '1:160425672499:web:9e47e5aac6bdba5f0e0846',
    messagingSenderId: '160425672499',
    projectId: 'our-love-story-2026',
    authDomain: 'our-love-story-2026.firebaseapp.com',
    storageBucket: 'our-love-story-2026.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGIFsIe5FktSreMyQQ1tCp4gD9GktBXDQ',
    appId: '1:160425672499:android:9e47e5aac6bdba5f0e0846',
    messagingSenderId: '160425672499',
    projectId: 'our-love-story-2026',
    storageBucket: 'our-love-story-2026.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGIFsIe5FktSreMyQQ1tCp4gD9GktBXDQ',
    appId: '1:160425672499:ios:9e47e5aac6bdba5f0e0846',
    messagingSenderId: '160425672499',
    projectId: 'our-love-story-2026',
    storageBucket: 'our-love-story-2026.firebasestorage.app',
    iosBundleId: 'com.our.loveStory',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAGIFsIe5FktSreMyQQ1tCp4gD9GktBXDQ',
    appId: '1:160425672499:ios:9e47e5aac6bdba5f0e0846',
    messagingSenderId: '160425672499',
    projectId: 'our-love-story-2026',
    storageBucket: 'our-love-story-2026.firebasestorage.app',
    iosBundleId: 'com.our.loveStory',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAGIFsIe5FktSreMyQQ1tCp4gD9GktBXDQ',
    appId: '1:160425672499:web:9e47e5aac6bdba5f0e0846',
    messagingSenderId: '160425672499',
    projectId: 'our-love-story-2026',
    authDomain: 'our-love-story-2026.firebaseapp.com',
    storageBucket: 'our-love-story-2026.firebasestorage.app',
  );
}
