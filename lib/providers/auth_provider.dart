import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();

  ProfileModel? profile;
  bool isGuest = true;
  bool loading = false;
  String? error;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final existingSession = SupabaseService.client.auth.currentSession;
    if (existingSession != null) {
      isGuest = false;
      await _loadProfile();
      notifyListeners();
    }

    SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        isGuest = false;
        await _loadProfile();
      } else {
        isGuest = true;
        profile = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadProfile() async {
    try {
      profile = await _auth.fetchProfile();
    } catch (e) {
      debugPrint('loadProfile: $e');
    }
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) =>
      _run(() => _auth.signInWithEmail(email, password));

  Future<bool> signUpWithEmail(String email, String password, String name) =>
      _run(() => _auth.signUpWithEmail(email, password, name));

  Future<bool> resetPassword(String email) =>
      _run(() => _auth.resetPassword(email));

  Future<bool> _run(Future<dynamic> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      await _loadProfile();
      loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      error = _translateAuthError(e.message);
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
    return false;
  }

  /// ترجمة أخطاء شائعة إلى رسائل واضحة
  String _translateAuthError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (m.contains('email not confirmed')) {
      return 'يجب تأكيد البريد الإلكتروني أولاً (تحقق من صندوق الوارد)';
    }
    if (m.contains('user already registered')) {
      return 'البريد مسجل مسبقاً — جرّب تسجيل الدخول';
    }
    if (m.contains('password should be at least')) {
      return 'كلمة المرور قصيرة جداً (6 أحرف على الأقل)';
    }
    if (m.contains('unable to validate email')) {
      return 'صيغة البريد غير صحيحة';
    }
    if (m.contains('signups not allowed')) {
      return 'التسجيل مغلق حالياً في Supabase';
    }
    return msg;
  }

  void continueAsGuest() {
    isGuest = true;
    profile = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    isGuest = true;
    profile = null;
    notifyListeners();
  }

  bool get isAdmin => profile?.isAdmin ?? false;
  String? get userEmail => profile?.email ?? _auth.currentUser?.email;
  String? get userName => profile?.fullName;
}
