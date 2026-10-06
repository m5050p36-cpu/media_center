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
  String? error;
  bool isOffline = false;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1) التحقق من الجلسة المحلية أولاً (بدون شبكة)
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        debugPrint('✅ Local session found: ${session.user.email}');
        isGuest = false;
        // محاولة تحميل الملف الشخصي من الذاكرة أو من الشبكة
        await _loadProfile(useCache: true);
      } else {
        debugPrint('ℹ️ No local session');
      }
    } catch (e) {
      debugPrint('Init session error: $e');
    }

    initialized = true;
    notifyListeners();

    // 2) الاستماع لتغيرات المصادقة مع معالج أخطاء إجباري
    try {
      SupabaseService.client.auth.onAuthStateChange.listen(
        (data) async {
          try {
            if (data.session != null) {
              isGuest = false;
              isOffline = false;
              await _loadProfile();
            } else {
              // لا نعتبر المستخدم زائراً إذا كان لديه جلسة محلية سابقة
              // وهذا يحدث فقط عند signOut فعلي
              isGuest = true;
              profile = null;
            }
            notifyListeners();
          } catch (e) {
            debugPrint('AuthState handler error: $e');
          }
        },
        // 🔥 إجباري: معالج أخطاء الشبكة
        onError: (error, stackTrace) {
          debugPrint('⚠️ Auth stream network error (offline mode): $error');
          isOffline = true;
          // لا نغير حالة المستخدم — نبقيه مسجلاً
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('listen error: $e');
    }
  }

  Future<void> _loadProfile({bool useCache = false}) async {
    try {
      profile = await _auth.fetchProfile();
      isOffline = false;
    } catch (e) {
      debugPrint('loadProfile error: $e');
      // إذا فشل تحميل الملف الشخصي بسبب الشبكة، نستخدم نسخة مخزنة
      if (profile == null) {
        final user = SupabaseService.client.auth.currentUser;
        if (user != null) {
          // إنشاء بروفايل مؤقت من بيانات المستخدم الحالية
          profile = ProfileModel(
            id: user.id,
            email: user.email,
            fullName: user.userMetadata?['full_name'] as String?,
            role: 'user',
          );
        }
      }
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
      debugPrint('AuthException: ${e.message}');
    } catch (e, st) {
      debugPrint('error: $e\n$st');
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Connection') ||
          msg.contains('HandshakeException')) {
        error = 'لا يوجد اتصال بالإنترنت — تحقق من الشبكة';
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
    if (m.contains('email not confirmed')) {
      return 'البريد غير مؤكد';
    }
    if (m.contains('user already registered') ||
        m.contains('already been registered')) {
      return 'البريد مسجل مسبقاً';
    }
    if (m.contains('password should be at least')) {
      return 'كلمة المرور قصيرة جداً';
    }
    if (m.contains('unable to validate email') ||
        m.contains('invalid email') ||
        m.contains('invalid format')) {
      return 'صيغة البريد غير صحيحة';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'محاولات كثيرة — انتظر قليلاً';
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
    } catch (e) {
      debugPrint('signOut error (offline?): $e');
    }
    isGuest = true;
    profile = null;
    notifyListeners();
  }

  bool get isAdmin => profile?.isAdmin ?? false;
  String? get userEmail => profile?.email ?? _auth.currentUser?.email;
  String? get userName => profile?.fullName;
}
