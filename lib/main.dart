// lib/main.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'generated/l10n.dart';
import 'core/constants/app_constants.dart';
import 'core/services/firebase_online_service.dart';
import 'core/services/onesignal_service.dart';
import 'data/models/media_file_hive_model.dart';
import 'data/models/timeline_event_hive_model.dart';
import 'domain/entities/entities.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/splash_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعداد اتجاه الشاشة
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // تهيئة Hive (الكاش المحلي للعمل دون إنترنت والمزامنة التلقائية)
  await Hive.initFlutter();
  Hive.registerAdapter(TimelineEventHiveModelAdapter());
  Hive.registerAdapter(MediaFileHiveModelAdapter());
  await Hive.openBox<TimelineEventHiveModel>(AppConstants.eventsBoxName);
  await Hive.openBox<MediaFileHiveModel>(AppConstants.mediaBoxName);

  // تهيئة SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // تهيئة الاتصال السحابي المباشر (يقرأ google-services.json تلقائياً مع fallback أونلاين مضمون)
  final firestore = await FirebaseOnlineService.initialize(prefs);

  // تهيئة إشعارات OneSignal وتسجيل حالة الاتصال أونلاين
  final oneSignal = OneSignalService(prefs, firestore);
  unawaited(oneSignal.initAndRegisterDevice());

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreInstanceProvider.overrideWithValue(firestore),
      ],
      child: const OurLoveStoryApp(),
    ),
  );
}

class OurLoveStoryApp extends ConsumerStatefulWidget {
  const OurLoveStoryApp({super.key});

  @override
  ConsumerState<OurLoveStoryApp> createState() => _OurLoveStoryAppState();
}

class _OurLoveStoryAppState extends ConsumerState<OurLoveStoryApp>
    with WidgetsBindingObserver {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  final int _appStartTimeMs = DateTime.now().millisecondsSinceEpoch;
  final Set<String> _shownNotifIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToRealtimePartnerNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final oneSignal = ref.read(oneSignalServiceProvider);
    if (state == AppLifecycleState.resumed) {
      oneSignal.updateOnlinePresence(isOnline: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      oneSignal.updateOnlinePresence(isOnline: false);
    }
  }

  void _listenToRealtimePartnerNotifications() {
    final firestore = ref.read(firestoreInstanceProvider);
    if (firestore == null) return;

    _notifSub = firestore
        .collection(AppConstants.firestoreNotificationsCollection)
        .orderBy('createdAtMs', descending: true)
        .limit(5)
        .snapshots()
        .listen((snap) {
          final myRole = ref.read(myPartnerRoleProvider);
          final notificationsEnabled = ref.read(isNotificationsEnabledProvider);
          if (!notificationsEnabled) return;

          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final doc = change.doc;
            if (_shownNotifIds.contains(doc.id)) continue;

            final data = doc.data();
            if (data == null) continue;
            final createdAtMs = (data['createdAtMs'] as num?)?.toInt() ?? 0;
            final senderRole = (data['senderRole'] as String?) ?? '';

            // نعرض فقط الإشعارات الجديدة المرسلة من الشريك الآخر بعد فتح التطبيق
            if (createdAtMs < _appStartTimeMs || senderRole == myRole) continue;

            _shownNotifIds.add(doc.id);
            final title = (data['title'] as String?) ?? 'إشعار جديد 💕';
            final message = (data['message'] as String?) ?? '';

            if (!mounted) return;

            HapticFeedback.mediumImpact();
            rootScaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 4),
                content: Row(
                  children: [
                    const Text('🔔', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.cairo(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                          if (message.isNotEmpty)
                            Text(
                              message,
                              style: GoogleFonts.cairo(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: S.delegate.supportedLocales,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode == AppThemeMode.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
