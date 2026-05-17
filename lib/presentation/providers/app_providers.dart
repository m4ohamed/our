// lib/presentation/providers/app_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/timeline_event_hive_model.dart';
import '../../data/repositories/hive_timeline_repository.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/timeline_event_entity.dart';
import '../../domain/repositories/repositories.dart';

// ─── Infrastructure Providers ────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final hiveEventsBoxProvider = Provider<Box<TimelineEventHiveModel>>((ref) {
  return Hive.box<TimelineEventHiveModel>(AppConstants.eventsBoxName);
});

// ─── Repository Providers ─────────────────────────────────────────────────────

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  final box = ref.watch(hiveEventsBoxProvider);
  final repo = HiveTimelineRepository(box);
  ref.onDispose(repo.dispose);
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

class TimelineNotifier extends AsyncNotifier<List<TimelineEventEntity>> {
  @override
  Future<List<TimelineEventEntity>> build() async {
    final repo = ref.watch(timelineRepositoryProvider);

    await repo.getAllEvents();

    repo.watchEvents().listen((events) {
      if (state.hasValue) {
        state = AsyncData(events);
      }
    });

    final result = await repo.getAllEvents();
    return result.when(success: (events) => events, failure: (e) => throw e);
  }

  Future<void> addEvent(TimelineEventEntity event) async {
    final repo = ref.read(timelineRepositoryProvider);
    final result = await repo.saveEvent(event);
    result.when(
      success: (_) => _refresh(),
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
    final result = await repo.getAllEvents();
    state = result.when(
      success: (events) => AsyncData(events),
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
