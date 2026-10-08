import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailService {
  static const _cacheKey = 'video_thumbs_v1';
  static final Map<String, String> _memoryCache = {};
  static bool _loaded = false;
  static int _writeCounter = 0;

  static Future<void> _loadCache() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((k, v) => _memoryCache[k] = v as String);
      debugPrint('✅ Loaded ${_memoryCache.length} thumbs from cache');
    } catch (e) {
      debugPrint('⚠️ Load thumbs error: $e');
    }
  }

  static Future<void> _saveCache({bool force = false}) async {
    _writeCounter++;
    if (!force && _writeCounter < 10) return;
    _writeCounter = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_memoryCache));
    } catch (_) {}
  }

  static String? getCached(String videoPath) => _memoryCache[videoPath];

  static Future<String?> generate(String videoPath) async {
    await _loadCache();

    // ⚡ من الكاش
    final cached = _memoryCache[videoPath];
    if (cached != null) {
      final f = File(cached);
      if (await f.exists()) return cached;
      // حذف مرجع تالف
      _memoryCache.remove(videoPath);
    }

    // قراءة جديدة
    try {
      final dir = await getTemporaryDirectory();
      final thumbDir = Directory('${dir.path}/video_thumbs');
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);

      final name = videoPath.hashCode.abs().toString();
      final target = '${thumbDir.path}/vt_$name.jpg';

      if (await File(target).exists()) {
        _memoryCache[videoPath] = target;
        return target;
      }

      final path = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 70,
      );

      if (path != null) {
        _memoryCache[videoPath] = path;
        _saveCache();
      }
      return path;
    } catch (e) {
      debugPrint('⚠️ Thumbnail error: $e');
      return null;
    }
  }

  /// ⚡ توليد متوازي
  static Future<void> generateBatch(
    List<String> paths, {
    int concurrency = 4,
    Function(int done, int total)? onProgress,
  }) async {
    await _loadCache();

    final need = paths.where((p) => !_memoryCache.containsKey(p)).toList();
    if (need.isEmpty) return;

    int done = 0;
    for (var i = 0; i < need.length; i += concurrency) {
      final end = (i + concurrency).clamp(0, need.length);
      final batch = need.sublist(i, end);
      await Future.wait(batch.map(generate));
      done += batch.length;
      onProgress?.call(done, need.length);
    }
    await _saveCache(force: true);
  }

  static Future<void> clearCache() async {
    _memoryCache.clear();
    _loaded = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      final dir = await getTemporaryDirectory();
      final thumbDir = Directory('${dir.path}/video_thumbs');
      if (await thumbDir.exists()) await thumbDir.delete(recursive: true);
    } catch (_) {}
  }
}
