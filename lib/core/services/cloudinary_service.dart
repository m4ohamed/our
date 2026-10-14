// lib/core/services/cloudinary_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../errors/app_exception.dart';

class CloudinaryUploadResult {
  final String secureUrl;
  final String thumbnailUrl;
  final String publicId;
  final int? bytes;
  final double aspectRatio;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.thumbnailUrl,
    required this.publicId,
    this.bytes,
    this.aspectRatio = 1.0,
  });
}

class CloudinaryService {
  final SharedPreferences _prefs;

  CloudinaryService(this._prefs);

  String get cloudName {
    final saved = _prefs.getString(AppConstants.keyCloudinaryCloudName)?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    return AppConstants.defaultCloudinaryCloudName;
  }

  String get uploadPreset {
    final saved = _prefs
        .getString(AppConstants.keyCloudinaryUploadPreset)
        ?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    return AppConstants.defaultCloudinaryUploadPreset;
  }

  bool get isConfigured => cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  Future<void> saveConfig({
    required String cloudName,
    required String uploadPreset,
  }) async {
    await _prefs.setString(
      AppConstants.keyCloudinaryCloudName,
      cloudName.trim(),
    );
    await _prefs.setString(
      AppConstants.keyCloudinaryUploadPreset,
      uploadPreset.trim(),
    );
  }

  /// رفع صورة مباشرة إلى Cloudinary باستخدام Unsigned Upload Preset
  Future<Result<CloudinaryUploadResult>> uploadImage(File file) async {
    return _uploadFile(file, resourceType: 'image');
  }

  /// رفع ملف فيديو مباشرة إلى Cloudinary باستخدام Unsigned Upload Preset
  Future<Result<CloudinaryUploadResult>> uploadVideo(File file) async {
    return _uploadFile(file, resourceType: 'video');
  }

  Future<Result<CloudinaryUploadResult>> _uploadFile(
    File file, {
    required String resourceType,
  }) async {
    if (!isConfigured) {
      return const Failure(
        MediaException(
          'لم يتم ضبط إعدادات Cloudinary بعد (Cloud Name / Upload Preset)',
        ),
      );
    }

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = AppConstants.cloudinaryFolder
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        return Failure(
          MediaException('فشل رفع الملف إلى Cloudinary: ${response.body}'),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = data['secure_url'] as String;
      final publicId = data['public_id'] as String? ?? '';
      final bytes = data['bytes'] as int?;
      final width = (data['width'] as num?)?.toDouble() ?? 1.0;
      final height = (data['height'] as num?)?.toDouble() ?? 1.0;
      final aspectRatio = height > 0 ? width / height : 1.0;

      final thumbnailUrl = resourceType == 'video'
          ? secureUrl
                .replaceFirst('/upload/', '/upload/so_0,c_fill,w_500,q_auto/')
                .replaceAll(RegExp(r'\.(mp4|avi|mov)$'), '.jpg')
          : secureUrl.replaceFirst(
              '/upload/',
              '/upload/c_fill,w_500,q_auto,f_auto/',
            );

      return Success(
        CloudinaryUploadResult(
          secureUrl: secureUrl,
          thumbnailUrl: thumbnailUrl,
          publicId: publicId,
          bytes: bytes,
          aspectRatio: aspectRatio,
        ),
      );
    } catch (e) {
      return Failure(NetworkException('خطأ في الاتصال بـ Cloudinary: $e'));
    }
  }
}
