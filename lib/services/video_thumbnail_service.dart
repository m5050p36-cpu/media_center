import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailService {
  /// توليد صورة مصغرة من الفيديو
  static Future<String?> generate(String videoPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final name = videoPath.hashCode.abs().toString();
      final cached = File('${dir.path}/thumb_$name.jpg');

      // إذا موجودة مسبقاً، استخدمها
      if (await cached.exists()) {
        return cached.path;
      }

      final path = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 320,
        quality: 75,
      );

      debugPrint('✅ Thumbnail: $path');
      return path;
    } catch (e) {
      debugPrint('⚠️ Thumbnail error: $e');
      return null;
    }
  }

  /// حذف كل الصور المصغرة المخزنة
  static Future<void> clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      await for (final f in dir.list()) {
        if (f is File && f.path.contains('thumb_')) {
          await f.delete();
        }
      }
      debugPrint('🗑️ Thumbnails cleared');
    } catch (e) {
      debugPrint('clearThumbnails error: $e');
    }
  }
}
