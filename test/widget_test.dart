// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:our_love_story/core/services/rust_video_bridge.dart';
import 'package:our_love_story/data/mappers/event_mapper.dart';
import 'package:our_love_story/data/mappers/media_mapper.dart';
import 'package:our_love_story/domain/entities/entities.dart';
import 'package:our_love_story/domain/entities/timeline_event_entity.dart';
import 'package:our_love_story/domain/entities/video_project_entity.dart';

void main() {
  group('Domain, Mapper & Keyframe Video Engine Tests', () {
    test('TimelineEventEntity maps to HiveModel and back accurately', () {
      final now = DateTime(2025, 9, 17);
      final entity = TimelineEventEntity(
        id: 'evt_1',
        date: now,
        title: 'الفرح',
        description: 'يوم زفافنا السعيد',
        icon: '🎉',
        location: 'نادي المقاولون العرب',
        tags: ['زفاف', 'فرح'],
        orderIndex: 1,
        createdAt: now,
        updatedAt: now,
      );

      final model = entity.toHiveModel();
      final roundTrip = model.toEntity();

      expect(roundTrip.id, equals(entity.id));
      expect(roundTrip.title, equals(entity.title));
      expect(roundTrip.location, equals(entity.location));
      expect(roundTrip.tags, equals(['زفاف', 'فرح']));
      expect(roundTrip.seasonKey, equals('autumn'));
    });

    test('MediaFileEntity maps to HiveModel and back accurately', () {
      final now = DateTime(2025, 11, 15);
      final media = MediaFileEntity(
        id: 'med_1',
        cloudinaryUrl: 'https://example.com/photo.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        localPath: '/tmp/local.jpg',
        mediaType: MediaType.photo,
        uploadDate: now,
        description: 'ذكرى جميلة',
        isFeatured: true,
        tags: ['حمل'],
      );

      final model = media.toHiveModel();
      final roundTrip = model.toEntity();

      expect(roundTrip.id, equals(media.id));
      expect(roundTrip.localPath, equals('/tmp/local.jpg'));
      expect(roundTrip.isFeatured, isTrue);
      expect(roundTrip.tags, contains('حمل'));
    });

    test('RustVideoBridge interpolates Keyframes accurately across time', () {
      const keyframes = [
        KeyframePoint(
          timestamp: 0.0,
          scale: 1.0,
          x: 0.0,
          opacity: 0.5,
          easing: KeyframeEasing.linear,
        ),
        KeyframePoint(
          timestamp: 4.0,
          scale: 2.0,
          x: 0.4,
          opacity: 1.0,
          easing: KeyframeEasing.linear,
        ),
      ];

      final mid = RustVideoBridge.instance.evaluateKeyframes(keyframes, 2.0);
      expect(mid.scale, closeTo(1.5, 0.001));
      expect(mid.x, closeTo(0.2, 0.001));
      expect(mid.opacity, closeTo(0.75, 0.001));
    });
  });
}
