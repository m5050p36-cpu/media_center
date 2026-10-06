import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/banner_model.dart';
import '../supabase_config.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  /// الوصول للعميل عبر Supabase.instance
  static SupabaseClient get client => Supabase.instance.client;

  /// تهيئة supabase_flutter — يحفظ الجلسة تلقائياً
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
      );
      debugPrint('✅ Supabase initialized with persistent session');

      final user = client.auth.currentUser;
      if (user != null) {
        debugPrint('✅ Session restored for: ${user.email}');
      } else {
        debugPrint('ℹ️ No session — user is guest');
      }
    } catch (e, st) {
      debugPrint('❌ Supabase init failed: $e\n$st');
      rethrow;
    }
  }

  /// مسح الجلسة (اختياري)
  static Future<void> clearSavedSession() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('clearSavedSession error: $e');
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
