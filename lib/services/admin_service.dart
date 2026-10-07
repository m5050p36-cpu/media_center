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

      final response = await SupabaseService.client.functions.invoke(
        'admin-change-password',
        body: {
          'target_user_id': userId,
          'new_password': newPassword,
        },
      );

      if (response.status != 200) {
        final data = response.data;
        final msg = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'فشل تغيير كلمة المرور (${response.status})';
        throw Exception(msg);
      }

      debugPrint('✅ Password changed for user: $userId');
    } on FunctionException catch (e) {
      debugPrint('FunctionException: $e');
      throw Exception('خطأ في الاتصال: ${e.details ?? e.reasonPhrase}');
    } catch (e) {
      debugPrint('changeUserPassword error: $e');
      rethrow;
    }
  }
}
