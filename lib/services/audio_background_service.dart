import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioBackgroundService {
  static Future<void> initialize() async {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.mediahub.mediacenter.channel.audio',
        androidNotificationChannelName: 'Media Center Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      );
      debugPrint('✅ Background audio service initialized');
    } catch (e) {
      debugPrint('⚠️ Background audio init failed: $e');
    }
  }
}
