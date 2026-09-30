import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const _audioKey = 'cached_audio_files_v1';
  static const _videoKey = 'cached_video_files_v1';
  static const _lastScanKey = 'last_scan_timestamp_v1';
  static const _cacheDurationHours = 6;

  /// هل مرّ وقت كافٍ لإعادة الفحص؟
  static Future<bool> shouldRescan() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastScanKey);
    if (last == null) return true;
    final age = DateTime.now().millisecondsSinceEpoch - last;
    return age > Duration(hours: _cacheDurationHours).inMilliseconds;
  }

  /// حفظ قائمة الصوتيات
  static Future<void> saveAudioFiles(List<Map<String, dynamic>> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioKey, jsonEncode(files));
    await prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// استرجاع قائمة الصوتيات
  static Future<List<Map<String, dynamic>>> loadAudioFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_audioKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// حفظ قائمة الفيديوهات
  static Future<void> saveVideoFiles(List<Map<String, dynamic>> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_videoKey, jsonEncode(files));
  }

  /// استرجاع قائمة الفيديوهات
  static Future<List<Map<String, dynamic>>> loadVideoFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_videoKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// مسح كل شيء
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_audioKey);
    await prefs.remove(_videoKey);
    await prefs.remove(_lastScanKey);
  }
}
