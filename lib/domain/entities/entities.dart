// lib/domain/entities/entities.dart
import 'package:flutter/foundation.dart';

enum MediaType { photo, video }

@immutable
class MediaFileEntity {
  final String id;
  final String cloudinaryUrl;
  final String thumbnailUrl;
  final String? localPath;
  final MediaType mediaType;
  final DateTime uploadDate;
  final String? eventId;
  final String? description;
  final bool isFeatured;
  final String? location;
  final double aspectRatio;
  final int? fileSize;
  final String? fileName;
  final List<String> tags;

  const MediaFileEntity({
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

  MediaFileEntity copyWith({
    String? id,
    String? cloudinaryUrl,
    String? thumbnailUrl,
    String? localPath,
    MediaType? mediaType,
    DateTime? uploadDate,
    String? eventId,
    String? description,
    bool? isFeatured,
    String? location,
    double? aspectRatio,
    int? fileSize,
    String? fileName,
    List<String>? tags,
  }) {
    return MediaFileEntity(
      id: id ?? this.id,
      cloudinaryUrl: cloudinaryUrl ?? this.cloudinaryUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      localPath: localPath ?? this.localPath,
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

  bool get isRecent => DateTime.now().difference(uploadDate).inDays <= 7;

  String get mediaTypeArabic =>
      mediaType == MediaType.photo ? 'صورة' : 'فيديو';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaFileEntity && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class AppSettingsEntity {
  final bool musicEnabled;
  final double musicVolume;
  final bool notificationsEnabled;
  final bool animationsEnabled;
  final AppThemeMode themeMode;
  final bool pinEnabled;
  final String? pinHash;
  final bool biometricEnabled;
  final String language;
  final bool enableDemoData;

  const AppSettingsEntity({
    this.musicEnabled = true,
    this.musicVolume = 0.7,
    this.notificationsEnabled = true,
    this.animationsEnabled = true,
    this.themeMode = AppThemeMode.light,
    this.pinEnabled = false,
    this.pinHash,
    this.biometricEnabled = false,
    this.language = 'ar',
    this.enableDemoData = true,
  });

  AppSettingsEntity copyWith({
    bool? musicEnabled,
    double? musicVolume,
    bool? notificationsEnabled,
    bool? animationsEnabled,
    AppThemeMode? themeMode,
    bool? pinEnabled,
    String? pinHash,
    bool? biometricEnabled,
    String? language,
    bool? enableDemoData,
  }) {
    return AppSettingsEntity(
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinHash: pinHash ?? this.pinHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      language: language ?? this.language,
      enableDemoData: enableDemoData ?? this.enableDemoData,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettingsEntity &&
        other.musicEnabled == musicEnabled &&
        other.musicVolume == musicVolume &&
        other.notificationsEnabled == notificationsEnabled &&
        other.animationsEnabled == animationsEnabled &&
        other.themeMode == themeMode &&
        other.pinEnabled == pinEnabled &&
        other.pinHash == pinHash &&
        other.biometricEnabled == biometricEnabled &&
        other.language == language &&
        other.enableDemoData == enableDemoData;
  }

  @override
  int get hashCode => Object.hash(
    musicEnabled,
    musicVolume,
    notificationsEnabled,
    animationsEnabled,
    themeMode,
    pinEnabled,
    pinHash,
    biometricEnabled,
    language,
    enableDemoData,
  );

  static const AppSettingsEntity defaults = AppSettingsEntity();
}

enum AppThemeMode { light, dark }
