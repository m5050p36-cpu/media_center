import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import '../models/banner_model.dart';
import '../supabase_config.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  static const _sessionKey = 'supabase_session_v2';
  static SupabaseClient? _client;

  static SupabaseClient get client {
    final c = _client;
    if (c == null) {
      throw StateError('SupabaseService not initialized');
    }
    return c;
  }

  static Future<void> initialize() async {
    try {
      _client = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.supabaseAnonKey,
      );
      debugPrint('✅ Supabase client created');

      await _restoreSession();

      _client!.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        debugPrint('🔔 Auth event: $event');

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession) {
          _saveSession(data.session);
        } else if (event == AuthChangeEvent.signedOut) {
          _clearSession();
        }
      });
    } catch (e, st) {
      debugPrint('❌ Supabase init failed: $e\n$st');
      rethrow;
    }
  }

  static Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null || raw.isEmpty) {
        debugPrint('ℹ️ No saved session found');
        return;
      }
      debugPrint('📥 Restoring session (${raw.length} chars)...');
      await _client!.auth.recoverSession(raw);
      debugPrint('✅ Session restored: user=${_client!.auth.currentUser?.email}');
    } catch (e) {
      debugPrint('⚠️ Failed to restore session: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_sessionKey);
      } catch (_) {}
    }
  }

  static Future<void> _saveSession(Session? session) async {
    if (session == null) {
      debugPrint('ℹ️ No session to save');
      return;
    }
    try {
      final jsonStr = jsonEncode(session.toJson());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonStr);
      debugPrint('💾 Session saved (${jsonStr.length} chars)');
    } catch (e) {
      debugPrint('⚠️ Failed to save session: $e');
    }
  }

  static Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      debugPrint('🗑️ Session cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear session: $e');
    }
  }

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
