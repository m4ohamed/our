// lib/data/repositories/hive_media_repository.dart
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../mappers/media_mapper.dart';
import '../models/media_file_hive_model.dart';
import '../seeds/demo_media_seed.dart';

class HiveMediaRepository implements MediaRepository {
  final Box<MediaFileHiveModel> _box;
  final SharedPreferences _prefs;
  final _streamController = StreamController<List<MediaFileEntity>>.broadcast();

  HiveMediaRepository(this._box, this._prefs) {
    _box.watch().listen((_) => _emit());
  }

  void _emit() {
    final media = _box.values.map((m) => m.toEntity()).toList()
      ..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    _streamController.add(media);
  }

  @override
  Future<Result<List<MediaFileEntity>>> getAllMedia() async {
    try {
      await _seedIfNeeded();
      final media = _box.values.map((m) => m.toEntity()).toList()
        ..sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      return Success(media);
    } catch (e) {
      return Failure(StorageException('فشل تحميل ألبوم الذكريات: $e'));
    }
  }

  @override
  Future<Result<MediaFileEntity?>> getMediaById(String id) async {
    try {
      final model = _box.get(id);
      return Success(model?.toEntity());
    } catch (e) {
      return Failure(StorageException('فشل جلب الذكرى: $e'));
    }
  }

  @override
  Future<Result<MediaFileEntity>> saveMedia(MediaFileEntity media) async {
    try {
      await _box.put(media.id, media.toHiveModel());
      return Success(media);
    } catch (e) {
      return Failure(StorageException('فشل حفظ الصورة: $e'));
    }
  }

  @override
  Future<Result<void>> deleteMedia(String id) async {
    try {
      if (id.startsWith('demo_')) {
        await _prefs.setBool(AppConstants.keyDemoMediaSeeded, true);
      }
      await _box.delete(id);
      await _prefs.setBool(AppConstants.keyDemoMediaSeeded, true);
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل حذف الصورة: $e'));
    }
  }

  @override
  Future<Result<void>> deleteAllMedia() async {
    try {
      await _box.clear();
      await _prefs.setBool(AppConstants.keyDemoMediaSeeded, true);
      await _prefs.setBool(AppConstants.keyEnableDemoData, false);
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('فشل مسح ألبوم الذكريات: $e'));
    }
  }

  @override
  Future<Result<List<MediaFileEntity>>> getMediaByEventId(
    String eventId,
  ) async {
    try {
      final media = _box.values
          .where((m) => m.eventId == eventId)
          .map((m) => m.toEntity())
          .toList();
      return Success(media);
    } catch (e) {
      return Failure(StorageException('فشل جلب وسائط الحدث: $e'));
    }
  }

  @override
  Stream<List<MediaFileEntity>> watchMedia() => _streamController.stream;

  Future<void> _seedIfNeeded() async {
    final enableDemoData =
        _prefs.getBool(AppConstants.keyEnableDemoData) ?? true;
    if (!enableDemoData) {
      final demoKeys = _box.values
          .where((m) => m.id.startsWith('demo_'))
          .map((m) => m.id)
          .toList();
      if (demoKeys.isNotEmpty) {
        await _box.deleteAll(demoKeys);
      }
      return;
    }

    final alreadySeeded =
        _prefs.getBool(AppConstants.keyDemoMediaSeeded) ?? false;
    if (alreadySeeded) return;

    if (_box.isEmpty) {
      for (final item in DemoMediaSeed.items) {
        await _box.put(item.id, item.toHiveModel());
      }
    }
    await _prefs.setBool(AppConstants.keyDemoMediaSeeded, true);
  }

  void dispose() {
    _streamController.close();
  }
}
