import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'supabase_service.dart';

class AuthService {
  static SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isGuest => _client.auth.currentUser == null;

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

  Future<AuthResponse> signUpWithEmail(
      String email, String password, String fullName) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      debugPrint('✅ SignUp: ${res.user?.email}');
      return res;
    } catch (e) {
      debugPrint('❌ signUp error: $e');
      rethrow;
    }
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
