import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import '../models/profile_model.dart';
import '../supabase_config.dart';
import 'supabase_service.dart';

class AuthService {
  static SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isGuest => _client.auth.currentUser == null;

  // ═══════════════════════════════════════════════════
  // تسجيل الدخول — عبر SDK (يعمل)
  // ═══════════════════════════════════════════════════
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('✅ SignIn: ${res.user?.email}');
      return res;
    } catch (e) {
      debugPrint('❌ signIn error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════
  // إنشاء حساب — عبر REST مباشر (يتجاوز bug في SDK)
  // ═══════════════════════════════════════════════════
  Future<AuthResponse> signUpWithEmail(
      String email, String password, String fullName) async {
    final cleanEmail = email.trim();
    final cleanName = fullName.trim();

    // ─── 1) إرسال طلب REST مباشر ───
    final uri = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1/signup');

    debugPrint('📤 POST $uri');

    final httpRes = await http.post(
      uri,
      headers: {
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': cleanEmail,
        'password': password,
        'data': {'full_name': cleanName},
      }),
    );

    debugPrint('📥 Status: ${httpRes.statusCode}');
    debugPrint('📥 Body: ${httpRes.body}');

    // ─── 2) فحص الأخطاء ───
    if (httpRes.statusCode >= 400) {
      throw AuthException(_parseError(httpRes.body));
    }

    // ─── 3) تحليل الرد ───
    final body = jsonDecode(httpRes.body) as Map<String, dynamic>;

    // ─── 4) إذا رجع access_token (Confirm email معطّل) ───
    if (body['access_token'] != null) {
      debugPrint('✅ Session returned — signing in via SDK');
      try {
        return await _client.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );
      } catch (e) {
        debugPrint('signIn after signup failed: $e');
        // إذا فشل الدخول بعد التسجيل، أعد AuthResponse مع user فقط
        final userJson = body['user'] as Map<String, dynamic>?;
        if (userJson != null) {
          return AuthResponse(
            user: User.fromJson(userJson),
            session: null,
          );
        }
        rethrow;
      }
    }

    // ─── 5) إذا رجع user فقط (يحتاج تأكيد) ───
    final userJson = body['user'] as Map<String, dynamic>?;
    if (userJson != null) {
      debugPrint('⚠️ User created — needs email confirmation');
      return AuthResponse(
        user: User.fromJson(userJson),
        session: null,
      );
    }

    // ─── 6) الرد غير متوقع ───
    throw AuthException('رد غير متوقع من Supabase: ${httpRes.body}');
  }

  /// استخراج رسالة الخطأ من رد REST
  String _parseError(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map) {
        return parsed['msg']?.toString() ??
            parsed['message']?.toString() ??
            parsed['error_description']?.toString() ??
            parsed['error']?.toString() ??
            'فشل التسجيل';
      }
    } catch (_) {}
    return body.isNotEmpty ? body : 'فشل التسجيل';
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      debugPrint('resetPassword error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('signOut error: $e');
    }
  }

  /// جلب profile (مع إنشاء تلقائي)
  Future<ProfileModel?> fetchProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) return ProfileModel.fromMap(data);

      debugPrint('⚠️ No profile — creating for ${user.email}');
      final fallbackName = (user.userMetadata?['full_name'] as String?) ??
          (user.email ?? '').split('@').first;

      try {
        await _client.from('profiles').insert(<String, dynamic>{
          'id': user.id,
          'email': user.email ?? '',
          'full_name': fallbackName,
          'role': 'user',
        });
        final created = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (created != null) return ProfileModel.fromMap(created);
      } catch (e) {
        debugPrint('insert profile error: $e');
        return ProfileModel(
          id: user.id,
          email: user.email,
          fullName: fallbackName,
          role: 'user',
        );
      }
      return null;
    } catch (e) {
      debugPrint('fetchProfile error: $e');
      return null;
    }
  }
}
