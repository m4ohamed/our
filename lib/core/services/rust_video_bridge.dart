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

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List<void Function()>.from(_listeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  void addListener(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void throwIfCancelled([
    VideoExportStage stage = VideoExportStage.cancelled,
  ]) {
    if (_isCancelled) {
      throw VideoExportException(
        stage: stage,
        message: 'تم إلغاء عملية التصدير بواسطة المستخدم.',
        isCancelled: true,
      );
    }
  }
}

/// استثناء مخصص لمراحل تصدير الفيديو يحدد المرحلة الدقيقة وسبب التوقف (VID-012 / VID-014)
class VideoExportException implements Exception {
  final VideoExportStage stage;
  final String message;
  final bool isCancelled;
  final Object? cause;

  const VideoExportException({
    required this.stage,
    required this.message,
    this.isCancelled = false,
    this.cause,
  });

  @override
  String toString() => '[${stage.arabicLabel}] $message';
}

/// حالات معالجة Lumetri الصريحة لمنع النجاح الصامت عند الفشل (VID-007)
enum LumetriProcessStatus {
  notRequired,
  appliedNative,
  appliedDartFallback,
  failed,
  unsupported,
}

class LumetriBatchResult {
  final LumetriProcessStatus status;
  final Uint8List bytes;
  final String? errorMessage;

  const LumetriBatchResult({
    required this.status,
    required this.bytes,
    this.errorMessage,
  });

  bool get isSuccess =>
      status == LumetriProcessStatus.notRequired ||
      status == LumetriProcessStatus.appliedNative ||
      status == LumetriProcessStatus.appliedDartFallback;
}

/// قدرات الترميز العتادي للجهاز لفحص دعم H.264 و HEVC قبل التصدير (VID-017)
class DeviceEncoderCapabilities {
  final bool supportsH264;
  final bool supportsHevc;
  final bool supports1080p60H264;
  final bool supports1080p60Hevc;
  final int maxSupportedBitrateBps;

  const DeviceEncoderCapabilities({
    this.supportsH264 = true,
    this.supportsHevc = true,
    this.supports1080p60H264 = true,
    this.supports1080p60Hevc = true,
    this.maxSupportedBitrateBps = 20000000,
  });
}

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

typedef _GetHardwareConcurrencyNative = ffi.Uint32 Function();
typedef _GetHardwareConcurrencyDart = int Function();

typedef _SecondsToTicksNative = ffi.Int64 Function(ffi.Double seconds);
typedef _SecondsToTicksDart = int Function(double seconds);

typedef _TicksToSecondsNative = ffi.Double Function(ffi.Int64 ticks);
typedef _TicksToSecondsDart = double Function(int ticks);

typedef _TicksToAudioSampleNative =
    ffi.Int64 Function(ffi.Int64 ticks, ffi.Uint32 sampleRate);
typedef _TicksToAudioSampleDart = int Function(int ticks, int sampleRate);

typedef _FrameIndexToSecondsNative =
    ffi.Double Function(ffi.Uint32 frameIndex, ffi.Uint32 targetFps);
typedef _FrameIndexToSecondsDart =
    double Function(int frameIndex, int targetFps);

typedef _ApplyEasingNative =
    ffi.Double Function(ffi.Double t, ffi.Int32 easingType);
typedef _ApplyEasingDart = double Function(double t, int easingType);

typedef _SolveCubicBezier2dNative =
    ffi.Double Function(
      ffi.Double x1,
      ffi.Double y1,
      ffi.Double x2,
      ffi.Double y2,
      ffi.Double t,
    );
typedef _SolveCubicBezier2dDart =
    double Function(double x1, double y1, double x2, double y2, double t);

typedef _CubicBezierEvalNative =
    ffi.Double Function(
      ffi.Double p0,
      ffi.Double p1,
      ffi.Double p2,
      ffi.Double p3,
      ffi.Double t,
    );
typedef _CubicBezierEvalDart =
    double Function(double p0, double p1, double p2, double p3, double t);

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

typedef _RgbaToBt709Yuv420StridedNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> rgbaPtr,
      ffi.Pointer<ffi.Uint8> yOutPtr,
      ffi.Pointer<ffi.Uint8> uOutPtr,
      ffi.Pointer<ffi.Uint8> vOutPtr,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Uint32 yRowStride,
      ffi.Uint32 uvRowStride,
      ffi.Uint32 uvPixelStride,
    );

typedef _RgbaToBt709Yuv420StridedDart =
    int Function(
      ffi.Pointer<ffi.Uint8> rgbaPtr,
      ffi.Pointer<ffi.Uint8> yOutPtr,
      ffi.Pointer<ffi.Uint8> uOutPtr,
      ffi.Pointer<ffi.Uint8> vOutPtr,
      int width,
      int height,
      int yRowStride,
      int uvRowStride,
      int uvPixelStride,
    );

typedef _ProcessRgbaBatchLumetriNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> rgbaBatchPtr,
      ffi.Size numFrames,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Double exposure,
      ffi.Double contrast,
      ffi.Double saturation,
      ffi.Double temperature,
      ffi.Double fadedFilm,
      ffi.Double vignette,
    );

typedef _ProcessRgbaBatchLumetriDart =
    int Function(
      ffi.Pointer<ffi.Uint8> rgbaBatchPtr,
      int numFrames,
      int width,
      int height,
      double exposure,
      double contrast,
      double saturation,
      double temperature,
      double fadedFilm,
      double vignette,
    );

typedef _RgbaBatchToBt709Nv12Native =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> rgbaBatchPtr,
      ffi.Pointer<ffi.Uint8> nv12BatchOutPtr,
      ffi.Size numFrames,
      ffi.Uint32 width,
      ffi.Uint32 height,
    );

typedef _RgbaBatchToBt709Nv12Dart =
    int Function(
      ffi.Pointer<ffi.Uint8> rgbaBatchPtr,
      ffi.Pointer<ffi.Uint8> nv12BatchOutPtr,
      int numFrames,
      int width,
      int height,
    );

typedef _RgbaToNv12Native =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> rgbaPtr,
      ffi.Pointer<ffi.Uint8> nv12OutPtr,
      ffi.Uint32 width,
      ffi.Uint32 height,
    );

typedef _RgbaToNv12Dart =
    int Function(
      ffi.Pointer<ffi.Uint8> rgbaPtr,
      ffi.Pointer<ffi.Uint8> nv12OutPtr,
      int width,
      int height,
    );

typedef _MixPcm16OverlayNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> masterPcmPtr,
      ffi.Size masterByteLen,
      ffi.Pointer<ffi.Uint8> overlayPcmPtr,
      ffi.Size overlayByteLen,
      ffi.Uint32 sampleRate,
      ffi.Uint16 channels,
      ffi.Double startTimeSeconds,
      ffi.Double overlayVolume,
    );

typedef _MixPcm16OverlayDart =
    int Function(
      ffi.Pointer<ffi.Uint8> masterPcmPtr,
      int masterByteLen,
      ffi.Pointer<ffi.Uint8> overlayPcmPtr,
      int overlayByteLen,
      int sampleRate,
      int channels,
      double startTimeSeconds,
      double overlayVolume,
    );

typedef _MixPcm16OverlayResampledNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> masterPcmPtr,
      ffi.Size masterByteLen,
      ffi.Pointer<ffi.Uint8> overlayPcmPtr,
      ffi.Size overlayByteLen,
      ffi.Uint32 masterSampleRate,
      ffi.Uint16 masterChannels,
      ffi.Uint32 overlaySampleRate,
      ffi.Uint16 overlayChannels,
      ffi.Double startTimeSeconds,
      ffi.Double overlayVolume,
    );

typedef _MixPcm16OverlayResampledDart =
    int Function(
      ffi.Pointer<ffi.Uint8> masterPcmPtr,
      int masterByteLen,
      ffi.Pointer<ffi.Uint8> overlayPcmPtr,
      int overlayByteLen,
      int masterSampleRate,
      int masterChannels,
      int overlaySampleRate,
      int overlayChannels,
      double startTimeSeconds,
      double overlayVolume,
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

typedef _MuxFramesAndPcmToAviNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> outputPathPtr,
      ffi.Size outputPathLen,
      ffi.Pointer<ffi.Uint8> framesConcatPtr,
      ffi.Pointer<ffi.Uint32> frameSizesPtr,
      ffi.Size numFrames,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Uint32 fps,
      ffi.Pointer<ffi.Uint8> pcmDataPtr,
      ffi.Size pcmByteLen,
      ffi.Uint32 sampleRate,
      ffi.Uint16 channels,
    );

typedef _MuxFramesAndPcmToAviDart =
    int Function(
      ffi.Pointer<ffi.Uint8> outputPathPtr,
      int outputPathLen,
      ffi.Pointer<ffi.Uint8> framesConcatPtr,
      ffi.Pointer<ffi.Uint32> frameSizesPtr,
      int numFrames,
      int width,
      int height,
      int fps,
      ffi.Pointer<ffi.Uint8> pcmDataPtr,
      int pcmByteLen,
      int sampleRate,
      int channels,
    );

typedef _MuxFramesAndPcmToAviCheckedNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> outputPathPtr,
      ffi.Size outputPathLen,
      ffi.Pointer<ffi.Uint8> framesConcatPtr,
      ffi.Size framesConcatLen,
      ffi.Pointer<ffi.Uint32> frameSizesPtr,
      ffi.Size numFrames,
      ffi.Uint32 width,
      ffi.Uint32 height,
      ffi.Uint32 fps,
      ffi.Pointer<ffi.Uint8> pcmDataPtr,
      ffi.Size pcmByteLen,
      ffi.Uint32 sampleRate,
      ffi.Uint16 channels,
    );

typedef _MuxFramesAndPcmToAviCheckedDart =
    int Function(
      ffi.Pointer<ffi.Uint8> outputPathPtr,
      int outputPathLen,
      ffi.Pointer<ffi.Uint8> framesConcatPtr,
      int framesConcatLen,
      ffi.Pointer<ffi.Uint32> frameSizesPtr,
      int numFrames,
      int width,
      int height,
      int fps,
      ffi.Pointer<ffi.Uint8> pcmDataPtr,
      int pcmByteLen,
      int sampleRate,
      int channels,
    );

typedef _ProcessPcm16AudioNative =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Uint8> pcmBytesPtr,
      ffi.Size pcmByteLen,
      ffi.Uint32 sampleRate,
      ffi.Uint16 channels,
      ffi.Double volume,
      ffi.Int32 fadeIn,
      ffi.Int32 fadeOut,
    );

typedef _ProcessPcm16AudioDart =
    int Function(
      ffi.Pointer<ffi.Uint8> pcmBytesPtr,
      int pcmByteLen,
      int sampleRate,
      int channels,
      double volume,
      int fadeIn,
      int fadeOut,
    );

typedef _MallocNative = ffi.Pointer<ffi.Void> Function(ffi.Size size);
typedef _MallocDart = ffi.Pointer<ffi.Void> Function(int size);

typedef _FreeNative = ffi.Void Function(ffi.Pointer<ffi.Void> ptr);
typedef _FreeDart = void Function(ffi.Pointer<ffi.Void> ptr);

/// جسر هجين يربط تطبيق Flutter بمحرك Rust الأصلي (`librust_video_engine`)
class RustVideoBridge {
  static final RustVideoBridge instance = RustVideoBridge._();

  /// قاعدة التوقيت الدقيقة المعتمدة في FilmCraft: 254,016,000,000 نبضة في الثانية
  static const int ticksPerSecond = 254016000000;

  /// الحد الأقصى لأبعاد الإطار (VID-004 / VID-011)
  static const int maxFrameDimension = 8192;

  /// الحد الأقصى لعدد الإطارات في عملية تجميع واحدة (VID-004)
  static const int maxMuxFrames = 108000;

  /// التوقيع القياسي لملفات PNG (8 بايت)
  static const List<int> pngSignature = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];

  static const MethodChannel _mediaChannel = MethodChannel(
    'com.our.loveStory/media_bridge',
  );

  ffi.DynamicLibrary? _dylib;
  ffi.DynamicLibrary? _stdlib;

  _GetHardwareConcurrencyDart? _rustGetHardwareConcurrency;
  _SecondsToTicksDart? _rustSecondsToTicks;
  _TicksToSecondsDart? _rustTicksToSeconds;
  _TicksToAudioSampleDart? _rustTicksToAudioSample;
  _FrameIndexToSecondsDart? _rustFrameIndexToSeconds;
  _ApplyEasingDart? _rustApplyEasing;
  _SolveCubicBezier2dDart? _rustSolveCubicBezier2d;
  _CubicBezierEvalDart? _rustCubicBezierEval;
  _CatmullRomDart? _rustCatmullRom;
  _InterpolateDart? _rustInterpolate;
  _ComputeLumetriMatrixDart? _rustComputeLumetriMatrix;
  _BlendRgbaFramesDart? _rustBlendRgbaFrames;
  _RgbaToBt709Yuv420StridedDart? _rustRgbaToBt709Yuv420Strided;
  _ProcessRgbaBatchLumetriDart? _rustProcessRgbaBatchLumetri;
  _RgbaBatchToBt709Nv12Dart? _rustRgbaBatchToBt709Nv12;
  _RgbaToNv12Dart? _rustRgbaToNv12;
  _MixPcm16OverlayDart? _rustMixPcm16Overlay;
  _MixPcm16OverlayResampledDart? _rustMixPcm16OverlayResampled;
  _MuxFramesToAviDart? _rustMuxFramesToAvi;
  _MuxFramesAndPcmToAviDart? _rustMuxFramesAndPcmToAvi;
  _MuxFramesAndPcmToAviCheckedDart? _rustMuxFramesAndPcmToAviChecked;
  _ProcessPcm16AudioDart? _rustProcessPcm16Audio;

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

  /// عدد أنوية المعالج الفعلية لتحديد حجم دفعة الرندر المتوازي (Parallel Batch Size)
  int getHardwareConcurrency() {
    final rustFn = _rustGetHardwareConcurrency;
    if (rustFn != null) {
      return rustFn().clamp(2, 8);
    }
    return Platform.numberOfProcessors.clamp(2, 8);
  }

  /// تحويل الثواني إلى نبضات صحيحة (Exact Integer Ticks)
  /// القاعدة العددية الموحدة (VID-010): `round()` لأقرب عدد صحيح مع حماية القيم غير المحدودة.
  int secondsToTicks(double seconds) {
    if (!seconds.isFinite) return 0;
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

  /// تحويل النبضات الزمنية (Ticks) إلى فهرس إطار عينة صوتية دقيق (VID-010)
  /// القاعدة العددية الموحدة بين Rust وDart: قسمة صحيحة مقتطعة (`~/`) بحساب `BigInt` (مكافئ `i128` في Rust)
  /// لمنع أي انحراف ناتج عن تقريب الأعداد العشرية في المدد الطويلة.
  int ticksToAudioSample(int ticks, int sampleRate) {
    if (ticks <= 0 || sampleRate <= 0) return 0;
    final rustFn = _rustTicksToAudioSample;
    if (rustFn != null) {
      return rustFn(ticks, sampleRate);
    }
    final num = BigInt.from(ticks) * BigInt.from(sampleRate);
    final den = BigInt.from(ticksPerSecond);
    return (num ~/ den).toInt();
  }

  /// حساب وقت الإطار بالثواني من رقم الإطار ومعدل الإطارات المستهدف عبر النبضات الزمنية الدقيقة (VID-002 / VID-010)
  double frameIndexToSeconds(int frameIndex, int targetFps) {
    if (frameIndex <= 0 || targetFps <= 0) return 0.0;
    final rustFn = _rustFrameIndexToSeconds;
    if (rustFn != null) {
      return rustFn(frameIndex, targetFps);
    }
    final int ticksPerFrame = ticksPerSecond ~/ targetFps;
    final int frameTicks = frameIndex * ticksPerFrame;
    return frameTicks / ticksPerSecond;
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
          _rustGetHardwareConcurrency = lib
              .lookupFunction<
                _GetHardwareConcurrencyNative,
                _GetHardwareConcurrencyDart
              >('rust_get_hardware_concurrency');
          _rustSecondsToTicks = lib
              .lookupFunction<_SecondsToTicksNative, _SecondsToTicksDart>(
                'rust_seconds_to_ticks',
              );
          _rustTicksToSeconds = lib
              .lookupFunction<_TicksToSecondsNative, _TicksToSecondsDart>(
                'rust_ticks_to_seconds',
              );
          _rustTicksToAudioSample = lib
              .lookupFunction<
                _TicksToAudioSampleNative,
                _TicksToAudioSampleDart
              >('rust_ticks_to_audio_sample');
          _rustApplyEasing = lib
              .lookupFunction<_ApplyEasingNative, _ApplyEasingDart>(
                'rust_apply_easing',
              );
          _rustSolveCubicBezier2d = lib
              .lookupFunction<
                _SolveCubicBezier2dNative,
                _SolveCubicBezier2dDart
              >('rust_solve_cubic_bezier_2d');
          _rustCubicBezierEval = lib
              .lookupFunction<_CubicBezierEvalNative, _CubicBezierEvalDart>(
                'rust_cubic_bezier_eval',
              );
          _rustCatmullRom = lib
              .lookupFunction<_CatmullRomNative, _CatmullRomDart>(
                'rust_catmull_rom_spline',
              );
          _rustBlendRgbaFrames = lib
              .lookupFunction<_BlendRgbaFramesNative, _BlendRgbaFramesDart>(
                'rust_blend_rgba_frames',
              );
          _rustRgbaToBt709Yuv420Strided = lib
              .lookupFunction<
                _RgbaToBt709Yuv420StridedNative,
                _RgbaToBt709Yuv420StridedDart
              >('rust_rgba_to_bt709_yuv420_strided');
          _rustProcessRgbaBatchLumetri = lib
              .lookupFunction<
                _ProcessRgbaBatchLumetriNative,
                _ProcessRgbaBatchLumetriDart
              >('rust_process_rgba_batch_lumetri');
          _rustRgbaBatchToBt709Nv12 = lib
              .lookupFunction<
                _RgbaBatchToBt709Nv12Native,
                _RgbaBatchToBt709Nv12Dart
              >('rust_rgba_batch_to_bt709_nv12');
          _rustRgbaToNv12 = lib
              .lookupFunction<_RgbaToNv12Native, _RgbaToNv12Dart>(
                'rust_rgba_to_nv12',
              );
          _rustMixPcm16Overlay = lib
              .lookupFunction<_MixPcm16OverlayNative, _MixPcm16OverlayDart>(
                'rust_mix_pcm16_overlay',
              );
          _rustMuxFramesAndPcmToAvi = lib
              .lookupFunction<
                _MuxFramesAndPcmToAviNative,
                _MuxFramesAndPcmToAviDart
              >('rust_mux_frames_and_pcm_to_avi');
          _rustProcessPcm16Audio = lib
              .lookupFunction<_ProcessPcm16AudioNative, _ProcessPcm16AudioDart>(
                'rust_process_pcm16_audio',
              );
        } catch (_) {}

        // دوال موسعة اختيارية في حال توفرت في النسخة المترجمة من المكتبة
        try {
          _rustFrameIndexToSeconds = lib
              .lookupFunction<
                _FrameIndexToSecondsNative,
                _FrameIndexToSecondsDart
              >('rust_frame_index_to_seconds');
        } catch (_) {}
        try {
          _rustMixPcm16OverlayResampled = lib
              .lookupFunction<
                _MixPcm16OverlayResampledNative,
                _MixPcm16OverlayResampledDart
              >('rust_mix_pcm16_overlay_resampled');
        } catch (_) {}
        try {
          _rustMuxFramesAndPcmToAviChecked = lib
              .lookupFunction<
                _MuxFramesAndPcmToAviCheckedNative,
                _MuxFramesAndPcmToAviCheckedDart
              >('rust_mux_frames_and_pcm_to_avi_checked');
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
    if (mallocFn == null ||
        byteCount <= 0 ||
        byteCount > 1536 * 1024 * 1024) {
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

  /// حل معادلة الزمن x(u) = t لمنحنى Cubic Bezier ثنائي البعد عبر Newton-Raphson + Bisection
  /// مطابق عددياً 100% لتنفيذ Rust في `rust_solve_cubic_bezier_2d` (VID-010)
  double solveCubicBezier2d(
    double x1,
    double y1,
    double x2,
    double y2,
    double t,
  ) {
    if (!t.isFinite) return 0.0;
    final rustSolver = _rustSolveCubicBezier2d;
    if (rustSolver != null) {
      return rustSolver(x1, y1, x2, y2, t);
    }
    final clampedT = t.clamp(0.0, 1.0);
    if (clampedT <= 0.0) return 0.0;
    if (clampedT >= 1.0) return 1.0;

    final cx1 = x1.clamp(0.0, 1.0);
    final cx2 = x2.clamp(0.0, 1.0);
    if ((cx1 - y1).abs() < 1e-7 && (cx2 - y2).abs() < 1e-7) {
      return clampedT;
    }

    double sampleAxis(double c1, double c2, double u) {
      final inv = 1.0 - u;
      return 3.0 * inv * inv * u * c1 + 3.0 * inv * u * u * c2 + u * u * u;
    }

    double sampleDeriv(double c1, double c2, double u) {
      final inv = 1.0 - u;
      return 3.0 * inv * inv * c1 +
          6.0 * inv * u * (c2 - c1) +
          3.0 * u * u * (1.0 - c2);
    }

    // 1. 6 تكرارات سريعة بطريقة Newton-Raphson
    double u = clampedT;
    for (int i = 0; i < 6; i++) {
      final err = sampleAxis(cx1, cx2, u) - clampedT;
      if (err.abs() < 1e-7) return sampleAxis(y1, y2, u);
      final d = sampleDeriv(cx1, cx2, u);
      if (d.abs() < 1e-6) break;
      u = (u - err / d).clamp(0.0, 1.0);
    }

    // 2. بديل التنصيف المضمون (Bisection) عند المنحنيات الحادة (مطابق لـ Rust VID-010)
    double lo = 0.0;
    double hi = 1.0;
    u = clampedT;
    for (int i = 0; i < 10; i++) {
      final xVal = sampleAxis(cx1, cx2, u);
      if ((xVal - clampedT).abs() < 1e-7) break;
      if (clampedT > xVal) {
        lo = u;
      } else {
        hi = u;
      }
      u = 0.5 * (lo + hi);
    }

    return sampleAxis(y1, y2, u);
  }

  /// استيفاء منحنى Cubic Bezier عبر دالة Rust `rust_cubic_bezier_eval`
  double evaluateCubicBezier(
    double p0,
    double p1,
    double p2,
    double p3,
    double t,
  ) {
    final rustFn = _rustCubicBezierEval;
    if (rustFn != null) {
      return rustFn(p0, p1, p2, p3, t);
    }
    final u = t.clamp(0.0, 1.0);
    final inv = 1.0 - u;
    return (inv * inv * inv) * p0 +
        3.0 * (inv * inv) * u * p1 +
        3.0 * inv * (u * u) * p2 +
        (u * u * u) * p3;
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
    final u = t.clamp(0.0, 1.0);
    final t2 = u * u;
    final t3 = t2 * u;
    return 0.5 *
        ((2.0 * p1) +
            (-p0 + p2) * u +
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
      KeyframeEasing.easeIn => solveCubicBezier2d(0.42, 0.0, 1.0, 1.0, c),
      KeyframeEasing.easeOut => solveCubicBezier2d(0.0, 0.0, 0.58, 1.0, c),
      KeyframeEasing.easeInOut => solveCubicBezier2d(0.42, 0.0, 0.58, 1.0, c),
      KeyframeEasing.elasticOut =>
        (c == 0.0 || c == 1.0)
            ? c
            : math.pow(2.0, -10.0 * c).toDouble() *
                      math.sin((c * 10.0 - 0.75) * ((2.0 * math.pi) / 3.0)) +
                  1.0,
      KeyframeEasing.hold => c < 1.0 ? 0.0 : 1.0,
      KeyframeEasing.autoBezier => solveCubicBezier2d(0.25, 0.1, 0.25, 1.0, c),
    };
  }

  /// توليد مصفوفة تصحيح الألوان 4x5 (20 عنصراً) بأسلوب Lumetri Color في FilmCraft
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

    return _computeLumetriMatrixDart(grade);
  }

  List<double> _computeLumetriMatrixDart(LumetriColorGrade grade) {
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
      out[i] = (frameA[i] * invAlpha + frameB[i] * alpha)
          .round()
          .clamp(0, 255);
    }
    return out;
  }

  /// معالجة دفعة إطارات RGBA8888 بتصحيح ألوان Lumetri مع إرجاع حالة صريحة (VID-007)
  /// تفصل بوضوح بين:
  /// 1. `notRequired` (عندما تكون إعدادات Lumetri افتراضية `grade.isIdentity`).
  /// 2. `appliedNative` (تم التطبيق بنجاح في Rust بالتوازي).
  /// 3. `appliedDartFallback` (تم التطبيق بنجاح في مسار التوافق البرمجي).
  /// 4. `failed` / `unsupported` (فشل التحقق من المدخلات أو الإعدادات غير المدعومة).
  LumetriBatchResult processRgbaBatchLumetriWithStatus({
    required Uint8List rgbaBatchBytes,
    required int numFrames,
    required int width,
    required int height,
    required LumetriColorGrade grade,
    bool allowSoftwareFallback = true,
  }) {
    if (!grade.hasValidParameters) {
      return LumetriBatchResult(
        status: LumetriProcessStatus.unsupported,
        bytes: Uint8List(0),
        errorMessage: 'إعدادات Lumetri تحتوي على معاملات خارج النطاق المدعوم.',
      );
    }
    if (numFrames <= 0 ||
        width <= 0 ||
        height <= 0 ||
        width > maxFrameDimension ||
        height > maxFrameDimension) {
      return LumetriBatchResult(
        status: LumetriProcessStatus.failed,
        bytes: Uint8List(0),
        errorMessage:
            'أبعاد الدفعة أو عدد الإطارات غير صالح ($numFrames frames @ ${width}x$height).',
      );
    }
    final expected = numFrames * width * height * 4;
    if (rgbaBatchBytes.length < expected) {
      return LumetriBatchResult(
        status: LumetriProcessStatus.failed,
        bytes: Uint8List(0),
        errorMessage:
            'حجم مخزن RGBA (${rgbaBatchBytes.length}) أصغر من الحجم المطلوب ($expected بايت).',
      );
    }

    // الحالة 1: التأثير غير مطلوب (Identity)
    if (grade.isIdentity) {
      return LumetriBatchResult(
        status: LumetriProcessStatus.notRequired,
        bytes: Uint8List.fromList(rgbaBatchBytes.sublist(0, expected)),
      );
    }

    // الحالة 2: محاولة المعالجة الأصلية في Rust
    final rustBatch = _rustProcessRgbaBatchLumetri;
    if (rustBatch != null) {
      final batchPtr = _alloc<ffi.Uint8>(expected);
      if (batchPtr != ffi.nullptr) {
        try {
          batchPtr.asTypedList(expected).setRange(0, expected, rgbaBatchBytes);
          final status = rustBatch(
            batchPtr,
            numFrames,
            width,
            height,
            grade.exposure,
            grade.contrast,
            grade.saturation,
            grade.temperature,
            grade.fadedFilm,
            grade.vignette,
          );
          if (status == 0) {
            return LumetriBatchResult(
              status: LumetriProcessStatus.appliedNative,
              bytes: Uint8List.fromList(batchPtr.asTypedList(expected)),
            );
          }
        } finally {
          _freePtr(batchPtr);
        }
      }
    }

    if (!allowSoftwareFallback) {
      return LumetriBatchResult(
        status: LumetriProcessStatus.failed,
        bytes: Uint8List(0),
        errorMessage: 'تعذر تطبيق تأثير Lumetri عبر المحرك الأصلي.',
      );
    }

    // مسار المعالجة البرمجية المطابق رياضياً لـ Rust لضمان تطبيق التأثير فعلياً وعدم إرجاع الصورة الأصلية بصمت
    final m = _computeLumetriMatrixDart(grade);
    final vig = grade.vignette.clamp(0.0, 0.85);
    final out = Uint8List.fromList(rgbaBatchBytes.sublist(0, expected));
    final frameBytes = width * height * 4;
    final cx = width * 0.5;
    final cy = height * 0.5;
    final invMaxDist = 1.0 / math.max(1.0, math.sqrt(cx * cx + cy * cy));

    for (int f = 0; f < numFrames; f++) {
      final frameOff = f * frameBytes;
      for (int y = 0; y < height; y++) {
        final dy = y - cy;
        final rowOff = frameOff + y * width * 4;
        for (int x = 0; x < width; x++) {
          final idx = rowOff + x * 4;
          final r = out[idx].toDouble();
          final g = out[idx + 1].toDouble();
          final b = out[idx + 2].toDouble();

          double nr = m[0] * r + m[1] * g + m[2] * b + m[4];
          double ng = m[5] * r + m[6] * g + m[7] * b + m[9];
          double nb = m[10] * r + m[11] * g + m[12] * b + m[14];

          if (vig > 0.01) {
            final dx = x - cx;
            final dist = math.sqrt(dx * dx + dy * dy) * invMaxDist;
            if (dist > 0.45) {
              final factor = 1.0 - vig * ((dist - 0.45) / 0.55).clamp(0.0, 1.0);
              nr *= factor;
              ng *= factor;
              nb *= factor;
            }
          }

          out[idx] = nr.round().clamp(0, 255);
          out[idx + 1] = ng.round().clamp(0, 255);
          out[idx + 2] = nb.round().clamp(0, 255);
        }
      }
    }

    return LumetriBatchResult(
      status: LumetriProcessStatus.appliedDartFallback,
      bytes: out,
    );
  }

  /// معالجة دفعة كاملة من إطارات RGBA8888 بتصحيح Lumetri
  /// يرمي `VideoExportException` صريحاً إذا كان التأثير مطلوباً وفشلت المعالجة (VID-007)
  Uint8List processRgbaBatchLumetri({
    required Uint8List rgbaBatchBytes,
    required int numFrames,
    required int width,
    required int height,
    required LumetriColorGrade grade,
    bool allowCompatibilityBypass = false,
  }) {
    final res = processRgbaBatchLumetriWithStatus(
      rgbaBatchBytes: rgbaBatchBytes,
      numFrames: numFrames,
      width: width,
      height: height,
      grade: grade,
    );
    if (res.isSuccess) {
      return res.bytes;
    }
    if (allowCompatibilityBypass) {
      return rgbaBatchBytes;
    }
    throw VideoExportException(
      stage: VideoExportStage.processing,
      message: res.errorMessage ?? 'فشل تطبيق تصحيح الألوان Lumetri.',
    );
  }

  /// تحويل دفعة إطارات RGBA8888 بالتوازي إلى فضاء ITU-R BT.709 Studio-Swing NV12 مع فلتر 2x2 Box-Filter (VID-011 / VID-016)
  Uint8List? convertRgbaBatchToBt709Nv12({
    required Uint8List rgbaBatchBytes,
    required int numFrames,
    required int width,
    required int height,
  }) {
    if (numFrames <= 0 ||
        width <= 0 ||
        height <= 0 ||
        width > maxFrameDimension ||
        height > maxFrameDimension ||
        width.isOdd ||
        height.isOdd) {
      return null;
    }
    final expectedRgba = numFrames * width * height * 4;
    final expectedNv12 = numFrames * ((width * height * 3) ~/ 2);
    if (rgbaBatchBytes.length < expectedRgba) {
      return null;
    }

    final rustBatch = _rustRgbaBatchToBt709Nv12;
    if (rustBatch != null) {
      final inPtr = _alloc<ffi.Uint8>(expectedRgba);
      final outPtr = _alloc<ffi.Uint8>(expectedNv12);
      try {
        if (inPtr != ffi.nullptr && outPtr != ffi.nullptr) {
          inPtr
              .asTypedList(expectedRgba)
              .setRange(0, expectedRgba, rgbaBatchBytes);
          final status = rustBatch(inPtr, outPtr, numFrames, width, height);
          if (status == 0) {
            return Uint8List.fromList(outPtr.asTypedList(expectedNv12));
          }
        }
      } finally {
        _freePtr(inPtr);
        _freePtr(outPtr);
      }
    }

    // بديل Dart مطابق رياضياً لمعيار ITU-R BT.709 Studio-Swing مع 2x2 Chroma Box-Filter
    final out = Uint8List(expectedNv12);
    final rgbaFrameSize = width * height * 4;
    final nv12FrameSize = (width * height * 3) ~/ 2;
    for (int f = 0; f < numFrames; f++) {
      _convertSingleRgbaToBt709Nv12Dart(
        Uint8List.sublistView(
          rgbaBatchBytes,
          f * rgbaFrameSize,
          (f + 1) * rgbaFrameSize,
        ),
        Uint8List.sublistView(out, f * nv12FrameSize, (f + 1) * nv12FrameSize),
        width,
        height,
      );
    }
    return out;
  }

  /// تحويل إطار RGBA8888 مفرد إلى فضاء ITU-R BT.709 YUV420 (NV12) (VID-011)
  Uint8List? convertRgbaToNv12({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
  }) {
    if (width <= 0 ||
        height <= 0 ||
        width > maxFrameDimension ||
        height > maxFrameDimension ||
        width.isOdd ||
        height.isOdd) {
      return null;
    }
    final expectedRgba = width * height * 4;
    final nv12Len = (width * height * 3) ~/ 2;
    if (rgbaBytes.length < expectedRgba) {
      return null;
    }

    final rustConvert = _rustRgbaToNv12;
    if (rustConvert != null) {
      final inPtr = _alloc<ffi.Uint8>(expectedRgba);
      final outPtr = _alloc<ffi.Uint8>(nv12Len);
      try {
        if (inPtr != ffi.nullptr && outPtr != ffi.nullptr) {
          inPtr.asTypedList(expectedRgba).setRange(0, expectedRgba, rgbaBytes);
          final status = rustConvert(inPtr, outPtr, width, height);
          if (status == 0) {
            return Uint8List.fromList(outPtr.asTypedList(nv12Len));
          }
        }
      } finally {
        _freePtr(inPtr);
        _freePtr(outPtr);
      }
    }

    final out = Uint8List(nv12Len);
    _convertSingleRgbaToBt709Nv12Dart(rgbaBytes, out, width, height);
    return out;
  }

  void _convertSingleRgbaToBt709Nv12Dart(
    Uint8List rgba,
    Uint8List nv12,
    int w,
    int h,
  ) {
    final ySize = w * h;
    for (int y = 0; y < h; y++) {
      final srcRow = y * w * 4;
      final dstRow = y * w;
      for (int x = 0; x < w; x++) {
        final px = srcRow + x * 4;
        final r = rgba[px];
        final g = rgba[px + 1];
        final b = rgba[px + 2];
        nv12[dstRow + x] =
            (((47 * r + 157 * g + 16 * b + 128) >> 8) + 16).clamp(16, 235);
      }
    }

    final halfH = h ~/ 2;
    final halfW = w ~/ 2;
    for (int uy = 0; uy < halfH; uy++) {
      final y0 = uy * 2;
      final y1 = y0 + 1;
      final row0 = y0 * w * 4;
      final row1 = y1 * w * 4;
      final uvDstRow = ySize + uy * w;

      for (int ux = 0; ux < halfW; ux++) {
        final x0 = ux * 2;
        final x1 = x0 + 1;

        final p00 = row0 + x0 * 4;
        final p01 = row0 + x1 * 4;
        final p10 = row1 + x0 * 4;
        final p11 = row1 + x1 * 4;

        final rAvg =
            (rgba[p00] + rgba[p01] + rgba[p10] + rgba[p11] + 2) >> 2;
        final gAvg =
            (rgba[p00 + 1] + rgba[p01 + 1] + rgba[p10 + 1] + rgba[p11 + 1] + 2) >>
            2;
        final bAvg =
            (rgba[p00 + 2] + rgba[p01 + 2] + rgba[p10 + 2] + rgba[p11 + 2] + 2) >>
            2;

        final uVal =
            (((-25 * rAvg - 87 * gAvg + 112 * bAvg + 128) >> 8) + 128).clamp(
              16,
              240,
            );
        final vVal =
            (((112 * rAvg - 102 * gAvg - 10 * bAvg + 128) >> 8) + 128).clamp(
              16,
              240,
            );

        final dstIdx = uvDstRow + ux * 2;
        nv12[dstIdx] = uVal;
        nv12[dstIdx + 1] = vVal;
      }
    }
  }

  /// محدد ذروة للعينة المفردة بمنحنى ناعم (Soft-Knee Tanh Sample-Peak Limiter) (VID-013)
  static int softKneeSamplePeakLimit(double sample) {
    if (!sample.isFinite) return 0;
    const double kneeStart = 28000.0;
    const double maxCeiling = 32700.0;
    const double headroom = maxCeiling - kneeStart;

    final double absS = sample.abs();
    if (absS <= kneeStart) {
      return sample.round();
    }
    final double sign = sample >= 0.0 ? 1.0 : -1.0;
    final double excess = (absS - kneeStart) / headroom;
    // tanh(x) = (e^(2x) - 1) / (e^(2x) + 1)
    final double tanhVal = excess > 20.0
        ? 1.0
        : (math.exp(2.0 * excess) - 1.0) / (math.exp(2.0 * excess) + 1.0);
    final double compressed = kneeStart + headroom * tanhVal;
    return (sign * compressed).round().clamp(-32767, 32767);
  }

  /// تقدير القمة الحقيقية بين العينات (4x Oversampled Catmull-Rom Inter-Sample Peak) (VID-013)
  double estimateIntersamplePeak4x(
    double s0,
    double s1,
    double s2,
    double s3,
  ) {
    double maxAbs = math.max(s1.abs(), s2.abs());
    for (final t in const <double>[0.25, 0.50, 0.75]) {
      final interp = _catmullRom(s0, s1, s2, s3, t).abs();
      if (interp > maxAbs) {
        maxAbs = interp;
      }
    }
    return maxAbs;
  }

  /// محدد القمة الحقيقية بين العينات (4x True-Peak Aware Soft-Knee Limiter) (VID-013)
  int softKneeTruePeakLimit4x(double s0, double s1, double s2, double s3) {
    const double kneeStart = 28000.0;
    final double truePeak = estimateIntersamplePeak4x(s0, s1, s2, s3);
    final double sampleAbs = s1.abs();
    if (truePeak > kneeStart && truePeak > sampleAbs && sampleAbs > 1.0) {
      final double limitedPeak = softKneeSamplePeakLimit(truePeak).abs().toDouble();
      final double attenuation = (limitedPeak / truePeak).clamp(0.5, 1.0);
      return softKneeSamplePeakLimit(s1 * attenuation);
    }
    return softKneeSamplePeakLimit(s1);
  }

  /// إعادة أخذ العينات (Linear Resampling) وتحويل القنوات (Mono <-> Stereo) لبيانات PCM16 LE (VID-005)
  Int16List resampleAndConvertPcm16({
    required Uint8List srcPcmBytes,
    required int srcSampleRate,
    required int srcChannels,
    required int dstSampleRate,
    required int dstChannels,
  }) {
    if (srcSampleRate <= 0 ||
        srcChannels <= 0 ||
        dstSampleRate <= 0 ||
        dstChannels <= 0) {
      return Int16List(0);
    }
    final int frameStride = srcChannels * 2;
    final int srcFrames = srcPcmBytes.length ~/ frameStride;
    if (srcFrames <= 0) {
      return Int16List(0);
    }

    final ByteData srcView = ByteData.sublistView(srcPcmBytes);
    final Float64List normalized = Float64List(srcFrames * dstChannels);

    for (int f = 0; f < srcFrames; f++) {
      final int base = f * frameStride;
      if (srcChannels == dstChannels) {
        for (int c = 0; c < dstChannels; c++) {
          normalized[f * dstChannels + c] = srcView
              .getInt16(base + c * 2, Endian.little)
              .toDouble();
        }
      } else if (srcChannels == 1 && dstChannels == 2) {
        final double s = srcView.getInt16(base, Endian.little).toDouble();
        normalized[f * 2] = s;
        normalized[f * 2 + 1] = s;
      } else if (srcChannels >= 2 && dstChannels == 1) {
        double sum = 0.0;
        for (int c = 0; c < srcChannels; c++) {
          sum += srcView.getInt16(base + c * 2, Endian.little).toDouble();
        }
        normalized[f] = sum / srcChannels;
      } else {
        for (int c = 0; c < dstChannels; c++) {
          final int srcC = c % srcChannels;
          normalized[f * dstChannels + c] = srcView
              .getInt16(base + srcC * 2, Endian.little)
              .toDouble();
        }
      }
    }

    if (srcSampleRate == dstSampleRate) {
      final Int16List direct = Int16List(normalized.length);
      for (int i = 0; i < normalized.length; i++) {
        direct[i] = normalized[i].round().clamp(-32768, 32767);
      }
      return direct;
    }

    final int dstFrames =
        ((BigInt.from(srcFrames) * BigInt.from(dstSampleRate) +
                    BigInt.from(srcSampleRate ~/ 2)) ~/
                BigInt.from(srcSampleRate))
            .toInt();
    if (dstFrames <= 0) {
      return Int16List(0);
    }

    final Int16List resampled = Int16List(dstFrames * dstChannels);
    final double rateRatio = srcSampleRate / dstSampleRate;

    for (int outF = 0; outF < dstFrames; outF++) {
      final double srcPos = outF * rateRatio;
      final int idx0 = math.min(srcPos.floor(), srcFrames - 1);
      final int idx1 = math.min(idx0 + 1, srcFrames - 1);
      final double frac = (srcPos - idx0).clamp(0.0, 1.0);

      for (int c = 0; c < dstChannels; c++) {
        final double v0 = normalized[idx0 * dstChannels + c];
        final double v1 = normalized[idx1 * dstChannels + c];
        final double interp = v0 + (v1 - v0) * frac;
        resampled[outF * dstChannels + c] = interp.round().clamp(-32768, 32767);
      }
    }

    return resampled;
  }

  /// مزج مؤثر صوتي (Overlay PCM 16-bit LE) فوق المسار الصوتي الرئيسي بدقة الـ Tick
  /// مع دعم اختلاف معدلات العينات (`overlaySampleRate`) وعدد القنوات (`overlayChannels`) (VID-005)
  Uint8List mixPcm16Overlay({
    required Uint8List masterPcm,
    required Uint8List overlayPcm,
    int sampleRate = 44100,
    int channels = 2,
    int? overlaySampleRate,
    int? overlayChannels,
    required double startTimeSeconds,
    double overlayVolume = 0.9,
  }) {
    final int effOverlayRate = overlaySampleRate ?? sampleRate;
    final int effOverlayChannels = overlayChannels ?? channels;
    if (masterPcm.length < 2 ||
        overlayPcm.length < 2 ||
        sampleRate <= 0 ||
        channels <= 0 ||
        effOverlayRate <= 0 ||
        effOverlayChannels <= 0) {
      return masterPcm;
    }

    // 1. إذا توفرت دالة Rust الموسعة لإعادة أخذ العينات والمزج
    final rustResampledMix = _rustMixPcm16OverlayResampled;
    if (rustResampledMix != null) {
      final masterPtr = _alloc<ffi.Uint8>(masterPcm.length);
      final overlayPtr = _alloc<ffi.Uint8>(overlayPcm.length);
      try {
        if (masterPtr != ffi.nullptr && overlayPtr != ffi.nullptr) {
          masterPtr
              .asTypedList(masterPcm.length)
              .setRange(0, masterPcm.length, masterPcm);
          overlayPtr
              .asTypedList(overlayPcm.length)
              .setRange(0, overlayPcm.length, overlayPcm);
          final status = rustResampledMix(
            masterPtr,
            masterPcm.length,
            overlayPtr,
            overlayPcm.length,
            sampleRate,
            channels,
            effOverlayRate,
            effOverlayChannels,
            startTimeSeconds,
            overlayVolume,
          );
          if (status == 0) {
            return Uint8List.fromList(masterPtr.asTypedList(masterPcm.length));
          }
        }
      } finally {
        _freePtr(masterPtr);
        _freePtr(overlayPtr);
      }
    }

    // 2. إذا تطابق المعدل والقنوات وتوفرت دالة Rust الأساسية
    final rustMix = _rustMixPcm16Overlay;
    if (rustMix != null &&
        effOverlayRate == sampleRate &&
        effOverlayChannels == channels) {
      final masterPtr = _alloc<ffi.Uint8>(masterPcm.length);
      final overlayPtr = _alloc<ffi.Uint8>(overlayPcm.length);
      try {
        if (masterPtr != ffi.nullptr && overlayPtr != ffi.nullptr) {
          masterPtr
              .asTypedList(masterPcm.length)
              .setRange(0, masterPcm.length, masterPcm);
          overlayPtr
              .asTypedList(overlayPcm.length)
              .setRange(0, overlayPcm.length, overlayPcm);
          final status = rustMix(
            masterPtr,
            masterPcm.length,
            overlayPtr,
            overlayPcm.length,
            sampleRate,
            channels,
            startTimeSeconds,
            overlayVolume,
          );
          if (status == 0) {
            return Uint8List.fromList(masterPtr.asTypedList(masterPcm.length));
          }
        }
      } finally {
        _freePtr(masterPtr);
        _freePtr(overlayPtr);
      }
    }

    // 3. مسار Dart الموحد مع إعادة أخذ العينات وتحويل القنوات ومحدد الذروة الناعم (VID-005 / VID-013)
    final int masterFrameStride = channels * 2;
    final int alignedMasterLen =
        (masterPcm.length ~/ masterFrameStride) * masterFrameStride;
    if (alignedMasterLen <= 0) return masterPcm;

    final out = Uint8List.fromList(masterPcm);
    final outData = ByteData.sublistView(out);
    final startFrame = ticksToAudioSample(
      secondsToTicks(math.max(0.0, startTimeSeconds)),
      sampleRate,
    );
    final startByte = startFrame * masterFrameStride;
    if (startByte >= alignedMasterLen) return out;

    final Int16List convertedOverlay = resampleAndConvertPcm16(
      srcPcmBytes: overlayPcm,
      srcSampleRate: effOverlayRate,
      srcChannels: effOverlayChannels,
      dstSampleRate: sampleRate,
      dstChannels: channels,
    );

    final int maxMasterSamples = (alignedMasterLen - startByte) ~/ 2;
    final int mixSamples = math.min(convertedOverlay.length, maxMasterSamples);
    final double gain = overlayVolume.isFinite
        ? overlayVolume.clamp(0.0, 2.0)
        : 0.0;

    for (int i = 0; i < mixSamples; i++) {
      final int mIdx = startByte + i * 2;
      final int mVal = outData.getInt16(mIdx, Endian.little);
      final int oVal = convertedOverlay[i];
      final double mixed = mVal + oVal * gain;
      final int limited = softKneeSamplePeakLimit(mixed);
      outData.setInt16(mIdx, limited, Endian.little);
    }
    return out;
  }

  /// معالجة عينات الصوت PCM 16-bit LE عبر `rust_process_pcm16_audio` أو مسار Dart المطابق (VID-001 / VID-013)
  /// يحسب الزمن باستخدام عدد إطارات الصوت المعالجة (`frameIdx / sampleRate`) بحيث تحصل جميع قنوات الإطار الواحد
  /// (Mono أو Stereo أو متعدد القنوات) على معامل التلاشي نفسه في اللحظة الزمنية نفسها.
  Uint8List processPcm16Audio({
    required Uint8List pcmBytes,
    int sampleRate = 44100,
    int channels = 2,
    double volume = 0.85,
    bool fadeIn = true,
    bool fadeOut = true,
  }) {
    if (pcmBytes.length < 2 || sampleRate <= 0 || channels <= 0) {
      return pcmBytes;
    }
    final int frameByteStride = channels * 2;
    final int totalFrames = pcmBytes.length ~/ frameByteStride;
    if (totalFrames <= 0) {
      return pcmBytes;
    }

    final rustDsp = _rustProcessPcm16Audio;
    if (rustDsp != null) {
      final ptr = _alloc<ffi.Uint8>(pcmBytes.length);
      if (ptr != ffi.nullptr) {
        try {
          ptr.asTypedList(pcmBytes.length).setRange(
            0,
            pcmBytes.length,
            pcmBytes,
          );
          final status = rustDsp(
            ptr,
            pcmBytes.length,
            sampleRate,
            channels,
            volume,
            fadeIn ? 1 : 0,
            fadeOut ? 1 : 0,
          );
          if (status == 0) {
            return Uint8List.fromList(ptr.asTypedList(pcmBytes.length));
          }
        } finally {
          _freePtr(ptr);
        }
      }
    }

    // مسار Dart المطابق رياضياً لـ Rust (VID-001 / VID-013)
    final out = Uint8List.fromList(pcmBytes);
    final view = ByteData.sublistView(out);
    final double totalSeconds = totalFrames / sampleRate;
    const double defaultFadeSec = 1.2;
    final double fadeWindow = (fadeIn && fadeOut)
        ? math.min(defaultFadeSec, totalSeconds * 0.5)
        : ((fadeIn || fadeOut)
              ? math.min(defaultFadeSec, totalSeconds)
              : 0.0);
    final double baseGain = volume.isFinite ? volume.clamp(0.0, 1.5) : 1.0;

    for (int frameIdx = 0; frameIdx < totalFrames; frameIdx++) {
      final double currentSec = frameIdx / sampleRate;
      final int remainingFrames = math.max(0, totalFrames - 1 - frameIdx);
      final double remainingSec = remainingFrames / sampleRate;

      double gain = baseGain;
      if (fadeIn && fadeWindow > 1e-9 && currentSec < fadeWindow) {
        final double ratio = (currentSec / fadeWindow).clamp(0.0, 1.0);
        gain *= math.sin(ratio * math.pi * 0.5);
      }
      if (fadeOut && fadeWindow > 1e-9 && remainingSec < fadeWindow) {
        final double ratio = (remainingSec / fadeWindow).clamp(0.0, 1.0);
        gain *= math.sin(ratio * math.pi * 0.5);
      }

      final int frameBase = frameIdx * frameByteStride;
      for (int c = 0; c < channels; c++) {
        final int byteIdx = frameBase + c * 2;
        final double rawS1 =
            view.getInt16(byteIdx, Endian.little).toDouble() * gain;

        int limited;
        if (rawS1.abs() > 24000.0 && frameIdx + 1 < totalFrames) {
          final int nextIdx = (frameIdx + 1) * frameByteStride + c * 2;
          final double rawS2 =
              view.getInt16(nextIdx, Endian.little).toDouble() * gain;
          final double prevS0 = frameIdx > 0
              ? view
                    .getInt16(
                      (frameIdx - 1) * frameByteStride + c * 2,
                      Endian.little,
                    )
                    .toDouble()
              : rawS1;
          final double nextS3 = frameIdx + 2 < totalFrames
              ? view
                        .getInt16(
                          (frameIdx + 2) * frameByteStride + c * 2,
                          Endian.little,
                        )
                        .toDouble() *
                    gain
              : rawS2;
          limited = softKneeTruePeakLimit4x(prevS0, rawS1, rawS2, nextS3);
        } else {
          limited = softKneeSamplePeakLimit(rawS1);
        }

        view.setInt16(byteIdx, limited, Endian.little);
      }
    }

    return out;
  }

  /// تجميع قائمة إطارات PNG مع الصوت المتداخل (`00dc` + `01wb`) إلى ملف فيديو قياسي (RIFF AVI)
  /// مع التحقق الصارم من سلامة الذاكرة والأبعاد (VID-003 / VID-004)
  Future<File> muxFramesToVideoContainer({
    required List<Uint8List> frames,
    required String outputPath,
    required int width,
    required int height,
    required int fps,
    Uint8List? pcm16Audio,
    int audioSampleRate = 44100,
    int audioChannels = 2,
  }) async {
    if (frames.isEmpty) {
      throw const VideoExportException(
        stage: VideoExportStage.encoding,
        message: 'لا يمكن إنشاء حاوية AVI من قائمة إطارات فارغة.',
      );
    }
    if (width <= 0 ||
        height <= 0 ||
        width > maxFrameDimension ||
        height > maxFrameDimension ||
        fps <= 0 ||
        fps > 240) {
      throw VideoExportException(
        stage: VideoExportStage.encoding,
        message:
            'معاملات حاوية AVI غير صالحة (${width}x$height @ $fps FPS).',
      );
    }

    // حساب الحجم الإجمالي والتحقق من صلاحية كل إطار قبل الوصول إلى الذاكرة (VID-004)
    int totalFramesBytes = 0;
    for (int i = 0; i < frames.length; i++) {
      final f = frames[i];
      if (f.isEmpty) {
        throw VideoExportException(
          stage: VideoExportStage.encoding,
          message: 'الإطار رقم $i فارغ ولا يمكن تجميعه.',
        );
      }
      totalFramesBytes += f.length;
    }

    // إذا كان الحجم صغيراً ومناسباً للذاكرة الأصلية (< 128 MB) وتوفرت مكتبة Rust، نستخدم FFI الآمن
    if (totalFramesBytes <= 128 * 1024 * 1024 &&
        frames.length <= maxMuxFrames &&
        (_rustMuxFramesAndPcmToAviChecked != null ||
            _rustMuxFramesAndPcmToAvi != null ||
            _rustMuxFramesToAvi != null)) {
      final muxedInRust = _tryMuxFramesViaRustFfi(
        frames: frames,
        totalFramesBytes: totalFramesBytes,
        outputPath: outputPath,
        width: width,
        height: height,
        fps: fps,
        pcm16Audio: pcm16Audio,
        audioSampleRate: audioSampleRate,
        audioChannels: audioChannels,
      );
      if (muxedInRust) {
        return File(outputPath);
      }
    }

    // المسار التدفقّي المحكوم بالذاكرة مباشرة إلى القرص (Streaming Disk Writer) لمنع استنزاف الذاكرة (VID-003)
    return _writeAviContainerStreamingToDisk(
      frames: frames,
      outputPath: outputPath,
      width: width,
      height: height,
      fps: fps,
      pcm16Audio: pcm16Audio,
      audioSampleRate: audioSampleRate,
      audioChannels: audioChannels,
    );
  }

  bool _tryMuxFramesViaRustFfi({
    required List<Uint8List> frames,
    required int totalFramesBytes,
    required String outputPath,
    required int width,
    required int height,
    required int fps,
    Uint8List? pcm16Audio,
    int audioSampleRate = 44100,
    int audioChannels = 2,
  }) {
    final pathBytes = utf8.encode(outputPath);
    if (pathBytes.isEmpty ||
        pathBytes.length > 4096 ||
        frames.isEmpty ||
        frames.length > maxMuxFrames ||
        totalFramesBytes <= 0) {
      return false;
    }

    final pathPtr = _alloc<ffi.Uint8>(pathBytes.length);
    final framesConcatPtr = _alloc<ffi.Uint8>(totalFramesBytes);
    final frameSizesPtr = _alloc<ffi.Uint32>(
      frames.length * ffi.sizeOf<ffi.Uint32>(),
    );

    final hasPcm =
        pcm16Audio != null &&
        pcm16Audio.isNotEmpty &&
        (_rustMuxFramesAndPcmToAviChecked != null ||
            _rustMuxFramesAndPcmToAvi != null);
    final pcmPtr = hasPcm
        ? _alloc<ffi.Uint8>(pcm16Audio.length)
        : ffi.nullptr.cast<ffi.Uint8>();

    try {
      if (pathPtr == ffi.nullptr ||
          framesConcatPtr == ffi.nullptr ||
          frameSizesPtr == ffi.nullptr ||
          (hasPcm && pcmPtr == ffi.nullptr)) {
        return false;
      }

      pathPtr.asTypedList(pathBytes.length).setAll(0, pathBytes);

      final concatView = framesConcatPtr.asTypedList(totalFramesBytes);
      final sizesView = frameSizesPtr.asTypedList(frames.length);

      int cursor = 0;
      for (int i = 0; i < frames.length; i++) {
        final frame = frames[i];
        final frameLen = frame.length;
        if (frameLen <= 0 || cursor + frameLen > totalFramesBytes) {
          return false;
        }
        sizesView[i] = frameLen;
        concatView.setRange(cursor, cursor + frameLen, frame);
        cursor += frameLen;
      }
      if (cursor != totalFramesBytes) {
        return false;
      }

      int status = -1;
      if (hasPcm && pcmPtr != ffi.nullptr) {
        pcmPtr.asTypedList(pcm16Audio.length).setRange(
          0,
          pcm16Audio.length,
          pcm16Audio,
        );
        if (_rustMuxFramesAndPcmToAviChecked != null) {
          status = _rustMuxFramesAndPcmToAviChecked!(
            pathPtr,
            pathBytes.length,
            framesConcatPtr,
            totalFramesBytes,
            frameSizesPtr,
            frames.length,
            width,
            height,
            fps,
            pcmPtr,
            pcm16Audio.length,
            audioSampleRate,
            audioChannels,
          );
        } else {
          status = _rustMuxFramesAndPcmToAvi!(
            pathPtr,
            pathBytes.length,
            framesConcatPtr,
            frameSizesPtr,
            frames.length,
            width,
            height,
            fps,
            pcmPtr,
            pcm16Audio.length,
            audioSampleRate,
            audioChannels,
          );
        }
      } else if (_rustMuxFramesAndPcmToAviChecked != null) {
        status = _rustMuxFramesAndPcmToAviChecked!(
          pathPtr,
          pathBytes.length,
          framesConcatPtr,
          totalFramesBytes,
          frameSizesPtr,
          frames.length,
          width,
          height,
          fps,
          ffi.nullptr,
          0,
          audioSampleRate,
          audioChannels,
        );
      } else if (_rustMuxFramesToAvi != null) {
        status = _rustMuxFramesToAvi!(
          pathPtr,
          pathBytes.length,
          framesConcatPtr,
          frameSizesPtr,
          frames.length,
          width,
          height,
          fps,
        );
      }

      return status == 0 && File(outputPath).existsSync();
    } catch (_) {
      return false;
    } finally {
      _freePtr(pathPtr);
      _freePtr(framesConcatPtr);
      _freePtr(frameSizesPtr);
      if (pcmPtr != ffi.nullptr) {
        _freePtr(pcmPtr);
      }
    }
  }

  /// كتابة حاوية RIFF/AVI متداخلة (`00dc` + `01wb`) مباشرة إلى القرص بدون تجميع كل الإطارات في مصفوفة واحدة (VID-003)
  Future<File> _writeAviContainerStreamingToDisk({
    required List<Uint8List> frames,
    required String outputPath,
    required int width,
    required int height,
    required int fps,
    Uint8List? pcm16Audio,
    int audioSampleRate = 44100,
    int audioChannels = 2,
  }) async {
    final writer = await StreamingAviFileWriter.open(
      outputPath: outputPath,
      width: width,
      height: height,
      fps: fps,
      totalExpectedFrames: frames.length,
      pcm16Audio: pcm16Audio,
      audioSampleRate: audioSampleRate,
      audioChannels: audioChannels,
    );
    try {
      for (int i = 0; i < frames.length; i++) {
        await writer.writeFrame(frames[i]);
      }
      return await writer.finalize();
    } catch (e) {
      await writer.abort();
      rethrow;
    }
  }

  /// فحص وتحليل شرائح إطارات `00dc` داخل بايتات حاوية RIFF/AVI بأمان كامل (VID-009)
  /// يتحقق من:
  /// 1. توقيع `RIFF` ونوع النموذج `AVI `.
  /// 2. حدود الحاوية `riffSize` وعدم القراءة خارج حدود الملف.
  /// 3. استخراج مقاطع `00dc` الموجودة حصرياً داخل قائمة `LIST("movi")`.
  /// 4. صحة توقيع PNG (`89 50 4E 47 0D 0A 1A 0A`) لكل إطار مستخرج.
  List<Uint8List> parseAviFramesFromBytes(
    Uint8List bytes, {
    bool requirePngSignature = true,
  }) {
    if (bytes.length < 32) return const <Uint8List>[];
    // التحقق من "RIFF" (0x52, 0x49, 0x46, 0x46) و "AVI " (0x41, 0x56, 0x49, 0x20)
    if (bytes[0] != 0x52 ||
        bytes[1] != 0x49 ||
        bytes[2] != 0x46 ||
        bytes[3] != 0x46 ||
        bytes[8] != 0x41 ||
        bytes[9] != 0x56 ||
        bytes[10] != 0x49 ||
        bytes[11] != 0x20) {
      return const <Uint8List>[];
    }

    final ByteData data = ByteData.sublistView(bytes);
    final int declaredRiffSize = data.getUint32(4, Endian.little);
    final int containerEnd = math.min(bytes.length, declaredRiffSize + 8);
    if (containerEnd < 24) return const <Uint8List>[];

    final List<Uint8List> frames = <Uint8List>[];
    int pos = 12;

    while (pos + 8 <= containerEnd) {
      final int c0 = bytes[pos];
      final int c1 = bytes[pos + 1];
      final int c2 = bytes[pos + 2];
      final int c3 = bytes[pos + 3];
      final int chunkSize = data.getUint32(pos + 4, Endian.little);
      final int dataStart = pos + 8;
      final int dataEnd = dataStart + chunkSize;

      if (chunkSize < 0 || dataEnd > containerEnd) {
        break; // مقطع مقطوع أو يتجاوز حدود الحاوية
      }

      // فحص قوائم LIST ("LIST" = 0x4C, 0x49, 0x53, 0x54)
      if (c0 == 0x4C && c1 == 0x49 && c2 == 0x53 && c3 == 0x54) {
        if (chunkSize >= 4 && dataStart + 4 <= dataEnd) {
          final int l0 = bytes[dataStart];
          final int l1 = bytes[dataStart + 1];
          final int l2 = bytes[dataStart + 2];
          final int l3 = bytes[dataStart + 3];
          // الدخول فقط في قائمة "movi" (0x6D, 0x6F, 0x76, 0x69) وتجاهل hdrl/strl/INFO
          if (l0 == 0x6D && l1 == 0x6F && l2 == 0x76 && l3 == 0x69) {
            int mpos = dataStart + 4;
            while (mpos + 8 <= dataEnd) {
              final int mc0 = bytes[mpos];
              final int mc1 = bytes[mpos + 1];
              final int mc2 = bytes[mpos + 2];
              final int mc3 = bytes[mpos + 3];
              final int mSize = data.getUint32(mpos + 4, Endian.little);
              final int mStart = mpos + 8;
              final int mEnd = mStart + mSize;

              if (mSize < 0 || mEnd > dataEnd) {
                break;
              }

              // LIST("rec ") فرعية داخل movi
              if (mc0 == 0x4C &&
                  mc1 == 0x49 &&
                  mc2 == 0x53 &&
                  mc3 == 0x54 &&
                  mSize >= 4) {
                if (bytes[mStart] == 0x72 &&
                    bytes[mStart + 1] == 0x65 &&
                    bytes[mStart + 2] == 0x63 &&
                    bytes[mStart + 3] == 0x20) {
                  mpos = mStart + 4;
                  continue;
                }
              } else if (mc0 == 0x30 &&
                  mc1 == 0x30 &&
                  mc2 == 0x64 &&
                  mc3 == 0x63 &&
                  mSize >= 8) {
                // "00dc" — التحقق من توقيع PNG القياسي
                bool validFormat = true;
                if (requirePngSignature) {
                  for (int k = 0; k < 8; k++) {
                    if (bytes[mStart + k] != pngSignature[k]) {
                      validFormat = false;
                      break;
                    }
                  }
                }
                if (validFormat) {
                  frames.add(Uint8List.sublistView(bytes, mStart, mEnd));
                }
              }

              final int mPadded = mSize + (mSize.isOdd ? 1 : 0);
              final int nextMpos = mStart + mPadded;
              if (nextMpos <= mpos) break;
              mpos = nextMpos;
            }
          }
        }
      }

      final int paddedSize = chunkSize + (chunkSize.isOdd ? 1 : 0);
      final int nextPos = dataStart + paddedSize;
      if (nextPos <= pos) break;
      pos = nextPos;
    }

    return frames;
  }

  /// استخراج إطارات PNG من ملف RIFF/AVI المصدّر عبر القراءة المفهرسة الآمنة (VID-003 / VID-009)
  Future<List<Uint8List>> extractFramesFromAvi(String aviFilePath) async {
    final file = File(aviFilePath);
    if (!file.existsSync()) return const <Uint8List>[];

    RandomAccessFile? raf;
    try {
      final int fileLen = await file.length();
      if (fileLen < 32) return const <Uint8List>[];

      raf = await file.open(mode: FileMode.read);
      final header = await raf.read(12);
      if (header.length < 12 ||
          header[0] != 0x52 ||
          header[1] != 0x49 ||
          header[2] != 0x46 ||
          header[3] != 0x46 ||
          header[8] != 0x41 ||
          header[9] != 0x56 ||
          header[10] != 0x49 ||
          header[11] != 0x20) {
        return const <Uint8List>[];
      }

      final headerView = ByteData.sublistView(header);
      final int declaredRiffSize = headerView.getUint32(4, Endian.little);
      final int containerEnd = math.min(fileLen, declaredRiffSize + 8);

      final List<Uint8List> frames = <Uint8List>[];
      int pos = 12;

      while (pos + 8 <= containerEnd) {
        await raf.setPosition(pos);
        final chunkHdr = await raf.read(8);
        if (chunkHdr.length < 8) break;

        final int c0 = chunkHdr[0];
        final int c1 = chunkHdr[1];
        final int c2 = chunkHdr[2];
        final int c3 = chunkHdr[3];
        final int chunkSize = ByteData.sublistView(
          chunkHdr,
        ).getUint32(4, Endian.little);
        final int dataStart = pos + 8;
        final int dataEnd = dataStart + chunkSize;

        if (chunkSize < 0 || dataEnd > containerEnd) break;

        if (c0 == 0x4C &&
            c1 == 0x49 &&
            c2 == 0x53 &&
            c3 == 0x54 &&
            chunkSize >= 4) {
          final listType = await raf.read(4);
          if (listType.length == 4 &&
              listType[0] == 0x6D &&
              listType[1] == 0x6F &&
              listType[2] == 0x76 &&
              listType[3] == 0x69) {
            int mpos = dataStart + 4;
            while (mpos + 8 <= dataEnd) {
              await raf.setPosition(mpos);
              final mHdr = await raf.read(8);
              if (mHdr.length < 8) break;
              final int mc0 = mHdr[0];
              final int mc1 = mHdr[1];
              final int mc2 = mHdr[2];
              final int mc3 = mHdr[3];
              final int mSize = ByteData.sublistView(
                mHdr,
              ).getUint32(4, Endian.little);
              final int mStart = mpos + 8;
              final int mEnd = mStart + mSize;
              if (mSize < 0 || mEnd > dataEnd) break;

              if (mc0 == 0x30 &&
                  mc1 == 0x30 &&
                  mc2 == 0x64 &&
                  mc3 == 0x63 &&
                  mSize >= 8) {
                final frameBytes = await raf.read(mSize);
                if (frameBytes.length == mSize &&
                    _hasValidPngSignature(frameBytes)) {
                  frames.add(frameBytes);
                }
              }

              final int mPadded = mSize + (mSize.isOdd ? 1 : 0);
              final int nextMpos = mStart + mPadded;
              if (nextMpos <= mpos) break;
              mpos = nextMpos;
            }
          }
        }

        final int padded = chunkSize + (chunkSize.isOdd ? 1 : 0);
        final int nextPos = dataStart + padded;
        if (nextPos <= pos) break;
        pos = nextPos;
      }

      return frames;
    } catch (_) {
      return const <Uint8List>[];
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  static bool _hasValidPngSignature(Uint8List bytes) {
    if (bytes.length < 8) return false;
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != pngSignature[i]) return false;
    }
    return true;
  }

  /// استعلام قدرات الترميز العتادي للجهاز (H.264 / H.265 HEVC / 1080p60) (VID-017)
  Future<DeviceEncoderCapabilities> queryEncoderCapabilities() async {
    if (Platform.isAndroid) {
      try {
        final res = await _mediaChannel.invokeMethod<Map<Object?, Object?>>(
          'queryEncoderCapabilities',
        );
        if (res != null) {
          return DeviceEncoderCapabilities(
            supportsH264: (res['supportsH264'] as bool?) ?? true,
            supportsHevc: (res['supportsHevc'] as bool?) ?? false,
            supports1080p60H264: (res['supports1080p60H264'] as bool?) ?? true,
            supports1080p60Hevc: (res['supports1080p60Hevc'] as bool?) ?? false,
            maxSupportedBitrateBps:
                (res['maxSupportedBitrateBps'] as num?)?.toInt() ?? 20000000,
          );
        }
      } catch (_) {}
    }
    return const DeviceEncoderCapabilities();
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

  /// الكشف عن نوع MIME الفعلي لحاوية الفيديو من التوقيع الثنائي للملف (VID-008)
  static Future<String> detectContainerMimeType(File file) async {
    try {
      if (file.existsSync() && file.lengthSync() >= 12) {
        final raf = await file.open(mode: FileMode.read);
        try {
          final hdr = await raf.read(12);
          if (hdr.length >= 12) {
            if (hdr[0] == 0x52 &&
                hdr[1] == 0x49 &&
                hdr[2] == 0x46 &&
                hdr[3] == 0x46 &&
                hdr[8] == 0x41 &&
                hdr[9] == 0x56 &&
                hdr[10] == 0x49 &&
                hdr[11] == 0x20) {
              return 'video/x-msvideo';
            }
            if (hdr[4] == 0x66 &&
                hdr[5] == 0x74 &&
                hdr[6] == 0x79 &&
                hdr[7] == 0x70) {
              return 'video/mp4';
            }
          }
        } finally {
          await raf.close();
        }
      }
    } catch (_) {}
    final lower = file.path.toLowerCase();
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    return 'video/mp4';
  }

  /// حفظ ملف الفيديو المصدّر في المعرض (`Movies/OurLoveStory`) ومجلد التنزيلات العام (`Download/OurLoveStory`)
  Future<String?> saveVideoToPublicDownloads(
    String sourcePath, {
    String? customFileName,
  }) async {
    final srcFile = File(sourcePath);
    if (!srcFile.existsSync()) return null;

    final mimeType = await detectContainerMimeType(srcFile);
    final expectedExt = mimeType == 'video/x-msvideo' ? 'avi' : 'mp4';
    String fileName =
        customFileName ?? sourcePath.split(Platform.pathSeparator).last;
    if (!fileName.toLowerCase().endsWith('.$expectedExt')) {
      final dotIdx = fileName.lastIndexOf('.');
      fileName = dotIdx > 0
          ? '${fileName.substring(0, dotIdx)}.$expectedExt'
          : '$fileName.$expectedExt';
    }

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

  /// مشاركة الفيديو المصدّر أو فتحه بتطبيق خارجي مع تمرير نوع MIME الفعلي للحاوية (VID-008)
  Future<bool> shareExportedVideo(String filePath, {String? title}) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    try {
      final mimeType = await detectContainerMimeType(file);
      final res = await _mediaChannel.invokeMethod<bool>('shareVideoFile', {
        'filePath': filePath,
        'title': title ?? 'فيديو ذكرياتنا 🎬',
        'mimeType': mimeType,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _prepareSingleAudioSource(
    String sourcePath, {
    required bool isLocalFile,
    required String tempTag,
  }) async {
    try {
      if (isLocalFile) {
        if (sourcePath.isNotEmpty && File(sourcePath).existsSync()) {
          return sourcePath;
        }
        return null;
      }
      if (sourcePath.isNotEmpty) {
        final byteData = await rootBundle.load('assets/$sourcePath');
        final tempDir = await getTemporaryDirectory();
        final ext = sourcePath.split('.').last;
        final tempAudio = File('${tempDir.path}/${tempTag}_audio.$ext');
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

  Future<String?> _prepareAudioFileForExport(VideoProjectEntity project) async {
    if (project.customAudioPath != null &&
        project.customAudioPath!.isNotEmpty) {
      return _prepareSingleAudioSource(
        project.customAudioPath!,
        isLocalFile: true,
        tempTag: 'export_bgm_custom',
      );
    }
    if (project.audioAsset != null && project.audioAsset!.isNotEmpty) {
      return _prepareSingleAudioSource(
        project.audioAsset!,
        isLocalFile: false,
        tempTag: 'export_bgm_asset',
      );
    }
    return null;
  }

  /// التحقق النهائي المستقل من سلامة ملف الفيديو الناتج قبل إعلان النجاح (VID-014 / VID-018)
  Future<void> verifyExportedVideoOutput({
    required File outputFile,
    required VideoExportConfig config,
    required int expectedWidth,
    required int expectedHeight,
  }) async {
    if (!outputFile.existsSync()) {
      throw const VideoExportException(
        stage: VideoExportStage.validating,
        message: 'ملف الفيديو الناتج غير موجود على القرص.',
      );
    }
    final int len = outputFile.lengthSync();
    if (len < 256) {
      throw VideoExportException(
        stage: VideoExportStage.validating,
        message: 'ملف الفيديو الناتج فارغ أو تالف ($len بايت).',
      );
    }

    final actualMime = await detectContainerMimeType(outputFile);
    if (config.format == VideoExportFormat.aviLossless) {
      if (actualMime != 'video/x-msvideo') {
        throw VideoExportException(
          stage: VideoExportStage.validating,
          message: 'نوع الحاوية الناتجة ($actualMime) لا يطابق صيغة AVI المطلوبة.',
        );
      }
      final frames = await extractFramesFromAvi(outputFile.path);
      if (frames.isEmpty) {
        throw const VideoExportException(
          stage: VideoExportStage.validating,
          message: 'ملف AVI الناتج لا يحتوي على إطارات فيديو صالحة (00dc).',
        );
      }
    } else {
      if (actualMime != 'video/mp4') {
        throw VideoExportException(
          stage: VideoExportStage.validating,
          message:
              'فشل التحقق من الحاوية: كان المتوقع MP4 (${config.codecLabel}) ولكن الملف الناتج من نوع $actualMime.',
        );
      }
    }
  }

  /// تصدير مشروع الفيديو كاملاً مع التحقق الصارم من المدخلات والذاكرة والصوت والصيغ (VID-001..VID-018)
  Future<ExportedVideoBundle> exportVideoProject({
    required VideoProjectEntity project,
    required List<Uint8List> renderedFrames,
    required int width,
    required int height,
    required int fps,
    VideoExportConfig config = const VideoExportConfig(),
    VideoExportCancelToken? cancelToken,
    void Function(double progress, String status)? onProgress,
  }) async {
    // 0. التحقق المسبق من صلاحية المشروع والإطارات قبل لمس القرص (VID-012)
    if (project.clips.isEmpty) {
      throw const VideoExportException(
        stage: VideoExportStage.preparing,
        message: 'لا يمكن تصدير مشروع فارغ لا يحتوي على أي مقاطع.',
      );
    }
    if (!project.colorGrade.hasValidParameters) {
      throw const VideoExportException(
        stage: VideoExportStage.preparing,
        message: 'إعدادات تصحيح الألوان Lumetri غير صالحة.',
      );
    }

    cancelToken?.throwIfCancelled(VideoExportStage.preparing);

    final (int targetW, int targetH) = config.resolveDimensions(
      project.numericAspectRatio,
    );
    final int effectiveFps = config.targetFps.clamp(15, 60);

    List<Uint8List> validInputFrames = renderedFrames
        .where((f) => f.length >= 8 && _hasValidPngSignature(f))
        .toList();

    // إذا لم تُمرر إطارات جاهزة، نولّدها عبر محرك الرندر الخلفي المستقل بالدقة ومعدل الإطارات المستهدفين (VID-015)
    int activeWidth = width > 0 && width.isEven ? width : targetW;
    int activeHeight = height > 0 && height.isEven ? height : targetH;
    int activeFps = fps > 0 ? fps : effectiveFps;

    if (validInputFrames.isEmpty) {
      if (renderedFrames.isNotEmpty) {
        // تم تمرير قائمة إطارات لكنها كلها فارغة أو تالفة (VID-012)
        throw const VideoExportException(
          stage: VideoExportStage.rendering,
          message: 'فشل التصدير: الإطارات الممررة فارغة أو تالفة.',
        );
      }
      validInputFrames =
          await OffscreenVideoCompositor.renderProjectFramesParallel(
            project: project,
            config: config,
            renderFps: effectiveFps,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
      activeWidth = targetW;
      activeHeight = targetH;
      activeFps = effectiveFps;
    }

    if (validInputFrames.isEmpty) {
      throw const VideoExportException(
        stage: VideoExportStage.rendering,
        message: 'فشل الرندر الخلفي: لم يتم إنتاج أي إطارات صالحة للتصدير.',
      );
    }

    cancelToken?.throwIfCancelled(VideoExportStage.processing);

    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${appDir.path}/exported_videos');
    if (!exportDir.existsSync()) {
      await exportDir.create(recursive: true);
    }

    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final baseName = 'love_reel_${project.id}_$timestampMs';
    final coverFile = File('${exportDir.path}/$baseName.png');
    final aviPath = '${exportDir.path}/$baseName.avi';
    final mp4Path = '${exportDir.path}/$baseName.mp4';
    final List<String> tempFilesToClean = <String>[];

    try {
      await coverFile.writeAsBytes(validInputFrames.first, flush: true);

      final preparedAudioPath = await _prepareAudioFileForExport(project);
      Uint8List? rustProcessedPcm;
      String? processedPcmFilePath;
      int pcmSampleRate = 44100;
      int pcmChannels = 2;

      final durationMs =
          ((validInputFrames.length / math.max(1, activeFps)) * 1000).round();

      // 1. فك ترميز الموسيقى الخلفية + كافة المؤثرات الصوتية على خط الزمن ومزجها مع توحيد معدلات العينات (VID-001 / VID-005)
      if (Platform.isAndroid &&
          (preparedAudioPath != null || project.soundEffects.isNotEmpty)) {
        onProgress?.call(
          0.78,
          'معالجة الصوت: جاري فك الترميز وتوحيد معدلات العينات وتطبيق التلاشي...',
        );
        final tempDir = await getTemporaryDirectory();
        final masterPcmPath = '${tempDir.path}/master_audio_$timestampMs.pcm';
        tempFilesToClean.add(masterPcmPath);

        if (preparedAudioPath != null && project.audioVolume > 0.01) {
          final decodedInfo = await _mediaChannel
              .invokeMethod<Map<Object?, Object?>>('decodeAudioToPcmFile', {
                'audioPath': preparedAudioPath,
                'outputPcmPath': masterPcmPath,
                'startOffsetMs': (project.audioStartOffset * 1000).round(),
                'durationMs': durationMs,
                'loopIfShorter': true,
              });
          if (decodedInfo != null) {
            final pcmPath = decodedInfo['pcmPath']?.toString();
            pcmSampleRate =
                (decodedInfo['sampleRate'] as num?)?.toInt() ?? 44100;
            pcmChannels = (decodedInfo['channels'] as num?)?.toInt() ?? 2;
            if (pcmPath != null && File(pcmPath).existsSync()) {
              final rawBgm = await File(pcmPath).readAsBytes();
              rustProcessedPcm = processPcm16Audio(
                pcmBytes: rawBgm,
                sampleRate: pcmSampleRate,
                channels: pcmChannels,
                volume: project.audioVolume,
                fadeIn: project.audioFadeIn,
                fadeOut: project.audioFadeOut,
              );
            }
          }
        }

        cancelToken?.throwIfCancelled(VideoExportStage.processing);

        if (rustProcessedPcm == null && project.soundEffects.isNotEmpty) {
          final totalPcmBytes =
              (((durationMs / 1000.0) * pcmSampleRate).round() *
                  pcmChannels *
                  2) &
              ~3;
          if (totalPcmBytes > 0) {
            rustProcessedPcm = Uint8List(totalPcmBytes);
          }
        }

        // مزج كل مؤثر صوتي مع قراءة معدل عيناته وعدد قنواته الفعليين (VID-005)
        if (rustProcessedPcm != null && project.soundEffects.isNotEmpty) {
          for (int sfxIdx = 0; sfxIdx < project.soundEffects.length; sfxIdx++) {
            cancelToken?.throwIfCancelled(VideoExportStage.processing);
            final sfx = project.soundEffects[sfxIdx];
            final sfxFile = await _prepareSingleAudioSource(
              sfx.sourcePath,
              isLocalFile: sfx.isLocalFile,
              tempTag: 'export_sfx_${timestampMs}_$sfxIdx',
            );
            if (sfxFile == null) continue;

            final sfxPcmPath =
                '${tempDir.path}/sfx_${timestampMs}_$sfxIdx.pcm';
            tempFilesToClean.add(sfxPcmPath);
            final sfxDecoded = await _mediaChannel
                .invokeMethod<Map<Object?, Object?>>('decodeAudioToPcmFile', {
                  'audioPath': sfxFile,
                  'outputPcmPath': sfxPcmPath,
                  'startOffsetMs': 0,
                  'durationMs': (sfx.durationSeconds * 1000).round().clamp(
                    100,
                    durationMs,
                  ),
                  'loopIfShorter': false,
                });
            final resolvedSfxPcm = sfxDecoded?['pcmPath']?.toString();
            final int sfxSampleRate =
                (sfxDecoded?['sampleRate'] as num?)?.toInt() ?? pcmSampleRate;
            final int sfxChannels =
                (sfxDecoded?['channels'] as num?)?.toInt() ?? pcmChannels;

            if (resolvedSfxPcm != null && File(resolvedSfxPcm).existsSync()) {
              final sfxBytes = await File(resolvedSfxPcm).readAsBytes();
              rustProcessedPcm = mixPcm16Overlay(
                masterPcm: rustProcessedPcm!,
                overlayPcm: sfxBytes,
                sampleRate: pcmSampleRate,
                channels: pcmChannels,
                overlaySampleRate: sfxSampleRate,
                overlayChannels: sfxChannels,
                startTimeSeconds: sfx.startTime,
                overlayVolume: sfx.volume,
              );
            }
          }
        }

        if (rustProcessedPcm != null && rustProcessedPcm.isNotEmpty) {
          await File(masterPcmPath).writeAsBytes(rustProcessedPcm, flush: true);
          processedPcmFilePath = masterPcmPath;
        }
      }

      cancelToken?.throwIfCancelled(VideoExportStage.encoding);
      onProgress?.call(
        0.84,
        'التجميع: جاري كتابة حاوية الفيديو والصوت المتداخلة...',
      );

      // 2. تجميع الإطارات (`00dc`) مع الصوت المتداخل (`01wb`) داخل حاوية RIFF/AVI
      await muxFramesToVideoContainer(
        frames: validInputFrames,
        outputPath: aviPath,
        width: activeWidth,
        height: activeHeight,
        fps: activeFps,
        pcm16Audio: rustProcessedPcm,
        audioSampleRate: pcmSampleRate,
        audioChannels: pcmChannels,
      );

      String finalVideoPath = aviPath;

      // 3. إذا اختار المستخدم صيغة MP4 (H.264 أو H.265 HEVC)، نقوم بالترميز الفعلي بدون سقوط صامت إلى AVI (VID-014 / VID-017)
      if (config.format != VideoExportFormat.aviLossless) {
        tempFilesToClean.add(aviPath);
        cancelToken?.throwIfCancelled(VideoExportStage.encoding);
        onProgress?.call(
          0.90,
          'الترميز: جاري ضغط الفيديو (${config.codecLabel} • ${config.resolutionLabel} • ${config.targetFps} FPS)...',
        );

        String? encodingError;
        if (Platform.isAndroid) {
          try {
            final nativeMp4 = await _mediaChannel.invokeMethod<String>(
              'muxToMp4WithAudio',
              {
                'aviPath': aviPath,
                'outputMp4Path': mp4Path,
                'audioPath': preparedAudioPath,
                'processedPcmPath': processedPcmFilePath,
                'pcmSampleRate': pcmSampleRate,
                'pcmChannels': pcmChannels,
                'audioStartOffsetMs': (project.audioStartOffset * 1000).round(),
                'audioVolume': project.audioVolume,
                'audioFadeIn': project.audioFadeIn,
                'audioFadeOut': project.audioFadeOut,
                'fps': activeFps,
                'targetFps': config.targetFps,
                'width': activeWidth,
                'height': activeHeight,
                'codecMime': config.codecMime,
                'bitrateBps': config.bitrateBps,
                'allowCodecFallback': false,
              },
            );
            if (nativeMp4 != null &&
                nativeMp4.isNotEmpty &&
                File(nativeMp4).existsSync() &&
                File(nativeMp4).lengthSync() > 0) {
              finalVideoPath = nativeMp4;
            }
          } catch (e) {
            encodingError = e.toString();
          }
        }

        // على أنظمة سطح المكتب والاختبار: استخدام FFmpeg
        if (finalVideoPath == aviPath && !Platform.isAndroid) {
          try {
            final ffmpegCodec = config.format == VideoExportFormat.mp4Hevc
                ? 'libx265'
                : 'libx264';
            final ffmpegArgs = <String>['-y', '-i', aviPath];
            if (rustProcessedPcm == null &&
                preparedAudioPath != null &&
                File(preparedAudioPath).existsSync()) {
              if (project.audioStartOffset > 0) {
                ffmpegArgs.addAll([
                  '-ss',
                  project.audioStartOffset.toStringAsFixed(2),
                ]);
              }
              ffmpegArgs.addAll(['-i', preparedAudioPath]);
            }
            ffmpegArgs.addAll([
              '-c:v',
              ffmpegCodec,
              '-pix_fmt',
              'yuv420p',
              '-vf',
              'scale=$activeWidth:$activeHeight:flags=lanczos,fps=${config.targetFps}',
              '-r',
              '${config.targetFps}',
              '-b:v',
              '${config.bitrateMbps}M',
            ]);
            if (rustProcessedPcm != null ||
                (preparedAudioPath != null &&
                    File(preparedAudioPath).existsSync())) {
              ffmpegArgs.addAll(['-c:a', 'aac', '-b:a', '128k', '-shortest']);
            }
            ffmpegArgs.add(mp4Path);

            final res = await Process.run('ffmpeg', ffmpegArgs);
            if (res.exitCode == 0 &&
                File(mp4Path).existsSync() &&
                File(mp4Path).lengthSync() > 0) {
              finalVideoPath = mp4Path;
            } else {
              encodingError =
                  'FFmpeg exited with code ${res.exitCode}: ${res.stderr}';
            }
          } catch (e) {
            encodingError = e.toString();
          }
        }

        if (finalVideoPath != mp4Path) {
          throw VideoExportException(
            stage: VideoExportStage.encoding,
            message:
                'فشل ترميز الفيديو بصيغة ${config.codecLabel} (${config.resolutionLabel} @ ${config.targetFps} FPS). ${encodingError ?? ""}',
          );
        }
      }

      cancelToken?.throwIfCancelled(VideoExportStage.validating);
      onProgress?.call(
        0.96,
        'التحقق النهائي: جاري فحص سلامة الحاوية والمسارات...',
      );

      // 4. التحقق المستقل النهائي قبل إعلان النجاح (VID-014 / VID-018)
      await verifyExportedVideoOutput(
        outputFile: File(finalVideoPath),
        config: config,
        expectedWidth: activeWidth,
        expectedHeight: activeHeight,
      );

      onProgress?.call(0.98, 'جاري حفظ الفيديو في المعرض ومجلد التنزيلات...');

      final ext = finalVideoPath.split('.').last;
      final publicFileName = '$baseName.$ext';
      final publicPath = await saveVideoToPublicDownloads(
        finalVideoPath,
        customFileName: publicFileName,
      );

      final exportedFps = config.format == VideoExportFormat.aviLossless
          ? activeFps
          : config.targetFps;

      final projectJsonFile = File('${exportDir.path}/$baseName.json');
      final jsonMap = project.toJson()
        ..['exportedVideoPath'] = finalVideoPath
        ..['publicVideoPath'] = publicPath ?? finalVideoPath
        ..['coverImagePath'] = coverFile.path
        ..['renderedFramesCount'] = validInputFrames.length
        ..['exportedFps'] = exportedFps
        ..['exportFormat'] = config.format.name
        ..['exportWidth'] = activeWidth
        ..['exportHeight'] = activeHeight
        ..['exportedAt'] = DateTime.now().toIso8601String();

      await projectJsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(jsonMap),
        flush: true,
      );

      final fileBytes = File(finalVideoPath).existsSync()
          ? File(finalVideoPath).lengthSync()
          : 0;

      onProgress?.call(1.0, 'اكتمل التصدير والتحقق بنجاح!');

      return ExportedVideoBundle(
        title: project.title,
        coverImagePath: coverFile.path,
        projectJsonPath: projectJsonFile.path,
        videoFilePath: finalVideoPath,
        publicVideoPath: publicPath ?? finalVideoPath,
        renderedFramesCount: validInputFrames.length,
        fps: exportedFps,
        fileSizeBytes: fileBytes,
        exportedAt: DateTime.now(),
      );
    } catch (e) {
      // تنظيف الملفات غير المكتملة عند الفشل أو الإلغاء (VID-003 / VID-014)
      for (final p in <String>[coverFile.path, aviPath, mp4Path]) {
        try {
          if (File(p).existsSync()) {
            await File(p).delete();
          }
        } catch (_) {}
      }
      if (e is VideoExportException) rethrow;
      throw VideoExportException(
        stage: VideoExportStage.failed,
        message: 'حدث خطأ غير متوقع أثناء التصدير: $e',
        cause: e,
      );
    } finally {
      for (final tempPath in tempFilesToClean) {
        try {
          if (File(tempPath).existsSync()) {
            await File(tempPath).delete();
          }
        } catch (_) {}
      }
    }
  }

  /// جلب قائمة جميع الفيديوهات المصدّرة لعرضها وإدارتها داخل الاستوديو
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
          final basePath = jsonFile.path.substring(
            0,
            jsonFile.path.length - 5,
          );
          final mp4Candidate = '$basePath.mp4';
          final aviCandidate = '$basePath.avi';
          final pngCandidate = '$basePath.png';

          final resolvedVideoPath = (map['exportedVideoPath'] as String?) !=
                      null &&
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
          final fps = (map['exportedFps'] as num?)?.toInt() ?? 30;
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

/// كاتب حاوية RIFF/AVI متدفق إلى القرص (Streaming Disk Writer) لمنع الاحتفاظ بكل الإطارات في الذاكرة (VID-003)
class StreamingAviFileWriter {
  final String outputPath;
  final int width;
  final int height;
  final int fps;
  final RandomAccessFile _raf;
  final Uint8List? _pcm16Audio;
  final int _audioSampleRate;
  final int _audioChannels;
  final int _totalExpectedFrames;

  final List<_AviIndexEntry> _indexEntries = <_AviIndexEntry>[];
  int _framesWritten = 0;
  int _audFrameCursor = 0;
  int _totalAudioBytesWritten = 0;
  int _moviPayloadBytes = 4; // "movi"
  int _currentChunkOffset = 4;
  late final int _riffSizePos;
  late final int _numFramesPos1;
  late final int _numFramesPos2;
  int? _audioTotalSamplesPos;
  int? _audioTotalBytesPos;
  late final int _moviSizePos;
  bool _closed = false;

  StreamingAviFileWriter._({
    required this.outputPath,
    required this.width,
    required this.height,
    required this.fps,
    required RandomAccessFile raf,
    required int totalExpectedFrames,
    Uint8List? pcm16Audio,
    int audioSampleRate = 44100,
    int audioChannels = 2,
  }) : _raf = raf,
       _totalExpectedFrames = math.max(1, totalExpectedFrames),
       _pcm16Audio = pcm16Audio,
       _audioSampleRate = audioSampleRate,
       _audioChannels = audioChannels;

  static Future<StreamingAviFileWriter> open({
    required String outputPath,
    required int width,
    required int height,
    required int fps,
    required int totalExpectedFrames,
    Uint8List? pcm16Audio,
    int audioSampleRate = 44100,
    int audioChannels = 2,
  }) async {
    final file = File(outputPath);
    if (file.existsSync()) {
      await file.delete();
    }
    final raf = await file.open(mode: FileMode.write);
    final writer = StreamingAviFileWriter._(
      outputPath: outputPath,
      width: width,
      height: height,
      fps: fps,
      raf: raf,
      totalExpectedFrames: totalExpectedFrames,
      pcm16Audio: pcm16Audio,
      audioSampleRate: audioSampleRate,
      audioChannels: audioChannels,
    );
    await writer._writeInitialHeaders();
    return writer;
  }

  bool get _hasAudio {
    final pcm = _pcm16Audio;
    final blockAlign = math.max(1, _audioChannels) * 2;
    return pcm != null &&
        pcm.length >= blockAlign &&
        _audioSampleRate > 0 &&
        _audioChannels > 0;
  }

  Future<void> _writeU32(int v) async {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    await _raf.writeFrom(b.buffer.asUint8List());
  }

  Future<void> _writeU16(int v) async {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    await _raf.writeFrom(b.buffer.asUint8List());
  }

  Future<void> _writeFourCC(String tag) async {
    await _raf.writeFrom(ascii.encode(tag.padRight(4).substring(0, 4)));
  }

  Future<void> _writeInitialHeaders() async {
    final safeFps = math.max(1, fps);
    final usecPerFrame = (1000000 + (safeFps ~/ 2)) ~/ safeFps;
    final frameBufferSize = width * height * 4;
    final maxBytesPerSec = frameBufferSize * safeFps;
    final hasAudio = _hasAudio;
    final numStreams = hasAudio ? 2 : 1;
    final audioStrlTotal = hasAudio ? (8 + 92) : 0;
    final hdrlSize = 192 + audioStrlTotal;

    await _writeFourCC('RIFF');
    _riffSizePos = await _raf.position();
    await _writeU32(0); // يُحدّث عند الإغلاق
    await _writeFourCC('AVI ');

    await _writeFourCC('LIST');
    await _writeU32(hdrlSize);
    await _writeFourCC('hdrl');

    await _writeFourCC('avih');
    await _writeU32(56);
    await _writeU32(usecPerFrame);
    await _writeU32(maxBytesPerSec);
    await _writeU32(0);
    await _writeU32(hasAudio ? 0x110 : 0x10);
    _numFramesPos1 = await _raf.position();
    await _writeU32(_totalExpectedFrames);
    await _writeU32(0);
    await _writeU32(numStreams);
    await _writeU32(frameBufferSize);
    await _writeU32(width);
    await _writeU32(height);
    await _raf.writeFrom(Uint8List(16));

    // Stream 0: Video (MPNG)
    await _writeFourCC('LIST');
    await _writeU32(116);
    await _writeFourCC('strl');

    await _writeFourCC('strh');
    await _writeU32(56);
    await _writeFourCC('vids');
    await _writeFourCC('MPNG');
    await _writeU32(0);
    await _writeU16(0);
    await _writeU16(0);
    await _writeU32(0);
    await _writeU32(1);
    await _writeU32(safeFps);
    await _writeU32(0);
    _numFramesPos2 = await _raf.position();
    await _writeU32(_totalExpectedFrames);
    await _writeU32(frameBufferSize);
    await _writeU32(0xFFFFFFFF);
    await _writeU32(0);
    await _writeU16(0);
    await _writeU16(0);
    await _writeU16(width);
    await _writeU16(height);

    await _writeFourCC('strf');
    await _writeU32(40);
    await _writeU32(40);
    await _writeU32(width);
    await _writeU32(height);
    await _writeU16(1);
    await _writeU16(32);
    await _writeFourCC('MPNG');
    await _writeU32(frameBufferSize);
    await _raf.writeFrom(Uint8List(16));

    // Stream 1: Audio (PCM 16-bit LE)
    if (hasAudio) {
      final int blockAlign = _audioChannels * 2;
      final int avgBytesPerSec = _audioSampleRate * blockAlign;

      await _writeFourCC('LIST');
      await _writeU32(92);
      await _writeFourCC('strl');

      await _writeFourCC('strh');
      await _writeU32(56);
      await _writeFourCC('auds');
      await _writeU32(1);
      await _writeU32(0);
      await _writeU16(0);
      await _writeU16(0);
      await _writeU32(0);
      await _writeU32(blockAlign);
      await _writeU32(avgBytesPerSec);
      await _writeU32(0);
      _audioTotalSamplesPos = await _raf.position();
      await _writeU32(0);
      _audioTotalBytesPos = await _raf.position();
      await _writeU32(0);
      await _writeU32(0xFFFFFFFF);
      await _writeU32(blockAlign);
      await _raf.writeFrom(Uint8List(8));

      await _writeFourCC('strf');
      await _writeU32(16);
      await _writeU16(1);
      await _writeU16(_audioChannels);
      await _writeU32(_audioSampleRate);
      await _writeU32(avgBytesPerSec);
      await _writeU16(blockAlign);
      await _writeU16(16);
    }

    await _writeFourCC('LIST');
    _moviSizePos = await _raf.position();
    await _writeU32(0); // يُحدّث عند الإغلاق
    await _writeFourCC('movi');
  }

  Future<void> writeFrame(Uint8List pngFrame) async {
    if (_closed || pngFrame.isEmpty) return;

    final int sz = pngFrame.length;
    _indexEntries.add(_AviIndexEntry('00dc', _currentChunkOffset, sz));
    await _writeFourCC('00dc');
    await _writeU32(sz);
    await _raf.writeFrom(pngFrame);
    if (sz.isOdd) {
      await _raf.writeByte(0);
    }
    final int paddedVideo = sz + (sz.isOdd ? 1 : 0);
    _currentChunkOffset += 8 + paddedVideo;
    _moviPayloadBytes += 8 + paddedVideo;
    _framesWritten++;

    if (_hasAudio) {
      final pcm = _pcm16Audio!;
      final int blockAlign = _audioChannels * 2;
      final int totalAudioFrames = pcm.length ~/ blockAlign;
      if (_audFrameCursor < totalAudioFrames) {
        final int safeFps = math.max(1, fps);
        final int nextTargetFrame = _framesWritten >= _totalExpectedFrames
            ? totalAudioFrames
            : math.min(
                totalAudioFrames,
                ((_framesWritten * _audioSampleRate) ~/ safeFps),
              );
        if (nextTargetFrame > _audFrameCursor) {
          final int byteStart = _audFrameCursor * blockAlign;
          final int byteEnd = nextTargetFrame * blockAlign;
          final int audSz = byteEnd - byteStart;
          _indexEntries.add(_AviIndexEntry('01wb', _currentChunkOffset, audSz));
          await _writeFourCC('01wb');
          await _writeU32(audSz);
          await _raf.writeFrom(pcm, byteStart, byteEnd);
          if (audSz.isOdd) {
            await _raf.writeByte(0);
          }
          final int paddedAud = audSz + (audSz.isOdd ? 1 : 0);
          _currentChunkOffset += 8 + paddedAud;
          _moviPayloadBytes += 8 + paddedAud;
          _totalAudioBytesWritten += audSz;
          _audFrameCursor = nextTargetFrame;
        }
      }
    }
  }

  Future<File> finalize() async {
    if (_closed) return File(outputPath);
    _closed = true;

    final int idx1Bytes = _indexEntries.length * 16;
    await _writeFourCC('idx1');
    await _writeU32(idx1Bytes);
    for (final entry in _indexEntries) {
      await _writeFourCC(entry.tag);
      await _writeU32(0x10);
      await _writeU32(entry.offset);
      await _writeU32(entry.size);
    }

    final int fileLength = await _raf.length();
    final int riffSize = math.max(0, fileLength - 8);

    await _raf.setPosition(_riffSizePos);
    await _writeU32(riffSize);

    await _raf.setPosition(_numFramesPos1);
    await _writeU32(_framesWritten);

    await _raf.setPosition(_numFramesPos2);
    await _writeU32(_framesWritten);

    if (_audioTotalSamplesPos != null && _audioTotalBytesPos != null) {
      final int blockAlign = math.max(1, _audioChannels * 2);
      await _raf.setPosition(_audioTotalSamplesPos!);
      await _writeU32(_totalAudioBytesWritten ~/ blockAlign);
      await _raf.setPosition(_audioTotalBytesPos!);
      await _writeU32(_totalAudioBytesWritten);
    }

    await _raf.setPosition(_moviSizePos);
    await _writeU32(_moviPayloadBytes);

    await _raf.flush();
    await _raf.close();
    return File(outputPath);
  }

  Future<void> abort() async {
    if (!_closed) {
      _closed = true;
      try {
        await _raf.close();
      } catch (_) {}
    }
    try {
      final f = File(outputPath);
      if (f.existsSync()) {
        await f.delete();
      }
    } catch (_) {}
  }
}

class _AviIndexEntry {
  final String tag;
  final int offset;
  final int size;
  const _AviIndexEntry(this.tag, this.offset, this.size);
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
    this.fps = 30,
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

/// صيغ وكودك تصدير الفيديو المدعومة
enum VideoExportFormat {
  mp4H264,
  mp4Hevc,
  aviLossless,
}

/// إعدادات الرندر والتصدير الاحترافية (الصيغة، الكودك، الدقة 1080p/720p، معدل الإطارات 30/60 FPS، معدل البت، وحجم الدفعة المتوازية)
class VideoExportConfig {
  final VideoExportFormat format;
  final int resolutionShortSide; // 1080 (Full HD) or 720 (HD)
  final int targetFps;           // 30 or 60 FPS
  final int bitrateMbps;         // 6..16 Mbps (supports 14 Mbps Full HD)
  final int parallelBatchSize;   // 4..8 frames rendered concurrently

  const VideoExportConfig({
    this.format = VideoExportFormat.mp4H264,
    this.resolutionShortSide = 1080,
    this.targetFps = 30,
    this.bitrateMbps = 14,
    this.parallelBatchSize = 6,
  });

  String get codecMime => switch (format) {
    VideoExportFormat.mp4Hevc => 'video/hevc',
    _ => 'video/avc',
  };

  String get containerMime => switch (format) {
    VideoExportFormat.aviLossless => 'video/x-msvideo',
    _ => 'video/mp4',
  };

  String get codecLabel => switch (format) {
    VideoExportFormat.mp4H264 => 'MP4 (H.264 AVC)',
    VideoExportFormat.mp4Hevc => 'MP4 (H.265 HEVC)',
    VideoExportFormat.aviLossless => 'AVI (Motion-PNG Lossless)',
  };

  String get resolutionLabel =>
      resolutionShortSide >= 1080 ? '1080p Full HD' : '720p HD';

  int get bitrateBps => bitrateMbps.clamp(2, 24) * 1000000;

  /// حساب أبعاد الرندر الخلفي الحقيقية (Offscreen True Resolution) بناءً على نسبة العرض إلى الارتفاع للمشروع
  (int, int) resolveDimensions(double aspectRatio) {
    final isFullHd = resolutionShortSide >= 1080;
    if (aspectRatio < 0.8) {
      return isFullHd ? (1080, 1920) : (720, 1280);
    } else if (aspectRatio > 1.2) {
      return isFullHd ? (1920, 1080) : (1280, 720);
    } else {
      return isFullHd ? (1080, 1080) : (720, 720);
    }
  }

  VideoExportConfig copyWith({
    VideoExportFormat? format,
    int? resolutionShortSide,
    int? targetFps,
    int? bitrateMbps,
    int? parallelBatchSize,
  }) {
    return VideoExportConfig(
      format: format ?? this.format,
      resolutionShortSide: resolutionShortSide ?? this.resolutionShortSide,
      targetFps: targetFps ?? this.targetFps,
      bitrateMbps: bitrateMbps ?? this.bitrateMbps,
      parallelBatchSize: parallelBatchSize ?? this.parallelBatchSize,
    );
  }
}