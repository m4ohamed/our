// lib/data/models/media_file_hive_model.dart
import 'package:hive/hive.dart';

part 'media_file_hive_model.g.dart';

@HiveType(typeId: 1)
class MediaFileHiveModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String cloudinaryUrl;

  @HiveField(2)
  late String thumbnailUrl;

  @HiveField(3)
  String? localPath;

  @HiveField(4)
  late String mediaType; // 'photo' or 'video'

  @HiveField(5)
  late DateTime uploadDate;

  @HiveField(6)
  String? eventId;

  @HiveField(7)
  String? description;

  @HiveField(8)
  late bool isFeatured;

  @HiveField(9)
  String? location;

  @HiveField(10)
  late double aspectRatio;

  @HiveField(11)
  int? fileSize;

  @HiveField(12)
  String? fileName;

  @HiveField(13)
  late List<String> tags;

  MediaFileHiveModel({
    required this.id,
    required this.cloudinaryUrl,
    required this.thumbnailUrl,
    this.localPath,
    required this.mediaType,
    required this.uploadDate,
    this.eventId,
    this.description,
    this.isFeatured = false,
    this.location,
    this.aspectRatio = 1.0,
    this.fileSize,
    this.fileName,
    this.tags = const [],
  });
}
