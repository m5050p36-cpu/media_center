import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';
import '../models/profile_model.dart';
import 'supabase_service.dart';

class AuthService {
  static SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isGuest => _client.auth.currentUser == null;

  /// تسجيل الدخول بالبريد وكلمة المرور
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      debugPrint('signIn error: $e');
      rethrow;
    }
  }

  /// إنشاء حساب جديد
  /// ملاحظة: إذا كان "Confirm email" مفعّلاً، قد يعيد session = null
  /// لكن العملية تكون ناجحة.
  Future<AuthResponse> signUpWithEmail(
      String email, String password, String fullName) async {
    try {
      return await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
    } catch (e, st) {
      debugPrint('signUp error: $e\n$st');
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
      if (data == null) return null;
      return ProfileModel.fromMap(data);
    } catch (e) {
      debugPrint('fetchProfile error: $e');
      return null;
    }
  }
}
