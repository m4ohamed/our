// lib/core/services/rust_video_bridge.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/video_project_entity.dart';
import 'offscreen_video_compositor.dart';

// ─── Export Lifecycle, Cancellation & Diagnostics (VID-007 / VID-012 / VID-014) ─

/// مراحل التصدير الصريحة لعرض التقدم الحقيقي وتشخيص أي فشل بدقة (VID-014)
enum VideoExportStage {
  preparing,
  rendering,
  processing,
  encoding,
  validating,
  completed,
  failed,
  cancelled;

  String get arabicLabel => switch (this) {
    VideoExportStage.preparing => 'التحضير (Preparing)',
    VideoExportStage.rendering => 'الرندر الخلفي (Rendering)',
    VideoExportStage.processing => 'معالجة الصوت والألوان (Processing)',
    VideoExportStage.encoding => 'الترميز والتجميع (Encoding)',
    VideoExportStage.validating => 'التحقق النهائي (Validating)',
    VideoExportStage.completed => 'اكتمل التصدير (Completed)',
    VideoExportStage.failed => 'فشل التصدير (Failed)',
    VideoExportStage.cancelled => 'تم إلغاء التصدير (Cancelled)',
  };
}

/// رمز إلغاء التصدير لإيقاف الرندر أو المعالجة أو الترميز وتحرير الموارد فوراً (VID-014)
class VideoExportCancelToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = <void Function()>[];