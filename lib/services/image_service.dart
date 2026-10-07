import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// معلومات صورة مختارة
class PickedImageInfo {
  final File file;
  final int sizeBytes;
  final String name;
  final bool isCompressed;

  PickedImageInfo({
    required this.file,
    required this.sizeBytes,
    required this.name,
    this.isCompressed = false,
  });

  double get sizeKB => sizeBytes / 1024;
  double get sizeMB => sizeBytes / (1024 * 1024);

  String get sizeText => sizeMB >= 1
      ? '${sizeMB.toStringAsFixed(2)} MB'
      : '${sizeKB.toStringAsFixed(0)} KB';
}

class ImageService {
  static final _picker = ImagePicker();

  // ═══════ اختيار من المعرض ═══════
  static Future<PickedImageInfo?> pickFromGallery() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      return await _fromXFile(x);
    } catch (e) {
      debugPrint('pickFromGallery error: $e');
      return null;
    }
  }

  // ═══════ اختيار من الكاميرا ═══════
  static Future<PickedImageInfo?> pickFromCamera() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
      return await _fromXFile(x);
    } catch (e) {
      debugPrint('pickFromCamera error: $e');
      return null;
    }
  }

  static Future<PickedImageInfo?> _fromXFile(XFile? x) async {
    if (x == null) return null;
    final file = File(x.path);
    final size = await file.length();
    return PickedImageInfo(
      file: file,
      sizeBytes: size,
      name: x.name,
    );
  }

  // ═══════ ضغط الصورة ═══════
  static Future<PickedImageInfo> compress(
    PickedImageInfo original, {
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        original.file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result == null) return original;

      final file = File(result.path);
      final size = await file.length();

      debugPrint(
          '✅ Compressed: ${original.sizeText} → ${(size / 1024).toStringAsFixed(0)} KB');

      return PickedImageInfo(
        file: file,
        sizeBytes: size,
        name: original.name,
        isCompressed: true,
      );
    } catch (e) {
      debugPrint('compress error: $e');
      return original;
    }
  }

  // ═══════ الرفع إلى Supabase Storage ═══════
  static Future<String> upload(
    PickedImageInfo info, {
    String folder = 'banners',
  }) async {
    final client = SupabaseService.client;

    final ext = info.file.path.split('.').last.toLowerCase();
    final safeExt =
        ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext) ? ext : 'jpg';

    final fname =
        '${DateTime.now().millisecondsSinceEpoch}_${info.name.hashCode.abs()}.$safeExt';
    final path = '$folder/$fname';

    final bytes = await info.file.readAsBytes();

    debugPrint('📤 Uploading ${info.sizeText} → $path');

    await client.storage.from('banners').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '3600',
          ),
        );

    final publicUrl = client.storage.from('banners').getPublicUrl(path);
    debugPrint('✅ Uploaded: $publicUrl');
    return publicUrl;
  }

  // ═══════ حذف صورة من Storage ═══════
  static Future<void> delete(String publicUrl) async {
    try {
      final marker = '/object/public/banners/';
      final idx = publicUrl.indexOf(marker);
      if (idx == -1) return;
      final path = publicUrl.substring(idx + marker.length);

      await SupabaseService.client.storage.from('banners').remove([path]);
      debugPrint('🗑️ Deleted storage: $path');
    } catch (e) {
      debugPrint('delete error: $e');
    }
  }

  // ═══════ رفع صورة الأفاتار ═══════
  static Future<String> uploadAvatar(
    PickedImageInfo info,
    String userId,
  ) async {
    final client = SupabaseService.client;
    final ext = info.file.path.split('.').last.toLowerCase();
    final safeExt =
        ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';

    // المسار: avatars/{userId}/avatar.{ext}
    final path = '$userId/avatar.$safeExt';
    final bytes = await info.file.readAsBytes();

    debugPrint('📤 Uploading avatar ${info.sizeText} → $path');

    await client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '3600',
          ),
        );

    final publicUrl = client.storage.from('avatars').getPublicUrl(path);
    // إضافة timestamp لتجنب cache
    final url = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('✅ Avatar uploaded: $url');
    return url;
  }

  // ═══════ حذف الأفاتار ═══════
  static Future<void> deleteAvatar(String userId) async {
    try {
      final client = SupabaseService.client;
      // حذف كل الملفات داخل المجلد
      final files = await client.storage.from('avatars').list(path: userId);
      if (files.isEmpty) return;
      final paths = files.map((f) => '$userId/${f.name}').toList();
      await client.storage.from('avatars').remove(paths);
      debugPrint('🗑️ Avatar deleted');
    } catch (e) {
      debugPrint('deleteAvatar error: $e');
    }
  }
}
