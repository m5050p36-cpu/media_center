import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TrackMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtPath;
  final Duration? duration;

  const TrackMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArtPath,
    this.duration,
  });
}

class MetadataService {
  static final Map<String, TrackMetadata> _cache = {};
  static final Map<String, String?> _artCache = {};

  /// قراءة كل البيانات الوصفية + حفظ صورة الغلاف
  static Future<TrackMetadata> read(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath]!;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const TrackMetadata();
      }

      final metadata = readMetadata(file, getImage: true);

      String? artPath;
      if (metadata.pictures.isNotEmpty) {
        final pic = metadata.pictures.first;
        artPath = await _saveAlbumArt(pic.bytes, filePath);
      }

      final result = TrackMetadata(
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        albumArtPath: artPath,
        duration: metadata.duration,
      );

      _cache[filePath] = result;
      _artCache[filePath] = artPath;
      return result;
    } catch (e) {
      debugPrint('⚠️ Metadata read error for $filePath: $e');
      return const TrackMetadata();
    }
  }

  /// قراءة سريعة للصورة فقط (من الكاش)
  static String? getCachedArt(String filePath) => _artCache[filePath];

  /// حفظ صورة الغلاف في الذاكرة المؤقتة
  static Future<String?> _saveAlbumArt(
    List<int> bytes,
    String trackPath,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final artDir = Directory('${dir.path}/album_art');
      if (!await artDir.exists()) await artDir.create(recursive: true);

      final hash = trackPath.hashCode.abs();
      final ext = _detectImageType(bytes);
      final file = File('${artDir.path}/art_$hash.$ext');

      // إذا موجودة، لا تعد الكتابة
      if (await file.exists()) return file.path;

      await file.writeAsBytes(bytes);
      debugPrint('✅ Album art saved: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('⚠️ Save art error: $e');
      return null;
    }
  }

  /// تحديد نوع الصورة من البايتات
  static String _detectImageType(List<int> bytes) {
    if (bytes.length < 4) return 'jpg';
    // PNG magic: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) {
      return 'png';
    }
    // JPEG magic: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'jpg';
    }
    // WebP
    if (bytes.length > 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42) {
      return 'webp';
    }
    return 'jpg';
  }

  /// مسح الكاش
  static Future<void> clearCache() async {
    _cache.clear();
    _artCache.clear();
    try {
      final dir = await getTemporaryDirectory();
      final artDir = Directory('${dir.path}/album_art');
      if (await artDir.exists()) {
        await artDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
