// lib/data/repositories/firestore_timeline_repository.dart
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/cloudinary_service.dart';
import '../../domain/entities/timeline_event_entity.dart';
import '../../domain/repositories/repositories.dart';
import 'hive_timeline_repository.dart';

/// مستودع يجمع بين التخزين السحابي الفوري ثنائي الاتجاه في Cloud Firestore
/// والرفع التلقائي للصور عبر Cloudinary مع الاحتفاظ بنسخة محلية في Hive للعمل دون اتصال
class FirestoreTimelineRepository implements TimelineRepository {
  final FirebaseFirestore? _firestore;
  final HiveTimelineRepository _localCache;
  final CloudinaryService _cloudinary;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  final _streamController =
      StreamController<List<TimelineEventEntity>>.broadcast();

  FirestoreTimelineRepository({
    required FirebaseFirestore? firestore,
    required HiveTimelineRepository localCache,
    required CloudinaryService cloudinary,
  }) : _firestore = firestore,
       _localCache = localCache,
       _cloudinary = cloudinary {
    _initRealtimeSync();
  }

  CollectionReference<Map<String, dynamic>>? get _collection =>
      _firestore?.collection(AppConstants.firestoreEventsCollection);

  void _initRealtimeSync() {
    if (_collection == null) {
      _localCache.watchEvents().listen(_streamController.add);
      return;
    }

    _firestoreSub = _collection!
        .orderBy('date')
        .snapshots()
        .listen(
          (snapshot) async {
            // معالجة الحذف الفوري بين الهواتف المتصلة
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.removed) {
                await _localCache.deleteEvent(change.doc.id);
              }
            }

            final events = snapshot.docs.map(_docToEntity).toList();
            // تحديث الكاش المحلي في Hive
            for (final event in events) {
              await _localCache.saveEvent(event);
            }
            _streamController.add(events);
          },
          onError: (_) async {
            final cached = await _localCache.getAllEvents();
            if (cached.isSuccess) {
              _streamController.add(cached.data);
            }
          },
        );
  }

  /// مزامنة ثنائية الاتجاه (Two-Way Sync): ترفع أي أحداث أو صور أُنشئت أوفلاين إلى Cloudinary وFirestore
  Future<void> syncPendingToCloud() async {
    if (_collection == null || _firestore == null) return;
    try {
      final remoteSnap = await _collection!.get();
      final remoteIds = remoteSnap.docs.map((d) => d.id).toSet();
      final localResult = await _localCache.getAllEvents();
      if (!localResult.isSuccess) return;

      for (final localEvent in localResult.data) {
        var eventToPush = localEvent;
        bool needsPush = !remoteIds.contains(localEvent.id);

        // إذا كانت هناك صورة محلية لم تُرفع بعد إلى السحابة وكان Cloudinary مفعلاً
        if (localEvent.localImagePath != null &&
            (localEvent.imageUrl == null || localEvent.imageUrl!.isEmpty) &&
            File(localEvent.localImagePath!).existsSync() &&
            _cloudinary.isConfigured) {
          final uploadRes = await _cloudinary.uploadImage(
            File(localEvent.localImagePath!),
          );
          if (uploadRes.isSuccess) {
            eventToPush = localEvent.copyWith(
              imageUrl: uploadRes.data.secureUrl,
            );
            await _localCache.saveEvent(eventToPush);
            needsPush = true;
          }
        }

        if (needsPush) {
          await _collection!.doc(eventToPush.id).set(
            _entityToMap(eventToPush),
            SetOptions(merge: true),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Future<Result<List<TimelineEventEntity>>> getAllEvents() async {
    if (_collection == null) {
      return _localCache.getAllEvents();
    }

    try {
      // أولاً: دفع أي عناصر محلية معلقة للسحابة
      await syncPendingToCloud();

      final snapshot = await _collection!.orderBy('date').get();
      if (snapshot.docs.isEmpty) {
        return _localCache.getAllEvents();
      }

      final events = snapshot.docs.map(_docToEntity).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      for (final e in events) {
        await _localCache.saveEvent(e);
      }
      return Success(events);
    } catch (_) {
      return _localCache.getAllEvents();
    }
  }

  @override
  Future<Result<TimelineEventEntity?>> getEventById(String id) async {
    if (_collection == null) return _localCache.getEventById(id);

    try {
      final doc = await _collection!.doc(id).get();
      if (!doc.exists || doc.data() == null) {
        return _localCache.getEventById(id);
      }
      return Success(_docToEntity(doc));
    } catch (_) {
      return _localCache.getEventById(id);
    }
  }

  @override
  Future<Result<TimelineEventEntity>> saveEvent(
    TimelineEventEntity event,
  ) async {
    try {
      var eventToSave = event;

      if (event.localImagePath != null &&
          File(event.localImagePath!).existsSync() &&
          _cloudinary.isConfigured) {
        final uploadResult = await _cloudinary.uploadImage(
          File(event.localImagePath!),
        );
        if (uploadResult.isSuccess) {
          eventToSave = event.copyWith(imageUrl: uploadResult.data.secureUrl);
        }
      }

      // 1. حفظ في الكاش المحلي فوراً
      final localSaved = await _localCache.saveEvent(eventToSave);
      final finalEvent = localSaved.getOrElse(eventToSave);

      // 2. حفظ في سيرفر Cloud Firestore
      if (_collection != null) {
        await _collection!.doc(finalEvent.id).set(_entityToMap(finalEvent));
      }

      return Success(finalEvent);
    } catch (e) {
      return Failure(StorageException('فشل حفظ الحدث في Firestore: $e'));
    }
  }

  @override
  Future<Result<void>> deleteEvent(String id) async {
    try {
      await _localCache.deleteEvent(id);
      if (_collection != null) {
        await _collection!.doc(id).delete();
      }
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل حذف الحدث من Firestore: $e'));
    }
  }

  @override
  Future<Result<void>> deleteAllEvents() async {
    try {
      await _localCache.deleteAllEvents();
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
      return Failure(StorageException('فشل مسح الأحداث من Firestore: $e'));
    }
  }

  @override
  Stream<List<TimelineEventEntity>> watchEvents() => _streamController.stream;

  Map<String, dynamic> _entityToMap(TimelineEventEntity e) {
    return {
      'id': e.id,
      'date': Timestamp.fromDate(e.date),
      'title': e.title,
      'description': e.description,
      'icon': e.icon,
      'imageUrl': e.imageUrl,
      'localImagePath': e.localImagePath,
      'isActive': e.isActive,
      'orderIndex': e.orderIndex,
      'location': e.location,
      'tags': e.tags,
      'isDemo': e.isDemo,
      'createdAt': Timestamp.fromDate(e.createdAt),
      'updatedAt': Timestamp.fromDate(e.updatedAt),
    };
  }

  TimelineEventEntity _docToEntity(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final now = DateTime.now();
    return TimelineEventEntity(
      id: (data['id'] as String?) ?? doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? now,
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      icon: (data['icon'] as String?) ?? '💕',
      imageUrl: data['imageUrl'] as String?,
      localImagePath: data['localImagePath'] as String?,
      isActive: (data['isActive'] as bool?) ?? true,
      orderIndex: (data['orderIndex'] as num?)?.toInt() ?? 0,
      location: data['location'] as String?,
      tags: (data['tags'] as List?)?.cast<String>() ?? const [],
      isDemo: (data['isDemo'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? now,
    );
  }

  void dispose() {
    _firestoreSub?.cancel();
    _streamController.close();
  }
}
