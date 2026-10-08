import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();

  ProfileModel? profile;
  bool isGuest = true;
  bool loading = false;
  bool initialized = false;
  bool isOffline = false;
  String? error;

  AuthProvider() {
    // ⚡ تهيئة فورية من الذاكرة
    _initFast();
    // ثم مراقبة الشبكة في الخلفية
    _initListeners();
  }

  /// ⚡ قراءة فورية (بدون شبكة)
  void _initFast() {
    try {
      if (!SupabaseService.isInitialized) {
        isGuest = true;
        initialized = true;
        notifyListeners();
        return;
      }

      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        isGuest = false;
        // بناء profile مؤقت من بيانات الجلسة (بدون شبكة)
        final user = session.user;
        profile = ProfileModel(
          id: user.id,
          email: user.email,
          fullName: user.userMetadata?['full_name'] as String?,
          avatarUrl: user.userMetadata?['avatar_url'] as String?,
          role: 'user', // سيُحدَّث من الشبكة لاحقاً
        );
      } else {
        isGuest = true;
      }
    } catch (e) {
      debugPrint('_initFast error: $e');
      isGuest = true;
    }
    initialized = true;
    notifyListeners();

    // 🔄 تحديث profile من الشبكة في الخلفية
    if (!isGuest) {
      _refreshFromNetwork();
    }
  }

  /// 🔄 تحديث من الشبكة (في الخلفية)
  Future<void> _refreshFromNetwork() async {
    try {
      final fresh = await _auth.fetchProfile().timeout(
        const Duration(seconds: 5),
      );
      if (fresh != null) {
        profile = fresh;
        isOffline = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Network refresh failed (offline?): $e');
      isOffline = true;
      notifyListeners();
    }
  }

  /// 🎧 مراقبة تغييرات المصادقة
  void _initListeners() {
    try {
      if (!SupabaseService.isInitialized) return;

      SupabaseService.client.auth.onAuthStateChange.listen(
        (data) async {
          try {
            if (data.session != null) {
              isGuest = false;
              notifyListeners();
              await _refreshFromNetwork();
            } else {
              isGuest = true;
              profile = null;
              notifyListeners();
            }
          } catch (e) {
            debugPrint('AuthState handler error: $e');
          }
        },
        onError: (error, stackTrace) {
          debugPrint('⚠️ Auth stream error: $error');
          isOffline = true;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('listen error: $e');
    }
  }

  Future<bool> signInWithEmail(String email, String password) =>
      _run(() => _auth.signInWithEmail(email, password));

  Future<bool> signUpWithEmail(String email, String password, String name) =>
      _run(() => _auth.signUpWithEmail(email, password, name));

  Future<bool> resetPassword(String email) =>
      _run(() => _auth.resetPassword(email));

  Future<bool> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      loading = true;
      notifyListeners();
      await _auth.updateProfile(fullName: fullName, avatarUrl: avatarUrl);
      await _refreshFromNetwork();
      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _run(Future<dynamic> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final result = await action();

      if (result is AuthResponse) {
        if (result.user != null && result.session == null) {
          loading = false;
          notifyListeners();
          return true;
        }
      }

      await _refreshFromNetwork();
      loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      error = _translateAuthError(e.message);
    } catch (e, st) {
      debugPrint('error: $e\n$st');
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Connection') ||
          msg.contains('HandshakeException') ||
          msg.contains('TimeoutException')) {
        error = 'لا يوجد اتصال بالإنترنت';
        isOffline = true;
      } else if (msg.contains('Invalid login credentials')) {
        error = 'البريد أو كلمة المرور غير صحيحة';
      } else if (msg.contains('already registered')) {
        error = 'البريد مسجل مسبقاً';
      } else {
        error = 'خطأ: $msg';
      }
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
    if (m.contains('email not confirmed')) return 'البريد غير مؤكد';
    if (m.contains('already been registered')) return 'البريد مسجل مسبقاً';
    if (m.contains('password should be at least')) {
      return 'كلمة المرور قصيرة جداً';
    }
    if (m.contains('invalid email')) return 'صيغة البريد غير صحيحة';
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
    } catch (e) {
      debugPrint('signOut error: $e');
    }
    isGuest = true;
    profile = null;
    notifyListeners();
  }

  bool get isAdmin => profile?.isAdmin ?? false;
  String? get userEmail => profile?.email ?? _auth.currentUser?.email;
  String? get userName => profile?.fullName;
  String? get userAvatar => profile?.avatarUrl;
}
