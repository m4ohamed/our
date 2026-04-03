enum MediaType { photo, video }

class MediaFile {
  final int id;
  final String cloudinaryUrl;
  final String thumbnailUrl;
  final MediaType mediaType;
  final DateTime uploadDate;
  final int? eventId;
  final String? description;
  final bool isFeatured;
  final String? location;
  final double aspectRatio;
  final int? fileSize; // بالبايت
  final String? fileName;
  final List<String>? tags;

  MediaFile({
    required this.id,
    required this.cloudinaryUrl,
    required this.thumbnailUrl,
    required this.mediaType,
    required this.uploadDate,
    this.eventId,
    this.description,
    this.isFeatured = false,
    this.location,
    this.aspectRatio = 1.0,
    this.fileSize,
    this.fileName,
    this.tags,
  });

  // إنشاء نسخة محدثة من الملف
  MediaFile copyWith({
    int? id,
    String? cloudinaryUrl,
    String? thumbnailUrl,
    MediaType? mediaType,
    DateTime? uploadDate,
    int? eventId,
    String? description,
    bool? isFeatured,
    String? location,
    double? aspectRatio,
    int? fileSize,
    String? fileName,
    List<String>? tags,
  }) {
    return MediaFile(
      id: id ?? this.id,
      cloudinaryUrl: cloudinaryUrl ?? this.cloudinaryUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaType: mediaType ?? this.mediaType,
      uploadDate: uploadDate ?? this.uploadDate,
      eventId: eventId ?? this.eventId,
      description: description ?? this.description,
      isFeatured: isFeatured ?? this.isFeatured,
      location: location ?? this.location,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      fileSize: fileSize ?? this.fileSize,
      fileName: fileName ?? this.fileName,
      tags: tags ?? this.tags,
    );
  }

  // تحويل إلى Map للحفظ في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cloudinary_url': cloudinaryUrl,
      'thumbnail_url': thumbnailUrl,
      'media_type': mediaType.toString().split('.').last,
      'upload_date': uploadDate.toIso8601String(),
      'event_id': eventId,
      'description': description,
      'is_featured': isFeatured ? 1 : 0,
      'location': location,
      'aspect_ratio': aspectRatio,
      'file_size': fileSize,
      'file_name': fileName,
      'tags': tags?.join(','),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // إنشاء MediaFile من Map
  factory MediaFile.fromMap(Map<String, dynamic> map) {
    return MediaFile(
      id: map['id'] ?? 0,
      cloudinaryUrl: map['cloudinary_url'] ?? '',
      thumbnailUrl: map['thumbnail_url'] ?? '',
      mediaType: map['media_type'] == 'video'
          ? MediaType.video
          : MediaType.photo,
      uploadDate: DateTime.parse(map['upload_date']),
      eventId: map['event_id'],
      description: map['description'],
      isFeatured: (map['is_featured'] ?? 0) == 1,
      location: map['location'],
      aspectRatio: (map['aspect_ratio'] ?? 1.0).toDouble(),
      fileSize: map['file_size'],
      fileName: map['file_name'],
      tags: map['tags']?.toString().split(','),
    );
  }

  // تحويل إلى JSON
  Map<String, dynamic> toJson() => toMap();

  // إنشاء من JSON
  factory MediaFile.fromJson(Map<String, dynamic> json) =>
      MediaFile.fromMap(json);

  // للطباعة والتصحيح
  @override
  String toString() {
    return 'MediaFile{id: $id, type: $mediaType, description: $description}';
  }

  // للمقارنة
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaFile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // حجم الملف بصيغة قابلة للقراءة
  String get formattedFileSize {
    if (fileSize == null) return 'غير محدد';

    if (fileSize! < 1024) {
      return '$fileSize B';
    } else if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // نوع الملف بالعربية
  String get mediaTypeArabic {
    switch (mediaType) {
      case MediaType.photo:
        return 'صورة';
      case MediaType.video:
        return 'فيديو';
    }
  }

  // تحديد ما إذا كان الملف جديد (خلال 7 أيام)
  bool get isRecent {
    return DateTime.now().difference(uploadDate).inDays <= 7;
  }

  // الحصول على البيانات التجريبية
  static List<MediaFile> getDemoMediaFiles() {
    return [
      MediaFile(
        id: 1,
        cloudinaryUrl:
            'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=600',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=300',
        mediaType: MediaType.photo,
        uploadDate: DateTime(2025, 1, 31),
        eventId: 1,
        description: 'أول لقاء جميل - بداية قصة الحب 💫',
        location: 'بمنزل العروسه بالخي 12',
        aspectRatio: 0.8,
        isFeatured: true,
        fileSize: 2048576, // 2MB
        fileName: 'first_meeting.jpg',
        tags: ['لقاء_أول', 'حب', 'ذكريات'],
      ),
      MediaFile(
        id: 2,
        cloudinaryUrl:
            'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?w=600',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1469371670807-013ccf25f16a?w=300',
        mediaType: MediaType.photo,
        uploadDate: DateTime(2025, 2, 6),
        eventId: 2,
        description: 'يوم قراءة الفاتحة المبارك 🤲',
        location: 'منزل العائلة',
        aspectRatio: 1.2,
        fileSize: 1876543,
        fileName: 'fatiha_day.jpg',
        tags: ['فاتحة', 'خطوبة', 'أهل'],
      ),
      MediaFile(
        id: 3,
        cloudinaryUrl:
            'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=600',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=300',
        mediaType: MediaType.photo,
        uploadDate: DateTime(2025, 2, 14),
        eventId: 3,
        description: 'خاتم الخطوبة الجميل 💍',
        location: 'محل الذهب بالاردنيه',
        aspectRatio: 0.75,
        isFeatured: true,
        fileSize: 3145728, // 3MB
        fileName: 'engagement_ring.jpg',
        tags: ['شبكة', 'عيد_الحب', 'خاتم'],
      ),
      MediaFile(
        id: 4,
        cloudinaryUrl:
            'https://images.unsplash.com/photo-1465495976277-4387d4b0e4a6?w=600',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1465495976277-4387d4b0e4a6?w=300',
        mediaType: MediaType.video,
        uploadDate: DateTime(2025, 8, 29),
        eventId: 4,
        description: 'فيديو من يوم كتب الكتاب 📝',
        location: 'مسجد التوحيد بالعاشر من رمضان',
        aspectRatio: 1.77, // 16:9
        fileSize: 52428800, // 50MB
        fileName: 'nikah_ceremony.mp4',
        tags: ['كتب_كتاب', 'زواج', 'احتفال'],
      ),
      MediaFile(
        id: 5,
        cloudinaryUrl:
            'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=600',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=300',
        mediaType: MediaType.photo,
        uploadDate: DateTime(2025, 9, 5),
        eventId: 5,
        description: 'ترتيب البيت الجديد 🏠',
        location: 'البيت الجديد -  الحي 29',
        aspectRatio: 1.33,
        fileSize: 2621440,
        fileName: 'new_home.jpg',
        tags: ['نقل', 'بيت', 'أثاث'],
      ),
      MediaFile(
        id: 6,
        cloudinaryUrl:
            'https://images.unsplash.com/photo-1519741497674-611481863552?w=600',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1519741497674-611481863552?w=300',
        mediaType: MediaType.photo,
        uploadDate: DateTime(2025, 9, 17),
        eventId: 6,
        description: 'يوم الفرح السعيد 🎉',
        location: 'سيشن تصوير بنادي المقاولين العرب  ',
        aspectRatio: 0.67,
        isFeatured: true,
        fileSize: 4194304, // 4MB
        fileName: 'wedding_day.jpg',
        tags: ['زفاف', 'فرح', 'احتفال'],
      ),
      // ملفات إضافية للتنوع
      MediaFile(
        id: 7,
        cloudinaryUrl:
            'https://images.unsplash.com/photo-1544982503-9f984c14501a?w=600',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1544982503-9f984c14501a?w=300',
        mediaType: MediaType.photo,
        uploadDate: DateTime(2025, 3, 8),
        eventId: 7,
        description: ' اول مره اعترف فيها محمد بي حبي',
        location: 'بنها ',
        aspectRatio: 1.0,
        fileSize: 1572864,
        fileName: 'mothers_day.jpg',
        tags: ['اعتراف', 'حب'],
      ),
      MediaFile(
        id: 8,
        cloudinaryUrl:
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600',
        thumbnailUrl:
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300',
        mediaType: MediaType.video,
        uploadDate: DateTime(2025, 7, 1),
        eventId: 8,
        description: ' اول مره اعترفت فيها بي حب محمد  ',
        location: 'راس البر',
        aspectRatio: 1.77,
        fileSize: 67108864, // 64MB
        fileName: 'alexandria_trip.mp4',
        tags: ['سفر', 'رحلة', 'بحر'],
      ),
    ];
  }

  // البحث في الملفات
  static List<MediaFile> searchMediaFiles(List<MediaFile> files, String query) {
    if (query.isEmpty) return files;

    final lowerQuery = query.toLowerCase();
    return files.where((file) {
      return file.description?.toLowerCase().contains(lowerQuery) == true ||
          file.location?.toLowerCase().contains(lowerQuery) == true ||
          file.fileName?.toLowerCase().contains(lowerQuery) == true ||
          file.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ==
              true;
    }).toList();
  }

  // ترتيب الملفات
  static List<MediaFile> sortMediaFiles(
    List<MediaFile> files, {
    String sortBy = 'date',
    bool ascending = false,
  }) {
    final sortedFiles = List<MediaFile>.from(files);

    switch (sortBy) {
      case 'date':
        sortedFiles.sort(
          (a, b) => ascending
              ? a.uploadDate.compareTo(b.uploadDate)
              : b.uploadDate.compareTo(a.uploadDate),
        );
        break;
      case 'size':
        sortedFiles.sort((a, b) {
          final sizeA = a.fileSize ?? 0;
          final sizeB = b.fileSize ?? 0;
          return ascending ? sizeA.compareTo(sizeB) : sizeB.compareTo(sizeA);
        });
        break;
      case 'name':
        sortedFiles.sort((a, b) {
          final nameA = a.fileName ?? '';
          final nameB = b.fileName ?? '';
          return ascending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
        });
        break;
      case 'featured':
        sortedFiles.sort((a, b) => b.isFeatured ? 1 : -1);
        break;
    }

    return sortedFiles;
  }

  // تصفية الملفات حسب النوع
  static List<MediaFile> filterByType(List<MediaFile> files, MediaType? type) {
    if (type == null) return files;
    return files.where((file) => file.mediaType == type).toList();
  }

  // تصفية الملفات حسب الحدث
  static List<MediaFile> filterByEvent(List<MediaFile> files, int? eventId) {
    if (eventId == null) return files;
    return files.where((file) => file.eventId == eventId).toList();
  }

  // تصفية الملفات المميزة
  static List<MediaFile> filterFeatured(List<MediaFile> files) {
    return files.where((file) => file.isFeatured).toList();
  }

  // إحصائيات الملفات
  static Map<String, dynamic> getMediaStatistics(List<MediaFile> files) {
    final stats = <String, dynamic>{};

    stats['total'] = files.length;
    stats['photos'] = files.where((f) => f.mediaType == MediaType.photo).length;
    stats['videos'] = files.where((f) => f.mediaType == MediaType.video).length;
    stats['featured'] = files.where((f) => f.isFeatured).length;
    stats['recent'] = files.where((f) => f.isRecent).length;

    // حساب المساحة الإجمالية
    final totalSize = files.fold<int>(
      0,
      (sum, file) => sum + (file.fileSize ?? 0),
    );
    stats['totalSize'] = totalSize;
    stats['formattedTotalSize'] = _formatBytes(totalSize);

    // متوسط حجم الملف
    stats['averageSize'] = files.isNotEmpty ? totalSize / files.length : 0;

    return stats;
  }

  // تنسيق حجم الملف
  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // تجميع الملفات حسب التاريخ
  static Map<String, List<MediaFile>> groupByDate(List<MediaFile> files) {
    final groups = <String, List<MediaFile>>{};

    for (final file in files) {
      final months = [
        '',
        'يناير',
        'فبراير',
        'مارس',
        'إبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      final displayKey =
          '${months[file.uploadDate.month]} ${file.uploadDate.year}';

      groups[displayKey] ??= [];
      groups[displayKey]!.add(file);
    }

    return groups;
  }

  // تحقق من صحة URL
  bool get hasValidUrls {
    return cloudinaryUrl.isNotEmpty &&
        thumbnailUrl.isNotEmpty &&
        Uri.tryParse(cloudinaryUrl) != null &&
        Uri.tryParse(thumbnailUrl) != null;
  }
}
