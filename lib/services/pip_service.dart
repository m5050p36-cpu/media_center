import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PipService {
  static const _channel = MethodChannel('com.mediahub.mediacenter/pip');

  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPiPAvailable');
      return result ?? false;
    } catch (e) {
      debugPrint('PiP check error: $e');
      return false;
    }
  }

  static Future<bool> enterPip() async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPiP');
      return result ?? false;
    } catch (e) {
      debugPrint('PiP enter error: $e');
      return false;
    }
  }
}
