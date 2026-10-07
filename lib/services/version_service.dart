import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class AppVersionInfo {
  final int versionCode;
  final String versionName;
  final bool isActive;
  final bool forceUpdate;
  final String? downloadUrl;
  final String? releaseNotes;

  AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.isActive,
    required this.forceUpdate,
    this.downloadUrl,
    this.releaseNotes,
  });

  factory AppVersionInfo.fromMap(Map<String, dynamic> m) => AppVersionInfo(
        versionCode: m['version_code'] as int,
        versionName: m['version_name'] as String,
        isActive: m['is_active'] as bool? ?? true,
        forceUpdate: m['force_update'] as bool? ?? false,
        downloadUrl: m['download_url'] as String?,
        releaseNotes: m['release_notes'] as String?,
      );
}

class VersionService {
  /// أحدث إصدار متاح
  static Future<AppVersionInfo?> fetchLatest() async {
    try {
      final data = await SupabaseService.client
          .from('app_versions')
          .select()
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return AppVersionInfo.fromMap(data);
    } catch (e) {
      debugPrint('fetchLatest version error: $e');
      return null;
    }
  }

  /// الإصدار الموصى به (الأعلى مع is_active = true)
  static Future<AppVersionInfo?> fetchRecommended() async {
    try {
      final data = await SupabaseService.client
          .from('app_versions')
          .select()
          .eq('is_active', true)
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return AppVersionInfo.fromMap(data);
    } catch (e) {
      debugPrint('fetchRecommended error: $e');
      return null;
    }
  }

  /// كل الإصدارات
  static Future<List<AppVersionInfo>> fetchAll() async {
    try {
      final data = await SupabaseService.client
          .from('app_versions')
          .select()
          .order('version_code', ascending: false);
      return (data as List).map((e) => AppVersionInfo.fromMap(e)).toList();
    } catch (e) {
      debugPrint('fetchAll versions error: $e');
      return [];
    }
  }

  /// إضافة إصدار جديد
  static Future<void> addVersion({
    required int versionCode,
    required String versionName,
    bool isActive = true,
    bool forceUpdate = false,
    String? downloadUrl,
    String? releaseNotes,
  }) async {
    await SupabaseService.client.from('app_versions').insert({
      'version_code': versionCode,
      'version_name': versionName,
      'is_active': isActive,
      'force_update': forceUpdate,
      'download_url': downloadUrl,
      'release_notes': releaseNotes,
    });
  }

  /// تعطيل إصدار
  static Future<void> deactivate(int versionCode) async {
    await SupabaseService.client
        .from('app_versions')
        .update({'is_active': false})
        .eq('version_code', versionCode);
  }

  /// تفعيل إصدار
  static Future<void> activate(int versionCode) async {
    await SupabaseService.client
        .from('app_versions')
        .update({'is_active': true})
        .eq('version_code', versionCode);
  }

  /// حذف إصدار
  static Future<void> delete(int versionCode) async {
    await SupabaseService.client
        .from('app_versions')
        .delete()
        .eq('version_code', versionCode);
  }
}
