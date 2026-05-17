import '../entities/timeline_event_entity.dart';
import '../entities/entities.dart';
import '../../core/errors/app_exception.dart';

abstract interface class TimelineRepository {
  /// جلب كل الأحداث
  Future<Result<List<TimelineEventEntity>>> getAllEvents();

  /// جلب حدث بالـ ID
  Future<Result<TimelineEventEntity?>> getEventById(String id);

  /// حفظ حدث جديد أو تحديث موجود
  Future<Result<TimelineEventEntity>> saveEvent(TimelineEventEntity event);

  /// حذف حدث
  Future<Result<void>> deleteEvent(String id);

  /// حذف كل الأحداث
  Future<Result<void>> deleteAllEvents();

  /// مراقبة التغييرات (stream)
  Stream<List<TimelineEventEntity>> watchEvents();
}

abstract interface class MediaRepository {
  Future<Result<List<MediaFileEntity>>> getAllMedia();
  Future<Result<MediaFileEntity?>> getMediaById(String id);
  Future<Result<MediaFileEntity>> saveMedia(MediaFileEntity media);
  Future<Result<void>> deleteMedia(String id);
  Future<Result<void>> deleteAllMedia();
  Future<Result<List<MediaFileEntity>>> getMediaByEventId(String eventId);
  Stream<List<MediaFileEntity>> watchMedia();
}

abstract interface class SettingsRepository {
  Future<AppSettingsEntity> getSettings();
  Future<void> saveSettings(AppSettingsEntity settings);
  Future<void> resetSettings();
  Stream<AppSettingsEntity> watchSettings();
}
