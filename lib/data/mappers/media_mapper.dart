// lib/data/mappers/media_mapper.dart
import '../../domain/entities/entities.dart';
import '../models/media_file_hive_model.dart';

extension MediaFileHiveModelMapper on MediaFileHiveModel {
  MediaFileEntity toEntity() {
    return MediaFileEntity(
      id: id,
      cloudinaryUrl: cloudinaryUrl,
      thumbnailUrl: thumbnailUrl,
      localPath: localPath,
      mediaType: mediaType == 'video' ? MediaType.video : MediaType.photo,
      uploadDate: uploadDate,
      eventId: eventId,
      description: description,
      isFeatured: isFeatured,
      location: location,
      aspectRatio: aspectRatio,
      fileSize: fileSize,
      fileName: fileName,
      tags: List<String>.from(tags),
    );
  }
}

extension MediaFileEntityMapper on MediaFileEntity {
  MediaFileHiveModel toHiveModel() {
    return MediaFileHiveModel(
      id: id,
      cloudinaryUrl: cloudinaryUrl,
      thumbnailUrl: thumbnailUrl,
      localPath: localPath,
      mediaType: mediaType == MediaType.video ? 'video' : 'photo',
      uploadDate: uploadDate,
      eventId: eventId,
      description: description,
      isFeatured: isFeatured,
      location: location,
      aspectRatio: aspectRatio,
      fileSize: fileSize,
      fileName: fileName,
      tags: List<String>.from(tags),
    );
  }
}
