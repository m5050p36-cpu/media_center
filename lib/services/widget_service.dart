import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _androidWidgetName = 'MusicWidgetProvider';
  static const _iosWidgetName = 'MusicWidget';

  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.com.mediahub.mediacenter');
      debugPrint('✅ Widget service initialized');
    } catch (e) {
      debugPrint('Widget init error: $e');
    }
  }

  /// تحديث بيانات الـ Widget
  static Future<void> updateWidget({
    required String title,
    required String artist,
    required bool isPlaying,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('title', title);
      await HomeWidget.saveWidgetData<String>('artist', artist);
      await HomeWidget.saveWidgetData<bool>('isPlaying', isPlaying);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
      debugPrint('✅ Widget updated: $title');
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }

  /// إفراغ البيانات
  static Future<void> clear() async {
    try {
      await HomeWidget.saveWidgetData<String>('title', '');
      await HomeWidget.saveWidgetData<String>('artist', '');
      await HomeWidget.saveWidgetData<bool>('isPlaying', false);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
    } catch (_) {}
  }
}
