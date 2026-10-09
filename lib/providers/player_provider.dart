import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' as jab;
import 'package:video_player/video_player.dart';
import '../services/favorites_service.dart';
import '../services/playback_state_service.dart';
import '../services/widget_service.dart';
import '../services/equalizer_service.dart';

/// وضعيات تكرار الصوت
enum AudioRepeatMode { none, once, twice, thrice, loopAll }

/// ترتيب التشغيل
enum PlayOrder { forward, reverse, shuffle }

/// عنصر وسائط موحّد
class MediaItem {
  final String title;
  final String path;
  final bool isVideo;
  final Duration? duration;
  final String? artist;
  final String? album;
  final String? albumArt;

  const MediaItem({
    required this.title,
    required this.path,
    this.isVideo = false,
    this.duration,
    this.artist,
    this.album,
    this.albumArt,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'path': path,
        'isVideo': isVideo,
        'albumArt': albumArt,
      };
}

class PlayerProvider extends ChangeNotifier {
  // ═══════════ Audio ═══════════
  final AudioPlayer audioPlayer = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [EqualizerService.equalizer],
    ),
  );

  List<MediaItem> audioQueue = [];
  List<MediaItem> originalAudioOrder = [];
  int audioIndex = 0;
  AudioRepeatMode audioRepeat = AudioRepeatMode.none;
  PlayOrder audioOrder = PlayOrder.forward;
  int _repeatCounter = 0;

  // ─── آخر خطأ ───
  String? lastError;

  // ─── المفضلة ───
  Set<String> favorites = {};

  // ─── مؤقت النوم ───
  Timer? _sleepTimer;
  DateTime? _sleepEndTime;
  Duration? _remainingSleepTime;

  // ─── سرعة التشغيل ───
  double playbackSpeed = 1.0;

  // ─── حفظ الموضع ───
  Timer? _positionSaveTimer;

  // ─── A-B Repeat ───
  Duration? abStart;
  Duration? abEnd;
  bool abActive = false;
  Timer? _abCheckTimer;

  // ─── Throttling & Flags ───
  DateTime _lastWidgetSync = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;
  bool _wasPlaying = false;

  MediaItem? get currentAudio =>
      audioQueue.isEmpty ? null : audioQueue[audioIndex];

  bool get hasNext => audioQueue.isNotEmpty;
  bool get hasPrevious => audioQueue.isNotEmpty;
  int get queueLength => audioQueue.length;

  Duration? get remainingSleepTime => _remainingSleepTime;
  bool get isSleepTimerActive => _sleepTimer?.isActive ?? false;

  PlayerProvider() {
    _init();
  }

  // ═══════════════════════════════════════════════
  // تهيئة سريعة + تحميلات خلفية
  // ═══════════════════════════════════════════════
  Future<void> _init() async {
    try {
      playbackSpeed = 1.0;
      favorites = {};

      // ─── استماع لحالة التشغيل ───
      audioPlayer.playerStateStream.listen((state) {
        if (_disposed) return;

        // ✅ فقط عند الانتهاء
        if (state.processingState == ProcessingState.completed) {
          _onAudioComplete();
        }

        // ✅ Throttled: فقط عند تغير حالة التشغيل
        if (state.playing != _wasPlaying) {
          _wasPlaying = state.playing;
          _syncWidgetThrottled();
        }
      });

      audioPlayer.currentIndexStream.listen((_) {
        if (_disposed) return;
        _syncWidgetThrottled();
      });

      // ✅ حفظ الموضع كل 30 ثانية
      _positionSaveTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _saveCurrentPosition(),
      );

      if (!_disposed) notifyListeners();

      // ─── تحميلات ثقيلة في الخلفية ───
      _loadHeavyInBackground();
    } catch (e) {
      debugPrint('PlayerProvider init error: $e');
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _loadHeavyInBackground() async {
    try {
      // سرعة التشغيل
      try {
        playbackSpeed = await PlaybackStateService.loadSpeed();
        await audioPlayer.setSpeed(playbackSpeed);
        if (!_disposed) notifyListeners();
      } catch (e) {
        debugPrint('Load speed error: $e');
      }

      // المفضلة
      try {
        favorites = await FavoritesService.load();
        if (!_disposed) notifyListeners();
      } catch (e) {
        debugPrint('Load favorites error: $e');
      }

      // المعادل
      try {
        await EqualizerService.init();
      } catch (e) {
        debugPrint('Equalizer init error: $e');
      }

      debugPrint('✅ PlayerProvider heavy loads done');
    } catch (e) {
      debugPrint('_loadHeavyInBackground error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // 🐢 Throttled Widget sync — مرة كل 3 ثوانٍ
  // ═══════════════════════════════════════════════
  void _syncWidgetThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastWidgetSync).inSeconds < 3) return;
    _lastWidgetSync = now;
    _syncWidgetAsync();
  }

  Future<void> _syncWidgetAsync() async {
    try {
      final current = currentAudio;
      if (current == null) {
        await WidgetService.clear();
        return;
      }
      await WidgetService.updateWidget(
        title: current.title,
        artist: current.album ?? 'AR Player',
        isPlaying: audioPlayer.playing,
      );
    } catch (_) {}
  }

  void clearError() {
    lastError = null;
    if (!_disposed) notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // تحميل قائمة التشغيل
  // ═══════════════════════════════════════════════
  Future<void> loadAudioQueue(List<MediaItem> items,
      {int startIndex = 0}) async {
    if (items.isEmpty) return;
    if (startIndex < 0 || startIndex >= items.length) startIndex = 0;

    try {
      audioQueue = List.from(items);
      originalAudioOrder = List.from(items);
      audioIndex = startIndex;
      _repeatCounter = 0;
      lastError = null;
      if (!_disposed) notifyListeners();

      final firstFile = File(items[startIndex].path);
      if (!await firstFile.exists()) {
        lastError = 'الملف غير موجود: ${items[startIndex].title}';
        if (!_disposed) notifyListeners();
        return;
      }

      final List<AudioSource> sources = [];
      for (final item in items) {
        sources.add(
          AudioSource.file(
            item.path,
            tag: jab.MediaItem(
              id: item.path,
              title: item.title,
              album: item.album ?? 'Media Center',
            ),
          ),
        );
      }

      final playlist = ConcatenatingAudioSource(children: sources);
      await audioPlayer.setAudioSource(playlist);
      await audioPlayer.seek(Duration.zero, index: startIndex);
      await audioPlayer.setSpeed(playbackSpeed);
      await audioPlayer.play();
      debugPrint('▶️ Playing: ${items[startIndex].title}');
    } catch (e, st) {
      lastError = 'فشل التشغيل: $e';
      debugPrint('❌ loadAudioQueue error: $e\n$st');
    }

    if (!_disposed) notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // Fallback: تشغيل أغنية واحدة
  // ═══════════════════════════════════════════════
  Future<void> playSingle(MediaItem item,
      {List<MediaItem>? queue, int? index}) async {
    try {
      if (queue != null) audioQueue = List.from(queue);
      if (index != null) audioIndex = index;
      lastError = null;
      if (!_disposed) notifyListeners();

      final file = File(item.path);
      if (!await file.exists()) {
        lastError = 'الملف غير موجود';
        if (!_disposed) notifyListeners();
        return;
      }

      await audioPlayer.setAudioSource(
        AudioSource.file(
          item.path,
          tag: jab.MediaItem(
            id: item.path,
            title: item.title,
            album: item.album ?? 'Media Center',
          ),
        ),
      );
      await audioPlayer.setSpeed(playbackSpeed);
      await audioPlayer.play();
    } catch (e, st) {
      lastError = 'فشل: $e';
      debugPrint('❌ playSingle error: $e\n$st');
    }
    if (!_disposed) notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // إيقاف نهائي + مسح قائمة التشغيل
  // ═══════════════════════════════════════════════
  Future<void> stopAndClear() async {
    try {
      await audioPlayer.stop();
      audioQueue.clear();
      originalAudioOrder.clear();
      audioIndex = 0;
      _repeatCounter = 0;
      lastError = null;
      cancelSleepTimer();
    } catch (e) {
      debugPrint('stopAndClear error: $e');
    }
    if (!_disposed) notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // A-B Repeat
  // ═══════════════════════════════════════════════
  void setABStart() {
    abStart = audioPlayer.position;
    if (abEnd != null && abEnd! <= abStart!) abEnd = null;
    if (!_disposed) notifyListeners();
  }

  void setABEnd() {
    abEnd = audioPlayer.position;
    if (abStart != null && abEnd! <= abStart!) abStart = null;
    if (!_disposed) notifyListeners();
  }

  void toggleAB() {
    if (abStart == null || abEnd == null) return;
    abActive = !abActive;

    if (abActive) {
      _abCheckTimer?.cancel();
      _abCheckTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) {
          if (!abActive || abStart == null || abEnd == null || _disposed) {
            return;
          }
          final pos = audioPlayer.position;
          if (pos >= abEnd!) {
            audioPlayer.seek(abStart!);
          }
        },
      );
    } else {
      _abCheckTimer?.cancel();
      _abCheckTimer = null;
    }
    if (!_disposed) notifyListeners();
  }

  void clearAB() {
    abStart = null;
    abEnd = null;
    abActive = false;
    _abCheckTimer?.cancel();
    _abCheckTimer = null;
    if (!_disposed) notifyListeners();
  }

  String? get abStatus {
    if (abStart == null && abEnd == null) return null;
    if (abStart == null) return 'A: -- • B: ${_fmt(abEnd!)}';
    if (abEnd == null) return 'A: ${_fmt(abStart!)} • B: --';
    return 'A: ${_fmt(abStart!)} • B: ${_fmt(abEnd!)}${abActive ? " ●" : ""}';
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ═══════════════════════════════════════════════
  // حفظ الموضع
  // ═══════════════════════════════════════════════
  Future<void> _saveCurrentPosition() async {
    final current = currentAudio;
    if (current == null) return;
    try {
      await PlaybackStateService.saveLastPosition(
        current.path,
        audioPlayer.position,
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════
  // عند انتهاء المسار
  // ═══════════════════════════════════════════════
  Future<void> _onAudioComplete() async {
    if (_disposed) return;
    switch (audioRepeat) {
      case AudioRepeatMode.once:
      case AudioRepeatMode.twice:
      case AudioRepeatMode.thrice:
        final maxReps = audioRepeat == AudioRepeatMode.once
            ? 1
            : (audioRepeat == AudioRepeatMode.twice ? 2 : 3);
        if (_repeatCounter < maxReps) {
          _repeatCounter++;
          await audioPlayer.seek(Duration.zero);
          await audioPlayer.play();
          return;
        }
        _repeatCounter = 0;
        await nextAudio(auto: true);
        break;
      case AudioRepeatMode.loopAll:
        if (audioIndex == audioQueue.length - 1) {
          audioIndex = 0;
        } else {
          audioIndex++;
        }
        await audioPlayer.seek(Duration.zero, index: audioIndex);
        await audioPlayer.play();
        if (!_disposed) notifyListeners();
        break;
      case AudioRepeatMode.none:
        await nextAudio(auto: true);
        break;
    }
  }

  // ═══════════════════════════════════════════════
  // التنقل
  // ═══════════════════════════════════════════════
  Future<void> nextAudio({bool auto = false}) async {
    if (audioQueue.isEmpty || _disposed) return;

    int newIndex;
    if (audioOrder == PlayOrder.shuffle && !auto) {
      newIndex = _randomIndex();
    } else if (audioOrder == PlayOrder.reverse) {
      newIndex = (audioIndex - 1 + audioQueue.length) % audioQueue.length;
    } else {
      newIndex = (audioIndex + 1) % audioQueue.length;
    }

    _repeatCounter = 0;
    audioIndex = newIndex;

    try {
      await audioPlayer.seek(Duration.zero, index: newIndex);
      await audioPlayer.play();
    } catch (e) {
      debugPrint('nextAudio error: $e');
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> previousAudio() async {
    if (audioQueue.isEmpty || _disposed) return;
    audioIndex = (audioIndex - 1 + audioQueue.length) % audioQueue.length;
    try {
      await audioPlayer.seek(Duration.zero, index: audioIndex);
      await audioPlayer.play();
    } catch (e) {
      debugPrint('previousAudio error: $e');
    }
    if (!_disposed) notifyListeners();
  }

  int _randomIndex() {
    if (audioQueue.length <= 1) return 0;
    final rng = Random();
    int idx;
    do {
      idx = rng.nextInt(audioQueue.length);
    } while (idx == audioIndex);
    return idx;
  }

  Future<void> togglePlay() async {
    if (audioPlayer.playing) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
  }

  void setAudioRepeat(AudioRepeatMode mode) {
    audioRepeat = mode;
    _repeatCounter = 0;
    if (!_disposed) notifyListeners();
  }

  void setAudioOrder(PlayOrder order) {
    audioOrder = order;
    if (!_disposed) notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed = speed;
    await audioPlayer.setSpeed(speed);
    await PlaybackStateService.saveSpeed(speed);
    if (!_disposed) notifyListeners();
  }

  Future<void> savePosition() async {
    final current = currentAudio;
    if (current == null) return;
    await PlaybackStateService.saveLastPosition(
      current.path,
      audioPlayer.position,
    );
  }

  // ═══════════════════════════════════════════════
  // المفضلة
  // ═══════════════════════════════════════════════
  Future<bool> toggleFavorite(String path) async {
    final added = await FavoritesService.toggle(path);
    favorites = await FavoritesService.load();
    if (!_disposed) notifyListeners();
    return added;
  }

  bool isFavorite(String path) => favorites.contains(path);

  List<MediaItem> get favoriteTracks =>
      audioQueue.where((item) => favorites.contains(item.path)).toList();

  // ═══════════════════════════════════════════════
  // مؤقت النوم
  // ═══════════════════════════════════════════════
  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepEndTime = DateTime.now().add(duration);

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      final remaining = _sleepEndTime!.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        cancelSleepTimer();
        audioPlayer.pause();
        if (!_disposed) notifyListeners();
      } else {
        _remainingSleepTime = remaining;
        if (!_disposed) notifyListeners();
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndTime = null;
    _remainingSleepTime = null;
    if (!_disposed) notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // 🎬 Video — محسّن لجودة الأداء
  // ═══════════════════════════════════════════════
  VideoPlayerController? videoController;
  List<MediaItem> videoQueue = [];
  int videoIndex = 0;
  bool videoLoop = false;
  PlayOrder videoOrder = PlayOrder.forward;

  /// ✅ حماية من الاستدعاء المتكرر
  bool _isVideoTransitioning = false;

  /// ✅ Throttle لمراقب الفيديو
  DateTime _lastVideoCheck = DateTime.fromMillisecondsSinceEpoch(0);

  MediaItem? get currentVideo =>
      videoQueue.isEmpty ? null : videoQueue[videoIndex];

  Future<void> loadVideoQueue(List<MediaItem> items,
      {int startIndex = 0}) async {
    if (items.isEmpty) return;
    if (_disposed) return;
    videoQueue = items;
    videoIndex = startIndex;
    await _playCurrentVideo();
  }

  Future<void> _playCurrentVideo() async {
    if (videoQueue.isEmpty || _disposed) return;

    // ✅ حماية من التنفيذ المتوازي
    if (_isVideoTransitioning) {
      debugPrint('⚠️ Video transition already in progress');
      return;
    }
    _isVideoTransitioning = true;

    try {
      // ─── 1) احفظ المرجع القديم ───
      final oldController = videoController;

      // ─── 2) أنشئ الجديد أولاً ───
      final newController = VideoPlayerController.file(
        File(videoQueue[videoIndex].path),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: true,
          mixWithOthers: false,
        ),
      );

      // ─── 3) هيّئه ───
      await newController.initialize();

      // ─── 4) بدّل المراجع ───
      videoController = newController;
      await newController.setLooping(videoLoop);

      // ─── 5) أضف المراقب ───
      newController.addListener(_onVideoTick);

      // ─── 6) شغّل ───
      await newController.play();

      // ─── 7) تخلّص من القديم ───
      if (oldController != null) {
        try {
          oldController.removeListener(_onVideoTick);
          await oldController.pause();
          await oldController.dispose();
        } catch (e) {
          debugPrint('⚠️ Old video dispose error: $e');
        }
      }

      debugPrint('▶️ Video playing: ${videoQueue[videoIndex].title}');
      if (!_disposed) notifyListeners();
    } catch (e, st) {
      debugPrint('❌ _playCurrentVideo error: $e\n$st');
      lastError = 'فشل تشغيل الفيديو: $e';
      if (!_disposed) notifyListeners();
    } finally {
      _isVideoTransitioning = false;
    }
  }

  /// ✅ مراقب فيديو محسّن — Throttled
  void _onVideoTick() {
    final c = videoController;
    if (c == null || _disposed) return;

    // ─── Throttle: مرة كل 500ms ───
    final now = DateTime.now();
    if (now.difference(_lastVideoCheck).inMilliseconds < 500) return;
    _lastVideoCheck = now;

    // ─── لا شيء إذا الفيديو لم ينتهِ ───
    final value = c.value;
    if (!value.isInitialized || value.duration <= Duration.zero) return;
    if (value.position < value.duration) return;

    // ─── حماية من الاستدعاء المتكرر ───
    if (_isVideoTransitioning) return;

    // ─── لووب أو التالي ───
    if (videoLoop) return; // setLooping يتولى الأمر

    nextVideo(auto: true);
  }

  Future<void> nextVideo({bool auto = false}) async {
    if (videoQueue.isEmpty || _disposed) return;
    if (_isVideoTransitioning) return;

    if (videoOrder == PlayOrder.shuffle) {
      videoIndex = _randomIndex();
    } else if (videoOrder == PlayOrder.reverse) {
      videoIndex = (videoIndex - 1 + videoQueue.length) % videoQueue.length;
    } else {
      videoIndex = (videoIndex + 1) % videoQueue.length;
    }
    await _playCurrentVideo();
  }

  Future<void> previousVideo() async {
    if (videoQueue.isEmpty || _disposed) return;
    if (_isVideoTransitioning) return;
    videoIndex = (videoIndex - 1 + videoQueue.length) % videoQueue.length;
    await _playCurrentVideo();
  }

  void setVideoOrder(PlayOrder order) {
    videoOrder = order;
    if (!_disposed) notifyListeners();
  }

  Future<void> setVideoLoop(bool loop) async {
    videoLoop = loop;
    await videoController?.setLooping(loop);
    if (!_disposed) notifyListeners();
  }

  Future<void> toggleVideoPlay() async {
    final c = videoController;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (!_disposed) notifyListeners();
  }

  /// ✅ إيقاف الفيديو وتنظيفه
  Future<void> stopVideo() async {
    try {
      final c = videoController;
      if (c != null) {
        c.removeListener(_onVideoTick);
        await c.pause();
        await c.dispose();
        videoController = null;
      }
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('stopVideo error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  // dispose شامل
  // ═══════════════════════════════════════════════
  @override
  void dispose() {
    _disposed = true;
    _positionSaveTimer?.cancel();
    _sleepTimer?.cancel();
    _abCheckTimer?.cancel();

    try {
      videoController?.removeListener(_onVideoTick);
      videoController?.dispose();
    } catch (_) {}

    try {
      audioPlayer.dispose();
    } catch (_) {}

    super.dispose();
  }
}
