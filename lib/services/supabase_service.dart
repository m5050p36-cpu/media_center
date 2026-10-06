import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import '../models/banner_model.dart';
import '../supabase_config.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  /// مفتاح تخزين refresh token
  static const _refreshTokenKey = 'sb_refresh_token_v4';
  static SupabaseClient? _client;

  static SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw StateError('SupabaseService not initialized');
    }
    return c;
  }

  /// تهيئة العميل + استعادة الجلسة + مراقبة تغييرات المصادقة
  static Future<void> initialize() async {
    try {
      _client = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.supabaseAnonKey,
      );
      debugPrint('✅ Supabase client created');

      // ═══ 1) استعادة الجلسة المحفوظة ═══
      await _restoreSession();

      // ═══ 2) مراقبة تغييرات المصادقة ═══
      _client!.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;
        debugPrint('🔔 Auth event: $event');

        if (session != null) {
          if (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.initialSession) {
            _saveSession(session);
          }
        } else {
          if (event == AuthChangeEvent.signedOut) {
            _clearSession();
          }
        }
      });
    } catch (e, st) {
      debugPrint('❌ Supabase init failed: $e\n$st');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════
  // استعادة الجلسة عبر refresh_token
  // ═══════════════════════════════════════════════════
  static Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('ℹ️ No saved refresh token — user is guest');
        return;
      }

      debugPrint('📥 Restoring session (token: ${refreshToken.substring(0, 10)}...)...');

      await _client!.auth.setSession(refreshToken);

      final user = _client!.auth.currentUser;
      if (user != null) {
        debugPrint('✅ Session restored: user=${user.email}');
      } else {
        debugPrint('⚠️ setSession succeeded but user is null');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to restore session: $e');
      // احذف التوكن التالف
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_refreshTokenKey);
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════════════
  // حفظ refresh_token عند تسجيل الدخول
  // ═══════════════════════════════════════════════════
  static Future<void> _saveSession(Session session) async {
    try {
      final refreshToken = session.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('⚠️ No refresh token in session');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_refreshTokenKey, refreshToken);
      debugPrint('💾 Session saved (refresh token)');
    } catch (e) {
      debugPrint('⚠️ Failed to save session: $e');
    }
  }

  // ═══════════════════════════════════════════════════
  // مسح الجلسة عند الخروج
  // ═══════════════════════════════════════════════════
  static Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_refreshTokenKey);
      debugPrint('🗑️ Session cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear session: $e');
    }
  }

  /// مسح يدوي (يُستدعى من signOut)
  static Future<void> clearSavedSession() async {
    await _clearSession();
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
