// test/widget_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:our_love_story/core/services/rust_video_bridge.dart';
import 'package:our_love_story/data/mappers/event_mapper.dart';
import 'package:our_love_story/data/mappers/media_mapper.dart';
import 'package:our_love_story/domain/entities/entities.dart';
import 'package:our_love_story/domain/entities/timeline_event_entity.dart';
import 'package:our_love_story/domain/entities/video_project_entity.dart';

void main() {
  group('Domain, Mapper & Keyframe Video Engine Regression Tests (VID-019)', () {
    test('TimelineEventEntity maps to HiveModel and back accurately', () {
      final now = DateTime(2025, 9, 17);
      final entity = TimelineEventEntity(
        id: 'evt_1',
        date: now,
        title: 'الفرح',
        description: 'يوم زفافنا السعيد',
        icon: '🎉',
        location: 'نادي المقاولون العرب',
        tags: ['زفاف', 'فرح'],
        orderIndex: 1,
        createdAt: now,
        updatedAt: now,
      );

      final model = entity.toHiveModel();
      final roundTrip = model.toEntity();

      expect(roundTrip.id, equals(entity.id));
      expect(roundTrip.title, equals(entity.title));
      expect(roundTrip.location, equals(entity.location));
      expect(roundTrip.tags, equals(['زفاف', 'فرح']));
      expect(roundTrip.seasonKey, equals('autumn'));
    });

    test('MediaFileEntity maps to HiveModel and back accurately', () {
      final now = DateTime(2025, 11, 15);
      final media = MediaFileEntity(
        id: 'med_1',
        cloudinaryUrl: 'https://example.com/photo.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        localPath: '/tmp/local.jpg',
        mediaType: MediaType.photo,
        uploadDate: now,
        description: 'ذكرى جميلة',
        isFeatured: true,
        tags: ['حمل'],
      );

      final model = media.toHiveModel();
      final roundTrip = model.toEntity();

      expect(roundTrip.id, equals(media.id));
      expect(roundTrip.localPath, equals('/tmp/local.jpg'));
      expect(roundTrip.isFeatured, isTrue);
      expect(roundTrip.tags, contains('حمل'));
    });

    test('RustVideoBridge interpolates Keyframes accurately across time', () {
      const keyframes = [
        KeyframePoint(
          timestamp: 0.0,
          scale: 1.0,
          x: 0.0,
          opacity: 0.5,
          easing: KeyframeEasing.linear,
        ),
        KeyframePoint(
          timestamp: 4.0,
          scale: 2.0,
          x: 0.4,
          opacity: 1.0,
          easing: KeyframeEasing.linear,
        ),
      ];

      final mid = RustVideoBridge.instance.evaluateKeyframes(keyframes, 2.0);
      expect(mid.scale, closeTo(1.5, 0.001));
      expect(mid.x, closeTo(0.2, 0.001));
      expect(mid.opacity, closeTo(0.75, 0.001));
    });
  });

  group('Video Engine Audit Verification Suite (VID-001 .. VID-018)', () {
    test('VID-001: Stereo and Mono PCM16 fade-in/out have identical frame timing and L/R symmetry', () {
      const int sampleRate = 1000;
      const int totalFrames = 3000; // 3.0 seconds
      final monoBytes = Uint8List(totalFrames * 2);
      final stereoBytes = Uint8List(totalFrames * 4);
      final monoView = ByteData.sublistView(monoBytes);
      final stereoView = ByteData.sublistView(stereoBytes);

      for (int f = 0; f < totalFrames; f++) {
        monoView.setInt16(f * 2, 20000, Endian.little);
        stereoView.setInt16(f * 4, 20000, Endian.little);
        stereoView.setInt16(f * 4 + 2, 20000, Endian.little);
      }

      final outMono = RustVideoBridge.instance.processPcm16Audio(
        pcmBytes: monoBytes,
        sampleRate: sampleRate,
        channels: 1,
        volume: 1.0,
        fadeIn: true,
        fadeOut: true,
      );
      final outStereo = RustVideoBridge.instance.processPcm16Audio(
        pcmBytes: stereoBytes,
        sampleRate: sampleRate,
        channels: 2,
        volume: 1.0,
        fadeIn: true,
        fadeOut: true,
      );

      final outMonoView = ByteData.sublistView(outMono);
      final outStereoView = ByteData.sublistView(outStereo);

      for (int f = 0; f < totalFrames; f++) {
        final m = outMonoView.getInt16(f * 2, Endian.little);
        final sL = outStereoView.getInt16(f * 4, Endian.little);
        final sR = outStereoView.getInt16(f * 4 + 2, Endian.little);
        expect(sL, equals(sR), reason: 'Stereo L and R must match at frame $f');
        expect(m, equals(sL), reason: 'Mono and Stereo must match at frame $f');
      }

      expect(outStereoView.getInt16(0, Endian.little), equals(0));
      expect(outStereoView.getInt16(1500 * 4, Endian.little), equals(20000));
      expect(
        outStereoView.getInt16((totalFrames - 1) * 4, Endian.little),
        equals(0),
      );
    });

    test('VID-005: mixPcm16Overlay resamples and converts channels accurately', () {
      const int masterRate = 48000;
      const int overlayRate = 24000;
      final master = Uint8List(masterRate * 4); // 1.0s stereo
      final overlay = Uint8List(12000 * 2); // 0.5s mono at 24kHz
      final ovView = ByteData.sublistView(overlay);
      for (int i = 0; i < 12000; i++) {
        ovView.setInt16(i * 2, 10000, Endian.little);
      }

      final mixed = RustVideoBridge.instance.mixPcm16Overlay(
        masterPcm: master,
        overlayPcm: overlay,
        sampleRate: masterRate,
        channels: 2,
        overlaySampleRate: overlayRate,
        overlayChannels: 1,
        startTimeSeconds: 0.25,
        overlayVolume: 1.0,
      );

      final mixedView = ByteData.sublistView(mixed);
      expect(mixedView.getInt16(11999 * 4, Endian.little), equals(0));
      expect(mixedView.getInt16(20000 * 4, Endian.little), equals(10000));
      expect(mixedView.getInt16(20000 * 4 + 2, Endian.little), equals(10000));
      expect(mixedView.getInt16(36005 * 4, Endian.little), equals(0));
    });

    test('VID-007: processRgbaBatchLumetriWithStatus distinguishes notRequired, applied, and failed', () {
      final rgba = Uint8List.fromList(List<int>.filled(4 * 4 * 4, 128));

      final idRes = RustVideoBridge.instance.processRgbaBatchLumetriWithStatus(
        rgbaBatchBytes: rgba,
        numFrames: 1,
        width: 4,
        height: 4,
        grade: const LumetriColorGrade(),
      );
      expect(idRes.status, equals(LumetriProcessStatus.notRequired));
      expect(idRes.bytes[0], equals(128));

      final gradedRes = RustVideoBridge.instance
          .processRgbaBatchLumetriWithStatus(
            rgbaBatchBytes: rgba,
            numFrames: 1,
            width: 4,
            height: 4,
            grade: const LumetriColorGrade(exposure: 1.0),
          );
      expect(gradedRes.isSuccess, isTrue);
      expect(gradedRes.bytes[0], greaterThan(200));

      expect(
        () => RustVideoBridge.instance.processRgbaBatchLumetri(
          rgbaBatchBytes: Uint8List(10), // smaller than 4*4*4
          numFrames: 1,
          width: 4,
          height: 4,
          grade: const LumetriColorGrade(exposure: 0.5),
        ),
        throwsA(isA<VideoExportException>()),
      );
    });

    test('VID-009: AVI parser validates RIFF/AVI headers, movi bounds, and PNG signature', () async {
      final fakePng = Uint8List.fromList([
        ...RustVideoBridge.pngSignature,
        1,
        2,
        3,
        4,
        5,
      ]);
      final tmpAvi = '${Directory.systemTemp.path}/vid009_test.avi';
      await RustVideoBridge.instance.muxFramesToVideoContainer(
        frames: [fakePng, fakePng],
        outputPath: tmpAvi,
        width: 720,
        height: 1280,
        fps: 30,
      );

      final extracted = await RustVideoBridge.instance.extractFramesFromAvi(
        tmpAvi,
      );
      expect(extracted.length, equals(2));
      expect(extracted.first, equals(fakePng));

      // اختبار ملف تالف لا يبدأ بـ RIFF
      final corruptBytes = Uint8List.fromList(List<int>.filled(64, 0x30));
      expect(
        RustVideoBridge.instance.parseAviFramesFromBytes(corruptBytes),
        isEmpty,
      );
      if (File(tmpAvi).existsSync()) {
        await File(tmpAvi).delete();
      }
    });

    test('VID-010 & VID-011: Numerical parity and odd-dimension NV12 rejection', () {
      // ticksToAudioSample integer floor parity
      const int halfSampleTicks =
          RustVideoBridge.ticksPerSecond ~/ (44100 * 2);
      expect(
        RustVideoBridge.instance.ticksToAudioSample(halfSampleTicks, 44100),
        equals(0),
      );

      // Odd dimensions rejected in NV12 conversion
      final oddRgba = Uint8List(15 * 16 * 4);
      expect(
        RustVideoBridge.instance.convertRgbaToNv12(
          rgbaBytes: oddRgba,
          width: 15,
          height: 16,
        ),
        isNull,
      );

      // Even dimensions succeed and produce Studio-Swing BT.709 Y=235, U=128, V=128 for pure white
      final whiteRgba = Uint8List.fromList(List<int>.filled(16 * 16 * 4, 255));
      final nv12 = RustVideoBridge.instance.convertRgbaToNv12(
        rgbaBytes: whiteRgba,
        width: 16,
        height: 16,
      );
      expect(nv12, isNotNull);
      expect(nv12![0], equals(235));
      expect(nv12[16 * 16], equals(128));
      expect(nv12[16 * 16 + 1], equals(128));
    });

    test('VID-012 & VID-013: Empty project rejection and 4x Inter-Sample Peak detection', () async {
      final emptyProject = VideoProjectEntity(
        id: 'empty_proj',
        title: 'فارغ',
        clips: const [],
        createdAt: DateTime(2026, 1, 1),
      );
      expect(
        () => RustVideoBridge.instance.exportVideoProject(
          project: emptyProject,
          renderedFrames: const [],
          width: 720,
          height: 1280,
          fps: 30,
        ),
        throwsA(isA<VideoExportException>()),
      );

      // Inter-sample peak between (-27000, +27500, +27500, -27000) overshoots 27500
      final truePeak = RustVideoBridge.instance.estimateIntersamplePeak4x(
        -27000.0,
        27500.0,
        27500.0,
        -27000.0,
      );
      expect(truePeak, greaterThan(27500.0));
      final limited = RustVideoBridge.instance.softKneeTruePeakLimit4x(
        -27000.0,
        27500.0,
        27500.0,
        -27000.0,
      );
      expect(limited, lessThan(27500));
    });
  });
}
