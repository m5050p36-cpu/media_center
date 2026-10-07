import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AdminService {
  /// تغيير كلمة مرور مستخدم عبر Edge Function
  static Future<void> changeUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session == null) {
        throw Exception('لا توجد جلسة نشطة');
      }

      debugPrint('🔐 Calling admin-change-password for: $userId');

      final response = await SupabaseService.client.functions.invoke(
        'admin-change-password',
        body: {
          'target_user_id': userId,
          'new_password': newPassword,
        },
      );

      debugPrint('📥 Response status: ${response.status}');
      debugPrint('📥 Response data: ${response.data}');

      if (response.status != 200) {
        final data = response.data;
        String msg = 'فشل تغيير كلمة المرور (${response.status})';
        if (data is Map) {
          if (data['error'] != null) msg = data['error'].toString();
          if (data['message'] != null) msg = data['message'].toString();
        }
        throw Exception(msg);
      }

      // ═══ تحقق من الرد ═══
      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw Exception(data['error']?.toString() ?? 'لم ينجح التغيير');
      }

      debugPrint('✅ Password changed successfully');
    } on FunctionException catch (e) {
      debugPrint('❌ FunctionException: status=${e.status}, details=${e.details}');
      String msg = 'خطأ في الاتصال بالخدمة';
      if (e.status == 404) {
        msg = 'الخدمة غير موجودة — تأكد من نشر Edge Function';
      } else if (e.status == 401) {
        msg = 'مصادقة فاشلة — أوقف JWT Verification في Edge Function';
      } else if (e.status == 403) {
        msg = 'ليس لديك صلاحية';
      } else if (e.details != null) {
        msg = 'خطأ ${e.status}: ${e.details}';
      }
      throw Exception(msg);
    } catch (e) {
      debugPrint('❌ changeUserPassword error: $e');
      rethrow;
    }
  }
}
