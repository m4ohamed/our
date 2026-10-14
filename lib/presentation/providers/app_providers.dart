// lib/presentation/providers/app_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/services/onesignal_service.dart';
import '../../data/models/media_file_hive_model.dart';
import '../../data/models/timeline_event_hive_model.dart';
import '../../data/repositories/firestore_media_repository.dart';
import '../../data/repositories/firestore_timeline_repository.dart';
import '../../data/repositories/hive_media_repository.dart';
import '../../data/repositories/hive_timeline_repository.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/timeline_event_entity.dart';
import '../../domain/repositories/repositories.dart';

// ─── Infrastructure Providers ────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final firestoreInstanceProvider = Provider<FirebaseFirestore?>((ref) {
  return null;
});

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CloudinaryService(prefs);
});

final oneSignalServiceProvider = Provider<OneSignalService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final firestore = ref.watch(firestoreInstanceProvider);
  return OneSignalService(prefs, firestore);
});

/// مزود لهوية الشريك على هذا الجهاز ('p1' = محمد | 'p2' = سارة)
class MyPartnerRoleNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(AppConstants.keyMyPartnerRole) ?? 'p1';
  }

  Future<void> setRole(String role) async {
    state = role;
    await ref.read(oneSignalServiceProvider).setMyRole(role);
  }
}

final myPartnerRoleProvider = NotifierProvider<MyPartnerRoleNotifier, String>(
  MyPartnerRoleNotifier.new,
);

/// تدفق مباشر لحالة اتصال الشريك ونقاط التناغم من Cloud Firestore
final coupleOnlineDocStreamProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
      final firestore = ref.watch(firestoreInstanceProvider);
      if (firestore == null) return Stream.value(null);
      return firestore
          .collection(AppConstants.firestoreCoupleDoc)
          .doc('main_couple')
          .snapshots()
          .map((snap) => snap.data());
    });

final hiveEventsBoxProvider = Provider<Box<TimelineEventHiveModel>>((ref) {
  return Hive.box<TimelineEventHiveModel>(AppConstants.eventsBoxName);
});

final hiveMediaBoxProvider = Provider<Box<MediaFileHiveModel>>((ref) {
  return Hive.box<MediaFileHiveModel>(AppConstants.mediaBoxName);
});

// ─── Repository Providers (Cloud Firestore + Cloudinary + Hive Cache) ────────

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  final box = ref.watch(hiveEventsBoxProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final firestore = ref.watch(firestoreInstanceProvider);
  final cloudinary = ref.watch(cloudinaryServiceProvider);

  final localCache = HiveTimelineRepository(box, prefs);
  final repo = FirestoreTimelineRepository(
    firestore: firestore,
    localCache: localCache,
    cloudinary: cloudinary,
  );
  ref.onDispose(() {
    repo.dispose();
    localCache.dispose();
  });
  return repo;
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final box = ref.watch(hiveMediaBoxProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final firestore = ref.watch(firestoreInstanceProvider);
  final cloudinary = ref.watch(cloudinaryServiceProvider);

  final localCache = HiveMediaRepository(box, prefs);
  final repo = FirestoreMediaRepository(
    firestore: firestore,
    localCache: localCache,
    cloudinary: cloudinary,
  );
  ref.onDispose(() {
    repo.dispose();
    localCache.dispose();
  });
  return repo;
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = SharedPrefsSettingsRepository(prefs);
  ref.onDispose(repo.dispose);
  return repo;
});

// ─── Settings Provider ────────────────────────────────────────────────────────

class SettingsNotifier extends AsyncNotifier<AppSettingsEntity> {
  @override
  Future<AppSettingsEntity> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getSettings();
  }

  Future<void> saveSettings(AppSettingsEntity settings) async {
    state = const AsyncLoading();
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveSettings(settings);
    state = AsyncData(settings);
  }

  Future<void> toggleMusic() async {
    final current = state.value;
    if (current == null) return;
    await saveSettings(current.copyWith(musicEnabled: !current.musicEnabled));
  }

  Future<void> setMusicVolume(double volume) async {
    final current = state.value;
    if (current == null) return;
    await saveSettings(current.copyWith(musicVolume: volume));
  }

  Future<void> toggleNotifications() async {
    final current = state.value;
    if (current == null) return;
    await saveSettings(
      current.copyWith(notificationsEnabled: !current.notificationsEnabled),
    );
  }

  Future<void> toggleAnimations() async {
    final current = state.value;
    if (current == null) return;
    await saveSettings(
      current.copyWith(animationsEnabled: !current.animationsEnabled),
    );
  }

  Future<void> toggleBiometric() async {
    final current = state.value;
    if (current == null) return;
    await saveSettings(
      current.copyWith(biometricEnabled: !current.biometricEnabled),
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final current = state.value;
    if (current == null) return;
    await saveSettings(current.copyWith(themeMode: mode));
  }

  Future<void> setLanguage(String language) async {
    final current = state.value;
    if (current == null) return;
    await saveSettings(current.copyWith(language: language));
  }

  Future<void> reset() async {
    state = const AsyncLoading();
    final repo = ref.read(settingsRepositoryProvider);
    await repo.resetSettings();
    state = const AsyncData(AppSettingsEntity.defaults);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettingsEntity>(
      SettingsNotifier.new,
    );

// Convenience selectors
final isMusicEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).value?.musicEnabled ?? true;
});

final musicVolumeProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).value?.musicVolume ?? 0.7;
});

final isNotificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).value?.notificationsEnabled ?? true;
});

final isAnimationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).value?.animationsEnabled ?? true;
});

final themeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(settingsProvider).value?.themeMode ?? AppThemeMode.light;
});

final localeProvider = Provider<Locale>((ref) {
  final lang = ref.watch(settingsProvider).value?.language ?? 'ar';
  return Locale(lang);
});

// ─── Timeline Providers ───────────────────────────────────────────────────────

class TimelineSortNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final timelineSortAscendingProvider =
    NotifierProvider<TimelineSortNotifier, bool>(TimelineSortNotifier.new);

class TimelineNotifier extends AsyncNotifier<List<TimelineEventEntity>> {
  @override
  Future<List<TimelineEventEntity>> build() async {
    final repo = ref.watch(timelineRepositoryProvider);
    final isAscending = ref.watch(timelineSortAscendingProvider);

    final sub = repo.watchEvents().listen((events) {
      if (state.hasValue) {
        final sorted = [...events]
          ..sort(
            (a, b) =>
                isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
          );
        state = AsyncData(sorted);
      }
    });
    ref.onDispose(sub.cancel);

    final result = await repo.getAllEvents();
    return result.when(
      success: (events) {
        final sorted = [...events]
          ..sort(
            (a, b) =>
                isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
          );
        return sorted;
      },
      failure: (e) => throw e,
    );
  }

  Future<void> addEvent(TimelineEventEntity event) async {
    final repo = ref.read(timelineRepositoryProvider);
    final result = await repo.saveEvent(event);
    result.when(
      success: (_) {
        _refresh();
        final oneSignal = ref.read(oneSignalServiceProvider);
        oneSignal.sendNotificationToPartner(
          title: 'ذكرى جديدة في قصتنا 💕',
          message: 'أضاف ${oneSignal.myName} حدثاً جديداً: "${event.title}" ${event.icon}',
          category: 'timeline',
        );
      },
      failure: (e) => state = AsyncError(e, StackTrace.current),
    );
  }

  Future<void> updateEvent(TimelineEventEntity event) async {
    final repo = ref.read(timelineRepositoryProvider);
    final result = await repo.saveEvent(event);
    result.when(
      success: (_) => _refresh(),
      failure: (e) => state = AsyncError(e, StackTrace.current),
    );
  }

  Future<void> deleteEvent(String id) async {
    final repo = ref.read(timelineRepositoryProvider);
    final result = await repo.deleteEvent(id);
    result.when(
      success: (_) => _refresh(),
      failure: (e) => state = AsyncError(e, StackTrace.current),
    );
  }

  Future<void> deleteAll() async {
    final repo = ref.read(timelineRepositoryProvider);
    await repo.deleteAllEvents();
    state = const AsyncData([]);
  }

  Future<void> _refresh() async {
    final repo = ref.read(timelineRepositoryProvider);
    final isAscending = ref.read(timelineSortAscendingProvider);
    final result = await repo.getAllEvents();
    state = result.when(
      success: (events) {
        final sorted = [...events]
          ..sort(
            (a, b) =>
                isAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
          );
        return AsyncData(sorted);
      },
      failure: (e) => AsyncError(e, StackTrace.current),
    );
  }
}

final timelineProvider =
    AsyncNotifierProvider<TimelineNotifier, List<TimelineEventEntity>>(
      TimelineNotifier.new,
    );

final daysTogetherProvider = Provider<int>((ref) {
  return DateTime.now().difference(AppConstants.coupleStartDate).inDays;
});

final countdownProvider = Provider<Duration>((ref) {
  final now = DateTime.now();
  final diff = AppConstants.weddingDate.difference(now);
  return diff.isNegative ? Duration.zero : diff;
});

final isWeddingPastProvider = Provider<bool>((ref) {
  return DateTime.now().isAfter(AppConstants.weddingDate);
});

final nextMilestoneReminderProvider = Provider<TimelineEventEntity?>((ref) {
  final isEnabled = ref.watch(isNotificationsEnabledProvider);
  if (!isEnabled) return null;

  final events = ref.watch(timelineProvider).value ?? [];
  if (events.isEmpty) return null;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  TimelineEventEntity? closest;
  int minDays = 999999;

  for (final e in events) {
    var nextOccurrence = DateTime(today.year, e.date.month, e.date.day);
    if (nextOccurrence.isBefore(today)) {
      nextOccurrence = DateTime(today.year + 1, e.date.month, e.date.day);
    }
    final diff = nextOccurrence.difference(today).inDays;
    if (diff < minDays) {
      minDays = diff;
      closest = e;
    }
  }
  return closest;
});
