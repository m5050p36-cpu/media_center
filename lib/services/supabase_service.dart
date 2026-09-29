import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';
import '../models/banner_model.dart';
import '../supabase_config.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  static SupabaseClient? _client;

  static SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw StateError('SupabaseService not initialized. Call initialize() first.');
    }
    return c;
  }

  /// يجب استدعاؤها في main() قبل أي استخدام
  static Future<void> initialize() async {
    try {
      _client = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.supabaseAnonKey,
      );
      debugPrint('✅ Supabase initialized: ${SupabaseConfig.supabaseUrl}');
    } catch (e, st) {
      debugPrint('❌ Supabase init failed: $e\n$st');
      rethrow;
    }
  }

  // ══════ Banners ══════
  Future<List<BannerModel>> fetchActiveBanners() async {
    try {
      final data = await client
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);
      return (data as List).map((e) => BannerModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('fetchActiveBanners error: $e');
      return [];
    }
  }

  Future<void> addBanner(BannerModel banner) async {
    await client.from('banners').insert(banner.toMap());
  }

  Future<void> updateBanner(String id, Map<String, dynamic> updates) async {
    await client.from('banners').update(updates).eq('id', id);
  }

  Future<void> deleteBanner(String id) async {
    await client.from('banners').delete().eq('id', id);
  }
}
