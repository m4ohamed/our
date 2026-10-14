// lib/data/repositories/firestore_media_repository.dart
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/cloudinary_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import 'hive_media_repository.dart';

/// مستودع ألبوم الذكريات المرتبط بـ Cloud Firestore وCloudinary (صور + فيديو) مع كاش Hive محلي
class FirestoreMediaRepository implements MediaRepository {
  final FirebaseFirestore? _firestore;
  final HiveMediaRepository _localCache;
  final CloudinaryService _cloudinary;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  final _streamController = StreamController<List<MediaFileEntity>>.broadcast();

  FirestoreMediaRepository({
    required FirebaseFirestore? firestore,
    required HiveMediaRepository localCache,
    required CloudinaryService cloudinary,
  }) : _firestore = firestore,
       _localCache = localCache,
       _cloudinary = cloudinary {
    _initRealtimeSync();
  }

  CollectionReference<Map<String, dynamic>>? get _collection =>
      _firestore?.collection(AppConstants.firestoreMediaCollection);

  void _initRealtimeSync() {
    if (_collection == null) {
      _localCache.watchMedia().listen(_streamController.add);
      return;
    }

    _firestoreSub = _collection!
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .listen(
          (snapshot) async {
            // معالجة الحذف الفوري بين الهواتف المتصلة
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.removed) {
                await _localCache.deleteMedia(change.doc.id);
              }
            }

            final items = snapshot.docs.map(_docToEntity).toList();
            for (final item in items) {
              await _localCache.saveMedia(item);
            }
            _streamController.add(items);
          },
          onError: (_) async {
            final cached = await _localCache.getAllMedia();
            if (cached.isSuccess) {
              _streamController.add(cached.data);
            }
          },
        );
  }

  /// مزامنة ثنائية الاتجاه: ترفع أي صور أو فيديوهات محلية لم تُرفع بعد إلى Cloudinary وFirestore
  Future<void> syncPendingToCloud() async {
    if (_collection == null || _firestore == null) return;
    try {
      final remoteSnap = await _collection!.get();
      final remoteIds = remoteSnap.docs.map((d) => d.id).toSet();
      final localResult = await _localCache.getAllMedia();
      if (!localResult.isSuccess) return;

      for (final localItem in localResult.data) {
        var itemToPush = localItem;
        bool needsPush = !remoteIds.contains(localItem.id);

        if (localItem.localPath != null &&
            localItem.cloudinaryUrl.isEmpty &&
            File(localItem.localPath!).existsSync() &&
            _cloudinary.isConfigured) {
          final file = File(localItem.localPath!);
          final uploadRes = localItem.mediaType == MediaType.video
              ? await _cloudinary.uploadVideo(file)
              : await _cloudinary.uploadImage(file);

          if (uploadRes.isSuccess) {
            final uploaded = uploadRes.data;
            itemToPush = localItem.copyWith(
              cloudinaryUrl: uploaded.secureUrl,
              thumbnailUrl: uploaded.thumbnailUrl,
              fileSize: uploaded.bytes,
              aspectRatio: uploaded.aspectRatio,
            );
            await _localCache.saveMedia(itemToPush);
            needsPush = true;
          }
        }

        if (needsPush) {
          await _collection!.doc(itemToPush.id).set(
            _entityToMap(itemToPush),
            SetOptions(merge: true),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Future<Result<List<MediaFileEntity>>> getAllMedia() async {
    if (_collection == null) {
      return _localCache.getAllMedia();
    }

    try {
      await syncPendingToCloud();

      final snapshot = await _collection!
          .orderBy('uploadDate', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return _localCache.getAllMedia();
      }

      final media = snapshot.docs.map(_docToEntity).toList();
      for (final m in media) {
        await _localCache.saveMedia(m);
      }
      return Success(media);
    } catch (_) {
      return _localCache.getAllMedia();
    }
  }

  @override
  Future<Result<MediaFileEntity?>> getMediaById(String id) async {
    if (_collection == null) return _localCache.getMediaById(id);

    try {
      final doc = await _collection!.doc(id).get();
      if (!doc.exists || doc.data() == null) {
        return _localCache.getMediaById(id);
      }
      return Success(_docToEntity(doc));
    } catch (_) {
      return _localCache.getMediaById(id);
    }
  }

  @override
  Future<Result<MediaFileEntity>> saveMedia(MediaFileEntity media) async {
    try {
      var mediaToSave = media;

      // رفع الصورة أو الفيديو تلقائياً إلى Cloudinary إذا كان ملفاً محلياً جديداً
      if (media.localPath != null &&
          media.cloudinaryUrl.isEmpty &&
          File(media.localPath!).existsSync() &&
          _cloudinary.isConfigured) {
        final file = File(media.localPath!);
        final uploadRes = media.mediaType == MediaType.video
            ? await _cloudinary.uploadVideo(file)
            : await _cloudinary.uploadImage(file);

        if (uploadRes.isSuccess) {
          final uploaded = uploadRes.data;
          mediaToSave = media.copyWith(
            cloudinaryUrl: uploaded.secureUrl,
            thumbnailUrl: uploaded.thumbnailUrl,
            fileSize: uploaded.bytes,
            aspectRatio: uploaded.aspectRatio,
          );
        }
      }

      await _localCache.saveMedia(mediaToSave);

      if (_collection != null) {
        await _collection!.doc(mediaToSave.id).set(_entityToMap(mediaToSave));
      }

      return Success(mediaToSave);
    } catch (e) {
      return Failure(StorageException('فشل حفظ الوسائط في Firestore: $e'));
    }
  }

  @override
  Future<Result<void>> deleteMedia(String id) async {
    try {
      await _localCache.deleteMedia(id);
      if (_collection != null) {
        await _collection!.doc(id).delete();
      }
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل حذف الوسائط من Firestore: $e'));
    }
  }

  @override
  Future<Result<void>> deleteAllMedia() async {
    try {
      await _localCache.deleteAllMedia();
      if (_collection != null && _firestore != null) {
        final snapshot = await _collection!.get();
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل مسح ألبوم الصور من Firestore: $e'));
    }
  }

  @override
  Future<Result<List<MediaFileEntity>>> getMediaByEventId(
    String eventId,
  ) async {
    if (_collection == null) return _localCache.getMediaByEventId(eventId);

    try {
      final snapshot = await _collection!
          .where('eventId', isEqualTo: eventId)
          .get();
      return Success(snapshot.docs.map(_docToEntity).toList());
    } catch (_) {
      return _localCache.getMediaByEventId(eventId);
    }
  }

  @override
  Stream<List<MediaFileEntity>> watchMedia() => _streamController.stream;

  Map<String, dynamic> _entityToMap(MediaFileEntity m) {
    return {
      'id': m.id,
      'cloudinaryUrl': m.cloudinaryUrl,
      'thumbnailUrl': m.thumbnailUrl,
      'localPath': m.localPath,
      'mediaType': m.mediaType.name,
      'uploadDate': Timestamp.fromDate(m.uploadDate),
      'eventId': m.eventId,
      'description': m.description,
      'isFeatured': m.isFeatured,
      'location': m.location,
      'aspectRatio': m.aspectRatio,
      'fileSize': m.fileSize,
      'fileName': m.fileName,
      'tags': m.tags,
    };
  }

  MediaFileEntity _docToEntity(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MediaFileEntity(
      id: (data['id'] as String?) ?? doc.id,
      cloudinaryUrl: (data['cloudinaryUrl'] as String?) ?? '',
      thumbnailUrl: (data['thumbnailUrl'] as String?) ?? '',
      localPath: data['localPath'] as String?,
      mediaType: (data['mediaType'] == 'video')
          ? MediaType.video
          : MediaType.photo,
      uploadDate:
          (data['uploadDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventId: data['eventId'] as String?,
      description: data['description'] as String?,
      isFeatured: (data['isFeatured'] as bool?) ?? false,
      location: data['location'] as String?,
      aspectRatio: (data['aspectRatio'] as num?)?.toDouble() ?? 1.0,
      fileSize: (data['fileSize'] as num?)?.toInt(),
      fileName: data['fileName'] as String?,
      tags: (data['tags'] as List?)?.cast<String>() ?? const [],
    );
  }

  void dispose() {
    _firestoreSub?.cancel();
    _streamController.close();
  }
}
