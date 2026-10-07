import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class EqualizerService {
  /// الـ Equalizer ننشئه هنا ويُمرَّر إلى AudioPlayer عند الإنشاء
  static final AndroidEqualizer equalizer = AndroidEqualizer();

  static bool _enabled = false;
  static String _preset = 'normal';

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
  static String get preset => _preset;

  /// تهيئة (يجب استدعاؤها بعد إنشاء AudioPlayer)
  static Future<void> init() async {
    try {
      final params = await equalizer.parameters;
      debugPrint('✅ Equalizer ready: ${params.bands.length} bands');
    } catch (e) {
      debugPrint('⚠️ Equalizer init error: $e');
    }
  }

  /// تفعيل/تعطيل
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      await equalizer.setEnabled(value);
    } catch (e) {
      debugPrint('setEnabled error: $e');
    }
  }

  /// تطبيق preset
  static Future<void> applyPreset(String name) async {
    try {
      final p = presets.firstWhere(
        (e) => e['name'] == name,
        orElse: () => presets.first,
      );
      final gains = (p['gains'] as List).cast<double>();
      final params = await equalizer.parameters;
      final bands = params.bands;

      for (int i = 0; i < bands.length && i < gains.length; i++) {
        bands[i].setGain(gains[i]);
      }

      _preset = name;
      _enabled = true;
      await equalizer.setEnabled(true);
      debugPrint('✅ Equalizer preset: $name');
    } catch (e) {
      debugPrint('applyPreset error: $e');
    }
  }

  /// تطبيق قيمة يدوية
  static Future<void> setBandGain(int bandIndex, double gain) async {
    try {
      final params = await equalizer.parameters;
      if (bandIndex < 0 || bandIndex >= params.bands.length) return;
      params.bands[bandIndex].setGain(gain);
      _preset = 'custom';
    } catch (e) {
      debugPrint('setBandGain error: $e');
    }
  }

  /// عدد النطاقات
  static Future<int> bandCount() async {
    try {
      final params = await equalizer.parameters;
      return params.bands.length;
    } catch (_) {
      return 5;
    }
  }
}
