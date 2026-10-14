// lib/data/repositories/hive_timeline_repository.dart
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/timeline_event_entity.dart';
import '../../domain/repositories/repositories.dart';
import '../mappers/event_mapper.dart';
import '../models/timeline_event_hive_model.dart';
import '../seeds/demo_events_seed.dart';

class HiveTimelineRepository implements TimelineRepository {
  final Box<TimelineEventHiveModel> _box;
  final SharedPreferences _prefs;
  final _streamController =
      StreamController<List<TimelineEventEntity>>.broadcast();

  HiveTimelineRepository(this._box, this._prefs) {
    _box.watch().listen((_) => _emit());
  }

  void _emit() {
    final events = _box.values.map((m) => m.toEntity()).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    _streamController.add(events);
  }

  @override
  Future<Result<List<TimelineEventEntity>>> getAllEvents() async {
    try {
      await _seedDemoEvents();

      final events = _box.values.map((m) => m.toEntity()).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      return Success(events);
    } catch (e) {
      return Failure(StorageException('فشل تحميل الأحداث: $e'));
    }
  }

  @override
  Future<Result<TimelineEventEntity?>> getEventById(String id) async {
    try {
      final model = _box.get(id);
      return Success(model?.toEntity());
    } catch (e) {
      return Failure(StorageException('فشل جلب الحدث: $e'));
    }
  }

  @override
  Future<Result<TimelineEventEntity>> saveEvent(
    TimelineEventEntity event,
  ) async {
    try {
      final now = DateTime.now();
      final isNew = !_box.containsKey(event.id);

      final eventToSave = isNew
          ? event.copyWith(createdAt: now, updatedAt: now)
          : event.copyWith(updatedAt: now);

      await _box.put(eventToSave.id, eventToSave.toHiveModel());
      return Success(eventToSave);
    } catch (e) {
      return Failure(StorageException('فشل حفظ الحدث: $e'));
    }
  }

  @override
  Future<Result<void>> deleteEvent(String id) async {
    try {
      final existing = _box.get(id);
      if (existing != null && existing.isDemo) {
        // منع إعادة زرع البيانات التجريبية بعد قيام المستخدم بحذف حدث تجريبي
        await _prefs.setBool(AppConstants.keyDemoEventsSeeded, true);
      }
      await _box.delete(id);
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل حذف الحدث: $e'));
    }
  }

  @override
  Future<Result<void>> deleteAllEvents() async {
    try {
      await _box.clear();
      await _prefs.setBool(AppConstants.keyDemoEventsSeeded, true);
      await _prefs.setBool(AppConstants.keyEnableDemoData, false);
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل مسح الأحداث: $e'));
    }
  }

  @override
  Stream<List<TimelineEventEntity>> watchEvents() => _streamController.stream;

  Future<void> _seedDemoEvents() async {
    final enableDemoData =
        _prefs.getBool(AppConstants.keyEnableDemoData) ?? true;
    final alreadySeeded =
        _prefs.getBool(AppConstants.keyDemoEventsSeeded) ?? false;
    if (!enableDemoData || alreadySeeded) return;

    if (_box.isEmpty) {
      final now = DateTime.now();
      for (final seed in DemoEventsSeed.events) {
        final demoId = 'demo_${seed.orderIndex}_${seed.title.hashCode}';
        final event = TimelineEventEntity(
          id: demoId,
          date: seed.date,
          title: seed.title,
          description: seed.description,
          icon: seed.icon,
          imageUrl: seed.imageUrl,
          orderIndex: seed.orderIndex,
          location: seed.location,
          tags: seed.tags,
          isDemo: true,
          createdAt: now,
          updatedAt: now,
        );
        await _box.put(demoId, event.toHiveModel());
      }
    }
    await _prefs.setBool(AppConstants.keyDemoEventsSeeded, true);
  }

  void dispose() {
    _streamController.close();
  }
}
