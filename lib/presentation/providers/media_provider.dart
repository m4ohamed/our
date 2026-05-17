// lib/presentation/providers/media_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entities.dart';

final mediaProvider =
    AsyncNotifierProvider<MediaNotifier, List<MediaFileEntity>>(
      MediaNotifier.new,
    );

class MediaNotifier extends AsyncNotifier<List<MediaFileEntity>> {
  @override
  Future<List<MediaFileEntity>> build() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _demoMedia;
  }

  Future<void> toggleFeatured(String id) async {
    final current = state.value ?? [];
    state = AsyncData(
      current.map((m) {
        return m.id == id ? m.copyWith(isFeatured: !m.isFeatured) : m;
      }).toList(),
    );
  }

  Future<void> deleteMedia(String id) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((m) => m.id != id).toList());
  }
}

final _demoMedia = [
  MediaFileEntity(
    id: '1',
    cloudinaryUrl:
        'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=600',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=300',
    mediaType: MediaType.photo,
    uploadDate: DateTime(2025, 1, 31),
    eventId: '1',
    description: 'أول لقاء جميل 💫',
    location: 'بمنزل العروسه بالخي 12',
    aspectRatio: 0.8,
    isFeatured: true,
    fileSize: 2048576,
    fileName: 'first_meeting.jpg',
    tags: ['لقاء_أول', 'حب'],
  ),
  MediaFileEntity(
    id: '2',
    cloudinaryUrl:
        'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?w=600',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?w=300',
    mediaType: MediaType.photo,
    uploadDate: DateTime(2025, 2, 6),
    eventId: '2',
    description: 'يوم قراءة الفاتحة المبارك 🤲',
    location: 'منزل العائلة',
    aspectRatio: 1.2,
    fileSize: 1876543,
    fileName: 'fatiha_day.jpg',
  ),
  MediaFileEntity(
    id: '3',
    cloudinaryUrl:
        'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=600',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=300',
    mediaType: MediaType.photo,
    uploadDate: DateTime(2025, 2, 14),
    eventId: '3',
    description: 'خاتم الخطوبة الجميل 💍',
    location: 'محل الذهب بالاردنيه',
    aspectRatio: 0.75,
    isFeatured: true,
    fileSize: 3145728,
    fileName: 'engagement_ring.jpg',
    tags: ['شبكة', 'خاتم'],
  ),
  MediaFileEntity(
    id: '4',
    cloudinaryUrl:
        'https://images.unsplash.com/photo-1465495976277-4387d4b0e4a6?w=600',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1465495976277-4387d4b0e4a6?w=300',
    mediaType: MediaType.video,
    uploadDate: DateTime(2025, 8, 29),
    eventId: '4',
    description: 'فيديو من يوم كتب الكتاب 📝',
    location: 'مسجد التوحيد بالعاشر من رمضان',
    aspectRatio: 1.77,
    fileSize: 52428800,
    fileName: 'nikah_ceremony.mp4',
    tags: ['كتب_كتاب', 'زواج'],
  ),
  MediaFileEntity(
    id: '5',
    cloudinaryUrl:
        'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=600',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=300',
    mediaType: MediaType.photo,
    uploadDate: DateTime(2025, 9, 5),
    eventId: '5',
    description: 'ترتيب البيت الجديد 🏠',
    location: 'البيت الجديد - الحي 29',
    aspectRatio: 1.33,
    fileSize: 2621440,
    fileName: 'new_home.jpg',
  ),
  MediaFileEntity(
    id: '6',
    cloudinaryUrl:
        'https://images.unsplash.com/photo-1519741497674-611481863552?w=600',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1519741497674-611481863552?w=300',
    mediaType: MediaType.photo,
    uploadDate: DateTime(2025, 9, 17),
    eventId: '6',
    description: 'يوم الفرح السعيد 🎉',
    location: 'سيشن تصوير بنادي المقاولين العرب',
    aspectRatio: 0.67,
    isFeatured: true,
    fileSize: 4194304,
    fileName: 'wedding_day.jpg',
    tags: ['زفاف', 'فرح'],
  ),
  MediaFileEntity(
    id: '7',
    cloudinaryUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300',
    mediaType: MediaType.video,
    uploadDate: DateTime(2025, 7, 3),
    description: 'أول اعتراف بالحب 🌊',
    location: 'رأس البر',
    aspectRatio: 1.77,
    fileSize: 67108864,
    fileName: 'sea_memory.mp4',
    tags: ['سفر', 'بحر'],
  ),
];
