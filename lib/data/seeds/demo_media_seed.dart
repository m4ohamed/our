// lib/data/seeds/demo_media_seed.dart
import '../../domain/entities/entities.dart';

class DemoMediaSeed {
  DemoMediaSeed._();

  static final List<MediaFileEntity> items = [
    MediaFileEntity(
      id: 'demo_1',
      cloudinaryUrl:
          'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=1080',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=300',
      mediaType: MediaType.photo,
      uploadDate: DateTime(2025, 1, 31),
      description: 'أول لقاء جمع بيننا ورسم بداية حكايتنا 💫',
      isFeatured: true,
      location: 'منزل العائلة بالحي 12',
      aspectRatio: 1.0,
      tags: ['لقاء_أول', 'حب', 'بداية'],
    ),
    MediaFileEntity(
      id: 'demo_2',
      cloudinaryUrl:
          'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?w=1080',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?w=300',
      mediaType: MediaType.photo,
      uploadDate: DateTime(2025, 2, 6),
      description: 'يوم قراءة الفاتحة المبارك 🤲',
      isFeatured: false,
      location: 'منزل العائلة بالحي 12',
      aspectRatio: 1.33,
      tags: ['فاتحة', 'خطوبة', 'أهل'],
    ),
    MediaFileEntity(
      id: 'demo_3',
      cloudinaryUrl:
          'https://images.unsplash.com/photo-1515934751635-c81c6bc9a2d8?w=1080',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1515934751635-c81c6bc9a2d8?w=300',
      mediaType: MediaType.photo,
      uploadDate: DateTime(2025, 2, 14),
      description: 'لبس الشبكة في يوم الحب 💍',
      isFeatured: true,
      location: 'محل الذهب بالأردنية',
      aspectRatio: 1.0,
      tags: ['شبكة', 'حب', 'ذهب'],
    ),
    MediaFileEntity(
      id: 'demo_4',
      cloudinaryUrl:
          'https://images.unsplash.com/photo-1519741497674-611481863552?w=1080',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1519741497674-611481863552?w=300',
      mediaType: MediaType.photo,
      uploadDate: DateTime(2025, 9, 17),
      description: 'ليلة العمر وزفافنا الأسطوري 🎉',
      isFeatured: true,
      location: 'نادي المقاولون العرب',
      aspectRatio: 1.5,
      tags: ['زفاف', 'فرح', 'ليلة_العمر'],
    ),
  ];
}
