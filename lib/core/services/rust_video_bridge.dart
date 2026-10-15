// lib/core/services/rust_video_bridge.dart
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
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

typedef _SecondsToTicksNative = ffi.Int64 Function(ffi.Double seconds);
typedef _SecondsToTicksDart = int Function(double seconds);

typedef _TicksToSecondsNative = ffi.Double Function(ffi.Int64 ticks);
typedef _TicksToSecondsDart = double Function(int ticks);

typedef _ApplyEasingNative =
    ffi.Double Function(ffi.Double t, ffi.Int32 easingType);
typedef _ApplyEasingDart = double Function(double t, int easingType);

typedef _CatmullRomNative =
    ffi.Double Function(
      ffi.Double p0,
      ffi.Double p1,
      ffi.Double p2,
      ffi.Double p3,
      ffi.Double t,
    );
typedef _CatmullRomDart =
    double Function(double p0, double p1, double p2, double p3, double t);

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

typedef _ComputeLumetriMatrixNative =
    ffi.Void Function(
      ffi.Double exposure,
      ffi.Double contrast,
      ffi.Double saturation,
      ffi.Double temperature,
      ffi.Double fadedFilm,
      ffi.Pointer<ffi.Double> outMatrix20,
    );

typedef _ComputeLumetriMatrixDart =
    void Function(
      double exposure,
      double contrast,
      double saturation,
      double temperature,
      double fadedFilm,
      ffi.Pointer<ffi.Double> outMatrix20,
    );

typedef _BlendRgbaFramesNative =
    ffi.Void Function(
      ffi.Pointer<ffi.Uint8> frameA,
      ffi.Pointer<ffi.Uint8> frameB,
      ffi.Pointer<ffi.Uint8> output,
      ffi.Size length,
      ffi.Double progress,
    );

typedef _BlendRgbaFramesDart =
    void Function(
      ffi.Pointer<ffi.Uint8> frameA,
      ffi.Pointer<ffi.Uint8> frameB,
      ffi.Pointer<ffi.Uint8> output,
      int length,
      double progress,
    );

typedef _MuxFramesToAviNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> outputPathPtr,
      ffi.Size outputPathLen,
      ffi.Pointer<ffi.Uint8> framesConcatPtr,
      ffi.Pointer<ffi.Uint32> frameSizesPtr,
      ffi.Size numFrames,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Uint32 fps,
    );

typedef _MuxFramesToAviDart =
    int Function(
      ffi.Pointer<ffi.Uint8> outputPathPtr,
      int outputPathLen,
      ffi.Pointer<ffi.Uint8> framesConcatPtr,
      ffi.Pointer<ffi.Uint32> frameSizesPtr,
      int numFrames,
      int width,
      int height,
      int fps,
    );

typedef _MallocNative = ffi.Pointer<ffi.Void> Function(ffi.Size size);
typedef _MallocDart = ffi.Pointer<ffi.Void> Function(int size);

typedef _FreeNative = ffi.Void Function(ffi.Pointer<ffi.Void> ptr);
typedef _FreeDart = void Function(ffi.Pointer<ffi.Void> ptr);

/// جسر هجين يربط تطبيق Flutter بمحرك Rust الأصلي (`librust_video_engine`)
/// المستلهم من معمارية FilmCraft و EffectCraft:
/// - التوقيت الصحيح بدون انجراف (254,016,000,000 ticks/sec)
/// - استيفاء Catmull-Rom Auto-Bezier و Hold Keyframes
/// - مصفوفات تصحيح الألوان البرمجية Lumetri Color Grading (Rec.709) عبر `rust_compute_lumetri_matrix`
/// - تجميع الإطارات وتوليد حاوية الفيديو RIFF/AVI مباشرة عبر `rust_mux_frames_to_avi`
/// - حفظ الفيديوهات المصدّرة مباشرة في مجلد التنزيلات العام (`Download/OurLoveStory`)
class RustVideoBridge {
  static final RustVideoBridge instance = RustVideoBridge._();

  /// قاعدة التوقيت الدقيقة المعتمدة في FilmCraft: 254,016,000,000 نبضة في الثانية
  static const int ticksPerSecond = 254016000000;

  static const MethodChannel _mediaChannel = MethodChannel(
    'com.our.loveStory/media_bridge',
  );

  ffi.DynamicLibrary? _dylib;
  ffi.DynamicLibrary? _stdlib;

  _SecondsToTicksDart? _rustSecondsToTicks;
  _TicksToSecondsDart? _rustTicksToSeconds;
  _ApplyEasingDart? _rustApplyEasing;
  _CatmullRomDart? _rustCatmullRom;
  _InterpolateDart? _rustInterpolate;
  _ComputeLumetriMatrixDart? _rustComputeLumetriMatrix;
  _BlendRgbaFramesDart? _rustBlendRgbaFrames;
  _MuxFramesToAviDart? _rustMuxFramesToAvi;

  _MallocDart? _malloc;
  _FreeDart? _free;

  /// مخزن مؤقت مخصص مسبقاً في الذاكرة الأصلية لنتائج مصفوفة Lumetri (20 عنصر double)
  ffi.Pointer<ffi.Double>? _lumetriMatrixBuffer;

  RustVideoBridge._() {
    _tryLoadNativeAllocator();
    _tryLoadRustLibrary();
  }

  bool get isRustNativeLoaded =>
      _rustInterpolate != null &&
      _rustComputeLumetriMatrix != null &&
      _rustMuxFramesToAvi != null;

  int secondsToTicks(double seconds) {
    final rustFn = _rustSecondsToTicks;
    if (rustFn != null) {
      return rustFn(seconds);
    }
    return (seconds * ticksPerSecond).round();
  }

  double ticksToSeconds(int ticks) {
    final rustFn = _rustTicksToSeconds;
    if (rustFn != null) {
      return rustFn(ticks);
    }
    return ticks / ticksPerSecond;
  }

  void _tryLoadNativeAllocator() {
    try {
      _stdlib = Platform.isWindows
          ? ffi.DynamicLibrary.open('msvcrt.dll')
          : ffi.DynamicLibrary.process();
      _malloc = _stdlib!.lookupFunction<_MallocNative, _MallocDart>('malloc');
      _free = _stdlib!.lookupFunction<_FreeNative, _FreeDart>('free');

      final ptr = _alloc<ffi.Double>(20 * ffi.sizeOf<ffi.Double>());
      if (ptr != ffi.nullptr) {
        _lumetriMatrixBuffer = ptr;
      }
    } catch (_) {
      _malloc = null;
      _free = null;
      _lumetriMatrixBuffer = null;
    }
  }

  void _tryLoadRustLibrary() {
    try {
      if (Platform.isAndroid || Platform.isLinux) {
        _dylib = ffi.DynamicLibrary.open('librust_video_engine.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        _dylib = ffi.DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _dylib = ffi.DynamicLibrary.open('rust_video_engine.dll');
      }

      final lib = _dylib;
      if (lib != null) {
        _rustInterpolate = lib
            .lookupFunction<_InterpolateNative, _InterpolateDart>(
              'rust_interpolate_keyframes',
            );
        _rustComputeLumetriMatrix = lib
            .lookupFunction<
              _ComputeLumetriMatrixNative,
              _ComputeLumetriMatrixDart
            >('rust_compute_lumetri_matrix');
        _rustMuxFramesToAvi = lib
            .lookupFunction<_MuxFramesToAviNative, _MuxFramesToAviDart>(
              'rust_mux_frames_to_avi',
            );

        try {
          _rustSecondsToTicks = lib
              .lookupFunction<_SecondsToTicksNative, _SecondsToTicksDart>(
                'rust_seconds_to_ticks',
              );
          _rustTicksToSeconds = lib
              .lookupFunction<_TicksToSecondsNative, _TicksToSecondsDart>(
                'rust_ticks_to_seconds',
              );
          _rustApplyEasing = lib
              .lookupFunction<_ApplyEasingNative, _ApplyEasingDart>(
                'rust_apply_easing',
              );
          _rustCatmullRom = lib
              .lookupFunction<_CatmullRomNative, _CatmullRomDart>(
                'rust_catmull_rom_spline',
              );
          _rustBlendRgbaFrames = lib
              .lookupFunction<_BlendRgbaFramesNative, _BlendRgbaFramesDart>(
                'rust_blend_rgba_frames',
              );
        } catch (_) {}
      }
    } catch (_) {
      _rustInterpolate = null;
      _rustComputeLumetriMatrix = null;
      _rustMuxFramesToAvi = null;
    }
  }

  ffi.Pointer<T> _alloc<T extends ffi.NativeType>(int byteCount) {
    final mallocFn = _malloc;
    if (mallocFn == null || byteCount <= 0) {
      return ffi.nullptr;
    }
    return mallocFn(byteCount).cast<T>();
  }

  void _freePtr<T extends ffi.NativeType>(ffi.Pointer<T> ptr) {
    final freeFn = _free;
    if (freeFn != null && ptr != ffi.nullptr) {
      freeFn(ptr.cast<ffi.Void>());
    }
  }

  /// حساب قيم التحويل (Position, Scale, Rotation, Opacity) عند أي لحظة زمنية
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

    final prevTicks = secondsToTicks(prev.timestamp);
    final nextTicks = secondsToTicks(next.timestamp);
    final curTicks = secondsToTicks(localTime);
    final spanTicks = nextTicks - prevTicks;
    final rawT = spanTicks > 0
        ? ((curTicks - prevTicks) / spanTicks).clamp(0.0, 1.0)
        : 1.0;

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
    final rustFn = _rustCatmullRom;
    if (rustFn != null) {
      return rustFn(p0, p1, p2, p3, t);
    }
    final t2 = t * t;
    final t3 = t2 * t;
    return 0.5 *
        ((2.0 * p1) +
            (-p0 + p2) * t +
            (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
            (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3);
  }

  double _applyEasing(double t, KeyframeEasing easing) {
    final rustFn = _rustApplyEasing;
    if (rustFn != null) {
      return rustFn(t, easing.index);
    }
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
  /// يستدعي `rust_compute_lumetri_matrix` مباشرة عبر FFI عند توفر مكتبة Rust الأصلية.
  List<double> computeLumetriColorMatrix(LumetriColorGrade grade) {
    final rustCompute = _rustComputeLumetriMatrix;
    if (rustCompute != null) {
      final reusablePtr = _lumetriMatrixBuffer;
      if (reusablePtr != null && reusablePtr != ffi.nullptr) {
        rustCompute(
          grade.exposure,
          grade.contrast,
          grade.saturation,
          grade.temperature,
          grade.fadedFilm,
          reusablePtr,
        );
        return Float64List.fromList(reusablePtr.asTypedList(20));
      }

      final tempPtr = _alloc<ffi.Double>(20 * ffi.sizeOf<ffi.Double>());
      if (tempPtr != ffi.nullptr) {
        try {
          rustCompute(
            grade.exposure,
            grade.contrast,
            grade.saturation,
            grade.temperature,
            grade.fadedFilm,
            tempPtr,
          );
          return Float64List.fromList(tempPtr.asTypedList(20));
        } finally {
          _freePtr(tempPtr);
        }
      }
    }

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

  /// دمج بكسلات إطارين (RGBA8888) في الذاكرة عبر دالة Rust `rust_blend_rgba_frames`
  Uint8List blendRgbaFrames({
    required Uint8List frameA,
    required Uint8List frameB,
    required double progress,
  }) {
    final length = math.min(frameA.length, frameB.length);
    if (length == 0) {
      return Uint8List(0);
    }

    final rustBlend = _rustBlendRgbaFrames;
    if (rustBlend != null) {
      final ptrA = _alloc<ffi.Uint8>(length);
      final ptrB = _alloc<ffi.Uint8>(length);
      final ptrOut = _alloc<ffi.Uint8>(length);
      try {
        if (ptrA != ffi.nullptr &&
            ptrB != ffi.nullptr &&
            ptrOut != ffi.nullptr) {
          ptrA.asTypedList(length).setRange(0, length, frameA);
          ptrB.asTypedList(length).setRange(0, length, frameB);
          rustBlend(ptrA, ptrB, ptrOut, length, progress);
          return Uint8List.fromList(ptrOut.asTypedList(length));
        }
      } finally {
        _freePtr(ptrA);
        _freePtr(ptrB);
        _freePtr(ptrOut);
      }
    }

    final alpha = progress.clamp(0.0, 1.0);
    final invAlpha = 1.0 - alpha;
    final out = Uint8List(length);
    for (int i = 0; i < length; i++) {
      out[i] = (frameA[i] * invAlpha + frameB[i] * alpha).round().clamp(0, 255);
    }
    return out;
  }

  /// تجميع قائمة إطارات PNG ملتقطة من الـ Canvas إلى ملف فيديو قياسي (RIFF AVI Motion-PNG)
  /// يستدعي `rust_mux_frames_to_avi` مباشرة عبر FFI لتحقيق سرعة تجميع وتصدير فائقة.
  Future<File> muxFramesToVideoContainer({
    required List<Uint8List> frames,
    required String outputPath,
    required int width,
    required int height,
    required int fps,
  }) async {
    final rustMux = _rustMuxFramesToAvi;
    if (rustMux != null && frames.isNotEmpty) {
      final muxedInRust = _tryMuxFramesViaRustFfi(
        rustMux: rustMux,
        frames: frames,
        outputPath: outputPath,
        width: width,
        height: height,
        fps: fps,
      );
      if (muxedInRust) {
        return File(outputPath);
      }
    }

    return _muxFramesToVideoContainerDartFallback(
      frames: frames,
      outputPath: outputPath,
      width: width,
      height: height,
      fps: fps,
    );
  }

  bool _tryMuxFramesViaRustFfi({
    required _MuxFramesToAviDart rustMux,
    required List<Uint8List> frames,
    required String outputPath,
    required int width,
    required int height,
    required int fps,
  }) {
    final pathBytes = utf8.encode(outputPath);
    if (pathBytes.isEmpty) {
      return false;
    }

    int totalFramesBytes = 0;
    for (final frame in frames) {
      totalFramesBytes += frame.length;
    }
    if (totalFramesBytes <= 0) {
      return false;
    }

    final pathPtr = _alloc<ffi.Uint8>(pathBytes.length);
    final framesConcatPtr = _alloc<ffi.Uint8>(totalFramesBytes);
    final frameSizesPtr = _alloc<ffi.Uint32>(
      frames.length * ffi.sizeOf<ffi.Uint32>(),
    );

    try {
      if (pathPtr == ffi.nullptr ||
          framesConcatPtr == ffi.nullptr ||
          frameSizesPtr == ffi.nullptr) {
        return false;
      }

      pathPtr.asTypedList(pathBytes.length).setAll(0, pathBytes);

      final concatView = framesConcatPtr.asTypedList(totalFramesBytes);
      final sizesView = frameSizesPtr.asTypedList(frames.length);

      int cursor = 0;
      for (int i = 0; i < frames.length; i++) {
        final frame = frames[i];
        final frameLen = frame.length;
        sizesView[i] = frameLen;
        concatView.setRange(cursor, cursor + frameLen, frame);
        cursor += frameLen;
      }

      final status = rustMux(
        pathPtr,
        pathBytes.length,
        framesConcatPtr,
        frameSizesPtr,
        frames.length,
        width,
        height,
        fps,
      );

      return status == 0 && File(outputPath).existsSync();
    } catch (_) {
      return false;
    } finally {
      _freePtr(pathPtr);
      _freePtr(framesConcatPtr);
      _freePtr(frameSizesPtr);
    }
  }

  Future<File> _muxFramesToVideoContainerDartFallback({
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

  /// استخراج إطارات PNG من ملف RIFF/AVI المصدّر لمعاينته وتشغيله داخل التطبيق بسلاسة
  Future<List<Uint8List>> extractFramesFromAvi(String aviFilePath) async {
    final file = File(aviFilePath);
    if (!file.existsSync()) return const [];

    try {
      final bytes = await file.readAsBytes();
      final data = ByteData.sublistView(bytes);
      final frames = <Uint8List>[];

      int i = 12; // تخطي ترويسة RIFF....AVI
      while (i + 8 <= bytes.length) {
        final c0 = bytes[i];
        final c1 = bytes[i + 1];
        final c2 = bytes[i + 2];
        final c3 = bytes[i + 3];
        final chunkSize = data.getUint32(i + 4, Endian.little);

        if (c0 == 0x4C && c1 == 0x49 && c2 == 0x53 && c3 == 0x54) {
          i += 12;
          continue;
        }

        if (c0 == 0x30 && c1 == 0x30 && c2 == 0x64 && c3 == 0x63) {
          final frameStart = i + 8;
          final frameEnd = frameStart + chunkSize;
          if (frameEnd <= bytes.length && chunkSize > 0) {
            frames.add(Uint8List.sublistView(bytes, frameStart, frameEnd));
          }
        }

        final paddedSize = chunkSize + (chunkSize.isOdd ? 1 : 0);
        i += 8 + paddedSize;
      }
      return frames;
    } catch (_) {
      return const [];
    }
  }

  /// اختيار ملف موسيقى أو صوت من الهاتف عبر جسر النظام الأصلي
  Future<({String path, String name})?> pickAudioFileFromDevice() async {
    try {
      final res = await _mediaChannel.invokeMethod<Map<Object?, Object?>>(
        'pickAudioFile',
      );
      if (res == null) return null;
      final path = res['path']?.toString();
      final name = res['name']?.toString();
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        return (path: path, name: name ?? path.split('/').last);
      }
    } catch (_) {}
    return null;
  }

  /// حفظ ملف الفيديو المصدّر في مجلد التنزيلات العام (`Download/OurLoveStory`) لكي يصل إليه المستخدم بسهولة
  Future<String?> saveVideoToPublicDownloads(
    String sourcePath, {
    String? customFileName,
  }) async {
    final srcFile = File(sourcePath);
    if (!srcFile.existsSync()) return null;

    final fileName =
        customFileName ?? sourcePath.split(Platform.pathSeparator).last;
    final isMp4 = fileName.toLowerCase().endsWith('.mp4');
    final mimeType = isMp4 ? 'video/mp4' : 'video/x-msvideo';

    if (Platform.isAndroid) {
      try {
        final savedPath = await _mediaChannel.invokeMethod<String>(
          'saveToPublicDownloads',
          {'filePath': sourcePath, 'fileName': fileName, 'mimeType': mimeType},
        );
        if (savedPath != null && savedPath.isNotEmpty) {
          return savedPath;
        }
      } catch (_) {}

      for (final candidateDir in const [
        '/storage/emulated/0/Download/OurLoveStory',
        '/storage/emulated/0/Movies/OurLoveStory',
        '/storage/emulated/0/Download',
      ]) {
        try {
          final dir = Directory(candidateDir);
          if (!dir.existsSync()) {
            await dir.create(recursive: true);
          }
          final targetPath = '${dir.path}/$fileName';
          await srcFile.copy(targetPath);
          if (File(targetPath).existsSync()) {
            return targetPath;
          }
        } catch (_) {}
      }

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final pubDir = Directory('${extDir.path}/OurLoveStory_Videos');
          if (!pubDir.existsSync()) {
            await pubDir.create(recursive: true);
          }
          final targetPath = '${pubDir.path}/$fileName';
          await srcFile.copy(targetPath);
          return targetPath;
        }
      } catch (_) {}
    } else {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final targetDir = Directory('${downloadsDir.path}/OurLoveStory');
          if (!targetDir.existsSync()) {
            await targetDir.create(recursive: true);
          }
          final targetPath = '${targetDir.path}/$fileName';
          await srcFile.copy(targetPath);
          return targetPath;
        }
      } catch (_) {}
    }

    return null;
  }

  /// مشاركة الفيديو المصدّر أو فتحه بتطبيق خارجي
  Future<bool> shareExportedVideo(String filePath, {String? title}) async {
    try {
      final res = await _mediaChannel.invokeMethod<bool>('shareVideoFile', {
        'filePath': filePath,
        'title': title ?? 'فيديو ذكرياتنا 🎬',
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _prepareAudioFileForExport(VideoProjectEntity project) async {
    try {
      if (project.customAudioPath != null &&
          project.customAudioPath!.isNotEmpty &&
          File(project.customAudioPath!).existsSync()) {
        return project.customAudioPath;
      }
      if (project.audioAsset != null && project.audioAsset!.isNotEmpty) {
        final byteData = await rootBundle.load('assets/${project.audioAsset}');
        final tempDir = await getTemporaryDirectory();
        final ext = project.audioAsset!.split('.').last;
        final tempAudio = File('${tempDir.path}/export_bgm.$ext');
        await tempAudio.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          flush: true,
        );
        return tempAudio.path;
      }
    } catch (_) {}
    return null;
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

    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final baseName = 'love_reel_${project.id}_$timestampMs';

    final coverFile = File('${exportDir.path}/$baseName.png');
    await coverFile.writeAsBytes(renderedFrames.first, flush: true);

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
    final preparedAudioPath = await _prepareAudioFileForExport(project);

    try {
      final ffmpegArgs = <String>['-y', '-i', aviPath];
      if (preparedAudioPath != null && File(preparedAudioPath).existsSync()) {
        if (project.audioStartOffset > 0) {
          ffmpegArgs.addAll([
            '-ss',
            project.audioStartOffset.toStringAsFixed(2),
          ]);
        }
        ffmpegArgs.addAll(['-i', preparedAudioPath]);
      }
      ffmpegArgs.addAll(['-c:v', 'libx264', '-pix_fmt', 'yuv420p']);
      if (preparedAudioPath != null && File(preparedAudioPath).existsSync()) {
        ffmpegArgs.addAll(['-c:a', 'aac', '-shortest']);
      }
      ffmpegArgs.add(mp4Path);

      final res = await Process.run('ffmpeg', ffmpegArgs);
      if (res.exitCode == 0 && File(mp4Path).existsSync()) {
        finalVideoPath = mp4Path;
      }
    } catch (_) {}

    final ext = finalVideoPath.split('.').last;
    final publicFileName = '$baseName.$ext';
    final publicPath = await saveVideoToPublicDownloads(
      finalVideoPath,
      customFileName: publicFileName,
    );

    final projectJsonFile = File('${exportDir.path}/$baseName.json');
    final jsonMap = project.toJson()
      ..['exportedVideoPath'] = finalVideoPath
      ..['publicVideoPath'] = publicPath ?? finalVideoPath
      ..['coverImagePath'] = coverFile.path
      ..['renderedFramesCount'] = renderedFrames.length
      ..['exportedFps'] = fps
      ..['exportedAt'] = DateTime.now().toIso8601String();

    await projectJsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonMap),
      flush: true,
    );

    final fileBytes = File(finalVideoPath).existsSync()
        ? File(finalVideoPath).lengthSync()
        : 0;

    return ExportedVideoBundle(
      title: project.title,
      coverImagePath: coverFile.path,
      projectJsonPath: projectJsonFile.path,
      videoFilePath: finalVideoPath,
      publicVideoPath: publicPath ?? finalVideoPath,
      renderedFramesCount: renderedFrames.length,
      fps: fps,
      fileSizeBytes: fileBytes,
      exportedAt: DateTime.now(),
    );
  }

  /// جلب قائمة جميع الفيديوهات المصدّرة لعرضها وإدارتها (تشغيل، تعديل، حفظ، حذف) داخل الاستوديو
  Future<List<ExportedVideoBundle>> listExportedVideoBundles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDir.path}/exported_videos');
      if (!exportDir.existsSync()) return const [];

      final bundles = <ExportedVideoBundle>[];
      final files = exportDir.listSync().whereType<File>().toList();
      final jsonFiles = files.where((f) => f.path.endsWith('.json')).toList();

      for (final jsonFile in jsonFiles) {
        try {
          final raw = await jsonFile.readAsString();
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final basePath = jsonFile.path.substring(0, jsonFile.path.length - 5);
          final mp4Candidate = '$basePath.mp4';
          final aviCandidate = '$basePath.avi';
          final pngCandidate = '$basePath.png';

          final resolvedVideoPath =
              (map['exportedVideoPath'] as String?) != null &&
                  File(map['exportedVideoPath'] as String).existsSync()
              ? (map['exportedVideoPath'] as String)
              : (File(mp4Candidate).existsSync() ? mp4Candidate : aviCandidate);

          if (!File(resolvedVideoPath).existsSync()) continue;

          final resolvedCoverPath =
              (map['coverImagePath'] as String?) ?? pngCandidate;
          final publicPath =
              (map['publicVideoPath'] as String?) ?? resolvedVideoPath;
          final framesCount =
              (map['renderedFramesCount'] as num?)?.toInt() ?? 0;
          final fps = (map['exportedFps'] as num?)?.toInt() ?? 8;
          final exportedAt =
              DateTime.tryParse((map['exportedAt'] as String?) ?? '') ??
              jsonFile.lastModifiedSync();

          bundles.add(
            ExportedVideoBundle(
              title: (map['title'] as String?) ?? 'فيديو ذكرياتنا',
              coverImagePath: resolvedCoverPath,
              projectJsonPath: jsonFile.path,
              videoFilePath: resolvedVideoPath,
              publicVideoPath: publicPath,
              renderedFramesCount: framesCount,
              fps: fps,
              fileSizeBytes: File(resolvedVideoPath).lengthSync(),
              exportedAt: exportedAt,
            ),
          );
        } catch (_) {}
      }

      bundles.sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
      return bundles;
    } catch (_) {
      return const [];
    }
  }

  /// حذف فيديو مصدّر مع كافة ملفاته المرتبطة
  Future<void> deleteExportedBundle(ExportedVideoBundle bundle) async {
    final paths = <String>{
      bundle.videoFilePath,
      bundle.coverImagePath,
      bundle.projectJsonPath,
      bundle.publicVideoPath,
      bundle.projectJsonPath.replaceAll('.json', '.avi'),
      bundle.projectJsonPath.replaceAll('.json', '.mp4'),
    };
    for (final p in paths) {
      try {
        if (p.isNotEmpty && File(p).existsSync()) {
          await File(p).delete();
        }
      } catch (_) {}
    }
  }
}

class ExportedVideoBundle {
  final String title;
  final String coverImagePath;
  final String projectJsonPath;
  final String videoFilePath;
  final String publicVideoPath;
  final int renderedFramesCount;
  final int fps;
  final int fileSizeBytes;
  final DateTime? _exportedAt;

  const ExportedVideoBundle({
    this.title = 'فيديو ذكرياتنا',
    required this.coverImagePath,
    required this.projectJsonPath,
    required this.videoFilePath,
    String? publicVideoPath,
    required this.renderedFramesCount,
    this.fps = 8,
    this.fileSizeBytes = 0,
    DateTime? exportedAt,
  }) : publicVideoPath = publicVideoPath ?? videoFilePath,
       _exportedAt = exportedAt;

  DateTime get exportedAt =>
      _exportedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  String get readableFileSize {
    if (fileSizeBytes <= 0) return '';
    final kb = fileSizeBytes / 1024.0;
    if (kb < 1024.0) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }

  bool get isSavedInPublicDownloads =>
      publicVideoPath.contains('/Download/') ||
      publicVideoPath.contains('/Movies/');
}
