import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class EqualizerService {
  static bool _enabled = false;
  static String _preset = 'normal';
  static bool _available = false;
  static bool _initialized = false;

  static const List<Map<String, dynamic>> presets = [
    {'name': 'normal', 'label': 'عادي', 'gains': [0.0, 0.0, 0.0, 0.0, 0.0]},
    {'name': 'bass', 'label': 'باس قوي', 'gains': [8.0, 5.0, 2.0, 0.0, 0.0]},
    {'name': 'vocal', 'label': 'صوتي', 'gains': [-2.0, 0.0, 4.0, 3.0, 0.0]},
    {'name': 'rock', 'label': 'روك', 'gains': [5.0, 2.0, -1.0, 3.0, 5.0]},
    {'name': 'pop', 'label': 'بوب', 'gains': [-1.0, 2.0, 3.0, 2.0, -1.0]},
    {'name': 'jazz', 'label': 'جاز', 'gains': [3.0, 2.0, -1.0, 2.0, 4.0]},
    {'name': 'classical', 'label': 'كلاسيكي', 'gains': [4.0, 2.0, -2.0, 2.0, 4.0]},
    {'name': 'flat', 'label': 'مسطح', 'gains': [0.0, 0.0, 0.0, 0.0, 0.0]},
  ];

  static bool get enabled => _enabled;
  static bool get available => _available;
  static bool get initialized => _initialized;
  static String get preset => _preset;

  /// فحص توفّر المعادل على الجهاز
  static Future<bool> init() async {
    if (_initialized) return _available;
    _initialized = true;

    try {
      // إنشاء Equalizer جديد للفحص فقط
      final eq = AndroidEqualizer();
      final params = await eq.parameters.timeout(const Duration(seconds: 3));
      final bands = params.bands;

      if (bands.isEmpty) {
        _available = false;
        return false;
      }

      _available = true;
      debugPrint('✅ Equalizer available: ${bands.length} bands');
      return true;
    } catch (e) {
      debugPrint('⚠️ Equalizer not available: $e');
      _available = false;
      return false;
    }
  }

  /// تفعيل/تعطيل — لا يعمل حالياً بدون ربط بالمشغل
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    debugPrint('Equalizer enabled: $value (requires pipeline binding)');
  }

  /// تطبيق preset — لا يعمل حالياً
  static Future<void> applyPreset(String name) async {
    _preset = name;
    debugPrint('Equalizer preset: $name (requires pipeline binding)');
  }

  /// تطبيق قيمة يدوية — لا يعمل حالياً
  static Future<void> setBandGain(int bandIndex, double gain) async {
    _preset = 'custom';
  }

  /// عدد النطاقات
  static Future<int> bandCount() async {
    if (!_available) return 5; // افتراضي
    try {
      final eq = AndroidEqualizer();
      final params = await eq.parameters;
      return params.bands.length;
    } catch (_) {
      return 5;
    }
  }

  /// إعادة الضبط
  static Future<void> reset() async {
    _preset = 'normal';
  }
}
