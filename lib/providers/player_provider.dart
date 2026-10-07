import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' as jab;
import 'package:video_player/video_player.dart';
import '../services/favorites_service.dart';
import '../services/playback_state_service.dart';
import '../services/equalizer_service.dart';
import '../services/widget_service.dart';

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

  // ═══ آخر خطأ ═══
  String? lastError;

  // ═══ المفضلة ═══
  Set<String> favorites = {};

  // ═══ مؤقت النوم ═══
  Timer? _sleepTimer;
  DateTime? _sleepEndTime;
  Duration? _remainingSleepTime;

  // ═══ سرعة التشغيل ═══
  double playbackSpeed = 1.0;

  // ═══ حفظ الموضع ═══
  Timer? _positionSaveTimer;

  // ═══ A-B Repeat ═══
  Duration? abStart;
  Duration? abEnd;
  bool abActive = false;
  Timer? _abCheckTimer;

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

  Future<void> _init() async {
    // تهيئة المعادل الصوتي
    await EqualizerService.init();

    playbackSpeed = await PlaybackStateService.loadSpeed();
    await audioPlayer.setSpeed(playbackSpeed);

    favorites = await FavoritesService.load();

    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onAudioComplete();
      }
      _syncWidget();
    });

    audioPlayer.currentIndexStream.listen((_) {
      _syncWidget();
    });

    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentPosition();
    });

    notifyListeners();
  }

  /// مسح رسالة الخطأ
  void clearError() {
    lastError = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // تحميل قائمة التشغيل
  // ═══════════════════════════════════════════════
  Future<void> loadAudioQueue(List<MediaItem> items,
      {int startIndex = 0}) async {
    if (items.isEmpty) {
      debugPrint('⚠️ Empty queue');
      return;
    }

    if (startIndex < 0 || startIndex >= items.length) {
      startIndex = 0;
    }

    try {
      audioQueue = List.from(items);
      originalAudioOrder = List.from(items);
      audioIndex = startIndex;
      _repeatCounter = 0;
      lastError = null;
      notifyListeners();

      debugPrint('📂 Loading queue: ${items.length} items, start=$startIndex');

      final firstFile = File(items[startIndex].path);
      if (!await firstFile.exists()) {
        lastError = 'الملف غير موجود: ${items[startIndex].title}';
        debugPrint('❌ File not found: ${items[startIndex].path}');
        notifyListeners();
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
              artUri: Uri.parse(
                  'https://qoarusrrbarbqhstqmae.supabase.co/storage/v1/object/public/banners/default.png'),
            ),
          ),
        );
      }

      final playlist = ConcatenatingAudioSource(children: sources);
      debugPrint('📋 Playlist created with ${sources.length} sources');

      await audioPlayer.setAudioSource(playlist);
      await audioPlayer.seek(Duration.zero, index: startIndex);
      await audioPlayer.setSpeed(playbackSpeed);
      await audioPlayer.play();
      debugPrint('▶️ Playing: ${items[startIndex].title}');
    } catch (e, st) {
      lastError = 'فشل التشغيل: $e';
      debugPrint('❌ loadAudioQueue error: $e\n$st');
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // تشغيل أغنية واحدة (fallback)
  // ═══════════════════════════════════════════════
  Future<void> playSingle(MediaItem item,
      {List<MediaItem>? queue, int? index}) async {
    try {
      if (queue != null) audioQueue = List.from(queue);
      if (index != null) audioIndex = index;
      lastError = null;
      notifyListeners();

      debugPrint('🎵 playSingle: ${item.title}');

      final file = File(item.path);
      if (!await file.exists()) {
        lastError = 'الملف غير موجود';
        debugPrint('❌ File not found');
        notifyListeners();
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
      debugPrint('▶️ Playing single: ${item.title}');
    } catch (e, st) {
      lastError = 'فشل: $e';
      debugPrint('❌ playSingle error: $e\n$st');
    }
    notifyListeners();
  }

  Future<void> _syncWidget() async {
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

  Future<void> _onAudioComplete() async {
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
        notifyListeners();
        break;
      case AudioRepeatMode.none:
        await nextAudio(auto: true);
        break;
    }
  }

  Future<void> nextAudio({bool auto = false}) async {
    if (audioQueue.isEmpty) return;

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
    notifyListeners();
  }

  Future<void> previousAudio() async {
    if (audioQueue.isEmpty) return;
    audioIndex = (audioIndex - 1 + audioQueue.length) % audioQueue.length;
    try {
      await audioPlayer.seek(Duration.zero, index: audioIndex);
      await audioPlayer.play();
    } catch (e) {
      debugPrint('previousAudio error: $e');
    }
    notifyListeners();
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
    notifyListeners();
  }

  /// ═══ إيقاف نهائي + مسح قائمة التشغيل ═══
  Future<void> stopAndClear() async {
    try {
      await audioPlayer.stop();
      audioQueue.clear();
      originalAudioOrder.clear();
      audioIndex = 0;
      _repeatCounter = 0;
      lastError = null;
      cancelSleepTimer();
      debugPrint('🛑 Player stopped and cleared');
    } catch (e) {
      debugPrint('stopAndClear error: $e');
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // A-B Repeat
  // ═══════════════════════════════════════════════
  void setABStart() {
    abStart = audioPlayer.position;
    if (abEnd != null && abEnd! <= abStart!) abEnd = null;
    notifyListeners();
  }

  void setABEnd() {
    abEnd = audioPlayer.position;
    if (abStart != null && abEnd! <= abStart!) abStart = null;
    notifyListeners();
  }

  void toggleAB() {
    if (abStart == null || abEnd == null) return;
    abActive = !abActive;

    if (abActive) {
      _abCheckTimer?.cancel();
      _abCheckTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) {
          if (!abActive || abStart == null || abEnd == null) return;
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
    notifyListeners();
  }

  void clearAB() {
    abStart = null;
    abEnd = null;
    abActive = false;
    _abCheckTimer?.cancel();
    _abCheckTimer = null;
    notifyListeners();
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

  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
  }

  void setAudioRepeat(AudioRepeatMode mode) {
    audioRepeat = mode;
    _repeatCounter = 0;
    notifyListeners();
  }

  void setAudioOrder(PlayOrder order) {
    audioOrder = order;
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed = speed;
    await audioPlayer.setSpeed(speed);
    await PlaybackStateService.saveSpeed(speed);
    notifyListeners();
  }

  Future<void> savePosition() async {
    final current = currentAudio;
    if (current == null) return;
    await PlaybackStateService.saveLastPosition(
      current.path,
      audioPlayer.position,
    );
  }

  Future<bool> toggleFavorite(String path) async {
    final added = await FavoritesService.toggle(path);
    favorites = await FavoritesService.load();
    notifyListeners();
    return added;
  }

  bool isFavorite(String path) => favorites.contains(path);

  List<MediaItem> get favoriteTracks =>
      audioQueue.where((item) => favorites.contains(item.path)).toList();

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepEndTime = DateTime.now().add(duration);

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepEndTime!.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        cancelSleepTimer();
        audioPlayer.pause();
        notifyListeners();
      } else {
        _remainingSleepTime = remaining;
        notifyListeners();
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndTime = null;
    _remainingSleepTime = null;
    notifyListeners();
  }

  // ═══════════ Video ═══════════
  VideoPlayerController? videoController;
  List<MediaItem> videoQueue = [];
  int videoIndex = 0;
  bool videoLoop = false;
  PlayOrder videoOrder = PlayOrder.forward;

  MediaItem? get currentVideo =>
      videoQueue.isEmpty ? null : videoQueue[videoIndex];

  Future<void> loadVideoQueue(List<MediaItem> items,
      {int startIndex = 0}) async {
    videoQueue = items;
    videoIndex = startIndex;
    await _playCurrentVideo();
  }

  Future<void> _playCurrentVideo() async {
    if (videoQueue.isEmpty) return;
    await videoController?.dispose();
    videoController = VideoPlayerController.file(
      File(videoQueue[videoIndex].path),
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: true,
        mixWithOthers: false,
      ),
    );
    videoController!.addListener(_videoListener);
    await videoController!.initialize();
    await videoController!.setLooping(videoLoop);
    await videoController!.play();
    notifyListeners();
  }

  void _videoListener() {
    final c = videoController;
    if (c == null) return;
    if (c.value.position >= c.value.duration &&
        c.value.duration > Duration.zero) {
      if (!videoLoop) {
        nextVideo(auto: true);
      }
    }
  }

  Future<void> nextVideo({bool auto = false}) async {
    if (videoQueue.isEmpty) return;
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
    if (videoQueue.isEmpty) return;
    videoIndex = (videoIndex - 1 + videoQueue.length) % videoQueue.length;
    await _playCurrentVideo();
  }

  void setVideoOrder(PlayOrder order) {
    videoOrder = order;
    notifyListeners();
  }

  Future<void> setVideoLoop(bool loop) async {
    videoLoop = loop;
    await videoController?.setLooping(loop);
    notifyListeners();
  }

  Future<void> toggleVideoPlay() async {
    final c = videoController;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSaveTimer?.cancel();
    _sleepTimer?.cancel();
    _abCheckTimer?.cancel();
    audioPlayer.dispose();
    videoController?.dispose();
    super.dispose();
  }
}
