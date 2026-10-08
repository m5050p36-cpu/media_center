import 'dart:convert';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtPath': albumArtPath,
        'duration': duration?.inMilliseconds,
      };

  factory TrackMetadata.fromJson(Map<String, dynamic> json) => TrackMetadata(
        title: json['title'] as String?,
        artist: json['artist'] as String?,
        album: json['album'] as String?,
        albumArtPath: json['albumArtPath'] as String?,
        duration: json['duration'] != null
            ? Duration(milliseconds: json['duration'] as int)
            : null,
      );
}

class MetadataService {
  static const _cacheKey = 'metadata_cache_v1';

  static final Map<String, TrackMetadata> _memoryCache = {};
  static bool _loadedFromDisk = false;
  static int _writeCounter = 0;

  /// ⚡ تحميل كل الكاش من القرص مرة واحدة
  static Future<void> _loadFromDisk() async {
    if (_loadedFromDisk) return;
    _loadedFromDisk = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        try {
          _memoryCache[entry.key] =
              TrackMetadata.fromJson(entry.value as Map<String, dynamic>);
        } catch (_) {}
      }
      debugPrint('✅ Loaded ${_memoryCache.length} metadata from cache');
    } catch (e) {
      debugPrint('⚠️ Load metadata cache error: $e');
    }
  }

  /// 💾 حفظ الكاش (كل 20 قراءة)
  static Future<void> _saveToDisk({bool force = false}) async {
    _writeCounter++;
    if (!force && _writeCounter < 20) return;
    _writeCounter = 0;

    try {
      final map = <String, dynamic>{};
      _memoryCache.forEach((k, v) => map[k] = v.toJson());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(map));
      debugPrint('💾 Saved ${_memoryCache.length} metadata to disk');
    } catch (e) {
      debugPrint('⚠️ Save metadata cache error: $e');
    }
  }

  /// قراءة بيانات ملف واحد (مع cache)
  static Future<TrackMetadata> read(String filePath) async {
    await _loadFromDisk();

    // 1) من الكاش
    if (_memoryCache.containsKey(filePath)) {
      return _memoryCache[filePath]!;
    }

    // 2) قراءة حقيقية
    try {
      final file = File(filePath);
      if (!await file.exists()) return const TrackMetadata();

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

      _memoryCache[filePath] = result;
      _saveToDisk(); // غير متزامن
      return result;
    } catch (e) {
      debugPrint('⚠️ Metadata read error for $filePath: $e');
      final empty = const TrackMetadata();
      _memoryCache[filePath] = empty;
      return empty;
    }
  }

  /// ⚡ قراءة قائمة كاملة **بالتوازي** (5 بالتوازي)
  static Future<Map<String, TrackMetadata>> readBatch(
    List<String> paths, {
    int concurrency = 5,
    Function(int done, int total)? onProgress,
  }) async {
    await _loadFromDisk();

    // أولاً: رجّع الموجود في الكاش فوراً
    final results = <String, TrackMetadata>{};
    final needRead = <String>[];

    for (final path in paths) {
      final cached = _memoryCache[path];
      if (cached != null) {
        results[path] = cached;
      } else {
        needRead.add(path);
      }
    }

    if (needRead.isEmpty) {
      debugPrint('⚡ All ${paths.length} metadata from cache!');
      return results;
    }

    debugPrint('📖 Reading ${needRead.length} of ${paths.length} metadata...');

    int done = 0;
    final total = needRead.length;

    // تحميل متوازي
    for (var i = 0; i < needRead.length; i += concurrency) {
      final end = (i + concurrency).clamp(0, needRead.length);
      final batch = needRead.sublist(i, end);

      final batchResults = await Future.wait(
        batch.map((p) => read(p)),
      );

      for (var j = 0; j < batch.length; j++) {
        results[batch[j]] = batchResults[j];
      }

      done += batch.length;
      onProgress?.call(done, total);
    }

    // احفظ الكاش نهائياً
    await _saveToDisk(force: true);

    return results;
  }

  /// قراءة سريعة من الكاش (بدون قرص)
  static TrackMetadata? getCached(String filePath) => _memoryCache[filePath];

  static String? getCachedArt(String filePath) =>
      _memoryCache[filePath]?.albumArtPath;

  /// حفظ صورة الغلاف
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

      if (await file.exists()) return file.path;

      await file.writeAsBytes(bytes, flush: false);
      return file.path;
    } catch (e) {
      debugPrint('⚠️ Save art error: $e');
      return null;
    }
  }

  static String _detectImageType(List<int> bytes) {
    if (bytes.length < 4) return 'jpg';
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) return 'png';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    if (bytes.length > 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42) {
      return 'webp';
    }
    return 'jpg';
  }

  static Future<void> clearCache() async {
    _memoryCache.clear();
    _loadedFromDisk = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      final dir = await getTemporaryDirectory();
      final artDir = Directory('${dir.path}/album_art');
      if (await artDir.exists()) await artDir.delete(recursive: true);
    } catch (_) {}
  }
}
