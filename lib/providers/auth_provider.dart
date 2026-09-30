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
    try {
      final existingSession = SupabaseService.client.auth.currentSession;
      if (existingSession != null) {
        isGuest = false;
        await _loadProfile();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AuthProvider init error: $e');
    }

    try {
      SupabaseService.client.auth.onAuthStateChange.listen((data) async {
        try {
          if (data.session != null) {
            isGuest = false;
            await _loadProfile();
          } else {
            isGuest = true;
            profile = null;
          }
          notifyListeners();
        } catch (e) {
          debugPrint('authStateChange error: $e');
        }
      });
    } catch (e) {
      debugPrint('listen error: $e');
    }
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

  /// ═══ تحسين معالجة الأخطاء ═══
  Future<bool> _run(Future<dynamic> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final result = await action();

      // ═══ كشف: signup نجح لكن بدون session (Confirm email مفعّل) ═══
      if (result is AuthResponse) {
        if (result.user != null && result.session == null) {
          await _loadProfile();
          loading = false;
          notifyListeners();
          return true;
        }
      }

      await _loadProfile();
      loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      error = _translateAuthError(e.message);
    } on TypeError catch (e) {
      // ═══ يعوّض NullThrownError في Dart الحديث ═══
      error = 'فشل الاتصال بـ Supabase (رد فارغ). '
          'تأكد من تعطيل "Confirm email" في إعدادات المشروع.';
      debugPrint('TypeError: $e');
    } on FormatException catch (e) {
      error = 'صيغة غير صحيحة: ${e.message}';
      debugPrint('FormatException: $e');
    } catch (e, st) {
      // ═══ fallback عام لأي خطأ آخر ═══
      final msg = e.toString();
      if (msg.contains('Null check operator') ||
          msg.contains('null value') ||
          msg.contains('_TypeError')) {
        error = 'فشل الاتصال بـ Supabase (رد فارغ). '
            'تأكد من تعطيل "Confirm email" في إعدادات المشروع.';
      } else {
        error = 'خطأ غير متوقع: $msg';
      }
      debugPrint('unexpected error: $e\n$st');
    }

    loading = false;
    notifyListeners();
    return false;
  }

  String _translateAuthError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (m.contains('email not confirmed')) {
      return 'يجب تأكيد البريد الإلكتروني أولاً (تحقق من صندوق الوارد)';
    }
    if (m.contains('user already registered') ||
        m.contains('already been registered')) {
      return 'البريد مسجل مسبقاً — جرّب تسجيل الدخول';
    }
    if (m.contains('password should be at least')) {
      return 'كلمة المرور قصيرة جداً';
    }
    if (m.contains('unable to validate email') ||
        m.contains('invalid email')) {
      return 'صيغة البريد غير صحيحة';
    }
    if (m.contains('signups not allowed')) {
      return 'التسجيل مغلق حالياً في Supabase';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'محاولات كثيرة — انتظر قليلاً ثم أعد المحاولة';
    }
    return msg;
  }

  void continueAsGuest() {
    isGuest = true;
    profile = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    isGuest = true;
    profile = null;
    notifyListeners();
  }

  bool get isAdmin => profile?.isAdmin ?? false;
  String? get userEmail => profile?.email ?? _auth.currentUser?.email;
  String? get userName => profile?.fullName;
}
