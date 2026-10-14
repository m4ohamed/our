// lib/core/services/rust_video_bridge.dart
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/video_project_entity.dart';

// ─── FFI Struct & Signatures ──────────────────────────────────────────────────

final class _NativeTransform extends ffi.Struct {
  @ffi.Double()
  external double x;

  @ffi.Double()
  external double y;

  @ffi.Double()
  external double scale;

  @ffi.Double()
  external double rotation;

  @ffi.Double()
  external double opacity;
}

typedef _InterpolateNative =
    _NativeTransform Function(
      ffi.Double t,
      ffi.Int32 easingType,
      ffi.Double x0,
      ffi.Double y0,
      ffi.Double s0,
      ffi.Double r0,
      ffi.Double o0,
      ffi.Double x1,
      ffi.Double y1,
      ffi.Double s1,
      ffi.Double r1,
      ffi.Double o1,
    );

typedef _InterpolateDart =
    _NativeTransform Function(
      double t,
      int easingType,
      double x0,
      double y0,
      double s0,
      double r0,
      double o0,
      double x1,
      double y1,
      double s1,
      double r1,
      double o1,
    );

/// جسر هجين يربط تطبيق Flutter بمحرك Rust الأصلي (`librust_video_engine`)
/// المستلهم من معمارية FilmCraft و EffectCraft:
/// - التوقيت الصحيح بدون انجراف (254,016,000,000 ticks/sec)
/// - استيفاء Catmull-Rom Auto-Bezier و Hold Keyframes
/// - مصفوفات تصحيح الألوان البرمجية Lumetri Color Grading (Rec.709)
class RustVideoBridge {
  static final RustVideoBridge instance = RustVideoBridge._();

  /// قاعدة التوقيت الدقيقة المعتمدة في FilmCraft: 254,016,000,000 نبضة في الثانية
  static const int ticksPerSecond = 254016000000;

  ffi.DynamicLibrary? _dylib;
  _InterpolateDart? _rustInterpolate;

  RustVideoBridge._() {
    _tryLoadRustLibrary();
  }

  bool get isRustNativeLoaded => _rustInterpolate != null;

  int secondsToTicks(double seconds) => (seconds * ticksPerSecond).round();
  double ticksToSeconds(int ticks) => ticks / ticksPerSecond;

  void _tryLoadRustLibrary() {
    try {
      if (Platform.isAndroid || Platform.isLinux) {
        _dylib = ffi.DynamicLibrary.open('librust_video_engine.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        _dylib = ffi.DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _dylib = ffi.DynamicLibrary.open('rust_video_engine.dll');
      }

      if (_dylib != null) {
        _rustInterpolate = _dylib!
            .lookupFunction<_InterpolateNative, _InterpolateDart>(
              'rust_interpolate_keyframes',
            );
      }
    } catch (_) {
      _rustInterpolate = null;
    }
  }

  /// حساب قيم التحويل (Position, Scale, Rotation, Opacity) عند أي لحظة زمنية
  /// مع دعم منحنى Catmull-Rom Auto-Bezier المتصل عبر 4 نقاط كما في EffectCraft
  KeyframePoint evaluateKeyframes(
    List<KeyframePoint> keyframes,
    double localTime,
  ) {
    if (keyframes.isEmpty) {
      return KeyframePoint(timestamp: localTime);
    }
    final sorted = [...keyframes]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (localTime <= sorted.first.timestamp) {
      return sorted.first.copyWith(timestamp: localTime);
    }
    if (localTime >= sorted.last.timestamp) {
      return sorted.last.copyWith(timestamp: localTime);
    }

    int segIdx = 0;
    for (var i = 0; i < sorted.length - 1; i++) {
      if (localTime >= sorted[i].timestamp &&
          localTime <= sorted[i + 1].timestamp) {
        segIdx = i;
        break;
      }
    }

    final prev = sorted[segIdx];
    final next = sorted[segIdx + 1];

    // حساب النسبة الزمنية بدقة Integer Ticks لمنع انجراف الفريمات
    final prevTicks = secondsToTicks(prev.timestamp);
    final nextTicks = secondsToTicks(next.timestamp);
    final curTicks = secondsToTicks(localTime);
    final spanTicks = nextTicks - prevTicks;
    final rawT = spanTicks > 0
        ? ((curTicks - prevTicks) / spanTicks).clamp(0.0, 1.0)
        : 1.0;

    // إذا كان المنحنى Auto-Bezier ولدينا 3 نقاط أو أكثر، نطبق Catmull-Rom Spline كما في EffectCraft
    if (next.easing == KeyframeEasing.autoBezier && sorted.length >= 3) {
      final p0 = segIdx > 0 ? sorted[segIdx - 1] : prev;
      final p3 = (segIdx + 2 < sorted.length) ? sorted[segIdx + 2] : next;
      return KeyframePoint(
        timestamp: localTime,
        x: _catmullRom(p0.x, prev.x, next.x, p3.x, rawT),
        y: _catmullRom(p0.y, prev.y, next.y, p3.y, rawT),
        scale: _catmullRom(
          p0.scale,
          prev.scale,
          next.scale,
          p3.scale,
          rawT,
        ).clamp(0.1, 5.0),
        rotation: _catmullRom(
          p0.rotation,
          prev.rotation,
          next.rotation,
          p3.rotation,
          rawT,
        ),
        opacity: _catmullRom(
          p0.opacity,
          prev.opacity,
          next.opacity,
          p3.opacity,
          rawT,
        ).clamp(0.0, 1.0),
        easing: next.easing,
      );
    }

    if (_rustInterpolate != null) {
      final res = _rustInterpolate!(
        rawT,
        next.easing.index,
        prev.x,
        prev.y,
        prev.scale,
        prev.rotation,
        prev.opacity,
        next.x,
        next.y,
        next.scale,
        next.rotation,
        next.opacity,
      );
      return KeyframePoint(
        timestamp: localTime,
        x: res.x,
        y: res.y,
        scale: res.scale,
        rotation: res.rotation,
        opacity: res.opacity,
        easing: next.easing,
      );
    }

    final p = _applyEasing(rawT, next.easing);
    return KeyframePoint(
      timestamp: localTime,
      x: prev.x + (next.x - prev.x) * p,
      y: prev.y + (next.y - prev.y) * p,
      scale: (prev.scale + (next.scale - prev.scale) * p).clamp(0.1, 5.0),
      rotation: prev.rotation + (next.rotation - prev.rotation) * p,
      opacity: (prev.opacity + (next.opacity - prev.opacity) * p).clamp(
        0.0,
        1.0,
      ),
      easing: next.easing,
    );
  }

  double _catmullRom(double p0, double p1, double p2, double p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    return 0.5 *
        ((2.0 * p1) +
            (-p0 + p2) * t +
            (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
            (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3);
  }

  double _applyEasing(double t, KeyframeEasing easing) {
    final c = t.clamp(0.0, 1.0);
    return switch (easing) {
      KeyframeEasing.linear => c,
      KeyframeEasing.easeIn => c * c * c,
      KeyframeEasing.easeOut => 1.0 - math.pow(1.0 - c, 3).toDouble(),
      KeyframeEasing.easeInOut =>
        c < 0.5
            ? 4.0 * c * c * c
            : 1.0 - math.pow(-2.0 * c + 2.0, 3).toDouble() / 2.0,
      KeyframeEasing.elasticOut =>
        (c == 0.0 || c == 1.0)
            ? c
            : math.pow(2.0, -10.0 * c).toDouble() *
                      math.sin((c * 10.0 - 0.75) * ((2.0 * math.pi) / 3.0)) +
                  1.0,
      KeyframeEasing.hold => c < 1.0 ? 0.0 : 1.0,
      KeyframeEasing.autoBezier => c * c * (3.0 - 2.0 * c),
    };
  }

  /// توليد مصفوفة تصحيح الألوان 4x5 (20 عنصراً) بأسلوب Lumetri Color في FilmCraft
  List<double> computeLumetriColorMatrix(LumetriColorGrade grade) {
    final gain = math.pow(2.0, grade.exposure.clamp(-2.0, 2.0)).toDouble();
    final c = math.max(0.1, 1.0 + grade.contrast.clamp(-0.8, 1.5));
    final s = math.max(0.0, 1.0 + grade.saturation.clamp(-1.0, 1.5));
    final temp = grade.temperature.clamp(-1.0, 1.0) * 30.0;
    final fade = grade.fadedFilm.clamp(0.0, 0.5) * 45.0;

    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;

    final sr = (1.0 - s) * lumR;
    final sg = (1.0 - s) * lumG;
    final sb = (1.0 - s) * lumB;

    final scale = gain * c;
    final offset = (1.0 - c) * 128.0 + fade;

    return <double>[
      scale * (sr + s),
      scale * sg,
      scale * sb,
      0.0,
      offset + temp,
      scale * sr,
      scale * (sg + s),
      scale * sb,
      0.0,
      offset,
      scale * sr,
      scale * sg,
      scale * (sb + s),
      0.0,
      offset - temp,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  /// تجميع قائمة إطارات PNG ملتقطة من الـ Canvas إلى ملف فيديو قياسي (RIFF AVI Motion-PNG)
  Future<File> muxFramesToVideoContainer({
    required List<Uint8List> frames,
    required String outputPath,
    required int width,
    required int height,
    required int fps,
  }) async {
    final builder = BytesBuilder(copy: false);
    final numFrames = frames.length;
    final usecPerFrame = fps > 0 ? (1000000 ~/ fps) : 100000;

    void writeU32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      builder.add(b.buffer.asUint8List());
    }

    void writeU16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      builder.add(b.buffer.asUint8List());
    }

    void writeFourCC(String tag) {
      builder.add(ascii.encode(tag.padRight(4).substring(0, 4)));
    }

    int moviPayloadBytes = 4;
    for (final frame in frames) {
      moviPayloadBytes += 8 + frame.length + (frame.length.isOdd ? 1 : 0);
    }
    final idx1Bytes = frames.length * 16;
    final riffSize = 4 + (8 + 192) + (8 + moviPayloadBytes) + (8 + idx1Bytes);

    writeFourCC('RIFF');
    writeU32(riffSize);
    writeFourCC('AVI ');

    writeFourCC('LIST');
    writeU32(192);
    writeFourCC('hdrl');

    writeFourCC('avih');
    writeU32(56);
    writeU32(usecPerFrame);
    writeU32(width * height * 4 * fps);
    writeU32(0);
    writeU32(0x10);
    writeU32(numFrames);
    writeU32(0);
    writeU32(1);
    writeU32(width * height * 4);
    writeU32(width);
    writeU32(height);
    builder.add(Uint8List(16));

    writeFourCC('LIST');
    writeU32(116);
    writeFourCC('strl');

    writeFourCC('strh');
    writeU32(56);
    writeFourCC('vids');
    writeFourCC('MPNG');
    writeU32(0);
    writeU16(0);
    writeU16(0);
    writeU32(0);
    writeU32(1);
    writeU32(fps);
    writeU32(0);
    writeU32(numFrames);
    writeU32(width * height * 4);
    writeU32(0xFFFFFFFF);
    writeU32(0);
    writeU16(0);
    writeU16(0);
    writeU16(width);
    writeU16(height);

    writeFourCC('strf');
    writeU32(40);
    writeU32(40);
    writeU32(width);
    writeU32(height);
    writeU16(1);
    writeU16(32);
    writeFourCC('MPNG');
    writeU32(width * height * 4);
    builder.add(Uint8List(16));

    writeFourCC('LIST');
    writeU32(moviPayloadBytes);
    writeFourCC('movi');

    final offsets = <int>[];
    int currentOffset = 4;
    for (final frame in frames) {
      offsets.add(currentOffset);
      writeFourCC('00dc');
      writeU32(frame.length);
      builder.add(frame);
      if (frame.length.isOdd) {
        builder.addByte(0);
      }
      currentOffset += 8 + frame.length + (frame.length.isOdd ? 1 : 0);
    }

    writeFourCC('idx1');
    writeU32(idx1Bytes);
    for (int i = 0; i < frames.length; i++) {
      writeFourCC('00dc');
      writeU32(0x10);
      writeU32(offsets[i]);
      writeU32(frames[i].length);
    }

    final outFile = File(outputPath);
    await outFile.writeAsBytes(builder.takeBytes(), flush: true);
    return outFile;
  }

  Future<ExportedVideoBundle> exportVideoProject({
    required VideoProjectEntity project,
    required List<Uint8List> renderedFrames,
    required int width,
    required int height,
    required int fps,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${appDir.path}/exported_videos');
    if (!exportDir.existsSync()) {
      await exportDir.create(recursive: true);
    }

    final baseName =
        'love_reel_${project.id}_${DateTime.now().millisecondsSinceEpoch}';
    final coverFile = File('${exportDir.path}/$baseName.png');
    await coverFile.writeAsBytes(renderedFrames.first);

    final projectJsonFile = File('${exportDir.path}/$baseName.json');
    await projectJsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(project.toJson()),
    );

    final aviPath = '${exportDir.path}/$baseName.avi';
    await muxFramesToVideoContainer(
      frames: renderedFrames,
      outputPath: aviPath,
      width: width,
      height: height,
      fps: fps,
    );

    String finalVideoPath = aviPath;
    final mp4Path = '${exportDir.path}/$baseName.mp4';
    try {
      final res = await Process.run('ffmpeg', [
        '-y',
        '-i',
        aviPath,
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        mp4Path,
      ]);
      if (res.exitCode == 0 && File(mp4Path).existsSync()) {
        finalVideoPath = mp4Path;
      }
    } catch (_) {}

    return ExportedVideoBundle(
      coverImagePath: coverFile.path,
      projectJsonPath: projectJsonFile.path,
      videoFilePath: finalVideoPath,
      renderedFramesCount: renderedFrames.length,
    );
  }
}

class ExportedVideoBundle {
  final String coverImagePath;
  final String projectJsonPath;
  final String videoFilePath;
  final int renderedFramesCount;

  const ExportedVideoBundle({
    required this.coverImagePath,
    required this.projectJsonPath,
    required this.videoFilePath,
    required this.renderedFramesCount,
  });
}
