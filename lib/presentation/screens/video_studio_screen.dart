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
import '../../core/errors/app_exception.dart';
import '../../core/services/offscreen_video_compositor.dart';
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