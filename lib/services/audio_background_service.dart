import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioBackgroundService {
  static Future<void> initialize() async {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.mediahub.mediacenter.channel.audio',
        androidNotificationChannelName: 'AR مشغل موسيقى & فيديوهات',
        androidNotificationChannelDescription:
            'تشغيل الصوتيات في الخلفية',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        preloadArtwork: true,
        androidShowNotificationBadge: true,
        fastForwardInterval: const Duration(seconds: 30),
        rewindInterval: const Duration(seconds: 10),
      );
      debugPrint('✅ Background audio service initialized');
    } catch (e) {
      debugPrint('⚠️ Background audio init failed: $e');
    }
  }
}
