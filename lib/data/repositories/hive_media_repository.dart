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
  StreamSubscription<List<MediaFileEntity>>? _localSub;
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
    // الاستماع الدائم للكاش المحلي لضمان تحديث ألبوم الذكريات فوراً عند إضافة أو تعديل أي ذكرى محلياً
    _localSub = _localCache.watchMedia().listen((localMedia) {
      if (!_streamController.isClosed) {
        _streamController.add(localMedia);
      }
    });

    if (_collection == null) return;

    _firestoreSub = _collection!
        .orderBy('uploadDate', descending: true)
        .snapshots()
        .listen(
          (snapshot) async {
            try {
              // معالجة الحذف الفوري بين الهواتف المتصلة
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.removed) {
                  await _localCache.deleteMedia(change.doc.id);
                }
              }

              final remoteItems = snapshot.docs.map(_docToEntity).toList();
              for (final remoteItem in remoteItems) {
                final existingRes = await _localCache.getMediaById(
                  remoteItem.id,
                );
                final existing = existingRes.getOrNull();
                final preservedLocalPath =
                    (existing?.localPath != null &&
                        File(existing!.localPath!).existsSync())
                    ? existing.localPath
                    : remoteItem.localPath;

                await _localCache.saveMedia(
                  remoteItem.copyWith(localPath: preservedLocalPath),
                );
              }

              final merged = await _localCache.getAllMedia();
              if (merged.isSuccess && !_streamController.isClosed) {
                _streamController.add(merged.data);
              }
            } catch (_) {}
          },
          onError: (_) async {
            // في حال رفض صلاحيات Firestore (permission-denied) أو انقطاع الإنترنت، نعتمد على الكاش المحلي
            final cached = await _localCache.getAllMedia();
            if (cached.isSuccess && !_streamController.isClosed) {
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
          try {
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
          } catch (_) {}
        }

        if (needsPush) {
          await _collection!.doc(itemToPush.id).set(
            _entityToMap(itemToPush),
            SetOptions(merge: true),
          );
        }
      }
    } catch (_) {
      // تجاهل أخطاء الصلاحيات أو الشبكة بهدوء دون تعطيل التطبيق
    }
  }

  @override
  Future<Result<List<MediaFileEntity>>> getAllMedia() async {
    // 1. ضمان تهيئة الكاش المحلي أولاً
    final localInitial = await _localCache.getAllMedia();
    if (_collection == null) {
      return localInitial;
    }

    try {
      await syncPendingToCloud();

      final snapshot = await _collection!
          .orderBy('uploadDate', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final remoteMedia = snapshot.docs.map(_docToEntity).toList();
        for (final remoteItem in remoteMedia) {
          final existingRes = await _localCache.getMediaById(remoteItem.id);
          final existing = existingRes.getOrNull();
          final preservedLocalPath =
              (existing?.localPath != null &&
                  File(existing!.localPath!).existsSync())
              ? existing.localPath
              : remoteItem.localPath;

          await _localCache.saveMedia(
            remoteItem.copyWith(localPath: preservedLocalPath),
          );
        }
      }

      return await _localCache.getAllMedia();
    } catch (_) {
      return localInitial;
    }
  }

  @override
  Future<Result<MediaFileEntity?>> getMediaById(String id) async {
    if (_collection == null) return _localCache.getMediaById(id);

    try {
      final doc = await _collection!.doc(id).get();
      if (!doc.exists || doc.data() == null) {
        return await _localCache.getMediaById(id);
      }
      return Success(_docToEntity(doc));
    } catch (_) {
      return await _localCache.getMediaById(id);
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
        try {
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
        } catch (_) {}
      }

      // 1. الحفظ المحلي الفوري في Hive لضمان ظهور الذكرى وعدم ضياعها أبداً
      await _localCache.saveMedia(mediaToSave);

      // 2. محاولة الحفظ في Cloud Firestore بشكل معزول حتى لا يتسبب خطأ الصلاحيات في إظهار "خطأ في تحميل الذكريات"
      if (_collection != null) {
        try {
          await _collection!.doc(mediaToSave.id).set(
            _entityToMap(mediaToSave),
            SetOptions(merge: true),
          );
        } catch (_) {
          // في حال رفض صلاحيات Firestore أو انقطاع الإنترنت، تظل الذكرى محفوظة محلياً وتُزامن لاحقاً
        }
      }

      return Success(mediaToSave);
    } catch (e) {
      return Failure(StorageException('فشل حفظ الوسائط محلياً: $e'));
    }
  }

  @override
  Future<Result<void>> deleteMedia(String id) async {
    try {
      await _localCache.deleteMedia(id);
      if (_collection != null) {
        try {
          await _collection!.doc(id).delete();
        } catch (_) {}
      }
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل حذف الوسائط: $e'));
    }
  }

  @override
  Future<Result<void>> deleteAllMedia() async {
    try {
      await _localCache.deleteAllMedia();
      if (_collection != null && _firestore != null) {
        try {
          final snapshot = await _collection!.get();
          final batch = _firestore.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } catch (_) {}
      }
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل مسح ألبوم الصور: $e'));
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
      if (snapshot.docs.isEmpty) {
        return await _localCache.getMediaByEventId(eventId);
      }
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
    _localSub?.cancel();
    _streamController.close();
  }
}