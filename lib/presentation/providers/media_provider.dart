// lib/presentation/providers/media_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mappers/media_mapper.dart';
import '../../domain/entities/entities.dart';
import 'app_providers.dart';

final mediaProvider =
    AsyncNotifierProvider<MediaNotifier, List<MediaFileEntity>>(
      MediaNotifier.new,
    );

class MediaNotifier extends AsyncNotifier<List<MediaFileEntity>> {
  List<MediaFileEntity> _fallbackFromHive() {
    final box = ref.read(hiveMediaBoxProvider);
    final media = box.values.map((m) => m.toEntity()).toList()
      ..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    return media;
  }

  @override
  Future<List<MediaFileEntity>> build() async {
    final repo = ref.watch(mediaRepositoryProvider);

    final sub = repo.watchMedia().listen((media) {
      state = AsyncData(media);
    });
    ref.onDispose(sub.cancel);

    final result = await repo.getAllMedia();
    return result.when(
      success: (media) => media,
      failure: (_) => _fallbackFromHive(),
    );
  }

  Future<void> addMedia(MediaFileEntity media) async {
    final repo = ref.read(mediaRepositoryProvider);
    final result = await repo.saveMedia(media);
    await _refresh();
    if (result.isSuccess) {
      final oneSignal = ref.read(oneSignalServiceProvider);
      final isVideo = media.mediaType == MediaType.video;
      unawaited(
        oneSignal.sendNotificationToPartner(
          title: isVideo
              ? '賮賷丿賷賵 噩丿賷丿 賮賷 兀賱亘賵賲 丕賱匕賰乇賷丕鬲 馃幀'
              : '氐賵乇丞 噩丿賷丿丞 賮賷 兀賱亘賵賲 丕賱匕賰乇賷丕鬲 馃摳',
          message:
              '兀囟丕賮 ${oneSignal.myName} ${isVideo ? "賮賷丿賷賵 噩丿賷丿丕賸" : "氐賵乇丞 噩丿賷丿丞"}${media.description != null && media.description!.isNotEmpty ? ": ${media.description}" : " 廿賱賶 兀賱亘賵賲賰賲丕 丕賱賲卮鬲乇賰 馃挄"}',
          category: 'media',
        ),
      );
    }
  }

  Future<void> toggleFeatured(String id) async {
    final repo = ref.read(mediaRepositoryProvider);
    final current = state.value ?? _fallbackFromHive();
    final target = current.where((m) => m.id == id).firstOrNull;
    if (target == null) return;

    final updated = target.copyWith(isFeatured: !target.isFeatured);
    await repo.saveMedia(updated);
    await _refresh();
  }

  Future<void> deleteMedia(String id) async {
    final repo = ref.read(mediaRepositoryProvider);
    await repo.deleteMedia(id);
    await _refresh();
  }

  Future<void> deleteAll() async {
    final repo = ref.read(mediaRepositoryProvider);
    await repo.deleteAllMedia();
    state = const AsyncData([]);
  }

  Future<void> _refresh() async {
    final repo = ref.read(mediaRepositoryProvider);
    final result = await repo.getAllMedia();
    state = result.when(
      success: (media) => AsyncData(media),
      failure: (_) => AsyncData(_fallbackFromHive()),
    );
  }
}