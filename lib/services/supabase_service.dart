import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/banner_model.dart';
import '../supabase_config.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  static SupabaseClient get client => Supabase.instance.client;
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// ⚡ تهيئة سريعة — تحفظ الجلسة محلياً تلقائياً
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
      _initialized = true;
      debugPrint('✅ Supabase initialized');

      final user = client.auth.currentUser;
      if (user != null) {
        debugPrint('✅ Offline session: ${user.email}');
      }
    } catch (e, st) {
      debugPrint('❌ Supabase init failed: $e\n$st');
      // لا نُعيد رمي الخطأ — التطبيق يعمل offline
    }
  }

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
          .order('display_order', ascending: true)
          .timeout(const Duration(seconds: 5));
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
