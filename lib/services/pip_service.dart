import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PipService {
  static const _channel = MethodChannel('com.mediahub.mediacenter/pip');
  static bool? _cachedAvailability;

  static Future<bool> isAvailable() async {
    if (_cachedAvailability != null) return _cachedAvailability!;
    try {
      final result = await _channel.invokeMethod<bool>('isPiPAvailable');
      _cachedAvailability = result ?? false;
      debugPrint('✅ PiP available: $_cachedAvailability');
      return _cachedAvailability!;
    } on MissingPluginException {
      debugPrint('❌ PiP: MethodChannel not registered');
      _cachedAvailability = false;
      return false;
    } catch (e) {
      debugPrint('❌ PiP check error: $e');
      _cachedAvailability = false;
      return false;
    }
  }

  static Future<bool> enterPip({
    int aspectX = 16,
    int aspectY = 9,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPiP', {
        'aspectX': aspectX,
        'aspectY': aspectY,
      });
      debugPrint('✅ PiP enter: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ PiP enter error: $e');
      return false;
    }
  }

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

  static Future<bool> isInPipMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('isInPipMode');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
