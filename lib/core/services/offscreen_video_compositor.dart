// lib/core/services/offscreen_video_compositor.dart
// محرك رندر خلفي مستقل عن الشاشة (Offscreen True-1080p Parallel Batch Compositor)
// يرسم الصور الأصلية كاملة الدقة والانتقالات ومصفوفات ألوان Lumetri والنصوص المتجهة
// مباشرة على `ui.PictureRecorder` + `ui.Canvas` بأبعاد 1080x1920 (Full HD) أو 720x1280 (HD)
// على دفعات متوازية (Parallel Batches) دون الاعتماد على حجم ويدجت المعاينة المصغر.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/video_project_entity.dart';
import '../../theme/app_theme.dart';
import 'rust_video_bridge.dart';

class OffscreenVideoCompositor {
  OffscreenVideoCompositor._();

  /// رندر جميع إطارات المشروع في الخلفية بدقة 1080p/720p الحقيقية على دفعات متوازية
  static Future<List<Uint8List>> renderProjectFramesParallel({
    required VideoProjectEntity project,
    required VideoExportConfig config,
    required int renderFps,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (project.clips.isEmpty) return const [];

    onProgress?.call(
      0.04,
      'جاري تحميل الصور الأصلية بدقة ${config.resolutionLabel}...',
    );

    final preloadedImages = await preloadClipImages(project);
    try {
      final (int width, int height) = config.resolveDimensions(
        project.numericAspectRatio,
      );
      final double totalDur = project.totalDuration.clamp(1.0, 45.0);
      final int totalFrames = (totalDur * renderFps).round().clamp(15, 900);
      final int batchSize = config.parallelBatchSize.clamp(2, 8);

      final colorMatrix = RustVideoBridge.instance.computeLumetriColorMatrix(
        project.colorGrade,
      );

      final List<Uint8List> renderedFrames = List<Uint8List>.filled(
        totalFrames,
        Uint8List(0),
      );

      for (int batchStart = 0; batchStart < totalFrames; batchStart += batchSize) {
        final int batchEnd = math.min(totalFrames, batchStart + batchSize);
        final List<Future<Uint8List>> batchFutures = [];

        for (int idx = batchStart; idx < batchEnd; idx++) {
          final double timestampSec = (idx / renderFps).clamp(0.0, totalDur);
          batchFutures.add(
            renderSingleFrameOffscreen(
              project: project,
              timestampSeconds: timestampSec,
              width: width,
              height: height,
              preloadedImages: preloadedImages,
              colorMatrix: colorMatrix,
            ),
          );
        }

        final batchResults = await Future.wait(batchFutures);
        for (int k = 0; k < batchResults.length; k++) {
          renderedFrames[batchStart + k] = batchResults[k];
        }

        final ratio = batchEnd / totalFrames;
        onProgress?.call(
          0.05 + ratio * 0.75,
          'رندر خلفي فائق الدقة ($batchEnd / $totalFrames إطار • ${width}x$height • ×$batchSize متوازي)',
        );
        await Future<void>.delayed(Duration.zero);
      }

      return renderedFrames.where((f) => f.isNotEmpty).toList();
    } finally {
      for (final img in preloadedImages.values) {
        try {
          img.dispose();
        } catch (_) {}
      }
    }
  }

  /// تحميل الصور الأصلية كاملة الدقة مباشرة من الملفات بدون أي تصغير
  static Future<Map<String, ui.Image>> preloadClipImages(
    VideoProjectEntity project,
  ) async {
    final Map<String, ui.Image> result = {};
    for (final clip in project.clips) {
      if (clip.sourceType == VideoClipSourceType.romanticCard) continue;
      try {
        Uint8List? rawBytes;
        if (clip.localPath != null &&
            clip.localPath!.isNotEmpty &&
            File(clip.localPath!).existsSync()) {
          rawBytes = await File(clip.localPath!).readAsBytes();
        } else if (clip.networkUrl != null && clip.networkUrl!.isNotEmpty) {
          final uri = Uri.tryParse(clip.networkUrl!);
          if (uri != null) {
            final client = HttpClient();
            final req = await client.getUrl(uri);
            final resp = await req.close();
            if (resp.statusCode == 200) {
              final builder = BytesBuilder(copy: false);
              await for (final chunk in resp) {
                builder.add(chunk);
              }
              rawBytes = builder.takeBytes();
            }
            client.close();
          }
        }
        if (rawBytes != null && rawBytes.isNotEmpty) {
          final codec = await ui.instantiateImageCodec(rawBytes);
          final frameInfo = await codec.getNextFrame();
          result[clip.id] = frameInfo.image;
        }
      } catch (_) {}
    }
    return result;
  }

  /// رندر إطار واحد في الخلفية بدقة 1080p/720p الحقيقية عبر `ui.PictureRecorder`
  static Future<Uint8List> renderSingleFrameOffscreen({
    required VideoProjectEntity project,
    required double timestampSeconds,
    required int width,
    required int height,
    required Map<String, ui.Image> preloadedImages,
    required List<double> colorMatrix,
  }) async {
    final recorder = ui.PictureRecorder();
    final double w = width.toDouble();
    final double h = height.toDouble();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    final double scaleFactor = w / 360.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = AppTheme.studioCanvasBg,
    );

    if (project.clips.isNotEmpty) {
      int activeIdx = 0;
      double clipStart = 0.0;
      for (int i = 0; i < project.clips.length; i++) {
        final d = project.clips[i].durationSeconds;
        if (timestampSeconds <= clipStart + d ||
            i == project.clips.length - 1) {
          activeIdx = i;
          break;
        }
        clipStart += d;
      }

      final currentClip = project.clips[activeIdx];
      final localTime = (timestampSeconds - clipStart).clamp(
        0.0,
        currentClip.durationSeconds,
      );
      final kf = RustVideoBridge.instance.evaluateKeyframes(
        currentClip.keyframes,
        localTime,
      );

      final transDur = currentClip.transitionDuration.clamp(
        0.1,
        currentClip.durationSeconds,
      );
      final isInTransition =
          activeIdx > 0 &&
          currentClip.transition != VideoTransitionType.none &&
          localTime < transDur;
      final transProgress = isInTransition
          ? (localTime / transDur).clamp(0.0, 1.0)
          : 1.0;

      canvas.saveLayer(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..colorFilter = ColorFilter.matrix(colorMatrix),
      );

      if (isInTransition && activeIdx > 0) {
        final prevClip = project.clips[activeIdx - 1];
        final prevKf = RustVideoBridge.instance.evaluateKeyframes(
          prevClip.keyframes,
          prevClip.durationSeconds,
        );
        _drawClipLayer(
          canvas: canvas,
          clip: prevClip,
          kf: prevKf,
          width: w,
          height: h,
          scaleFactor: scaleFactor,
          preloadedImages: preloadedImages,
          extraOpacity: (1.0 - transProgress).clamp(0.0, 1.0),
          transition: VideoTransitionType.none,
          transitionProgress: 1.0,
        );
      }

      _drawClipLayer(
        canvas: canvas,
        clip: currentClip,
        kf: kf,
        width: w,
        height: h,
        scaleFactor: scaleFactor,
        preloadedImages: preloadedImages,
        extraOpacity: 1.0,
        transition: isInTransition
            ? currentClip.transition
            : VideoTransitionType.none,
        transitionProgress: transProgress,
      );

      canvas.restore();
    }

    final vignetteAmount = project.colorGrade.vignette.clamp(0.0, 0.85);
    if (vignetteAmount > 0.01) {
      final center = Offset(w * 0.5, h * 0.5);
      final radius = math.max(w, h) * 0.65;
      final vigPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            const Color(0x00000000),
            Color.fromRGBO(0, 0, 0, vignetteAmount),
          ],
          const [0.45, 1.0],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vigPaint);
    }

    for (final txt in project.textTracks) {
      if (timestampSeconds >= txt.startTime &&
          timestampSeconds <= txt.endTime) {
        _drawTextTrack(
          canvas: canvas,
          track: txt,
          localTime: timestampSeconds - txt.startTime,
          width: w,
          height: h,
          scaleFactor: scaleFactor,
        );
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    try {
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } finally {
      img.dispose();
    }
    return Uint8List(0);
  }

  static void _drawClipLayer({
    required Canvas canvas,
    required VideoClipItem clip,
    required KeyframePoint kf,
    required double width,
    required double height,
    required double scaleFactor,
    required Map<String, ui.Image> preloadedImages,
    required double extraOpacity,
    required VideoTransitionType transition,
    required double transitionProgress,
  }) {
    double opacity = (kf.opacity * extraOpacity).clamp(0.0, 1.0);
    double tx = kf.x * width;
    double ty = kf.y * height;
    double scale = kf.scale.clamp(0.1, 5.0);
    final double rotRad = kf.rotation * (math.pi / 180.0);

    switch (transition) {
      case VideoTransitionType.none:
        break;
      case VideoTransitionType.crossDissolve:
        opacity *= transitionProgress.clamp(0.0, 1.0);
        break;
      case VideoTransitionType.slideLeft:
        tx += (1.0 - transitionProgress) * width;
        break;
      case VideoTransitionType.zoomIn:
        opacity *= transitionProgress.clamp(0.0, 1.0);
        scale *= (0.6 + 0.4 * transitionProgress);
        break;
      case VideoTransitionType.heartPulse:
        opacity *= transitionProgress.clamp(0.0, 1.0);
        scale *= (1.0 + 0.15 * math.sin(transitionProgress * math.pi));
        break;
      case VideoTransitionType.dreamyBlur:
        opacity *= transitionProgress.clamp(0.0, 1.0);
        break;
    }

    if (opacity <= 0.005) return;

    canvas.save();
    if (transition == VideoTransitionType.dreamyBlur &&
        transitionProgress < 0.99) {
      final sigma = (1.0 - transitionProgress) * 14.0 * scaleFactor;
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, width, height),
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, opacity)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );
    } else if (opacity < 0.999) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
      );
    }

    canvas.translate(width * 0.5 + tx, height * 0.5 + ty);
    canvas.rotate(rotRad);
    canvas.scale(scale, scale);
    canvas.translate(-width * 0.5, -height * 0.5);

    final ui.Image? nativeImg = preloadedImages[clip.id];
    if (nativeImg != null &&
        clip.sourceType != VideoClipSourceType.romanticCard) {
      final srcSize = Size(
        nativeImg.width.toDouble(),
        nativeImg.height.toDouble(),
      );
      final dstSize = Size(width, height);
      final fitted = applyBoxFit(BoxFit.cover, srcSize, dstSize);
      final srcRect = Alignment.center.inscribe(
        fitted.source,
        Offset.zero & srcSize,
      );
      final dstRect = Alignment.center.inscribe(
        fitted.destination,
        Offset.zero & dstSize,
      );
      canvas.drawImageRect(
        nativeImg,
        srcRect,
        dstRect,
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true,
      );
    } else {
      final gradColors = AppTheme.studioCardGradient(clip.cardColorValue);
      final rect = Rect.fromLTWH(0, 0, width, height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(width, height),
            gradColors,
          ),
      );

      final titlePainter = TextPainter(
        text: TextSpan(
          text: '❤️\n${clip.title}',
          style: GoogleFonts.notoSerif(
            color: const Color(0xFFFFFFFF),
            fontSize: 24.0 * scaleFactor,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: width * 0.82);

      titlePainter.paint(
        canvas,
        Offset(
          (width - titlePainter.width) * 0.5,
          (height - titlePainter.height) * 0.5,
        ),
      );
    }

    if ((transition == VideoTransitionType.dreamyBlur &&
            transitionProgress < 0.99) ||
        opacity < 0.999) {
      canvas.restore();
    }
    canvas.restore();
  }

  static void _drawTextTrack({
    required Canvas canvas,
    required VideoTextTrack track,
    required double localTime,
    required double width,
    required double height,
    required double scaleFactor,
  }) {
    final kf = RustVideoBridge.instance.evaluateKeyframes(
      track.keyframes,
      localTime,
    );
    final opacity = kf.opacity.clamp(0.0, 1.0);
    if (opacity <= 0.01) return;

    final scaledFontSize = track.fontSize * scaleFactor;
    final baseColor = AppTheme.fromCode(track.colorValue).withValues(
      alpha: opacity,
    );
    final TextStyle font = switch (track.fontStyle) {
      'script' => GoogleFonts.dancingScript(
        fontSize: scaledFontSize,
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      'sans' => GoogleFonts.manrope(
        fontSize: scaledFontSize,
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      _ => GoogleFonts.notoSerif(
        fontSize: scaledFontSize,
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
    };

    final tp = TextPainter(
      text: TextSpan(text: track.text, style: font),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: width * 0.84);

    final padH = 16.0 * scaleFactor;
    final padV = 10.0 * scaleFactor;
    final boxW = tp.width + padH * 2;
    final boxH = tp.height + padV * 2;

    canvas.save();
    canvas.translate(width * 0.5 + kf.x * width, height * 0.5 + kf.y * height);
    canvas.rotate(kf.rotation * (math.pi / 180.0));
    canvas.scale(kf.scale.clamp(0.1, 5.0));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: boxW, height: boxH),
      Radius.circular(16.0 * scaleFactor),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.45 * opacity),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, 0.25 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scaleFactor,
    );

    tp.paint(canvas, Offset(-tp.width * 0.5, -tp.height * 0.5));
    canvas.restore();
  }
}
