// lib/presentation/screens/video_studio_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/rust_video_bridge.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/video_project_entity.dart';
import '../../theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../providers/audio_provider.dart';
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

  // سجل التراجع والإعادة (Undo / Redo Command History كما في FilmCraft و EffectCraft)
  final List<VideoProjectEntity> _undoStack = [];
  final List<VideoProjectEntity> _redoStack = [];

  late VideoProjectEntity _project;
  int _selectedClipIndex = 0;
  int _selectedKeyframeIndex = 0;
  int _selectedTextTrackIndex = 0;
  bool _editTextKeyframes = false;
  int _activeToolTab =
      0; // 0: المقاطع, 1: Keyframes, 2: النصوص, 3: Lumetri, 4: الانتقالات والصوت

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
    for (final ctrl in _videoControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _commitProjectChange(VideoProjectEntity updated) {
    _undoStack.add(_project);
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    setState(() {
      _project = updated;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_project);
    setState(() {
      _project = _undoStack.removeLast();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_project);
    setState(() {
      _project = _redoStack.removeLast();
    });
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

  // ─── Playback Engine ────────────────────────────────────────────────────────

  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    final total = _project.totalDuration;
    if (total <= 0) return;

    if (_playheadTime >= total) {
      _playheadTime = 0.0;
    }

    setState(() => _isPlaying = true);

    if (_project.audioAsset != null && ref.read(isMusicEnabledProvider)) {
      ref.read(audioControllerProvider).playSfx(_project.audioAsset!);
    }

    const tickMs = 33;
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _playheadTime += tickMs / 1000.0;
        if (_playheadTime >= _project.totalDuration) {
          _playheadTime = 0.0;
          _isPlaying = false;
          t.cancel();
        }
        _syncSelectedClipWithPlayhead();
      });
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    for (final ctrl in _videoControllers.values) {
      if (ctrl.value.isPlaying) ctrl.pause();
    }
    setState(() => _isPlaying = false);
  }

  void _syncSelectedClipWithPlayhead() {
    double acc = 0.0;
    for (int i = 0; i < _project.clips.length; i++) {
      final clip = _project.clips[i];
      final d = clip.durationSeconds;
      if (_playheadTime >= acc && _playheadTime <= acc + d) {
        if (_selectedClipIndex != i) {
          _selectedClipIndex = i;
          _selectedKeyframeIndex = 0;
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

  // ─── Keyframe Navigator (◀ ◆ ▶) Inspired by FilmCraft & EffectCraft ────────

  void _jumpToAdjacentKeyframe({required bool forward}) {
    _pausePlayback();
    final bool editingText =
        _editTextKeyframes && _project.textTracks.isNotEmpty;
    final List<KeyframePoint> kfs = editingText
        ? _project
              .textTracks[_selectedTextTrackIndex.clamp(
                0,
                _project.textTracks.length - 1,
              )]
              .keyframes
        : (_project.clips.isNotEmpty
              ? _project.clips[_selectedClipIndex].keyframes
              : const []);
    if (kfs.isEmpty) return;

    final baseStart = editingText
        ? _project
              .textTracks[_selectedTextTrackIndex.clamp(
                0,
                _project.textTracks.length - 1,
              )]
              .startTime
        : _clipStartTime(_selectedClipIndex);

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

  // ─── Interactive Touch Keyframing on Stage Canvas ──────────────────────────

  void _onStageScaleStart(ScaleStartDetails details) {
    _pausePlayback();
    _undoStack.add(_project);
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();

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
    final newRotation = (_gestureBaseRotation +
            (details.rotation * 180.0 / math.pi))
        .clamp(-90.0, 90.0);

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
      final double localT = (_playheadTime - track.startTime).clamp(
        0.0,
        math.max(0.1, track.endTime - track.startTime),
      ).toDouble();
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
      final double localT = (_playheadTime - track.startTime).clamp(
        0.0,
        math.max(0.1, track.endTime - track.startTime),
      ).toDouble();
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

  // ─── Add Clip (Image / Video / Card) ────────────────────────────────────────

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

  // ─── Keyframe Manipulation ──────────────────────────────────────────────────

  void _addKeyframeAtPlayhead() {
    if (_editTextKeyframes && _project.textTracks.isNotEmpty) {
      final safeTxtIdx = _selectedTextTrackIndex.clamp(
        0,
        _project.textTracks.length - 1,
      );
      final track = _project.textTracks[safeTxtIdx];
      final double localTime = (_playheadTime - track.startTime).clamp(
        0.0,
        math.max(0.1, track.endTime - track.startTime),
      ).toDouble();
      final evaluated = RustVideoBridge.instance.evaluateKeyframes(
        track.keyframes,
        localTime,
      );
      final updatedKfs = [...track.keyframes, evaluated]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final updatedTracks = [..._project.textTracks];
      updatedTracks[safeTxtIdx] = track.copyWith(keyframes: updatedKfs);
      _selectedKeyframeIndex = updatedKfs.indexOf(evaluated);
      _commitProjectChange(_project.copyWith(textTracks: updatedTracks));
      return;
    }

    if (_project.clips.isEmpty) return;
    final clip = _project.clips[_selectedClipIndex];
    final clipStart = _clipStartTime(_selectedClipIndex);
    final localTime = (_playheadTime - clipStart).clamp(
      0.0,
      clip.durationSeconds,
    );

    final evaluated = RustVideoBridge.instance.evaluateKeyframes(
      clip.keyframes,
      localTime,
    );

    final updatedKeyframes = [...clip.keyframes, evaluated]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final updatedClips = [..._project.clips];
    updatedClips[_selectedClipIndex] = clip.copyWith(
      keyframes: updatedKeyframes,
    );

    _selectedKeyframeIndex = updatedKeyframes.indexOf(evaluated);
    _commitProjectChange(_project.copyWith(clips: updatedClips));
  }

  void _updateSelectedKeyframe(KeyframePoint Function(KeyframePoint) updater) {
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
      final updatedKfs = [...track.keyframes];
      updatedKfs[safeKfIdx] = updater(updatedKfs[safeKfIdx]);

      final updatedTracks = [..._project.textTracks];
      updatedTracks[safeTxtIdx] = track.copyWith(keyframes: updatedKfs);
      setState(() {
        _project = _project.copyWith(textTracks: updatedTracks);
        _playheadTime = track.startTime + updatedKfs[safeKfIdx].timestamp;
      });
      return;
    }

    if (_project.clips.isEmpty) return;
    final clip = _project.clips[_selectedClipIndex];
    if (clip.keyframes.isEmpty) return;

    final safeIdx = _selectedKeyframeIndex.clamp(0, clip.keyframes.length - 1);
    final updatedKfs = [...clip.keyframes];
    updatedKfs[safeIdx] = updater(updatedKfs[safeIdx]);

    final updatedClips = [..._project.clips];
    updatedClips[_selectedClipIndex] = clip.copyWith(keyframes: updatedKfs);

    setState(() {
      _project = _project.copyWith(clips: updatedClips);
      _playheadTime =
          _clipStartTime(_selectedClipIndex) + updatedKfs[safeIdx].timestamp;
    });
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
      const int exportFps = 8;
      final double totalDur = math.min(_project.totalDuration, 20.0);
      final int totalFrames = math.max(1, (totalDur * exportFps).round());
      final List<Uint8List> capturedFrames = [];
      int frameWidth = 720;
      int frameHeight = 1280;

      for (int i = 0; i < totalFrames; i++) {
        if (!mounted) return;
        final t = (i / exportFps).clamp(0.0, totalDur);
        setState(() {
          _playheadTime = t;
          _exportProgress = (i + 1) / totalFrames;
          _syncSelectedClipWithPlayhead();
        });

        await WidgetsBinding.instance.endOfFrame;

        final boundary =
            _stageBoundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary != null) {
          final ui.Image img = await boundary.toImage(pixelRatio: 1.5);
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
        if (uploadRes.isSuccess) {
          cloudVideoUrl = uploadRes.data.secureUrl;
          cloudThumbUrl = uploadRes.data.thumbnailUrl;
        }
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• تم رندر ${bundle.renderedFramesCount} إطاراً بالـ Keyframes وتصحيح ألوان Lumetri وتجميعها في ملف فيديو فعلي.',
              style: GoogleFonts.manrope(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '• المسار: ${bundle.videoFilePath}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• المحرك: ${RustVideoBridge.instance.isRustNativeLoaded ? "Rust FFI VideoCraft Engine 🦀" : "Hybrid FilmCraft/EffectCraft Engine ⚡"}',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم'),
          ),
        ],
      ),
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
            fontSize: 18,
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
            icon: const Icon(Icons.undo_rounded, size: 20),
            onPressed: (_undoStack.isEmpty || _isExporting) ? null : _undo,
          ),
          IconButton(
            tooltip: 'إعادة (Redo)',
            icon: const Icon(Icons.redo_rounded, size: 20),
            onPressed: (_redoStack.isEmpty || _isExporting) ? null : _redo,
          ),
          IconButton(
            tooltip: 'توليد تلقائي من ذكرياتنا',
            icon: Icon(
              Icons.auto_fix_high_rounded,
              color: theme.colorScheme.secondary,
            ),
            onPressed: _isExporting ? null : _autoGenerateFromMemories,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 4),
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _exportVideo,
              icon: _isExporting
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.movie_creation_outlined, size: 18),
              label: Text(
                _isExporting ? '${(_exportProgress * 100).round()}%' : 'تصدير',
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
                  vertical: 8,
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

          // 2. Playback & Timeline Scrubber Bar with Keyframe Navigator (◀ ◆ ▶)
          _buildTimelineScrubber(theme),

          // 3. Studio Tool Tabs
          _buildToolSelectorBar(theme),

          // 4. Active Tool Inspector Panel
          Expanded(flex: 4, child: _buildActiveToolPanel(theme)),
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
            // طبقة الفيديو مع مصفوفة تصحيح الألوان Lumetri Color Matrix
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

            // طبقة تظليل الحواف السينمائي (Lumetri Vignette)
            if (vignetteAmount > 0.01)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        AppTheme.transparent(context),
                        Theme.of(context).colorScheme.scrim.withValues(alpha: vignetteAmount),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),

            // طبقة النصوص المتحركة بالـ Keyframes
            for (final txt in _project.textTracks)
              if (_playheadTime >= txt.startTime &&
                  _playheadTime <= txt.endTime)
                _buildAnimatedTextOverlay(txt, _playheadTime - txt.startTime),

            if (!_isExporting)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.54),
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
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.54),
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
                  color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.25),
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

  // ─── Timeline Scrubber + FilmCraft Keyframe Navigator (◀ ◆ ▶) ─────────────

  Widget _buildTimelineScrubber(ThemeData theme) {
    final total = math.max(_project.totalDuration, 0.1);
    final bool editingText =
        _editTextKeyframes && _project.textTracks.isNotEmpty;
    final List<KeyframePoint> activeKeyframes = editingText
        ? _project
              .textTracks[_selectedTextTrackIndex.clamp(
                0,
                _project.textTracks.length - 1,
              )]
              .keyframes
        : (_project.clips.isNotEmpty
              ? _project.clips[_selectedClipIndex].keyframes
              : const []);

    final double baseStartTime = editingText
        ? _project
              .textTracks[_selectedTextTrackIndex.clamp(
                0,
                _project.textTracks.length - 1,
              )]
              .startTime
        : _clipStartTime(_selectedClipIndex);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          // شريط التنقل بين الـ Keyframes (◀ ◆ ▶) المستلهم من FilmCraft و EffectCraft
          SizedBox(
            height: 28,
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
                      vertical: 2,
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
                const SizedBox(width: 6),
                // أزرار ◀ ◆ ▶
                InkWell(
                  onTap: () => _jumpToAdjacentKeyframe(forward: false),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_left_rounded, size: 18),
                  ),
                ),
                InkWell(
                  onTap: _addKeyframeAtPlayhead,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '◆+',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _jumpToAdjacentKeyframe(forward: true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
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
                          child: Text(
                            '◆ ${kf.timestamp.toStringAsFixed(1)}s',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : theme.colorScheme.primary,
                            ),
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

  // ─── Studio Tool Tabs (5 Tabs including Lumetri Color Grading) ─────────────

  Widget _buildToolSelectorBar(ThemeData theme) {
    const tabs = [
      'المقاطع',
      'Keyframes ◆',
      'النصوص',
      '🎨 Lumetri',
      'الانتقالات',
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _activeToolTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeToolTab = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
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
                        ? Theme.of(context).colorScheme.onPrimary
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
      _ => _buildTransitionsAndAudioPanel(theme),
    };
  }

  // ─── Panel 0: Clips & Media ─────────────────────────────────────────────────

  Widget _buildClipsPanel(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
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
        const SizedBox(height: 16),
        for (int i = 0; i < _project.clips.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: i == _selectedClipIndex
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
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
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
              title: Text(
                _project.clips[i].title,
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'المدة: ${_project.clips[i].durationSeconds.toStringAsFixed(1)}s • ${(_project.clips[i].keyframes.length)} Keyframes ◆',
                style: GoogleFonts.manrope(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: () {
                      final c = _project.clips[i];
                      if (c.durationSeconds <= 1.5) return;
                      final updated = [..._project.clips];
                      updated[i] = c.copyWith(
                        durationSeconds: c.durationSeconds - 0.5,
                      );
                      _commitProjectChange(_project.copyWith(clips: updated));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    onPressed: () {
                      final c = _project.clips[i];
                      final updated = [..._project.clips];
                      updated[i] = c.copyWith(
                        durationSeconds: c.durationSeconds + 0.5,
                      );
                      _commitProjectChange(_project.copyWith(clips: updated));
                    },
                  ),
                  if (_project.clips.length > 1)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 20,
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

  // ─── Panel 1: Keyframe Inspector (With Auto-Bezier & Hold Modes) ───────────

  Widget _buildKeyframesPanel(ThemeData theme) {
    final bool editingText =
        _editTextKeyframes && _project.textTracks.isNotEmpty;
    final List<KeyframePoint> kfs = editingText
        ? _project
              .textTracks[_selectedTextTrackIndex.clamp(
                0,
                _project.textTracks.length - 1,
              )]
              .keyframes
        : (_project.clips.isNotEmpty
              ? _project.clips[_selectedClipIndex].keyframes
              : const []);

    if (kfs.isEmpty) return const SizedBox.shrink();
    final safeIdx = _selectedKeyframeIndex.clamp(0, kfs.length - 1);
    final kf = kfs[safeIdx];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              onSelected: (_) => setState(() {
                _editTextKeyframes = true;
                _selectedKeyframeIndex = 0;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'تحرير Keyframe #${safeIdx + 1} (${kf.timestamp.toStringAsFixed(1)}s)',
          style: GoogleFonts.notoSerif(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _buildSliderRow(
          label: 'التكبير (Scale): ${kf.scale.toStringAsFixed(2)}x',
          value: kf.scale.clamp(0.4, 2.5),
          min: 0.4,
          max: 2.5,
          onChanged: (v) =>
              _updateSelectedKeyframe((k) => k.copyWith(scale: v)),
        ),
        _buildSliderRow(
          label: 'إزاحة أفقية (X): ${kf.x.toStringAsFixed(2)}',
          value: kf.x.clamp(-0.8, 0.8),
          min: -0.8,
          max: 0.8,
          onChanged: (v) => _updateSelectedKeyframe((k) => k.copyWith(x: v)),
        ),
        _buildSliderRow(
          label: 'إزاحة رأسية (Y): ${kf.y.toStringAsFixed(2)}',
          value: kf.y.clamp(-0.8, 0.8),
          min: -0.8,
          max: 0.8,
          onChanged: (v) => _updateSelectedKeyframe((k) => k.copyWith(y: v)),
        ),
        _buildSliderRow(
          label: 'الدوران (Rotation): ${kf.rotation.toStringAsFixed(0)}°',
          value: kf.rotation.clamp(-90.0, 90.0),
          min: -90.0,
          max: 90.0,
          onChanged: (v) =>
              _updateSelectedKeyframe((k) => k.copyWith(rotation: v)),
        ),
        _buildSliderRow(
          label: 'الشفافية (Opacity): ${(kf.opacity * 100).round()}%',
          value: kf.opacity.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          onChanged: (v) =>
              _updateSelectedKeyframe((k) => k.copyWith(opacity: v)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: KeyframeEasing.values.map((e) {
            return ChoiceChip(
              label: Text(e.name, style: const TextStyle(fontSize: 11)),
              selected: kf.easing == e,
              onSelected: (_) =>
                  _updateSelectedKeyframe((k) => k.copyWith(easing: e)),
            );
          }).toList(),
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

  // ─── Panel 2: Animated Text Overlays ────────────────────────────────────────

  Widget _buildTextTracksPanel(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: _showAddTextTrackDialog,
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: const Text('إضافة نص متحرك بالـ Keyframes'),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < _project.textTracks.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: (_editTextKeyframes && _selectedTextTrackIndex == i)
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
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
                style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'من ${_project.textTracks[i].startTime.toStringAsFixed(1)}s إلى ${_project.textTracks[i].endTime.toStringAsFixed(1)}s • ${_project.textTracks[i].keyframes.length} Keyframes ◆',
                style: GoogleFonts.manrope(fontSize: 12),
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                onPressed: () {
                  final updated = [..._project.textTracks]..removeAt(i);
                  _selectedTextTrackIndex = 0;
                  _commitProjectChange(_project.copyWith(textTracks: updated));
                },
              ),
            ),
          ),
      ],
    );
  }

  void _showAddTextTrackDialog() {
    final textCtrl = TextEditingController();
    String selectedStyle = 'serif';
    final start = _playheadTime;
    final end = math.min(
      _playheadTime + 3.5,
      math.max(_project.totalDuration, 3.5),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'إضافة نص متحرك للفيديو',
            style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'اكتب عبارة رومانسية...',
                ),
              ),
              const SizedBox(height: 12),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (textCtrl.text.trim().isEmpty) return;
                final newTrack = VideoTextTrack(
                  id: const Uuid().v4(),
                  text: textCtrl.text.trim(),
                  startTime: start,
                  endTime: end,
                  fontStyle: selectedStyle,
                  keyframes: [
                    const KeyframePoint(
                      timestamp: 0.0,
                      y: 0.25,
                      opacity: 0.0,
                      scale: 0.85,
                    ),
                    const KeyframePoint(
                      timestamp: 0.6,
                      y: 0.0,
                      opacity: 1.0,
                      scale: 1.0,
                    ),
                    KeyframePoint(
                      timestamp: math.max(0.8, end - start - 0.5),
                      y: 0.0,
                      opacity: 1.0,
                      scale: 1.05,
                    ),
                    KeyframePoint(
                      timestamp: math.max(1.0, end - start),
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
                Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
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
      padding: const EdgeInsets.all(16),
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
        const SizedBox(height: 16),
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
          label: 'دفء الألوان (Temperature): ${g.temperature.toStringAsFixed(2)}',
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

  // ─── Panel 4: Transitions & Background Audio ────────────────────────────────

  Widget _buildTransitionsAndAudioPanel(ThemeData theme) {
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

    const audioTracks = [
      (AppConstants.romanticIntro, 'موسيقى رومانسية ناعمة 🎵'),
      (AppConstants.weddingCelebration, 'موسيقى احتفال الزفاف 🎉'),
      (AppConstants.loveMessage, 'نغمة رسالة الحب 💕'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'انتقال الدخول للمقطع (${clip.title}):',
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
        const SizedBox(height: 20),
        Text(
          'الموسيقى الخلفية للفيديو:',
          style: GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _project.audioAsset,
          onChanged: (val) {
            _commitProjectChange(_project.copyWith(audioAsset: val));
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final track in audioTracks)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(track.$2, style: GoogleFonts.manrope(fontSize: 13)),
                  value: track.$1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
