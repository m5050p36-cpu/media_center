import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';

class BrightnessService {
  static double _current = 0.5;

  static double get current => _current;

  /// تهيئة السطوع — قراءة القيمة الحالية
  static Future<void> init() async {
    try {
      _current = await ScreenBrightness.instance.application;
      debugPrint('✅ Brightness init: $_current');
    } catch (e) {
      debugPrint('⚠️ Brightness init error: $e');
      _current = 0.5;
    }
  }

  /// تعيين سطوع التطبيق (لا يؤثر على سطوع النظام)
  static Future<void> setApplication(double value) async {
    final v = value.clamp(0.05, 1.0);
    _current = v;
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(v);
    } catch (e) {
      debugPrint('⚠️ setApplication error: $e');
    }
  }

  /// إعادة السطوع إلى الوضع الافتراضي
  static Future<void> reset() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
      debugPrint('✅ Brightness reset');
    } catch (e) {
      debugPrint('⚠️ Brightness reset error: $e');
    }
  }
}
