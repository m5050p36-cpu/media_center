import 'package:supabase/supabase.dart';
import '../models/profile_model.dart';
import 'supabase_service.dart';

class AuthService {
  static SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isGuest => _client.auth.currentUser == null;

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail(
      String email, String password, String fullName) async {
    return await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async => await _client.auth.signOut();

  Future<ProfileModel?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromMap(data);
  }
}
