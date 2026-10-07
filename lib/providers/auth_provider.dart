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
    _init();
  }

  Future<void> _init() async {
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        isGuest = false;
        await _loadProfile();
      }
    } catch (e) {
      debugPrint('AuthProvider init error: $e');
    }

    initialized = true;
    notifyListeners();

    try {
      SupabaseService.client.auth.onAuthStateChange.listen(
        (data) async {
          try {
            if (data.session != null) {
              isGuest = false;
              isOffline = false;
              await _loadProfile();
            } else {
              isGuest = true;
              profile = null;
            }
            notifyListeners();
          } catch (e) {
            debugPrint('AuthState handler error: $e');
          }
        },
        onError: (error, stackTrace) {
          debugPrint('⚠️ Auth stream error (offline): $error');
          isOffline = true;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('listen error: $e');
    }
  }

  Future<void> _loadProfile() async {
    try {
      profile = await _auth.fetchProfile();
      isOffline = false;
    } catch (e) {
      debugPrint('loadProfile error: $e');
      isOffline = true;
    }
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) =>
      _run(() => _auth.signInWithEmail(email, password));

  Future<bool> signUpWithEmail(String email, String password, String name) =>
      _run(() => _auth.signUpWithEmail(email, password, name));

  Future<bool> resetPassword(String email) =>
      _run(() => _auth.resetPassword(email));

  /// 🔥 تحديث الملف الشخصي
  Future<bool> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      loading = true;
      notifyListeners();
      await _auth.updateProfile(fullName: fullName, avatarUrl: avatarUrl);
      await _loadProfile();
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

      await _loadProfile();
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
          msg.contains('HandshakeException')) {
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
