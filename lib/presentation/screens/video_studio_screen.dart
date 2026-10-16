// lib/presentation/screens/video_studio_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart' hide VideoAudioTrack;

import '../../core/constants/app_constants.dart';
import '../../core/services/rust_video_bridge.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/video_project_entity.dart';
import '../../theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../providers/media_provider.dart';

class VideoStudioScreen extends ConsumerStatefulWidget {
  final VideoProjectEntity? initialProject;

  const VideoStudioScreen({super.key, this.initialProject});

  @override
  ConsumerState<VideoStudioScreen> createState() => _VideoStudioScreenState();
}

class _VideoStudioScreenState extends ConsumerState<VideoStudioScreen> {
  final GlobalKey _stageBoundaryKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  final Map<String, VideoPlayerController> _videoControllers = {};

  // مشغلات الصوت المخصصة للاستوديو (لتشغيل الموسيقى الخلفية، المعاينة، والمؤثرات الصوتية بدقة)
  final AudioPlayer _studioBgmPlayer = AudioPlayer();
  final AudioPlayer _studioSfxPlayer = AudioPlayer();
  final AudioPlayer _previewAudioPlayer = AudioPlayer();
  String? _currentlyPreviewingTrack;
  final Set<String> _triggeredSfxInCurrentPlay = {};

  // سجل التراجع والإعادة (Undo / Redo Command History)
  final List<VideoProjectEntity> _undoStack = [];
  final List<VideoProjectEntity> _redoStack = [];

  late VideoProjectEntity _project;
  int _selectedClipIndex = 0;
  int _selectedKeyframeIndex = 0;
  int _selectedTextTrackIndex = 0;
  bool _editTextKeyframes = false;
  KeyframePoint? _copiedKeyframe;

  // 0: المقاطع, 1: Keyframes ◆, 2: النصوص, 3: 🎨 Lumetri, 4: الانتقالات, 5: 🎵 الصوت
  int _activeToolTab = 0;

  double _playheadTime = 0.0;
  bool _isPlaying = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  Timer? _playbackTimer;

  double _gestureBaseScale = 1.0;
  double _gestureBaseRotation = 0.0;
  double _gestureBaseX = 0.0;
  double _gestureBaseY = 0.0;

  @override
  void initState() {
    super.initState();
    _project = widget.initialProject ?? _createInitialTemplate();
    _initVideoControllers();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _studioBgmPlayer.dispose();
    _studioSfxPlayer.dispose();
    _previewAudioPlayer.dispose();
    for (final ctrl in _videoControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _pushUndoSnapshot() {
    _undoStack.add(_project);
    if (_undoStack.length > 35) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _commitProjectChange(VideoProjectEntity updated) {
    _pushUndoSnapshot();
    setState(() {
      _project = updated;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_project);
    setState(() {
      _project = _undoStack.removeLast();
      _clampSelectionIndices();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_project);
    setState(() {
      _project = _redoStack.removeLast();
      _clampSelectionIndices();
    });
  }

  void _clampSelectionIndices() {
    if (_project.clips.isEmpty) {
      _selectedClipIndex = 0;
    } else {
      _selectedClipIndex = _selectedClipIndex.clamp(
        0,
        _project.clips.length - 1,
      );
    }
    if (_project.textTracks.isEmpty) {
      _selectedTextTrackIndex = 0;
      _editTextKeyframes = false;
    } else {
      _selectedTextTrackIndex = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
    }
    final activeKfs = _activeKeyframesList;
    if (activeKfs.isEmpty) {
      _selectedKeyframeIndex = 0;
    } else {
      _selectedKeyframeIndex = _selectedKeyframeIndex.clamp(
        0,
        activeKfs.length - 1,
      );
    }
  }

  List<KeyframePoint> get _activeKeyframesList {
    if (_editTextKeyframes && _project.textTracks.isNotEmpty) {
      final idx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      return _project.textTracks[idx].keyframes;
    }
    if (_project.clips.isNotEmpty) {
      final idx = _selectedClipIndex.clamp(0, _project.clips.length - 1);
      return _project.clips[idx].keyframes;
    }
    return const [];
  }

  double get _activeTargetDuration {
    if (_editTextKeyframes && _project.textTracks.isNotEmpty) {
      final idx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      final t = _project.textTracks[idx];
      return math.max(0.2, t.endTime - t.startTime);
    }
    if (_project.clips.isNotEmpty) {
      final idx = _selectedClipIndex.clamp(0, _project.clips.length - 1);
      return math.max(0.2, _project.clips[idx].durationSeconds);
    }
    return 4.0;
  }

  double get _activeTargetStartTime {
    if (_editTextKeyframes && _project.textTracks.isNotEmpty) {
      final idx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      return _project.textTracks[idx].startTime;
    }
    return _clipStartTime(_selectedClipIndex);
  }

  Future<void> _initVideoControllers() async {
    for (final clip in _project.clips) {
      if (clip.sourceType == VideoClipSourceType.video &&
          !_videoControllers.containsKey(clip.id)) {
        VideoPlayerController? ctrl;
        if (clip.localPath != null && File(clip.localPath!).existsSync()) {
          ctrl = VideoPlayerController.file(File(clip.localPath!));
        } else if (clip.networkUrl != null && clip.networkUrl!.isNotEmpty) {
          ctrl = VideoPlayerController.networkUrl(Uri.parse(clip.networkUrl!));
        }
        if (ctrl != null) {
          _videoControllers[clip.id] = ctrl;
          try {
            await ctrl.initialize();
            await ctrl.setVolume(0.0);
            if (mounted) setState(() {});
          } catch (_) {}
        }
      }
    }
  }

  VideoProjectEntity _createInitialTemplate() {
    return VideoProjectEntity(
      id: const Uuid().v4(),
      title: 'قصة حب محمد وسارة ❤️',
      aspectRatio: VideoAspectRatioPreset.portrait9x16,
      colorGrade: LumetriColorGrade.fromPreset(
        LumetriLookPreset.etherealRomance,
      ),
      audioAsset: AppConstants.romanticIntro,
      audioVolume: 0.85,
      createdAt: DateTime.now(),
      clips: const [
        VideoClipItem(
          id: 'clip_1',
          title: 'أول لقاء 💫',
          networkUrl:
              'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=600',
          durationSeconds: 4.0,
          transition: VideoTransitionType.crossDissolve,
          keyframes: [
            KeyframePoint(
              timestamp: 0.0,
              scale: 1.0,
              x: 0.0,
              y: 0.0,
              opacity: 1.0,
              easing: KeyframeEasing.autoBezier,
            ),
            KeyframePoint(
              timestamp: 4.0,
              scale: 1.18,
              x: -0.04,
              y: -0.03,
              opacity: 1.0,
              easing: KeyframeEasing.autoBezier,
            ),
          ],
        ),
        VideoClipItem(
          id: 'clip_2',
          title: 'خاتم الخطوبة 💍',
          networkUrl:
              'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=600',
          durationSeconds: 4.0,
          transition: VideoTransitionType.zoomIn,
          keyframes: [
            KeyframePoint(
              timestamp: 0.0,
              scale: 1.15,
              x: 0.03,
              y: 0.0,
              opacity: 1.0,
              easing: KeyframeEasing.autoBezier,
            ),
            KeyframePoint(
              timestamp: 2.0,
              scale: 1.02,
              x: 0.0,
              y: 0.0,
              rotation: 2.0,
              opacity: 1.0,
              easing: KeyframeEasing.autoBezier,
            ),
            KeyframePoint(
              timestamp: 4.0,
              scale: 1.12,
              x: -0.02,
              y: 0.02,
              rotation: 0.0,
              opacity: 1.0,
              easing: KeyframeEasing.autoBezier,
            ),
          ],
        ),
        VideoClipItem(
          id: 'clip_3',
          title: 'يوم زفافنا 🎉',
          networkUrl:
              'https://images.unsplash.com/photo-1519741497674-611481863552?w=600',
          durationSeconds: 4.0,
          transition: VideoTransitionType.heartPulse,
          keyframes: [
            KeyframePoint(
              timestamp: 0.0,
              scale: 1.0,
              opacity: 1.0,
              easing: KeyframeEasing.elasticOut,
            ),
            KeyframePoint(
              timestamp: 4.0,
              scale: 1.2,
              y: -0.04,
              opacity: 1.0,
              easing: KeyframeEasing.easeInOut,
            ),
          ],
        ),
      ],
      textTracks: const [
        VideoTextTrack(
          id: 'txt_1',
          text: 'محمد ❤️ سارة\nحكاية حب لا تنتهي',
          startTime: 0.2,
          endTime: 3.8,
          fontSize: 24,
          fontStyle: 'serif',
          keyframes: [
            KeyframePoint(timestamp: 0.0, y: 0.25, opacity: 0.0, scale: 0.8),
            KeyframePoint(timestamp: 0.8, y: 0.0, opacity: 1.0, scale: 1.0),
            KeyframePoint(timestamp: 3.0, y: 0.0, opacity: 1.0, scale: 1.05),
            KeyframePoint(timestamp: 3.6, y: -0.1, opacity: 0.0, scale: 0.95),
          ],
        ),
        VideoTextTrack(
          id: 'txt_2',
          text: 'كل لحظة معكِ هي إرث سينمائي ✨',
          startTime: 4.2,
          endTime: 11.5,
          fontSize: 20,
          fontStyle: 'script',
          keyframes: [
            KeyframePoint(timestamp: 0.0, y: 0.3, opacity: 0.0, scale: 0.9),
            KeyframePoint(timestamp: 0.7, y: 0.2, opacity: 1.0, scale: 1.0),
            KeyframePoint(timestamp: 6.5, y: 0.2, opacity: 1.0, scale: 1.0),
            KeyframePoint(timestamp: 7.2, y: 0.3, opacity: 0.0, scale: 0.9),
          ],
        ),
      ],
    );
  }

  // ─── Playback & Synchronized Audio Engine ──────────────────────────────────

  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  Future<void> _startStudioAudioAtPlayhead() async {
    try {
      await _previewAudioPlayer.stop();
      setState(() => _currentlyPreviewingTrack = null);

      if (!_project.hasBackgroundAudio || _project.audioVolume <= 0.01) {
        await _studioBgmPlayer.stop();
        return;
      }

      await _studioBgmPlayer.setVolume(
        _computeInstantAudioVolume(_playheadTime),
      );
      final seekOffsetSeconds = _project.audioStartOffset + _playheadTime;

      if (_project.customAudioPath != null &&
          _project.customAudioPath!.isNotEmpty &&
          File(_project.customAudioPath!).existsSync()) {
        await _studioBgmPlayer.play(
          DeviceFileSource(_project.customAudioPath!),
          position: Duration(milliseconds: (seekOffsetSeconds * 1000).round()),
        );
      } else if (_project.audioAsset != null &&
          _project.audioAsset!.isNotEmpty) {
        await _studioBgmPlayer.play(
          AssetSource(_project.audioAsset!),
          position: Duration(milliseconds: (seekOffsetSeconds * 1000).round()),
        );
      }
    } catch (_) {}
  }

  double _computeInstantAudioVolume(double playhead) {
    final baseVol = _project.audioVolume.clamp(0.0, 1.0);
    final total = _project.totalDuration;
    if (total <= 0.5) return baseVol;

    double factor = 1.0;
    const fadeWindow = 1.2;
    if (_project.audioFadeIn && playhead < fadeWindow) {
      factor *= (playhead / fadeWindow).clamp(0.0, 1.0);
    }
    if (_project.audioFadeOut && (total - playhead) < fadeWindow) {
      factor *= ((total - playhead) / fadeWindow).clamp(0.0, 1.0);
    }
    return (baseVol * factor).clamp(0.0, 1.0);
  }

  void _checkAndTriggerSoundEffects(double currentTime) {
    for (final sfx in _project.soundEffects) {
      if ((currentTime - sfx.startTime).abs() < 0.06 &&
          !_triggeredSfxInCurrentPlay.contains(sfx.id)) {
        _triggeredSfxInCurrentPlay.add(sfx.id);
        _playSingleSoundEffect(sfx);
      }
    }
  }

  Future<void> _playSingleSoundEffect(VideoAudioTrack sfx) async {
    try {
      await _studioSfxPlayer.setVolume(sfx.volume.clamp(0.0, 1.0));
      if (sfx.isLocalFile && File(sfx.sourcePath).existsSync()) {
        await _studioSfxPlayer.play(DeviceFileSource(sfx.sourcePath));
      } else {
        await _studioSfxPlayer.play(AssetSource(sfx.sourcePath));
      }
    } catch (_) {}
  }

  void _startPlayback() {
    final total = _project.totalDuration;
    if (total <= 0) return;

    if (_playheadTime >= total) {
      _playheadTime = 0.0;
    }

    _triggeredSfxInCurrentPlay.clear();
    setState(() => _isPlaying = true);
    _startStudioAudioAtPlayhead();

    const tickMs = 33;
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _playheadTime += tickMs / 1000.0;
        if (_project.hasBackgroundAudio) {
          _studioBgmPlayer.setVolume(_computeInstantAudioVolume(_playheadTime));
        }
        _checkAndTriggerSoundEffects(_playheadTime);

        if (_playheadTime >= _project.totalDuration) {
          _playheadTime = 0.0;
          _isPlaying = false;
          _studioBgmPlayer.stop();
          _studioSfxPlayer.stop();
          t.cancel();
        }
        _syncSelectedClipWithPlayhead();
      });
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    _studioBgmPlayer.pause();
    _studioSfxPlayer.stop();
    for (final ctrl in _videoControllers.values) {
      if (ctrl.value.isPlaying) ctrl.pause();
    }
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _togglePreviewAudioTrack(
    String source, {
    required bool isLocalFile,
  }) async {
    try {
      if (_currentlyPreviewingTrack == source) {
        await _previewAudioPlayer.stop();
        if (mounted) setState(() => _currentlyPreviewingTrack = null);
        return;
      }
      _pausePlayback();
      await _previewAudioPlayer.stop();
      await _previewAudioPlayer.setVolume(_project.audioVolume.clamp(0.1, 1.0));
      setState(() => _currentlyPreviewingTrack = source);

      if (isLocalFile) {
        await _previewAudioPlayer.play(DeviceFileSource(source));
      } else {
        await _previewAudioPlayer.play(AssetSource(source));
      }

      _previewAudioPlayer.onPlayerComplete.first.then((_) {
        if (mounted && _currentlyPreviewingTrack == source) {
          setState(() => _currentlyPreviewingTrack = null);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _currentlyPreviewingTrack = null);
    }
  }

  void _syncSelectedClipWithPlayhead() {
    double acc = 0.0;
    for (int i = 0; i < _project.clips.length; i++) {
      final clip = _project.clips[i];
      final d = clip.durationSeconds;
      if (_playheadTime >= acc && _playheadTime <= acc + d) {
        if (_selectedClipIndex != i) {
          _selectedClipIndex = i;
          if (!_editTextKeyframes) {
            _selectedKeyframeIndex = 0;
          }
        }
        final vCtrl = _videoControllers[clip.id];
        if (vCtrl != null && vCtrl.value.isInitialized) {
          final targetMs = ((_playheadTime - acc) * 1000).round();
          vCtrl.seekTo(Duration(milliseconds: targetMs));
        }
        break;
      }
      acc += d;
    }
  }

  double _clipStartTime(int clipIndex) {
    double acc = 0.0;
    for (int i = 0; i < clipIndex && i < _project.clips.length; i++) {
      acc += _project.clips[i].durationSeconds;
    }
    return acc;
  }

  // ─── Keyframe Navigator & Full CRUD (إضافة، تعديل، حذف، إعادة ضبط، قوالب) ─

  void _jumpToAdjacentKeyframe({required bool forward}) {
    _pausePlayback();
    final kfs = _activeKeyframesList;
    if (kfs.isEmpty) return;

    final baseStart = _activeTargetStartTime;
    final nextIdx = forward
        ? (_selectedKeyframeIndex + 1).clamp(0, kfs.length - 1)
        : (_selectedKeyframeIndex - 1).clamp(0, kfs.length - 1);

    setState(() {
      _selectedKeyframeIndex = nextIdx;
      _playheadTime = (baseStart + kfs[nextIdx].timestamp).clamp(
        0.0,
        math.max(0.1, _project.totalDuration),
      );
    });
  }

  void _addKeyframeSmart() {
    _pausePlayback();
    final bool editingText =
        _editTextKeyframes && _project.textTracks.isNotEmpty;

    if (editingText) {
      final safeTxtIdx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      final track = _project.textTracks[safeTxtIdx];
      final maxDur = math.max(0.2, track.endTime - track.startTime);
      double targetLocalTime = (_playheadTime - track.startTime)
          .clamp(0.0, maxDur)
          .toDouble();

      // إذا كان المؤشر واقفاً بالفعل فوق مفتاح موجود، نضيف المفتاح الجديد في منتصف المسافة للمفتاح التالي
      final existingIdx = track.keyframes.indexWhere(
        (k) => (k.timestamp - targetLocalTime).abs() < 0.08,
      );
      if (existingIdx >= 0) {
        if (existingIdx + 1 < track.keyframes.length) {
          targetLocalTime =
              (track.keyframes[existingIdx].timestamp +
                  track.keyframes[existingIdx + 1].timestamp) /
              2.0;
        } else if (existingIdx > 0) {
          targetLocalTime =
              (track.keyframes[existingIdx - 1].timestamp +
                  track.keyframes[existingIdx].timestamp) /
              2.0;
        } else {
          targetLocalTime = (targetLocalTime + 0.5).clamp(0.0, maxDur);
        }
      }

      final evaluated = RustVideoBridge.instance
          .evaluateKeyframes(track.keyframes, targetLocalTime)
          .copyWith(timestamp: targetLocalTime);

      final updatedKfs = [...track.keyframes];
      final clashIdx = updatedKfs.indexWhere(
        (k) => (k.timestamp - targetLocalTime).abs() < 0.04,
      );
      if (clashIdx >= 0) {
        updatedKfs[clashIdx] = evaluated;
        _selectedKeyframeIndex = clashIdx;
      } else {
        updatedKfs.add(evaluated);
        updatedKfs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _selectedKeyframeIndex = updatedKfs.indexOf(evaluated);
      }

      final updatedTracks = [..._project.textTracks];
      updatedTracks[safeTxtIdx] = track.copyWith(keyframes: updatedKfs);
      _playheadTime = (track.startTime + targetLocalTime).clamp(
        0.0,
        math.max(0.1, _project.totalDuration),
      );
      _commitProjectChange(_project.copyWith(textTracks: updatedTracks));
      return;
    }

    if (_project.clips.isEmpty) return;
    final clip = _project.clips[_selectedClipIndex];
    final clipStart = _clipStartTime(_selectedClipIndex);
    final maxDur = math.max(0.2, clip.durationSeconds);
    double targetLocalTime = (_playheadTime - clipStart).clamp(0.0, maxDur);

    final existingIdx = clip.keyframes.indexWhere(
      (k) => (k.timestamp - targetLocalTime).abs() < 0.08,
    );
    if (existingIdx >= 0) {
      if (existingIdx + 1 < clip.keyframes.length) {
        targetLocalTime =
            (clip.keyframes[existingIdx].timestamp +
                clip.keyframes[existingIdx + 1].timestamp) /
            2.0;
      } else if (existingIdx > 0) {
        targetLocalTime =
            (clip.keyframes[existingIdx - 1].timestamp +
                clip.keyframes[existingIdx].timestamp) /
            2.0;
      } else {
        targetLocalTime = (targetLocalTime + 0.5).clamp(0.0, maxDur);
      }
    }

    final evaluated = RustVideoBridge.instance
        .evaluateKeyframes(clip.keyframes, targetLocalTime)
        .copyWith(timestamp: targetLocalTime);

    final updatedKfs = [...clip.keyframes];
    final clashIdx = updatedKfs.indexWhere(
      (k) => (k.timestamp - targetLocalTime).abs() < 0.04,
    );
    if (clashIdx >= 0) {
      updatedKfs[clashIdx] = evaluated;
      _selectedKeyframeIndex = clashIdx;
    } else {
      updatedKfs.add(evaluated);
      updatedKfs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _selectedKeyframeIndex = updatedKfs.indexOf(evaluated);
    }

    final updatedClips = [..._project.clips];
    updatedClips[_selectedClipIndex] = clip.copyWith(keyframes: updatedKfs);
    _playheadTime = (clipStart + targetLocalTime).clamp(
      0.0,
      math.max(0.1, _project.totalDuration),
    );
    _commitProjectChange(_project.copyWith(clips: updatedClips));
  }

  void _deleteKeyframeAt(int indexToRemove) {
    _pausePlayback();
    final bool editingText =
        _editTextKeyframes && _project.textTracks.isNotEmpty;

    if (editingText) {
      final safeTxtIdx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      final track = _project.textTracks[safeTxtIdx];
      if (track.keyframes.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب إبقاء مفتاح حركة (Keyframe) واحد على الأقل.'),
          ),
        );
        return;
      }
      final safeKfIdx = indexToRemove.clamp(0, track.keyframes.length - 1);
      final updatedKfs = [...track.keyframes]..removeAt(safeKfIdx);
      final updatedTracks = [..._project.textTracks];
      updatedTracks[safeTxtIdx] = track.copyWith(keyframes: updatedKfs);
      _selectedKeyframeIndex = math.min(safeKfIdx, updatedKfs.length - 1);
      _playheadTime =
          track.startTime + updatedKfs[_selectedKeyframeIndex].timestamp;
      _commitProjectChange(_project.copyWith(textTracks: updatedTracks));
      return;
    }

    if (_project.clips.isEmpty) return;
    final clip = _project.clips[_selectedClipIndex];
    if (clip.keyframes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إبقاء مفتاح حركة (Keyframe) واحد على الأقل.'),
        ),
      );
      return;
    }
    final safeKfIdx = indexToRemove.clamp(0, clip.keyframes.length - 1);
    final updatedKfs = [...clip.keyframes]..removeAt(safeKfIdx);
    final updatedClips = [..._project.clips];
    updatedClips[_selectedClipIndex] = clip.copyWith(keyframes: updatedKfs);
    _selectedKeyframeIndex = math.min(safeKfIdx, updatedKfs.length - 1);
    _playheadTime =
        _clipStartTime(_selectedClipIndex) +
        updatedKfs[_selectedKeyframeIndex].timestamp;
    _commitProjectChange(_project.copyWith(clips: updatedClips));
  }

  void _resetSelectedKeyframe() {
    _pushUndoSnapshot();
    _updateSelectedKeyframe(
      (k) => k.copyWith(
        x: 0.0,
        y: 0.0,
        scale: 1.0,
        rotation: 0.0,
        opacity: 1.0,
        easing: KeyframeEasing.autoBezier,
      ),
    );
  }

  void _applyKeyframeMotionPreset(String presetId) {
    _pausePlayback();
    final dur = _activeTargetDuration;
    final List<KeyframePoint> presetKeyframes = switch (presetId) {
      'zoom_in' => [
        const KeyframePoint(
          timestamp: 0.0,
          scale: 1.0,
          x: 0.0,
          y: 0.0,
          opacity: 1.0,
          easing: KeyframeEasing.autoBezier,
        ),
        KeyframePoint(
          timestamp: dur,
          scale: 1.24,
          x: 0.0,
          y: -0.03,
          opacity: 1.0,
          easing: KeyframeEasing.autoBezier,
        ),
      ],
      'zoom_out' => [
        const KeyframePoint(
          timestamp: 0.0,
          scale: 1.25,
          x: 0.0,
          y: -0.02,
          opacity: 1.0,
          easing: KeyframeEasing.autoBezier,
        ),
        KeyframePoint(
          timestamp: dur,
          scale: 1.0,
          x: 0.0,
          y: 0.0,
          opacity: 1.0,
          easing: KeyframeEasing.autoBezier,
        ),
      ],
      'pan_lr' => [
        const KeyframePoint(
          timestamp: 0.0,
          scale: 1.15,
          x: -0.08,
          y: 0.0,
          opacity: 1.0,
          easing: KeyframeEasing.easeInOut,
        ),
        KeyframePoint(
          timestamp: dur,
          scale: 1.15,
          x: 0.08,
          y: 0.0,
          opacity: 1.0,
          easing: KeyframeEasing.easeInOut,
        ),
      ],
      'fade_in_out' => [
        const KeyframePoint(
          timestamp: 0.0,
          scale: 0.92,
          opacity: 0.0,
          y: 0.08,
          easing: KeyframeEasing.easeOut,
        ),
        KeyframePoint(
          timestamp: (dur * 0.2).clamp(0.1, dur),
          scale: 1.0,
          opacity: 1.0,
          y: 0.0,
          easing: KeyframeEasing.autoBezier,
        ),
        KeyframePoint(
          timestamp: (dur * 0.8).clamp(0.2, dur),
          scale: 1.04,
          opacity: 1.0,
          y: 0.0,
          easing: KeyframeEasing.easeIn,
        ),
        KeyframePoint(
          timestamp: dur,
          scale: 0.95,
          opacity: 0.0,
          y: -0.06,
          easing: KeyframeEasing.easeIn,
        ),
      ],
      'pulse' => [
        const KeyframePoint(
          timestamp: 0.0,
          scale: 1.0,
          opacity: 1.0,
          easing: KeyframeEasing.easeInOut,
        ),
        KeyframePoint(
          timestamp: dur * 0.5,
          scale: 1.18,
          rotation: 1.5,
          opacity: 1.0,
          easing: KeyframeEasing.elasticOut,
        ),
        KeyframePoint(
          timestamp: dur,
          scale: 1.0,
          rotation: 0.0,
          opacity: 1.0,
          easing: KeyframeEasing.easeInOut,
        ),
      ],
      _ => [KeyframePoint(timestamp: 0.0), KeyframePoint(timestamp: dur)],
    };

    _selectedKeyframeIndex = 0;
    if (_editTextKeyframes && _project.textTracks.isNotEmpty) {
      final idx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      final updatedTracks = [..._project.textTracks];
      updatedTracks[idx] = updatedTracks[idx].copyWith(
        keyframes: presetKeyframes,
      );
      _commitProjectChange(_project.copyWith(textTracks: updatedTracks));
    } else if (_project.clips.isNotEmpty) {
      final idx = _selectedClipIndex.clamp(0, _project.clips.length - 1);
      final updatedClips = [..._project.clips];
      updatedClips[idx] = updatedClips[idx].copyWith(
        keyframes: presetKeyframes,
      );
      _commitProjectChange(_project.copyWith(clips: updatedClips));
    }
  }

  void _updateSelectedKeyframe(
    KeyframePoint Function(KeyframePoint) updater, {
    bool sortIfTimestampChanged = false,
  }) {
    if (_editTextKeyframes && _project.textTracks.isNotEmpty) {
      final safeTxtIdx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      final track = _project.textTracks[safeTxtIdx];
      if (track.keyframes.isEmpty) return;
      final safeKfIdx = _selectedKeyframeIndex.clamp(
        0,
        track.keyframes.length - 1,
      );
      final updatedItem = updater(track.keyframes[safeKfIdx]);
      final updatedKfs = [...track.keyframes];
      updatedKfs[safeKfIdx] = updatedItem;
      if (sortIfTimestampChanged) {
        updatedKfs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _selectedKeyframeIndex = updatedKfs.indexOf(updatedItem);
      }

      final updatedTracks = [..._project.textTracks];
      updatedTracks[safeTxtIdx] = track.copyWith(keyframes: updatedKfs);
      setState(() {
        _project = _project.copyWith(textTracks: updatedTracks);
        _playheadTime =
            track.startTime + updatedKfs[_selectedKeyframeIndex].timestamp;
      });
      return;
    }

    if (_project.clips.isEmpty) return;
    final clip = _project.clips[_selectedClipIndex];
    if (clip.keyframes.isEmpty) return;

    final safeIdx = _selectedKeyframeIndex.clamp(0, clip.keyframes.length - 1);
    final updatedItem = updater(clip.keyframes[safeIdx]);
    final updatedKfs = [...clip.keyframes];
    updatedKfs[safeIdx] = updatedItem;
    if (sortIfTimestampChanged) {
      updatedKfs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _selectedKeyframeIndex = updatedKfs.indexOf(updatedItem);
    }

    final updatedClips = [..._project.clips];
    updatedClips[_selectedClipIndex] = clip.copyWith(keyframes: updatedKfs);

    setState(() {
      _project = _project.copyWith(clips: updatedClips);
      _playheadTime =
          _clipStartTime(_selectedClipIndex) +
          updatedKfs[_selectedKeyframeIndex].timestamp;
    });
  }

  // ─── Interactive Touch Keyframing on Stage Canvas ──────────────────────────

  void _onStageScaleStart(ScaleStartDetails details) {
    _pausePlayback();
    _pushUndoSnapshot();

    final activeKf = _evaluateActiveTargetAtPlayhead();
    _gestureBaseScale = activeKf.scale;
    _gestureBaseRotation = activeKf.rotation;
    _gestureBaseX = activeKf.x;
    _gestureBaseY = activeKf.y;
  }

  void _onStageScaleUpdate(ScaleUpdateDetails details, Size stageSize) {
    final dxNorm = details.focalPointDelta.dx / math.max(1.0, stageSize.width);
    final dyNorm = details.focalPointDelta.dy / math.max(1.0, stageSize.height);
    _gestureBaseX = (_gestureBaseX + dxNorm).clamp(-0.8, 0.8);
    _gestureBaseY = (_gestureBaseY + dyNorm).clamp(-0.8, 0.8);

    final newScale = (_gestureBaseScale * details.scale).clamp(0.4, 2.5);
    final newRotation =
        (_gestureBaseRotation + (details.rotation * 180.0 / math.pi)).clamp(
          -90.0,
          90.0,
        );

    _upsertKeyframeFromTouch(
      x: _gestureBaseX,
      y: _gestureBaseY,
      scale: newScale,
      rotation: newRotation,
    );
  }

  KeyframePoint _evaluateActiveTargetAtPlayhead() {
    if (_editTextKeyframes && _project.textTracks.isNotEmpty) {
      final safeTxtIdx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      final track = _project.textTracks[safeTxtIdx];
      final double localT = (_playheadTime - track.startTime)
          .clamp(0.0, math.max(0.1, track.endTime - track.startTime))
          .toDouble();
      return RustVideoBridge.instance.evaluateKeyframes(
        track.keyframes,
        localT,
      );
    }

    if (_project.clips.isEmpty) return const KeyframePoint(timestamp: 0.0);
    final clip = _project.clips[_selectedClipIndex];
    final localT = (_playheadTime - _clipStartTime(_selectedClipIndex)).clamp(
      0.0,
      clip.durationSeconds,
    );
    return RustVideoBridge.instance.evaluateKeyframes(clip.keyframes, localT);
  }

  void _upsertKeyframeFromTouch({
    required double x,
    required double y,
    required double scale,
    required double rotation,
  }) {
    if (_editTextKeyframes && _project.textTracks.isNotEmpty) {
      final safeTxtIdx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      final track = _project.textTracks[safeTxtIdx];
      final double localT = (_playheadTime - track.startTime)
          .clamp(0.0, math.max(0.1, track.endTime - track.startTime))
          .toDouble();
      final updatedKfs = _upsertInList(
        track.keyframes,
        localT,
        (kf) => kf.copyWith(x: x, y: y, scale: scale, rotation: rotation),
      );
      final updatedTracks = [..._project.textTracks];
      updatedTracks[safeTxtIdx] = track.copyWith(keyframes: updatedKfs);
      setState(() => _project = _project.copyWith(textTracks: updatedTracks));
      return;
    }

    if (_project.clips.isEmpty) return;
    final clip = _project.clips[_selectedClipIndex];
    final localT = (_playheadTime - _clipStartTime(_selectedClipIndex)).clamp(
      0.0,
      clip.durationSeconds,
    );
    final updatedKfs = _upsertInList(
      clip.keyframes,
      localT,
      (kf) => kf.copyWith(x: x, y: y, scale: scale, rotation: rotation),
    );
    final updatedClips = [..._project.clips];
    updatedClips[_selectedClipIndex] = clip.copyWith(keyframes: updatedKfs);
    setState(() => _project = _project.copyWith(clips: updatedClips));
  }

  List<KeyframePoint> _upsertInList(
    List<KeyframePoint> list,
    double localTime,
    KeyframePoint Function(KeyframePoint) updater,
  ) {
    final copy = [...list];
    final existingIdx = copy.indexWhere(
      (k) => (k.timestamp - localTime).abs() < 0.25,
    );
    if (existingIdx >= 0) {
      copy[existingIdx] = updater(copy[existingIdx]);
      _selectedKeyframeIndex = existingIdx;
    } else {
      final base = RustVideoBridge.instance.evaluateKeyframes(copy, localTime);
      final created = updater(base.copyWith(timestamp: localTime));
      copy.add(created);
      copy.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _selectedKeyframeIndex = copy.indexOf(created);
    }
    return copy;
  }

  // ─── Auto-Generate From Couple Memories ─────────────────────────────────────

  void _autoGenerateFromMemories() {
    final mediaList = ref.read(mediaProvider).value ?? [];
    final eventsList = ref.read(timelineProvider).value ?? [];

    final generatedClips = <VideoClipItem>[];
    final transitions = [
      VideoTransitionType.crossDissolve,
      VideoTransitionType.zoomIn,
      VideoTransitionType.slideLeft,
      VideoTransitionType.heartPulse,
      VideoTransitionType.dreamyBlur,
    ];

    int idx = 0;
    for (final m in mediaList.take(5)) {
      final isEven = idx.isEven;
      generatedClips.add(
        VideoClipItem(
          id: 'auto_m_$idx',
          title: m.description ?? 'ذكرى جميلة',
          sourceType: m.mediaType == MediaType.video
              ? VideoClipSourceType.video
              : VideoClipSourceType.image,
          localPath: m.localPath,
          networkUrl: m.cloudinaryUrl.isNotEmpty
              ? m.cloudinaryUrl
              : m.thumbnailUrl,
          durationSeconds: 3.5,
          transition: transitions[idx % transitions.length],
          keyframes: [
            KeyframePoint(
              timestamp: 0.0,
              scale: isEven ? 1.0 : 1.16,
              x: isEven ? -0.03 : 0.03,
              y: 0.0,
              opacity: 1.0,
              easing: KeyframeEasing.autoBezier,
            ),
            KeyframePoint(
              timestamp: 3.5,
              scale: isEven ? 1.16 : 1.0,
              x: isEven ? 0.03 : -0.03,
              y: -0.02,
              opacity: 1.0,
              easing: KeyframeEasing.autoBezier,
            ),
          ],
        ),
      );
      idx++;
    }

    if (generatedClips.isEmpty && eventsList.isNotEmpty) {
      for (final e in eventsList.take(5)) {
        generatedClips.add(
          VideoClipItem(
            id: 'auto_e_$idx',
            title: '${e.icon} ${e.title}',
            localPath: e.localImagePath,
            networkUrl: e.imageUrl,
            durationSeconds: 3.5,
            transition: transitions[idx % transitions.length],
            keyframes: const [
              KeyframePoint(
                timestamp: 0.0,
                scale: 1.0,
                easing: KeyframeEasing.autoBezier,
              ),
              KeyframePoint(
                timestamp: 3.5,
                scale: 1.15,
                y: -0.03,
                easing: KeyframeEasing.autoBezier,
              ),
            ],
          ),
        );
        idx++;
      }
    }

    if (generatedClips.isEmpty) return;

    final totalDur = generatedClips.fold(
      0.0,
      (double s, c) => s + c.durationSeconds,
    );

    _pausePlayback();
    _playheadTime = 0.0;
    _selectedClipIndex = 0;
    _selectedKeyframeIndex = 0;
    _commitProjectChange(
      _project.copyWith(
        clips: generatedClips,
        textTracks: [
          VideoTextTrack(
            id: const Uuid().v4(),
            text: '${AppConstants.coupleName}\nأجمل ذكريات عمرنا',
            startTime: 0.2,
            endTime: math.min(4.0, totalDur),
            fontSize: 24,
            fontStyle: 'serif',
          ),
          if (totalDur > 5.0)
            VideoTextTrack(
              id: const Uuid().v4(),
              text: 'بانتظار مولودنا الغالي ${AppConstants.babyName} 👶',
              startTime: 4.5,
              endTime: totalDur - 0.3,
              fontSize: 20,
              fontStyle: 'script',
            ),
        ],
      ),
    );
    _initVideoControllers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم توليد فيديو ذكريات بـ ${generatedClips.length} مقاطع مع Auto-Bezier Keyframes ✨',
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // ─── Add / Edit Clip (Image / Video / Card) ─────────────────────────────────

  Future<void> _pickMediaClip({required bool isVideo}) async {
    try {
      final XFile? picked = isVideo
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 1440,
              imageQuality: 85,
            );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final savedFile = await File(
        picked.path,
      ).copy('${appDir.path}/studio_${const Uuid().v4()}.$ext');

      final newClip = VideoClipItem(
        id: const Uuid().v4(),
        title: isVideo ? 'مقطع فيديو 🎥' : 'صورة من الجهاز 📸',
        sourceType: isVideo
            ? VideoClipSourceType.video
            : VideoClipSourceType.image,
        localPath: savedFile.path,
        durationSeconds: 4.0,
        transition: VideoTransitionType.crossDissolve,
        keyframes: const [
          KeyframePoint(
            timestamp: 0.0,
            scale: 1.0,
            easing: KeyframeEasing.autoBezier,
          ),
          KeyframePoint(
            timestamp: 4.0,
            scale: 1.14,
            easing: KeyframeEasing.autoBezier,
          ),
        ],
      );

      final updated = [..._project.clips, newClip];
      _selectedClipIndex = updated.length - 1;
      _selectedKeyframeIndex = 0;
      _commitProjectChange(_project.copyWith(clips: updated));
      await _initVideoControllers();
    } catch (_) {}
  }

  void _addRomanticCardClip() {
    final newClip = VideoClipItem(
      id: const Uuid().v4(),
      title: 'بطاقة رومانسية 💕',
      sourceType: VideoClipSourceType.romanticCard,
      durationSeconds: 3.5,
      transition: VideoTransitionType.heartPulse,
      keyframes: const [
        KeyframePoint(timestamp: 0.0, scale: 0.9, opacity: 0.8),
        KeyframePoint(timestamp: 3.5, scale: 1.08, opacity: 1.0),
      ],
    );
    final updated = [..._project.clips, newClip];
    _selectedClipIndex = updated.length - 1;
    _selectedKeyframeIndex = 0;
    _commitProjectChange(_project.copyWith(clips: updated));
  }

  void _showEditClipDialog(int clipIdx) {
    if (clipIdx < 0 || clipIdx >= _project.clips.length) return;
    final clip = _project.clips[clipIdx];
    final titleCtrl = TextEditingController(text: clip.title);
    double duration = clip.durationSeconds;
    int selectedColor = clip.cardColorValue;

    const cardColors = [
      0xFFF1878E,
      0xFFD81B60,
      0xFF8E24AA,
      0xFF3949AB,
      0xFF00897B,
      0xFFF4511E,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'تعديل المقطع #${clipIdx + 1}',
            style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان المقطع / البطاقة',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'مدة المقطع: ${duration.toStringAsFixed(1)} ثانية',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: duration.clamp(1.0, 15.0),
                  min: 1.0,
                  max: 15.0,
                  divisions: 28,
                  onChanged: (v) => setDialogState(() => duration = v),
                ),
                if (clip.sourceType == VideoClipSourceType.romanticCard) ...[
                  const SizedBox(height: 8),
                  Text(
                    'لون البطاقة الرومانسية:',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: cardColors.map((c) {
                      final isSel = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: CircleAvatar(
                          radius: isSel ? 18 : 15,
                          backgroundColor: Color(c),
                          child: isSel
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = [..._project.clips];
                updated[clipIdx] = clip.copyWith(
                  title: titleCtrl.text.trim().isEmpty
                      ? clip.title
                      : titleCtrl.text.trim(),
                  durationSeconds: duration,
                  cardColorValue: selectedColor,
                );
                _commitProjectChange(_project.copyWith(clips: updated));
                Navigator.pop(ctx);
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _moveClip(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _project.clips.length) return;
    final updated = [..._project.clips];
    final item = updated.removeAt(index);
    updated.insert(target, item);
    _selectedClipIndex = target;
    _commitProjectChange(_project.copyWith(clips: updated));
  }

  // ─── Real Frame-by-Frame Video Rendering & Export Pipeline ─────────────────

  Future<void> _exportVideo() async {
    if (_isExporting || _project.clips.isEmpty) return;
    _pausePlayback();

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    try {
      const int exportFps = 15;
      final double totalDur = _project.totalDuration.clamp(1.0, 30.0);
      final int totalFrames = (totalDur * exportFps).round().clamp(15, 450);
      final List<Uint8List> capturedFrames = [];
      int frameWidth = 720;
      int frameHeight = 1280;

      for (int i = 0; i < totalFrames; i++) {
        if (!mounted) return;
        setState(() {
          _playheadTime = (i / exportFps).clamp(0.0, totalDur);
          _exportProgress = (i + 1) / totalFrames;
          _syncSelectedClipWithPlayhead();
        });

        await WidgetsBinding.instance.endOfFrame;

        final boundary =
            _stageBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary != null) {
          final ui.Image img = await boundary.toImage(pixelRatio: 2.5);
          frameWidth = img.width;
          frameHeight = img.height;
          final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            capturedFrames.add(byteData.buffer.asUint8List());
          }
        }
      }

      if (capturedFrames.isEmpty) {
        setState(() => _isExporting = false);
        return;
      }

      final bundle = await RustVideoBridge.instance.exportVideoProject(
        project: _project,
        renderedFrames: capturedFrames,
        width: frameWidth,
        height: frameHeight,
        fps: exportFps,
      );

      String cloudVideoUrl = '';
      String cloudThumbUrl = '';
      final cloudinary = ref.read(cloudinaryServiceProvider);
      if (cloudinary.isConfigured && File(bundle.videoFilePath).existsSync()) {
        final uploadRes = await cloudinary.uploadVideo(
          File(bundle.videoFilePath),
        );
        uploadRes.when(
          success: (data) {
            cloudVideoUrl = data.secureUrl;
            cloudThumbUrl = data.thumbnailUrl;
          },
          failure: (_) {},
        );
      }

      final mediaItem = MediaFileEntity(
        id: const Uuid().v4(),
        cloudinaryUrl: cloudVideoUrl,
        thumbnailUrl: cloudThumbUrl,
        localPath: bundle.coverImagePath,
        mediaType: MediaType.video,
        uploadDate: DateTime.now(),
        description: '🎬 فيديو: ${_project.title}',
        location:
            'ملف فيديو (${bundle.renderedFramesCount} إطار • ${_project.totalDuration.toStringAsFixed(1)} ثانية)',
        isFeatured: true,
        fileName: bundle.projectJsonPath,
        tags: const ['فيديو', 'مونتاج', 'حب'],
      );

      await ref.read(mediaProvider.notifier).addMedia(mediaItem);

      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _playheadTime = 0.0;
      });

      _showExportSuccessDialog(bundle);
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ أثناء التصدير: $e')));
      }
    }
  }

  void _showExportSuccessDialog(ExportedVideoBundle bundle) {
    final theme = Theme.of(context);
    final fileName = bundle.publicVideoPath.split('/').last;
    final friendlyLocation = bundle.isSavedInPublicDownloads
        ? 'المعرض (Gallery) + التنزيلات (Download/OurLoveStory)'
        : 'مكتبة الفيديوهات المصدّرة داخل التطبيق';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم رندر وتصدير الفيديو بنجاح! 🎬',
                style: GoogleFonts.notoSerif(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• تم رندر ${bundle.renderedFramesCount} إطاراً بالـ Keyframes وتصحيح ألوان Lumetri (${bundle.readableFileSize}).',
                style: GoogleFonts.manrope(fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder_special_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            friendlyLocation,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'نسخ المسار',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: bundle.publicVideoPath),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم نسخ مسار الفيديو إلى الحافظة 📋',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Text(
                      'اسم الملف: $fileName',
                      style: GoogleFonts.manrope(fontSize: 11.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bundle.publicVideoPath,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '• المحرك: ${RustVideoBridge.instance.isRustNativeLoaded ? "Rust FFI VideoCraft Engine 🦀" : "Hybrid FilmCraft/EffectCraft Engine ⚡"}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showExportedVideoPlayerDialog(bundle);
                  },
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: const Text('تشغيل ومعاينة الفيديو المصدّر الآن ▶️'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final saved = await RustVideoBridge.instance
                            .saveVideoToPublicDownloads(bundle.videoFilePath);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              saved != null
                                  ? 'تم حفظ نسخة في التنزيلات: $saved ✅'
                                  : 'الفيديو محفوظ بالفعل في: ${bundle.publicVideoPath}',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text(
                        'حفظ بالتنزيلات',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        RustVideoBridge.instance.shareExportedVideo(
                          bundle.videoFilePath,
                          title: bundle.title,
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text(
                        'مشاركة / فتح',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showExportedVideosManagerSheet();
            },
            icon: const Icon(Icons.video_library_outlined, size: 18),
            label: const Text('كل الفيديوهات المصدّرة'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  // ─── Built-in Exported Videos Manager & Player ─────────────────────────────

  void _showExportedVideosManagerSheet() {
    _pausePlayback();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => _ExportedVideosManagerView(
          scrollController: scrollCtrl,
          onPlayBundle: (bundle) {
            Navigator.pop(ctx);
            _showExportedVideoPlayerDialog(bundle);
          },
          onLoadProjectIntoStudio: (project) {
            Navigator.pop(ctx);
            _pausePlayback();
            _playheadTime = 0.0;
            _selectedClipIndex = 0;
            _selectedKeyframeIndex = 0;
            _commitProjectChange(project);
            _initVideoControllers();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم تحميل مشروع "${project.title}" للتعديل ✏️'),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showExportedVideoPlayerDialog(ExportedVideoBundle bundle) {
    _pausePlayback();
    showDialog(
      context: context,
      builder: (ctx) => _ExportedVideoPlayerDialog(bundle: bundle),
    );
  }

  // ─── UI Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'استوديو الفيديو 🎬',
          style: GoogleFonts.notoSerif(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'تراجع (Undo)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.undo_rounded, size: 20),
            onPressed: (_undoStack.isEmpty || _isExporting) ? null : _undo,
          ),
          IconButton(
            tooltip: 'إعادة (Redo)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.redo_rounded, size: 20),
            onPressed: (_redoStack.isEmpty || _isExporting) ? null : _redo,
          ),
          IconButton(
            tooltip: 'الفيديوهات المصدّرة 📂',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.video_library_rounded,
              color: theme.colorScheme.primary,
              size: 21,
            ),
            onPressed: _isExporting ? null : _showExportedVideosManagerSheet,
          ),
          IconButton(
            tooltip: 'توليد تلقائي من ذكرياتنا',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.auto_fix_high_rounded,
              color: theme.colorScheme.secondary,
              size: 20,
            ),
            onPressed: _isExporting ? null : _autoGenerateFromMemories,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6, left: 4),
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _exportVideo,
              icon: _isExporting
                  ? SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.movie_creation_outlined, size: 17),
              label: Text(
                _isExporting ? '${(_exportProgress * 100).round()}%' : 'تصدير',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Live Interactive Stage Preview
          Expanded(
            flex: 5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: AspectRatio(
                  aspectRatio: _project.numericAspectRatio,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stageSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return GestureDetector(
                        onScaleStart: _onStageScaleStart,
                        onScaleUpdate: (d) => _onStageScaleUpdate(d, stageSize),
                        child: RepaintBoundary(
                          key: _stageBoundaryKey,
                          child: _buildStageCanvas(theme),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // 2. Playback & Timeline Scrubber Bar with Keyframe CRUD (◀ ◆+ 🗑️ ▶)
          _buildTimelineScrubber(theme),

          // 3. Studio Tool Tabs (6 Tabs including dedicated Audio & Music Tab)
          _buildToolSelectorBar(theme),

          // 4. Active Tool Inspector Panel
          Expanded(flex: 5, child: _buildActiveToolPanel(theme)),
        ],
      ),
    );
  }

  // ─── Stage Renderer (Clips + Lumetri Color Matrix + Vignette + Text) ───────

  Widget _buildStageCanvas(ThemeData theme) {
    if (_project.clips.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.scrim.withValues(alpha: 0.87),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'أضف صوراً أو مقاطع فيديو للبدء',
            style: TextStyle(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    int activeIdx = 0;
    double clipStart = 0.0;
    for (int i = 0; i < _project.clips.length; i++) {
      final d = _project.clips[i].durationSeconds;
      if (_playheadTime <= clipStart + d || i == _project.clips.length - 1) {
        activeIdx = i;
        break;
      }
      clipStart += d;
    }

    final currentClip = _project.clips[activeIdx];
    final localTime = (_playheadTime - clipStart).clamp(
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

    final prevClip = activeIdx > 0 ? _project.clips[activeIdx - 1] : null;
    final colorMatrix = RustVideoBridge.instance.computeLumetriColorMatrix(
      _project.colorGrade,
    );
    final vignetteAmount = _project.colorGrade.vignette.clamp(0.0, 0.85);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: AppTheme.studioCanvasBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.matrix(colorMatrix),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isInTransition && prevClip != null)
                    Opacity(
                      opacity: (1.0 - transProgress).clamp(0.0, 1.0),
                      child: _buildRenderedClipLayer(
                        prevClip,
                        RustVideoBridge.instance.evaluateKeyframes(
                          prevClip.keyframes,
                          prevClip.durationSeconds,
                        ),
                      ),
                    ),
                  _buildTransitionWrappedClip(
                    clip: currentClip,
                    kf: kf,
                    transition: isInTransition
                        ? currentClip.transition
                        : VideoTransitionType.none,
                    progress: transProgress,
                  ),
                ],
              ),
            ),

            if (vignetteAmount > 0.01)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        AppTheme.transparent(context),
                        Theme.of(
                          context,
                        ).colorScheme.scrim.withValues(alpha: vignetteAmount),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),

            for (final txt in _project.textTracks)
              if (_playheadTime >= txt.startTime &&
                  _playheadTime <= txt.endTime)
                _buildAnimatedTextOverlay(txt, _playheadTime - txt.startTime),

            if (!_isExporting)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.scrim.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_playheadTime.toStringAsFixed(1)}s / ${_project.totalDuration.toStringAsFixed(1)}s • اسحب للتحريك ◆',
                        style: GoogleFonts.manrope(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_project.hasBackgroundAudio)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.music_note_rounded,
                              size: 12,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(_project.audioVolume * 100).round()}%',
                              style: GoogleFonts.manrope(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransitionWrappedClip({
    required VideoClipItem clip,
    required KeyframePoint kf,
    required VideoTransitionType transition,
    required double progress,
  }) {
    Widget child = _buildRenderedClipLayer(clip, kf);

    switch (transition) {
      case VideoTransitionType.none:
        return child;
      case VideoTransitionType.crossDissolve:
        return Opacity(opacity: progress.clamp(0.0, 1.0), child: child);
      case VideoTransitionType.slideLeft:
        return FractionalTranslation(
          translation: Offset(1.0 - progress, 0.0),
          child: child,
        );
      case VideoTransitionType.zoomIn:
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.6 + 0.4 * progress, child: child),
        );
      case VideoTransitionType.heartPulse:
        final pulse = 1.0 + 0.15 * math.sin(progress * math.pi);
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.scale(scale: pulse, child: child),
        );
      case VideoTransitionType.dreamyBlur:
        final sigma = (1.0 - progress) * 14.0;
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          ),
        );
    }
  }

  Widget _buildRenderedClipLayer(VideoClipItem clip, KeyframePoint kf) {
    Widget mediaContent;
    final hasLocal =
        clip.localPath != null && File(clip.localPath!).existsSync();
    final hasNet = clip.networkUrl != null && clip.networkUrl!.isNotEmpty;
    final videoCtrl = _videoControllers[clip.id];

    if (clip.sourceType == VideoClipSourceType.video &&
        videoCtrl != null &&
        videoCtrl.value.isInitialized) {
      mediaContent = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: videoCtrl.value.size.width,
          height: videoCtrl.value.size.height,
          child: VideoPlayer(videoCtrl),
        ),
      );
    } else if (clip.sourceType == VideoClipSourceType.romanticCard ||
        (!hasLocal && !hasNet)) {
      mediaContent = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.studioCardGradient(clip.cardColorValue),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 54,
                ),
                const SizedBox(height: 16),
                Text(
                  clip.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSerif(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (hasLocal) {
      mediaContent = Image.file(File(clip.localPath!), fit: BoxFit.cover);
    } else {
      mediaContent = CachedNetworkImage(
        imageUrl: clip.networkUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
        errorWidget: (_, _, _) => Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Theme.of(
              context,
            ).colorScheme.onPrimary.withValues(alpha: 0.54),
          ),
        ),
      );
    }

    return Opacity(
      opacity: kf.opacity.clamp(0.0, 1.0),
      child: FractionalTranslation(
        translation: Offset(kf.x, kf.y),
        child: Transform.rotate(
          angle: kf.rotation * (math.pi / 180.0),
          child: Transform.scale(scale: kf.scale, child: mediaContent),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextOverlay(VideoTextTrack track, double localTime) {
    final kf = RustVideoBridge.instance.evaluateKeyframes(
      track.keyframes,
      localTime,
    );

    final TextStyle font = switch (track.fontStyle) {
      'script' => GoogleFonts.dancingScript(
        fontSize: track.fontSize,
        color: AppTheme.fromCode(track.colorValue),
        fontWeight: FontWeight.bold,
      ),
      'sans' => GoogleFonts.manrope(
        fontSize: track.fontSize,
        color: AppTheme.fromCode(track.colorValue),
        fontWeight: FontWeight.bold,
      ),
      _ => GoogleFonts.notoSerif(
        fontSize: track.fontSize,
        color: AppTheme.fromCode(track.colorValue),
        fontWeight: FontWeight.bold,
      ),
    };

    return Opacity(
      opacity: kf.opacity.clamp(0.0, 1.0),
      child: FractionalTranslation(
        translation: Offset(kf.x, kf.y),
        child: Transform.rotate(
          angle: kf.rotation * (math.pi / 180.0),
          child: Transform.scale(
            scale: kf.scale,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.scrim.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  track.text,
                  textAlign: TextAlign.center,
                  style: font,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Timeline Scrubber + Pro Keyframe Bar (◀ ◆+ 🗑️ ▶) ─────────────────────

  Widget _buildTimelineScrubber(ThemeData theme) {
    final total = math.max(_project.totalDuration, 0.1);
    final bool editingText =
        _editTextKeyframes && _project.textTracks.isNotEmpty;
    final List<KeyframePoint> activeKeyframes = _activeKeyframesList;
    final double baseStartTime = _activeTargetStartTime;
    final bool canDeleteKf = activeKeyframes.length > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                visualDensity: VisualDensity.compact,
                onPressed: _isExporting ? null : _togglePlayback,
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _playheadTime.clamp(0.0, total),
                  min: 0.0,
                  max: total,
                  onChanged: _isExporting
                      ? null
                      : (v) {
                          _pausePlayback();
                          setState(() {
                            _playheadTime = v;
                            _syncSelectedClipWithPlayhead();
                          });
                        },
                ),
              ),
              DropdownButton<VideoAspectRatioPreset>(
                value: _project.aspectRatio,
                underline: const SizedBox.shrink(),
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                items: const [
                  DropdownMenuItem(
                    value: VideoAspectRatioPreset.portrait9x16,
                    child: Text('9:16 Reels'),
                  ),
                  DropdownMenuItem(
                    value: VideoAspectRatioPreset.square1x1,
                    child: Text('1:1 مربع'),
                  ),
                  DropdownMenuItem(
                    value: VideoAspectRatioPreset.landscape16x9,
                    child: Text('16:9 سينما'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    _commitProjectChange(_project.copyWith(aspectRatio: val));
                  }
                },
              ),
            ],
          ),
          // شريط التحكم السريع في الـ Keyframes (تبديل الهدف + السابق + إضافة مفتاح + حذف مفتاح + التالي + الشرائح)
          SizedBox(
            height: 30,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _editTextKeyframes = !_editTextKeyframes;
                      _selectedKeyframeIndex = 0;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      editingText ? 'النص ✍️' : 'المقطع 🎞️',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _jumpToAdjacentKeyframe(forward: false),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(Icons.chevron_left_rounded, size: 18),
                  ),
                ),
                // زر إضافة مفتاح جديد (◆+)
                InkWell(
                  onTap: _addKeyframeSmart,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '◆+ إضافة',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // زر حذف المفتاح المحدد (◆-)
                InkWell(
                  onTap: canDeleteKf
                      ? () => _deleteKeyframeAt(_selectedKeyframeIndex)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: canDeleteKf
                          ? theme.colorScheme.error.withValues(alpha: 0.14)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 14,
                      color: canDeleteKf
                          ? theme.colorScheme.error
                          : theme.colorScheme.outline,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _jumpToAdjacentKeyframe(forward: true),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(Icons.chevron_right_rounded, size: 18),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activeKeyframes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final kf = activeKeyframes[i];
                      final isSelected = i == _selectedKeyframeIndex;
                      return GestureDetector(
                        onTap: () {
                          _pausePlayback();
                          setState(() {
                            _selectedKeyframeIndex = i;
                            _playheadTime = (baseStartTime + kf.timestamp)
                                .clamp(0.0, total);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '◆ #${i + 1} (${kf.timestamp.toStringAsFixed(1)}s)',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.primary,
                                ),
                              ),
                              if (isSelected && canDeleteKf) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _deleteKeyframeAt(i),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Studio Tool Tabs (6 Tabs including dedicated Audio & Music Tab) ────────

  Widget _buildToolSelectorBar(ThemeData theme) {
    const tabs = [
      'المقاطع 🎞️',
      'Keyframes ◆',
      'النصوص ✍️',
      'الألوان 🎨',
      'انتقالات ✨',
      'الصوت 🎵',
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _activeToolTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeToolTab = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : AppTheme.transparent(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveToolPanel(ThemeData theme) {
    return switch (_activeToolTab) {
      0 => _buildClipsPanel(theme),
      1 => _buildKeyframesPanel(theme),
      2 => _buildTextTracksPanel(theme),
      3 => _buildLumetriColorPanel(theme),
      4 => _buildTransitionsPanel(theme),
      _ => _buildAudioAndMusicPanel(theme),
    };
  }

  // ─── Panel 0: Clips & Media ─────────────────────────────────────────────────

  Widget _buildClipsPanel(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickMediaClip(isVideo: false),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('إضافة صورة'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickMediaClip(isVideo: true),
              icon: const Icon(Icons.video_call_outlined, size: 18),
              label: const Text('إضافة فيديو'),
            ),
            OutlinedButton.icon(
              onPressed: _addRomanticCardClip,
              icon: const Icon(Icons.favorite_border_rounded, size: 18),
              label: const Text('بطاقة رومانسية'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < _project.clips.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: i == _selectedClipIndex
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              onTap: () {
                _pausePlayback();
                setState(() {
                  _editTextKeyframes = false;
                  _selectedClipIndex = i;
                  _selectedKeyframeIndex = 0;
                  _playheadTime = _clipStartTime(i);
                });
              },
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                _project.clips[i].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                'المدة: ${_project.clips[i].durationSeconds.toStringAsFixed(1)}s • ${_project.clips[i].keyframes.length} Keyframes ◆',
                style: GoogleFonts.manrope(fontSize: 11.5),
              ),
              trailing: Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    tooltip: 'تحريك Keyframes ◆',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.animation_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () {
                      _pausePlayback();
                      setState(() {
                        _selectedClipIndex = i;
                        _editTextKeyframes = false;
                        _selectedKeyframeIndex = 0;
                        _playheadTime = _clipStartTime(i);
                        _activeToolTab = 1;
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'تعديل العنوان والمدة',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _showEditClipDialog(i),
                  ),
                  if (i > 0)
                    IconButton(
                      tooltip: 'تحريك لأعلى',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 17),
                      onPressed: () => _moveClip(i, -1),
                    ),
                  if (i < _project.clips.length - 1)
                    IconButton(
                      tooltip: 'تحريك لأسفل',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_downward_rounded, size: 17),
                      onPressed: () => _moveClip(i, 1),
                    ),
                  if (_project.clips.length > 1)
                    IconButton(
                      tooltip: 'حذف المقطع',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 19,
                      ),
                      onPressed: () {
                        final updated = [..._project.clips]..removeAt(i);
                        _selectedClipIndex = 0;
                        _playheadTime = 0.0;
                        _commitProjectChange(_project.copyWith(clips: updated));
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ─── Panel 1: Pro Keyframe Inspector (Add, Edit, Delete, Presets, Copy/Paste)

  Widget _buildKeyframesPanel(ThemeData theme) {
    final bool editingText =
        _editTextKeyframes && _project.textTracks.isNotEmpty;
    final List<KeyframePoint> kfs = _activeKeyframesList;
    if (kfs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            editingText
                ? 'لا توجد نصوص مضافة بعد. أضف نصاً من تبويب النصوص ✍️ أولاً.'
                : 'لا توجد مقاطع مضافة بعد.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(),
          ),
        ),
      );
    }

    final safeIdx = _selectedKeyframeIndex.clamp(0, kfs.length - 1);
    final kf = kfs[safeIdx];
    final maxDur = _activeTargetDuration;
    final canDelete = kfs.length > 1;

    const easingLabels = {
      KeyframeEasing.autoBezier: 'سلس تلقائي (Auto-Bezier)',
      KeyframeEasing.easeInOut: 'ناعم متوازن (Ease In/Out)',
      KeyframeEasing.linear: 'خطي مباشر (Linear)',
      KeyframeEasing.easeIn: 'تسارع دخول (Ease In)',
      KeyframeEasing.easeOut: 'تباطؤ خروج (Ease Out)',
      KeyframeEasing.elasticOut: 'نبض مرن (Elastic)',
      KeyframeEasing.hold: 'تثبيت مفاجئ (Hold)',
    };

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. اختيار الهدف (المقطع أو النص) + اختيار العنصر الفرعي
        Row(
          children: [
            ChoiceChip(
              label: const Text('تحريك المقطع 🎞️'),
              selected: !_editTextKeyframes,
              onSelected: (_) => setState(() {
                _editTextKeyframes = false;
                _selectedKeyframeIndex = 0;
              }),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('تحريك النص ✍️'),
              selected: _editTextKeyframes,
              onSelected: (_) {
                if (_project.textTracks.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('أضف نصاً أولاً من تبويب النصوص ✍️'),
                    ),
                  );
                  return;
                }
                setState(() {
                  _editTextKeyframes = true;
                  _selectedKeyframeIndex = 0;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // شريط اختيار أي مقطع أو أي نص نعدّل مفاتيحه حالياً
        if (!editingText && _project.clips.length > 1)
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _project.clips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => ActionChip(
                backgroundColor: i == _selectedClipIndex
                    ? theme.colorScheme.primaryContainer
                    : null,
                label: Text(
                  'مقطع ${i + 1}: ${_project.clips[i].title}',
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () {
                  setState(() {
                    _selectedClipIndex = i;
                    _selectedKeyframeIndex = 0;
                    _playheadTime = _clipStartTime(i);
                  });
                },
              ),
            ),
          ),

        if (editingText && _project.textTracks.isNotEmpty)
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _project.textTracks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => ActionChip(
                backgroundColor: i == _selectedTextTrackIndex
                    ? theme.colorScheme.primaryContainer
                    : null,
                label: Text(
                  'نص ${i + 1}: ${_project.textTracks[i].text.replaceAll('\n', ' ')}',
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () {
                  setState(() {
                    _selectedTextTrackIndex = i;
                    _selectedKeyframeIndex = 0;
                    _playheadTime = _project.textTracks[i].startTime;
                  });
                },
              ),
            ),
          ),

        const SizedBox(height: 10),

        // 2. شريط عمليات المفاتيح الاحترافي (إضافة، حذف، إعادة ضبط، نسخ، لصق)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.65,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مفتاح الحركة المحدد: #${safeIdx + 1} من ${kfs.length} (${kf.timestamp.toStringAsFixed(2)}s)',
                    style: GoogleFonts.notoSerif(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _addKeyframeSmart,
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text(
                      'إضافة مفتاح ◆+',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: canDelete
                        ? () => _deleteKeyframeAt(safeIdx)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text(
                      'حذف المفتاح',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _resetSelectedKeyframe,
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text(
                      'إعادة ضبط',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _copiedKeyframe = kf);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم نسخ إعدادات المفتاح 📋'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('نسخ', style: TextStyle(fontSize: 11)),
                  ),
                  if (_copiedKeyframe != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        final src = _copiedKeyframe!;
                        _pushUndoSnapshot();
                        _updateSelectedKeyframe(
                          (k) => k.copyWith(
                            x: src.x,
                            y: src.y,
                            scale: src.scale,
                            rotation: src.rotation,
                            opacity: src.opacity,
                            easing: src.easing,
                          ),
                        );
                      },
                      icon: const Icon(Icons.paste_rounded, size: 15),
                      label: const Text('لصق', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3. قوالب تحريك احترافية سريعة بضغطة واحدة (Motion Presets)
        Text(
          'قوالب تحريك جاهزة بضغطة واحدة (Motion Presets):',
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip('🔍 تقريب سينمائي', 'zoom_in'),
              const SizedBox(width: 6),
              _buildPresetChip('🔭 تبعيد ناعم', 'zoom_out'),
              const SizedBox(width: 6),
              _buildPresetChip('↔️ بانوراما أفقية', 'pan_lr'),
              const SizedBox(width: 6),
              _buildPresetChip('✨ ظهور وتلاشي', 'fade_in_out'),
              const SizedBox(width: 6),
              _buildPresetChip('💓 نبض رومانسي', 'pulse'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 4. تعديل توقيت المفتاح الزمني + خصائص التحويل الدقيقة
        _buildFineSliderRow(
          label:
              'توقيت المفتاح (Timestamp): ${kf.timestamp.toStringAsFixed(2)}s',
          value: kf.timestamp.clamp(0.0, maxDur),
          min: 0.0,
          max: maxDur,
          step: 0.1,
          defaultValue: kf.timestamp,
          onChangeStart: (_) => _pushUndoSnapshot(),
          onChanged: (v) => _updateSelectedKeyframe(
            (k) => k.copyWith(timestamp: v.clamp(0.0, maxDur)),
            sortIfTimestampChanged: true,
          ),
        ),
        _buildFineSliderRow(
          label: 'التكبير (Scale): ${kf.scale.toStringAsFixed(2)}x',
          value: kf.scale.clamp(0.4, 2.5),
          min: 0.4,
          max: 2.5,
          step: 0.05,
          defaultValue: 1.0,
          onChangeStart: (_) => _pushUndoSnapshot(),
          onChanged: (v) =>
              _updateSelectedKeyframe((k) => k.copyWith(scale: v)),
        ),
        _buildFineSliderRow(
          label: 'إزاحة أفقية (X): ${kf.x.toStringAsFixed(2)}',
          value: kf.x.clamp(-0.8, 0.8),
          min: -0.8,
          max: 0.8,
          step: 0.02,
          defaultValue: 0.0,
          onChangeStart: (_) => _pushUndoSnapshot(),
          onChanged: (v) => _updateSelectedKeyframe((k) => k.copyWith(x: v)),
        ),
        _buildFineSliderRow(
          label: 'إزاحة رأسية (Y): ${kf.y.toStringAsFixed(2)}',
          value: kf.y.clamp(-0.8, 0.8),
          min: -0.8,
          max: 0.8,
          step: 0.02,
          defaultValue: 0.0,
          onChangeStart: (_) => _pushUndoSnapshot(),
          onChanged: (v) => _updateSelectedKeyframe((k) => k.copyWith(y: v)),
        ),
        _buildFineSliderRow(
          label: 'الدوران (Rotation): ${kf.rotation.toStringAsFixed(0)}°',
          value: kf.rotation.clamp(-90.0, 90.0),
          min: -90.0,
          max: 90.0,
          step: 2.0,
          defaultValue: 0.0,
          onChangeStart: (_) => _pushUndoSnapshot(),
          onChanged: (v) =>
              _updateSelectedKeyframe((k) => k.copyWith(rotation: v)),
        ),
        _buildFineSliderRow(
          label: 'الشفافية (Opacity): ${(kf.opacity * 100).round()}%',
          value: kf.opacity.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          step: 0.05,
          defaultValue: 1.0,
          onChangeStart: (_) => _pushUndoSnapshot(),
          onChanged: (v) =>
              _updateSelectedKeyframe((k) => k.copyWith(opacity: v)),
        ),
        const SizedBox(height: 8),
        Text(
          'منحنى الحركة بين المفاتيح (Keyframe Easing):',
          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: KeyframeEasing.values.map((e) {
            return ChoiceChip(
              label: Text(
                easingLabels[e] ?? e.name,
                style: const TextStyle(fontSize: 11),
              ),
              selected: kf.easing == e,
              onSelected: (_) {
                _pushUndoSnapshot();
                _updateSelectedKeyframe((k) => k.copyWith(easing: e));
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, String presetId) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome_motion_rounded, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => _applyKeyframeMotionPreset(presetId),
    );
  }

  Widget _buildFineSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required double defaultValue,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeStart,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'إنقاص',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              icon: const Icon(Icons.remove_rounded, size: 16),
              onPressed: () {
                onChangeStart?.call(value);
                onChanged((value - step).clamp(min, max));
              },
            ),
            IconButton(
              tooltip: 'زيادة',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              icon: const Icon(Icons.add_rounded, size: 16),
              onPressed: () {
                onChangeStart?.call(value);
                onChanged((value + step).clamp(min, max));
              },
            ),
            IconButton(
              tooltip: 'إعادة للقيمة الافتراضية',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              onPressed: () {
                onChangeStart?.call(value);
                onChanged(defaultValue.clamp(min, max));
              },
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChangeStart: onChangeStart,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  // ─── Panel 2: Animated Text Overlays (Add, Edit, Keyframe Jump, Delete) ────

  Widget _buildTextTracksPanel(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ElevatedButton.icon(
          onPressed: () => _showAddOrEditTextTrackDialog(),
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: const Text('إضافة نص متحرك بالـ Keyframes'),
        ),
        const SizedBox(height: 12),
        if (_project.textTracks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'لا توجد نصوص مضافة حالياً. اضغط على الزر أعلاه لإضافة نص وتخصيص خطه ولونه ومفاتيح حركته.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 12.5),
            ),
          ),
        for (int i = 0; i < _project.textTracks.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: (_editTextKeyframes && _selectedTextTrackIndex == i)
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              onTap: () {
                _pausePlayback();
                setState(() {
                  _selectedTextTrackIndex = i;
                  _editTextKeyframes = true;
                  _selectedKeyframeIndex = 0;
                  _playheadTime = _project.textTracks[i].startTime;
                });
              },
              title: Text(
                _project.textTracks[i].text.replaceAll('\n', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSerif(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              subtitle: Text(
                'من ${_project.textTracks[i].startTime.toStringAsFixed(1)}s إلى ${_project.textTracks[i].endTime.toStringAsFixed(1)}s • ${_project.textTracks[i].keyframes.length} Keyframes ◆',
                style: GoogleFonts.manrope(fontSize: 11.5),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تحريك النص بالـ Keyframes ◆',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.animation_rounded,
                      color: theme.colorScheme.primary,
                      size: 19,
                    ),
                    onPressed: () {
                      _pausePlayback();
                      setState(() {
                        _selectedTextTrackIndex = i;
                        _editTextKeyframes = true;
                        _selectedKeyframeIndex = 0;
                        _playheadTime = _project.textTracks[i].startTime;
                        _activeToolTab = 1;
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'تعديل النص والخط والتوقيت ✏️',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    onPressed: () =>
                        _showAddOrEditTextTrackDialog(existingIndex: i),
                  ),
                  IconButton(
                    tooltip: 'حذف النص 🗑️',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    onPressed: () {
                      final updated = [..._project.textTracks]..removeAt(i);
                      _selectedTextTrackIndex = 0;
                      _commitProjectChange(
                        _project.copyWith(textTracks: updated),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showAddOrEditTextTrackDialog({int? existingIndex}) {
    final isEditing =
        existingIndex != null &&
        existingIndex >= 0 &&
        existingIndex < _project.textTracks.length;
    final existing = isEditing ? _project.textTracks[existingIndex] : null;

    final totalDur = math.max(_project.totalDuration, 4.0);
    final textCtrl = TextEditingController(text: existing?.text ?? '');
    String selectedStyle = existing?.fontStyle ?? 'serif';
    double fontSize = existing?.fontSize ?? 24.0;
    int selectedColor = existing?.colorValue ?? 0xFFFFFFFF;
    double startTime = (existing?.startTime ?? _playheadTime).clamp(
      0.0,
      math.max(0.0, totalDur - 0.5),
    );
    double endTime =
        (existing?.endTime ?? math.min(_playheadTime + 3.5, totalDur)).clamp(
          startTime + 0.5,
          totalDur,
        );

    const textColors = [
      0xFFFFFFFF,
      0xFFFFF3E0,
      0xFFFFCDD2,
      0xFFF8BBD0,
      0xFFFFD54F,
      0xFFB2DFDB,
      0xFFBBDEFB,
      0xFFE1BEE7,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            isEditing ? 'تعديل النص المتحرك ✏️' : 'إضافة نص متحرك للفيديو ✨',
            style: GoogleFonts.notoSerif(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'النص المعروض على الفيديو',
                    hintText: 'اكتب عبارة رومانسية...',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'نمط الخط:',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('كلاسيكي Serif'),
                      selected: selectedStyle == 'serif',
                      onSelected: (_) =>
                          setDialogState(() => selectedStyle = 'serif'),
                    ),
                    ChoiceChip(
                      label: const Text('خط يدوي Script'),
                      selected: selectedStyle == 'script',
                      onSelected: (_) =>
                          setDialogState(() => selectedStyle = 'script'),
                    ),
                    ChoiceChip(
                      label: const Text('عصري Sans'),
                      selected: selectedStyle == 'sans',
                      onSelected: (_) =>
                          setDialogState(() => selectedStyle = 'sans'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'حجم الخط: ${fontSize.round()}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: fontSize.clamp(14.0, 42.0),
                  min: 14.0,
                  max: 42.0,
                  onChanged: (v) => setDialogState(() => fontSize = v),
                ),
                Text(
                  'لون النص:',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: textColors.map((c) {
                    final isSel = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black26,
                            width: isSel ? 2.5 : 1.0,
                          ),
                        ),
                        child: isSel
                            ? const Icon(
                                Icons.check,
                                size: 15,
                                color: Colors.black87,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  'وقت الظهور: من ${startTime.toStringAsFixed(1)}s إلى ${endTime.toStringAsFixed(1)}s',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                RangeSlider(
                  values: RangeValues(
                    startTime.clamp(0.0, totalDur),
                    endTime.clamp(startTime + 0.3, totalDur),
                  ),
                  min: 0.0,
                  max: totalDur,
                  onChanged: (rv) {
                    if (rv.end - rv.start >= 0.4) {
                      setDialogState(() {
                        startTime = rv.start;
                        endTime = rv.end;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (textCtrl.text.trim().isEmpty) return;
                final span = math.max(0.5, endTime - startTime);
                if (isEditing) {
                  final updatedTracks = [..._project.textTracks];
                  updatedTracks[existingIndex] = existing!.copyWith(
                    text: textCtrl.text.trim(),
                    startTime: startTime,
                    endTime: endTime,
                    fontSize: fontSize,
                    colorValue: selectedColor,
                    fontStyle: selectedStyle,
                  );
                  _selectedTextTrackIndex = existingIndex;
                  _editTextKeyframes = true;
                  _commitProjectChange(
                    _project.copyWith(textTracks: updatedTracks),
                  );
                } else {
                  final newTrack = VideoTextTrack(
                    id: const Uuid().v4(),
                    text: textCtrl.text.trim(),
                    startTime: startTime,
                    endTime: endTime,
                    fontSize: fontSize,
                    colorValue: selectedColor,
                    fontStyle: selectedStyle,
                    keyframes: [
                      const KeyframePoint(
                        timestamp: 0.0,
                        y: 0.25,
                        opacity: 0.0,
                        scale: 0.85,
                      ),
                      KeyframePoint(
                        timestamp: math.min(0.6, span * 0.25),
                        y: 0.0,
                        opacity: 1.0,
                        scale: 1.0,
                      ),
                      KeyframePoint(
                        timestamp: math.max(0.7, span - 0.5),
                        y: 0.0,
                        opacity: 1.0,
                        scale: 1.05,
                      ),
                      KeyframePoint(
                        timestamp: span,
                        y: -0.15,
                        opacity: 0.0,
                        scale: 0.9,
                      ),
                    ],
                  );
                  final updated = [..._project.textTracks, newTrack];
                  _selectedTextTrackIndex = updated.length - 1;
                  _editTextKeyframes = true;
                  _commitProjectChange(_project.copyWith(textTracks: updated));
                }
                Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Panel 3: Lumetri Color Grading Panel (Inspired by FilmCraft) ──────────

  Widget _buildLumetriColorPanel(ThemeData theme) {
    final g = _project.colorGrade;
    const presetLabels = {
      LumetriLookPreset.original: 'طبيعي (Original)',
      LumetriLookPreset.etherealRomance: 'وردي حالم (Ethereal)',
      LumetriLookPreset.goldenHour: 'ساعة ذهبية (Golden Hour)',
      LumetriLookPreset.vintageFilm: 'فيلم كلاسيكي (Vintage)',
      LumetriLookPreset.warmAmber: 'عنبر دافئ (Warm Amber)',
      LumetriLookPreset.noirRomance: 'أبيض وأسود سينمائي (Noir)',
    };

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'القوالب اللونية البرمجية (FilmCraft Procedural Looks):',
          style: GoogleFonts.notoSerif(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LumetriLookPreset.values.map((preset) {
            return ChoiceChip(
              label: Text(
                presetLabels[preset] ?? preset.name,
                style: const TextStyle(fontSize: 11),
              ),
              selected: g.preset == preset,
              onSelected: (_) {
                _commitProjectChange(
                  _project.copyWith(
                    colorGrade: LumetriColorGrade.fromPreset(preset),
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _buildSliderRow(
          label: 'الإضاءة (Exposure): ${g.exposure.toStringAsFixed(2)}',
          value: g.exposure.clamp(-1.0, 1.0),
          min: -1.0,
          max: 1.0,
          onChanged: (v) => setState(
            () => _project = _project.copyWith(
              colorGrade: g.copyWith(exposure: v),
            ),
          ),
        ),
        _buildSliderRow(
          label: 'التباين (Contrast): ${g.contrast.toStringAsFixed(2)}',
          value: g.contrast.clamp(-0.5, 0.8),
          min: -0.5,
          max: 0.8,
          onChanged: (v) => setState(
            () => _project = _project.copyWith(
              colorGrade: g.copyWith(contrast: v),
            ),
          ),
        ),
        _buildSliderRow(
          label: 'التشبع (Saturation): ${g.saturation.toStringAsFixed(2)}',
          value: g.saturation.clamp(-1.0, 1.0),
          min: -1.0,
          max: 1.0,
          onChanged: (v) => setState(
            () => _project = _project.copyWith(
              colorGrade: g.copyWith(saturation: v),
            ),
          ),
        ),
        _buildSliderRow(
          label:
              'دفء الألوان (Temperature): ${g.temperature.toStringAsFixed(2)}',
          value: g.temperature.clamp(-1.0, 1.0),
          min: -1.0,
          max: 1.0,
          onChanged: (v) => setState(
            () => _project = _project.copyWith(
              colorGrade: g.copyWith(temperature: v),
            ),
          ),
        ),
        _buildSliderRow(
          label: 'تأثير الفيلم (Faded Film): ${(g.fadedFilm * 100).round()}%',
          value: g.fadedFilm.clamp(0.0, 0.4),
          min: 0.0,
          max: 0.4,
          onChanged: (v) => setState(
            () => _project = _project.copyWith(
              colorGrade: g.copyWith(fadedFilm: v),
            ),
          ),
        ),
        _buildSliderRow(
          label: 'تظليل الحواف (Vignette): ${(g.vignette * 100).round()}%',
          value: g.vignette.clamp(0.0, 0.8),
          min: 0.0,
          max: 0.8,
          onChanged: (v) => setState(
            () => _project = _project.copyWith(
              colorGrade: g.copyWith(vignette: v),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Panel 4: Transitions Panel ─────────────────────────────────────────────

  Widget _buildTransitionsPanel(ThemeData theme) {
    if (_project.clips.isEmpty) return const SizedBox.shrink();
    final clip = _project.clips[_selectedClipIndex];

    const transitionLabels = {
      VideoTransitionType.none: 'بدون انتقال',
      VideoTransitionType.crossDissolve: 'تلاشي ناعم (Crossfade)',
      VideoTransitionType.slideLeft: 'انزلاق سينمائي (Slide)',
      VideoTransitionType.zoomIn: 'تقريب (Zoom In)',
      VideoTransitionType.heartPulse: 'نبض رومانسي (Heartbeat)',
      VideoTransitionType.dreamyBlur: 'ضبابية حالمة (Dreamy Blur)',
    };

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'انتقال الدخول للمقطع المحدد (${clip.title}):',
          style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VideoTransitionType.values.map((t) {
            return ChoiceChip(
              label: Text(
                transitionLabels[t] ?? t.name,
                style: const TextStyle(fontSize: 12),
              ),
              selected: clip.transition == t,
              onSelected: (_) {
                final updatedClips = [..._project.clips];
                updatedClips[_selectedClipIndex] = clip.copyWith(transition: t);
                _commitProjectChange(_project.copyWith(clips: updatedClips));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildSliderRow(
          label:
              'مدة الانتقال: ${clip.transitionDuration.toStringAsFixed(1)} ثانية',
          value: clip.transitionDuration.clamp(0.2, 2.5),
          min: 0.2,
          max: 2.5,
          onChanged: (v) {
            final updatedClips = [..._project.clips];
            updatedClips[_selectedClipIndex] = clip.copyWith(
              transitionDuration: v,
            );
            setState(() => _project = _project.copyWith(clips: updatedClips));
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            final updatedClips = _project.clips
                .map(
                  (c) => c.copyWith(
                    transition: clip.transition,
                    transitionDuration: clip.transitionDuration,
                  ),
                )
                .toList();
            _commitProjectChange(_project.copyWith(clips: updatedClips));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تعميم الانتقال على جميع المقاطع ✨'),
              ),
            );
          },
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: const Text('تطبيق هذا الانتقال على كافة المقاطع'),
        ),
      ],
    );
  }

  // ─── Panel 5: Studio Audio, Music Library, Custom Audio & Sound Effects ────

  Widget _buildAudioAndMusicPanel(ThemeData theme) {
    const builtInTracks = [
      (AppConstants.romanticIntro, 'موسيقى رومانسية ناعمة 🎵'),
      (AppConstants.weddingCelebration, 'موسيقى احتفال الزفاف 🎉'),
      (AppConstants.loveMessage, 'نغمة رسالة الحب 💕'),
    ];

    final hasCustomAudio =
        _project.customAudioPath != null &&
        _project.customAudioPath!.isNotEmpty;
    final isMuted =
        !hasCustomAudio &&
        (_project.audioAsset == null || _project.audioAsset!.isEmpty);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. أزرار اختيار موسيقى من الهاتف أو كتم الموسيقى
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _pickCustomAudioFromPhone,
                icon: const Icon(Icons.library_music_rounded, size: 18),
                label: const Text(
                  'اختيار موسيقى / صوت من الهاتف 📁',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: isMuted
                  ? null
                  : () {
                      _previewAudioPlayer.stop();
                      _studioBgmPlayer.stop();
                      setState(() => _currentlyPreviewingTrack = null);
                      _commitProjectChange(
                        _project.copyWith(
                          clearAudioAsset: true,
                          clearCustomAudio: true,
                        ),
                      );
                    },
              icon: const Icon(Icons.volume_off_rounded, size: 17),
              label: const Text(
                'بدون موسيقى',
                style: TextStyle(fontSize: 11.5),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. بطاقة الملف الصوتي المخصص من الهاتف (إن وجد)
        if (hasCustomAudio)
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                Icons.audio_file_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                _project.customAudioName ?? 'ملف صوتي من الجهاز',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              subtitle: const Text(
                'موسيقى مخصصة من الهاتف • نشطة ✅',
                style: TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'معاينة الصوت',
                    icon: Icon(
                      _currentlyPreviewingTrack == _project.customAudioPath
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => _togglePreviewAudioTrack(
                      _project.customAudioPath!,
                      isLocalFile: true,
                    ),
                  ),
                  IconButton(
                    tooltip: 'إزالة الملف الصوتي',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () {
                      _previewAudioPlayer.stop();
                      setState(() => _currentlyPreviewingTrack = null);
                      _commitProjectChange(
                        _project.copyWith(
                          clearCustomAudio: true,
                          audioAsset: AppConstants.romanticIntro,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

        // 3. مكتبة الموسيقى المدمجة مع زر استماع فوري لكل مقطع
        Text(
          'الموسيقى الخلفية المدمجة (اضغط ▶️ للاستماع الفوري):',
          style: GoogleFonts.notoSerif(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        for (final track in builtInTracks)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: (!hasCustomAudio && _project.audioAsset == track.$1)
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              dense: true,
              onTap: () {
                _commitProjectChange(
                  _project.copyWith(
                    audioAsset: track.$1,
                    clearCustomAudio: true,
                  ),
                );
              },
              leading: Icon(
                (!hasCustomAudio && _project.audioAsset == track.$1)
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                track.$2,
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: IconButton(
                tooltip: 'استماع للمقطع',
                icon: Icon(
                  _currentlyPreviewingTrack == track.$1
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () =>
                    _togglePreviewAudioTrack(track.$1, isLocalFile: false),
              ),
            ),
          ),

        const SizedBox(height: 10),

        // 4. إعدادات مزج الصوت (مستوى الصوت، بداية الأغنية، التلاشي)
        _buildSliderRow(
          label:
              'مستوى صوت الموسيقى (Volume): ${(_project.audioVolume * 100).round()}%',
          value: _project.audioVolume.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          onChanged: (v) {
            _studioBgmPlayer.setVolume(v);
            _previewAudioPlayer.setVolume(v);
            setState(() => _project = _project.copyWith(audioVolume: v));
          },
        ),
        _buildSliderRow(
          label:
              'بداية المقطع الصوتي (Trim Start): ${_project.audioStartOffset.toStringAsFixed(1)}s',
          value: _project.audioStartOffset.clamp(0.0, 60.0),
          min: 0.0,
          max: 60.0,
          onChanged: (v) =>
              setState(() => _project = _project.copyWith(audioStartOffset: v)),
        ),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text(
                'تلاشي دخول الصوت (Fade In)',
                style: TextStyle(fontSize: 11),
              ),
              selected: _project.audioFadeIn,
              onSelected: (v) =>
                  _commitProjectChange(_project.copyWith(audioFadeIn: v)),
            ),
            FilterChip(
              label: const Text(
                'تلاشي خروج الصوت (Fade Out)',
                style: TextStyle(fontSize: 11),
              ),
              selected: _project.audioFadeOut,
              onSelected: (v) =>
                  _commitProjectChange(_project.copyWith(audioFadeOut: v)),
            ),
          ],
        ),

        const Divider(height: 24),

        // 5. المؤثرات والأصوات الإضافية على خط الزمن (Timeline Sound Effects)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'مؤثرات وأصوات إضافية على خط الزمن (${_project.soundEffects.length}):',
                style: GoogleFonts.notoSerif(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _showAddSoundEffectDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                'إضافة عند ${_playheadTime.toStringAsFixed(1)}s',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _project.soundEffects.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.graphic_eq_rounded,
                color: theme.colorScheme.secondary,
              ),
              title: Text(
                _project.soundEffects[i].title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              subtitle: Text(
                'يبدأ عند الثانية ${_project.soundEffects[i].startTime.toStringAsFixed(1)}s • الصوت ${(_project.soundEffects[i].volume * 100).round()}%',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تجربة المؤثر',
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    onPressed: () =>
                        _playSingleSoundEffect(_project.soundEffects[i]),
                  ),
                  IconButton(
                    tooltip: 'حذف المؤثر',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () {
                      final updated = [..._project.soundEffects]..removeAt(i);
                      _commitProjectChange(
                        _project.copyWith(soundEffects: updated),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickCustomAudioFromPhone() async {
    _pausePlayback();
    final picked = await RustVideoBridge.instance.pickAudioFileFromDevice();
    if (picked != null && mounted) {
      _commitProjectChange(
        _project.copyWith(
          customAudioPath: picked.path,
          customAudioName: picked.name,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إضافة الموسيقى: ${picked.name} 🎵')),
      );
    }
  }

  void _showAddSoundEffectDialog() {
    final sfxOptions = [
      (AppConstants.loveMessage, 'نغمة رسالة حب لطيفة 💕', false),
      (AppConstants.romanticIntro, 'نغمة بيانو رومانسي 🎹', false),
      (AppConstants.weddingCelebration, 'مؤثر احتفالي مبهج 🎉', false),
    ];
    double startAt = _playheadTime.clamp(
      0.0,
      math.max(0.1, _project.totalDuration),
    );
    double volume = 0.9;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'إضافة مؤثر صوتي على خط الزمن 🔊',
            style: GoogleFonts.notoSerif(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'توقيت بدء المؤثر: ${startAt.toStringAsFixed(1)} ثانية',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: startAt,
                  min: 0.0,
                  max: math.max(0.5, _project.totalDuration),
                  onChanged: (v) => setDialogState(() => startAt = v),
                ),
                Text(
                  'مستوى صوت المؤثر: ${(volume * 100).round()}%',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: volume,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (v) => setDialogState(() => volume = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await RustVideoBridge.instance
                          .pickAudioFileFromDevice();
                      if (picked != null && mounted) {
                        final newSfx = VideoAudioTrack(
                          id: const Uuid().v4(),
                          title: picked.name,
                          sourcePath: picked.path,
                          isLocalFile: true,
                          startTime: startAt,
                          volume: volume,
                        );
                        _commitProjectChange(
                          _project.copyWith(
                            soundEffects: [..._project.soundEffects, newSfx],
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('اختيار ملف صوتي من الهاتف 📁'),
                  ),
                ),
                const SizedBox(height: 10),
                for (final opt in sfxOptions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.music_note_rounded),
                    title: Text(opt.$2, style: const TextStyle(fontSize: 13)),
                    trailing: ElevatedButton(
                      onPressed: () {
                        final newSfx = VideoAudioTrack(
                          id: const Uuid().v4(),
                          title: opt.$2,
                          sourcePath: opt.$1,
                          isLocalFile: opt.$3,
                          startTime: startAt,
                          volume: volume,
                        );
                        _commitProjectChange(
                          _project.copyWith(
                            soundEffects: [..._project.soundEffects, newSfx],
                          ),
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text('إضافة'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exported Videos Manager BottomSheet View ───────────────────────────────

class _ExportedVideosManagerView extends StatefulWidget {
  final ScrollController scrollController;
  final ValueChanged<ExportedVideoBundle> onPlayBundle;
  final ValueChanged<VideoProjectEntity> onLoadProjectIntoStudio;

  const _ExportedVideosManagerView({
    required this.scrollController,
    required this.onPlayBundle,
    required this.onLoadProjectIntoStudio,
  });

  @override
  State<_ExportedVideosManagerView> createState() =>
      _ExportedVideosManagerViewState();
}

class _ExportedVideosManagerViewState
    extends State<_ExportedVideosManagerView> {
  List<ExportedVideoBundle> _bundles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBundles();
  }

  Future<void> _loadBundles() async {
    setState(() => _loading = true);
    final list = await RustVideoBridge.instance.listExportedVideoBundles();
    if (mounted) {
      setState(() {
        _bundles = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.video_library_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مكتبة الفيديوهات المصدّرة (${_bundles.length})',
                  style: GoogleFonts.notoSerif(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'تُحفظ الفيديوهات تلقائياً في مجلد التنزيلات (Download/OurLoveStory). يمكنك من هنا تشغيلها أو إعادة فتحها للتعديل أو حذفها:',
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _bundles.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد فيديوهات مصدّرة بعد.\nاضغط على زر "تصدير" في أعلى الاستوديو لتصدير أول فيديو!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(),
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: _bundles.length,
                    itemBuilder: (ctx, i) {
                      final b = _bundles[i];
                      final hasCover = File(b.coverImagePath).existsSync();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: hasCover
                                        ? Image.file(
                                            File(b.coverImagePath),
                                            width: 56,
                                            height: 72,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 56,
                                            height: 72,
                                            color: theme.colorScheme.primary,
                                            child: Icon(
                                              Icons.movie_rounded,
                                              color:
                                                  theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.title,
                                          style: GoogleFonts.notoSerif(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${b.renderedFramesCount} إطار • ${b.readableFileSize}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          b.publicVideoPath,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => widget.onPlayBundle(b),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'تشغيل ▶️',
                                      style: TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      try {
                                        final raw = await File(
                                          b.projectJsonPath,
                                        ).readAsString();
                                        final proj =
                                            VideoProjectEntity.fromJson(
                                              jsonDecode(raw)
                                                  as Map<String, dynamic>,
                                            );
                                        widget.onLoadProjectIntoStudio(proj);
                                      } catch (_) {}
                                    },
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'تعديل بالاستوديو',
                                      style: TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final saved = await RustVideoBridge
                                          .instance
                                          .saveVideoToPublicDownloads(
                                            b.videoFilePath,
                                          );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            saved != null
                                                ? 'تم الحفظ في التنزيلات: $saved ✅'
                                                : 'مسار الملف: ${b.publicVideoPath}',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.download_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'للتنزيلات',
                                      style: TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف الفيديو المصدّر',
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: theme.colorScheme.error,
                                    ),
                                    onPressed: () async {
                                      await RustVideoBridge.instance
                                          .deleteExportedBundle(b);
                                      await _loadBundles();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Built-in Exported Video & Audio Player Dialog ──────────────────────────

class _ExportedVideoPlayerDialog extends StatefulWidget {
  final ExportedVideoBundle bundle;

  const _ExportedVideoPlayerDialog({required this.bundle});

  @override
  State<_ExportedVideoPlayerDialog> createState() =>
      _ExportedVideoPlayerDialogState();
}

class _ExportedVideoPlayerDialogState
    extends State<_ExportedVideoPlayerDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Uint8List> _frames = [];
  VideoProjectEntity? _project;
  bool _loading = true;
  bool _playing = false;
  int _currentFrame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    try {
      if (File(widget.bundle.projectJsonPath).existsSync()) {
        final raw = await File(widget.bundle.projectJsonPath).readAsString();
        _project = VideoProjectEntity.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
      final aviCandidate =
          widget.bundle.videoFilePath.toLowerCase().endsWith('.avi')
          ? widget.bundle.videoFilePath
          : widget.bundle.projectJsonPath.replaceAll('.json', '.avi');
      final extracted = await RustVideoBridge.instance.extractFramesFromAvi(
        aviCandidate,
      );
      if (mounted) {
        setState(() {
          _frames = extracted;
          _loading = false;
        });
        if (_frames.isNotEmpty) {
          _startPlayback();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startPlayback() async {
    if (_frames.isEmpty) return;
    final fps = math.max(1, widget.bundle.fps);
    final proj = _project;

    setState(() => _playing = true);

    if (proj != null && proj.hasBackgroundAudio) {
      try {
        await _audioPlayer.setVolume(proj.audioVolume.clamp(0.0, 1.0));
        final offsetMs =
            ((proj.audioStartOffset + (_currentFrame / fps)) * 1000).round();
        if (proj.customAudioPath != null &&
            proj.customAudioPath!.isNotEmpty &&
            File(proj.customAudioPath!).existsSync()) {
          await _audioPlayer.play(
            DeviceFileSource(proj.customAudioPath!),
            position: Duration(milliseconds: offsetMs),
          );
        } else if (proj.audioAsset != null && proj.audioAsset!.isNotEmpty) {
          await _audioPlayer.play(
            AssetSource(proj.audioAsset!),
            position: Duration(milliseconds: offsetMs),
          );
        }
      } catch (_) {}
    }

    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: (1000 / fps).round()), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_currentFrame + 1 < _frames.length) {
          _currentFrame++;
        } else {
          _currentFrame = 0;
          _playing = false;
          _audioPlayer.stop();
          t.cancel();
        }
      });
    });
  }

  void _pausePlayback() {
    _timer?.cancel();
    _audioPlayer.pause();
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.bundle.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSerif(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: _project?.numericAspectRatio ?? (9 / 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _frames.isEmpty
                    ? (File(widget.bundle.coverImagePath).existsSync()
                          ? Image.file(
                              File(widget.bundle.coverImagePath),
                              fit: BoxFit.cover,
                            )
                          : const Center(child: Text('لا توجد إطارات للعرض')))
                    : Image.memory(
                        _frames[_currentFrame.clamp(0, _frames.length - 1)],
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            if (_frames.isNotEmpty)
              Row(
                children: [
                  IconButton.filled(
                    onPressed: _playing ? _pausePlayback : _startPlayback,
                    icon: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _currentFrame.toDouble().clamp(
                        0,
                        math.max(1, _frames.length - 1).toDouble(),
                      ),
                      min: 0,
                      max: math.max(1, _frames.length - 1).toDouble(),
                      onChanged: (v) {
                        _pausePlayback();
                        setState(() => _currentFrame = v.round());
                      },
                    ),
                  ),
                  Text(
                    '${_currentFrame + 1}/${_frames.length}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
