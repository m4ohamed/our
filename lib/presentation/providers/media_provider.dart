// lib/presentation/providers/media_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entities.dart';
import 'app_providers.dart';

final mediaProvider =
    AsyncNotifierProvider<MediaNotifier, List<MediaFileEntity>>(
      MediaNotifier.new,
    );

class MediaNotifier extends AsyncNotifier<List<MediaFileEntity>> {
  @override
  Future<List<MediaFileEntity>> build() async {
    final repo = ref.watch(mediaRepositoryProvider);

    final sub = repo.watchMedia().listen((media) {
      if (state.hasValue) {
        state = AsyncData(media);
      }
    });
    ref.onDispose(sub.cancel);

    final result = await repo.getAllMedia();
    return result.when(success: (media) => media, failure: (e) => throw e);
  }

  Future<void> addMedia(MediaFileEntity media) async {
    final repo = ref.read(mediaRepositoryProvider);
    final result = await repo.saveMedia(media);
    result.when(
      success: (_) {
        _refresh();
        final oneSignal = ref.read(oneSignalServiceProvider);
        final isVideo = media.mediaType == MediaType.video;
        oneSignal.sendNotificationToPartner(
          title: isVideo
              ? 'فيديو جديد في ألبوم الذكريات 🎬'
              : 'صورة جديدة في ألبوم الذكريات 📸',
          message:
              'أضاف ${oneSignal.myName} ${isVideo ? "فيديو جديداً" : "صورة جديدة"}${media.description != null && media.description!.isNotEmpty ? ": ${media.description}" : " إلى ألبومكما المشترك 💕"}',
          category: 'media',
        );
      },
      failure: (e) => state = AsyncError(e, StackTrace.current),
    );
  }

  Future<void> toggleFeatured(String id) async {
    final repo = ref.read(mediaRepositoryProvider);
    final current = state.value ?? [];
    final target = current.where((m) => m.id == id).firstOrNull;
    if (target == null) return;

    final updated = target.copyWith(isFeatured: !target.isFeatured);
    final result = await repo.saveMedia(updated);
    result.when(
      success: (_) => _refresh(),
      failure: (e) => state = AsyncError(e, StackTrace.current),
    );
  }

  Future<void> deleteMedia(String id) async {
    final repo = ref.read(mediaRepositoryProvider);
    final result = await repo.deleteMedia(id);
    result.when(
      success: (_) => _refresh(),
      failure: (e) => state = AsyncError(e, StackTrace.current),
    );
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
      failure: (e) => AsyncError(e, StackTrace.current),
    );
  }
}
