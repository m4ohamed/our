// lib/presentation/providers/audio_provider.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import 'app_providers.dart';

class AudioController {
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  Future<void> playBackground(String assetPath, double volume) async {
    try {
      await _bgPlayer.setVolume(volume);
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.play(AssetSource(assetPath));
    } catch (_) {}
  }

  Future<void> stopBackground() async {
    try {
      await _bgPlayer.stop();
    } catch (_) {}
  }

  Future<void> pauseBackground() async {
    try {
      await _bgPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeBackground() async {
    try {
      await _bgPlayer.resume();
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    try {
      await _bgPlayer.setVolume(volume);
    } catch (_) {}
  }

  Future<void> playSfx(String assetPath) async {
    try {
      await _sfxPlayer.setVolume(0.8);
      await _sfxPlayer.play(AssetSource(assetPath));
    } catch (_) {}
  }

  // Specialized methods
  Future<void> playWeddingCelebration(double volume) =>
      playBackground(AppConstants.weddingCelebration, volume);

  Future<void> playSurpriseIntro() => playSfx(AppConstants.romanticIntro);
  Future<void> playSurpriseReveal() => playSfx(AppConstants.loveMessage);

  void dispose() {
    _bgPlayer.dispose();
    _sfxPlayer.dispose();
  }
}

// Provider واحد للـ audio طول عمر التطبيق
final audioControllerProvider = Provider<AudioController>((ref) {
  final controller = AudioController();
  ref.onDispose(controller.dispose);

  // استمع للـ settings وطبّق الصوت تلقائياً
  ref.listen(isMusicEnabledProvider, (_, isEnabled) {
    if (isEnabled) {
      controller.resumeBackground();
    } else {
      controller.pauseBackground();
    }
  });

  ref.listen(musicVolumeProvider, (_, volume) {
    controller.setVolume(volume);
  });

  return controller;
});
