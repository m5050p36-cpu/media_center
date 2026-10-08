import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'supabase_service.dart';

class AuthService {
  static SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isGuest => _client.auth.currentUser == null;

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    final res = await _client.auth
        .signInWithPassword(email: email.trim(), password: password)
        .timeout(const Duration(seconds: 15));
    debugPrint('✅ SignIn: ${res.user?.email}');
    return res;
  }

  Future<AuthResponse> signUpWithEmail(
      String email, String password, String fullName) async {
    final res = await _client.auth
        .signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': fullName.trim()},
        )
        .timeout(const Duration(seconds: 15));
    debugPrint('✅ SignUp: ${res.user?.email}');
    return res;
  }

  Future<void> resetPassword(String email) async {
    await _client.auth
        .resetPasswordForEmail(email.trim())
        .timeout(const Duration(seconds: 15));
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('signOut error: $e');
    }
  }

  Future<ProfileModel?> fetchProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (data != null) return ProfileModel.fromMap(data);

      // إنشاء profile تلقائياً
      final fallbackName = (user.userMetadata?['full_name'] as String?) ??
          (user.email ?? '').split('@').first;

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
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (created != null) return ProfileModel.fromMap(created);
      return null;
    } catch (e) {
      debugPrint('fetchProfile error: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('لا يوجد مستخدم مسجل');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (fullName != null) updates['full_name'] = fullName.trim();
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await _client
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .timeout(const Duration(seconds: 10));

    try {
      await _client.auth
          .updateUser(
            UserAttributes(data: {
              if (fullName != null) 'full_name': fullName.trim(),
              if (avatarUrl != null) 'avatar_url': avatarUrl,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('update metadata error: $e');
    }
  }
}
