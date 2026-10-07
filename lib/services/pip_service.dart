import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PipService {
  static const _channel = MethodChannel('com.mediahub.mediacenter/pip');

  /// هل الجهاز يدعم PiP؟
  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPiPAvailable');
      return result ?? false;
    } catch (e) {
      debugPrint('PiP check error: $e');
      return false;
    }
  }

  /// الدخول لـ PiP فوراً
  static Future<bool> enterPip({
    int aspectX = 16,
    int aspectY = 9,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPiP', {
        'aspectX': aspectX,
        'aspectY': aspectY,
      });
      debugPrint('✅ PiP enter result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ PiP enter error: $e');
      return false;
    }
  }

  /// تفعيل الدخول التلقائي عند تصغير التطبيق (Android 12+)
  static Future<bool> setAutoEnter(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>('setAutoEnter', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('setAutoEnter error: $e');
      return false;
    }
  }

  /// هل التطبيق حالياً في وضع PiP؟
  static Future<bool> isInPipMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('isInPipMode');
      return result ?? false;
    } catch (e) {
      debugPrint('isInPipMode error: $e');
      return false;
    }
  }
}
