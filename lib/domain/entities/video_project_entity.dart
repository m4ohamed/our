// lib/domain/entities/video_project_entity.dart
import 'package:flutter/material.dart';

/// منحنيات الحركة مستلهمة من FilmCraft و EffectCraft
enum KeyframeEasing {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  elasticOut,
  hold, // تجميد القيمة حتى النقطة التالية (Hold Keyframe)
  autoBezier, // منحنى Catmull-Rom متصل عبر النقاط (Continuous Auto-Bezier)
}

enum VideoTransitionType {
  none,
  crossDissolve,
  slideLeft,
  zoomIn,
  heartPulse,
  dreamyBlur,
}

enum VideoAspectRatioPreset {
  portrait9x16, // 9:16 Reels / Stories
  square1x1, // 1:1 Post
  landscape16x9, // 16:9 Cinema
}

enum VideoClipSourceType { image, video, romanticCard }

/// القوالب اللونية البرمجية (Procedural Looks) مستلهمة من لوحة Lumetri في FilmCraft
enum LumetriLookPreset {
  original,
  etherealRomance,
  goldenHour,
  vintageFilm,
  warmAmber,
  noirRomance,
}

@immutable
class LumetriColorGrade {
  final LumetriLookPreset preset;
  final double exposure; // -1.5 .. 1.5
  final double contrast; // -0.5 .. 1.0
  final double saturation; // -1.0 .. 1.0
  final double temperature; // -1.0 (Cool) .. 1.0 (Warm)
  final double fadedFilm; // 0.0 .. 0.4
  final double vignette; // 0.0 .. 0.8

  const LumetriColorGrade({
    this.preset = LumetriLookPreset.original,
    this.exposure = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.temperature = 0.0,
    this.fadedFilm = 0.0,
    this.vignette = 0.0,
  });

  factory LumetriColorGrade.fromPreset(LumetriLookPreset preset) {
    return switch (preset) {
      LumetriLookPreset.original => const LumetriColorGrade(
        preset: LumetriLookPreset.original,
      ),
      LumetriLookPreset.etherealRomance => const LumetriColorGrade(
        preset: LumetriLookPreset.etherealRomance,
        exposure: 0.08,
        contrast: -0.05,
        saturation: 0.12,
        temperature: 0.18,
        fadedFilm: 0.08,
        vignette: 0.25,
      ),
      LumetriLookPreset.goldenHour => const LumetriColorGrade(
        preset: LumetriLookPreset.goldenHour,
        exposure: 0.05,
        contrast: 0.12,
        saturation: 0.25,
        temperature: 0.45,
        fadedFilm: 0.04,
        vignette: 0.30,
      ),
      LumetriLookPreset.vintageFilm => const LumetriColorGrade(
        preset: LumetriLookPreset.vintageFilm,
        exposure: 0.0,
        contrast: -0.10,
        saturation: -0.25,
        temperature: 0.22,
        fadedFilm: 0.22,
        vignette: 0.45,
      ),
      LumetriLookPreset.warmAmber => const LumetriColorGrade(
        preset: LumetriLookPreset.warmAmber,
        exposure: 0.04,
        contrast: 0.18,
        saturation: 0.15,
        temperature: 0.32,
        fadedFilm: 0.0,
        vignette: 0.20,
      ),
      LumetriLookPreset.noirRomance => const LumetriColorGrade(
        preset: LumetriLookPreset.noirRomance,
        exposure: 0.05,
        contrast: 0.35,
        saturation: -1.0,
        temperature: 0.0,
        fadedFilm: 0.10,
        vignette: 0.50,
      ),
    };
  }

  LumetriColorGrade copyWith({
    LumetriLookPreset? preset,
    double? exposure,
    double? contrast,
    double? saturation,
    double? temperature,
    double? fadedFilm,
    double? vignette,
  }) {
    return LumetriColorGrade(
      preset: preset ?? this.preset,
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      temperature: temperature ?? this.temperature,
      fadedFilm: fadedFilm ?? this.fadedFilm,
      vignette: vignette ?? this.vignette,
    );
  }

  Map<String, dynamic> toJson() => {
    'preset': preset.name,
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'temperature': temperature,
    'fadedFilm': fadedFilm,
    'vignette': vignette,
  };

  factory LumetriColorGrade.fromJson(Map<String, dynamic> json) =>
      LumetriColorGrade(
        preset: LumetriLookPreset.values.firstWhere(
          (e) => e.name == json['preset'],
          orElse: () => LumetriLookPreset.original,
        ),
        exposure: (json['exposure'] as num?)?.toDouble() ?? 0.0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 0.0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 0.0,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        fadedFilm: (json['fadedFilm'] as num?)?.toDouble() ?? 0.0,
        vignette: (json['vignette'] as num?)?.toDouble() ?? 0.0,
      );
}

@immutable
class KeyframePoint {
  final double timestamp;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final double opacity;
  final KeyframeEasing easing;

  const KeyframePoint({
    required this.timestamp,
    this.x = 0.0,
    this.y = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.easing = KeyframeEasing.easeInOut,
  });

  KeyframePoint copyWith({
    double? timestamp,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
    KeyframeEasing? easing,
  }) {
    return KeyframePoint(
      timestamp: timestamp ?? this.timestamp,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      easing: easing ?? this.easing,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
    'opacity': opacity,
    'easing': easing.name,
  };

  factory KeyframePoint.fromJson(Map<String, dynamic> json) => KeyframePoint(
    timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
    x: (json['x'] as num?)?.toDouble() ?? 0.0,
    y: (json['y'] as num?)?.toDouble() ?? 0.0,
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    easing: KeyframeEasing.values.firstWhere(
      (e) => e.name == json['easing'],
      orElse: () => KeyframeEasing.easeInOut,
    ),
  );
}

@immutable
class VideoClipItem {
  final String id;
  final String title;
  final VideoClipSourceType sourceType;
  final String? localPath;
  final String? networkUrl;
  final double durationSeconds;
  final VideoTransitionType transition;
  final double transitionDuration;
  final List<KeyframePoint> keyframes;
  final int cardColorValue;

  const VideoClipItem({
    required this.id,
    required this.title,
    this.sourceType = VideoClipSourceType.image,
    this.localPath,
    this.networkUrl,
    this.durationSeconds = 4.0,
    this.transition = VideoTransitionType.crossDissolve,
    this.transitionDuration = 0.8,
    this.keyframes = const [
      KeyframePoint(timestamp: 0.0, scale: 1.0),
      KeyframePoint(timestamp: 4.0, scale: 1.12),
    ],
    this.cardColorValue = 0xFFF1878E,
  });

  VideoClipItem copyWith({
    String? id,
    String? title,
    VideoClipSourceType? sourceType,
    String? localPath,
    String? networkUrl,
    double? durationSeconds,
    VideoTransitionType? transition,
    double? transitionDuration,
    List<KeyframePoint>? keyframes,
    int? cardColorValue,
  }) {
    return VideoClipItem(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      localPath: localPath ?? this.localPath,
      networkUrl: networkUrl ?? this.networkUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      transition: transition ?? this.transition,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      keyframes: keyframes ?? this.keyframes,
      cardColorValue: cardColorValue ?? this.cardColorValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sourceType': sourceType.name,
    'localPath': localPath,
    'networkUrl': networkUrl,
    'durationSeconds': durationSeconds,
    'transition': transition.name,
    'transitionDuration': transitionDuration,
    'keyframes': keyframes.map((k) => k.toJson()).toList(),
    'cardColorValue': cardColorValue,
  };

  factory VideoClipItem.fromJson(Map<String, dynamic> json) => VideoClipItem(
    id: json['id'] as String,
    title: (json['title'] as String?) ?? '',
    sourceType: VideoClipSourceType.values.firstWhere(
      (e) => e.name == json['sourceType'],
      orElse: () => VideoClipSourceType.image,
    ),
    localPath: json['localPath'] as String?,
    networkUrl: json['networkUrl'] as String?,
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 4.0,
    transition: VideoTransitionType.values.firstWhere(
      (e) => e.name == json['transition'],
      orElse: () => VideoTransitionType.crossDissolve,
    ),
    transitionDuration: (json['transitionDuration'] as num?)?.toDouble() ?? 0.8,
    keyframes:
        (json['keyframes'] as List?)
            ?.map((k) => KeyframePoint.fromJson(Map<String, dynamic>.from(k)))
            .toList() ??
        const [],
    cardColorValue: (json['cardColorValue'] as int?) ?? 0xFFF1878E,
  );
}

@immutable
class VideoTextTrack {
  final String id;
  final String text;
  final double startTime;
  final double endTime;
  final double fontSize;
  final int colorValue;
  final String fontStyle;
  final List<KeyframePoint> keyframes;

  const VideoTextTrack({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.fontSize = 24.0,
    this.colorValue = 0xFFFFFFFF,
    this.fontStyle = 'serif',
    this.keyframes = const [
      KeyframePoint(timestamp: 0.0, y: 0.55, opacity: 0.0, scale: 0.85),
      KeyframePoint(timestamp: 0.6, y: 0.5, opacity: 1.0, scale: 1.0),
    ],
  });

  VideoTextTrack copyWith({
    String? id,
    String? text,
    double? startTime,
    double? endTime,
    double? fontSize,
    int? colorValue,
    String? fontStyle,
    List<KeyframePoint>? keyframes,
  }) {
    return VideoTextTrack(
      id: id ?? this.id,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
      fontStyle: fontStyle ?? this.fontStyle,
      keyframes: keyframes ?? this.keyframes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'startTime': startTime,
    'endTime': endTime,
    'fontSize': fontSize,
    'colorValue': colorValue,
    'fontStyle': fontStyle,
    'keyframes': keyframes.map((k) => k.toJson()).toList(),
  };

  factory VideoTextTrack.fromJson(Map<String, dynamic> json) => VideoTextTrack(
    id: json['id'] as String,
    text: (json['text'] as String?) ?? '',
    startTime: (json['startTime'] as num?)?.toDouble() ?? 0.0,
    endTime: (json['endTime'] as num?)?.toDouble() ?? 4.0,
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
    colorValue: (json['colorValue'] as int?) ?? 0xFFFFFFFF,
    fontStyle: (json['fontStyle'] as String?) ?? 'serif',
    keyframes:
        (json['keyframes'] as List?)
            ?.map((k) => KeyframePoint.fromJson(Map<String, dynamic>.from(k)))
            .toList() ??
        const [],
  );
}

@immutable
class VideoProjectEntity {
  final String id;
  final String title;
  final VideoAspectRatioPreset aspectRatio;
  final List<VideoClipItem> clips;
  final List<VideoTextTrack> textTracks;
  final LumetriColorGrade colorGrade;
  final String? audioAsset;
  final DateTime createdAt;

  const VideoProjectEntity({
    required this.id,
    required this.title,
    this.aspectRatio = VideoAspectRatioPreset.portrait9x16,
    this.clips = const [],
    this.textTracks = const [],
    this.colorGrade = const LumetriColorGrade(),
    this.audioAsset,
    required this.createdAt,
  });

  double get totalDuration {
    if (clips.isEmpty) return 0.0;
    return clips.fold(0.0, (sum, c) => sum + c.durationSeconds);
  }

  double get numericAspectRatio => switch (aspectRatio) {
    VideoAspectRatioPreset.portrait9x16 => 9 / 16,
    VideoAspectRatioPreset.square1x1 => 1.0,
    VideoAspectRatioPreset.landscape16x9 => 16 / 9,
  };

  VideoProjectEntity copyWith({
    String? id,
    String? title,
    VideoAspectRatioPreset? aspectRatio,
    List<VideoClipItem>? clips,
    List<VideoTextTrack>? textTracks,
    LumetriColorGrade? colorGrade,
    String? audioAsset,
    DateTime? createdAt,
  }) {
    return VideoProjectEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      clips: clips ?? this.clips,
      textTracks: textTracks ?? this.textTracks,
      colorGrade: colorGrade ?? this.colorGrade,
      audioAsset: audioAsset ?? this.audioAsset,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'aspectRatio': aspectRatio.name,
    'clips': clips.map((c) => c.toJson()).toList(),
    'textTracks': textTracks.map((t) => t.toJson()).toList(),
    'colorGrade': colorGrade.toJson(),
    'audioAsset': audioAsset,
    'createdAt': createdAt.toIso8601String(),
  };

  factory VideoProjectEntity.fromJson(Map<String, dynamic> json) =>
      VideoProjectEntity(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        aspectRatio: VideoAspectRatioPreset.values.firstWhere(
          (e) => e.name == json['aspectRatio'],
          orElse: () => VideoAspectRatioPreset.portrait9x16,
        ),
        clips:
            (json['clips'] as List?)
                ?.map((c) => VideoClipItem.fromJson(Map<String, dynamic>.from(c)))
                .toList() ??
            const [],
        textTracks:
            (json['textTracks'] as List?)
                ?.map(
                  (t) => VideoTextTrack.fromJson(Map<String, dynamic>.from(t)),
                )
                .toList() ??
            const [],
        colorGrade: json['colorGrade'] != null
            ? LumetriColorGrade.fromJson(
                Map<String, dynamic>.from(json['colorGrade']),
              )
            : const LumetriColorGrade(),
        audioAsset: json['audioAsset'] as String?,
        createdAt:
            DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.now(),
      );
}
