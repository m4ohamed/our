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
  StreamSubscription<List<TimelineEventEntity>>? _localSub;
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
    // الاستماع الدائم للكاش المحلي لضمان تحديث الواجهة فوراً عند أي إضافة أو تعديل محلي
    _localSub = _localCache.watchEvents().listen((localEvents) {
      if (!_streamController.isClosed) {
        _streamController.add(localEvents);
      }
    });

    if (_collection == null) return;

    _firestoreSub = _collection!
        .orderBy('date')
        .snapshots()
        .listen(
          (snapshot) async {
            try {
              // معالجة الحذف الفوري بين الهواتف المتصلة
              for (final change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.removed) {
                  await _localCache.deleteEvent(change.doc.id);
                }
              }

              final remoteEvents = snapshot.docs.map(_docToEntity).toList();
              // دمج البيانات السحابية مع الكاش المحلي مع الحفاظ على مسارات الصور المحلية الصالحة
              for (final remoteEvent in remoteEvents) {
                final existingRes = await _localCache.getEventById(
                  remoteEvent.id,
                );
                final existing = existingRes.getOrNull();
                final preservedLocalPath =
                    (existing?.localImagePath != null &&
                        File(existing!.localImagePath!).existsSync())
                    ? existing.localImagePath
                    : remoteEvent.localImagePath;

                await _localCache.saveEvent(
                  remoteEvent.copyWith(localImagePath: preservedLocalPath),
                );
              }

              final merged = await _localCache.getAllEvents();
              if (merged.isSuccess && !_streamController.isClosed) {
                _streamController.add(merged.data);
              }
            } catch (_) {}
          },
          onError: (_) async {
            // في حال رفض صلاحيات Firestore (permission-denied) أو انقطاع الإنترنت، نعتمد على الكاش المحلي
            final cached = await _localCache.getAllEvents();
            if (cached.isSuccess && !_streamController.isClosed) {
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
          try {
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
          } catch (_) {}
        }

        if (needsPush) {
          await _collection!.doc(eventToPush.id).set(
            _entityToMap(eventToPush),
            SetOptions(merge: true),
          );
        }
      }
    } catch (_) {
      // تجاهل أخطاء الصلاحيات أو الشبكة بهدوء دون تعطيل التطبيق
    }
  }

  @override
  Future<Result<List<TimelineEventEntity>>> getAllEvents() async {
    // 1. نضمن دائماً تهيئة الكاش المحلي (والبيانات التجريبية إن كانت مفعلة) أولاً
    final localInitial = await _localCache.getAllEvents();
    if (_collection == null) {
      return localInitial;
    }

    try {
      // 2. محاولة دفع العناصر المحلية المعلقة للسحابة
      await syncPendingToCloud();

      final snapshot = await _collection!.orderBy('date').get();
      if (snapshot.docs.isNotEmpty) {
        final remoteEvents = snapshot.docs.map(_docToEntity).toList();
        for (final remoteEvent in remoteEvents) {
          final existingRes = await _localCache.getEventById(remoteEvent.id);
          final existing = existingRes.getOrNull();
          final preservedLocalPath =
              (existing?.localImagePath != null &&
                  File(existing!.localImagePath!).existsSync())
              ? existing.localImagePath
              : remoteEvent.localImagePath;

          await _localCache.saveEvent(
            remoteEvent.copyWith(localImagePath: preservedLocalPath),
          );
        }
      }

      return await _localCache.getAllEvents();
    } catch (_) {
      return localInitial;
    }
  }

  @override
  Future<Result<TimelineEventEntity?>> getEventById(String id) async {
    if (_collection == null) return _localCache.getEventById(id);

    try {
      final doc = await _collection!.doc(id).get();
      if (!doc.exists || doc.data() == null) {
        return await _localCache.getEventById(id);
      }
      return Success(_docToEntity(doc));
    } catch (_) {
      return await _localCache.getEventById(id);
    }
  }

  @override
  Future<Result<TimelineEventEntity>> saveEvent(
    TimelineEventEntity event,
  ) async {
    try {
      var eventToSave = event;

      // محاولة رفع الصورة إلى Cloudinary إن كان مضبوطاً، مع عدم تعطيل الحفظ المحلي عند فشل الرفع
      if (event.localImagePath != null &&
          File(event.localImagePath!).existsSync() &&
          _cloudinary.isConfigured) {
        try {
          final uploadResult = await _cloudinary.uploadImage(
            File(event.localImagePath!),
          );
          if (uploadResult.isSuccess) {
            eventToSave = event.copyWith(
              imageUrl: uploadResult.data.secureUrl,
            );
          }
        } catch (_) {}
      }

      // 1. حفظ في الكاش المحلي (Hive) فوراً — هذا يضمن عدم ضياع الذكرى أبداً
      final localSaved = await _localCache.saveEvent(eventToSave);
      final finalEvent = localSaved.getOrElse(eventToSave);

      // 2. محاولة المزامنة مع Cloud Firestore بشكل معزول حتى لا ينهار التطبيق عند خطأ permission-denied
      if (_collection != null) {
        try {
          await _collection!.doc(finalEvent.id).set(
            _entityToMap(finalEvent),
            SetOptions(merge: true),
          );
        } catch (_) {
          // في حال رفض صلاحيات Firestore أو انقطاع الإنترنت، تظل الذكرى محفوظة محلياً وتُزامن لاحقاً
        }
      }

      return Success(finalEvent);
    } catch (e) {
      return Failure(StorageException('فشل حفظ الحدث محلياً: $e'));
    }
  }

  @override
  Future<Result<void>> deleteEvent(String id) async {
    try {
      await _localCache.deleteEvent(id);
      if (_collection != null) {
        try {
          await _collection!.doc(id).delete();
        } catch (_) {}
      }
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل حذف الحدث: $e'));
    }
  }

  @override
  Future<Result<void>> deleteAllEvents() async {
    try {
      await _localCache.deleteAllEvents();
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
      return Failure(StorageException('فشل مسح الأحداث: $e'));
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
    _localSub?.cancel();
    _streamController.close();
  }
}