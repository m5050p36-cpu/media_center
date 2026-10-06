import 'package:shared_preferences/shared_preferences.dart';

class PlaybackStateService {
  static const _lastTrackKey = 'last_track_v1';
  static const _lastPositionKey = 'last_position_v1';
  static const _playbackSpeedKey = 'playback_speed_v1';

  /// حفظ آخر موضع تشغيل
  static Future<void> saveLastPosition(
      String trackPath, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastTrackKey, trackPath);
    await prefs.setInt(_lastPositionKey, position.inMilliseconds);
  }

  /// استرجاع آخر موضع
  static Future<({String? path, Duration? position})>
      loadLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_lastTrackKey);
    final ms = prefs.getInt(_lastPositionKey);
    return (
      path: path,
      position: ms != null ? Duration(milliseconds: ms) : null,
    );
  }

  /// حفظ سرعة التشغيل
  static Future<void> saveSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_playbackSpeedKey, speed);
  }

  /// استرجاع سرعة التشغيل
  static Future<double> loadSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_playbackSpeedKey) ?? 1.0;
  }
}
