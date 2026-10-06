import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' as jab;
import 'package:video_player/video_player.dart';
import '../services/favorites_service.dart';
import '../services/playback_state_service.dart';

/// وضعيات تكرار الصوت
enum AudioRepeatMode { none, once, twice, thrice, loopAll }

/// ترتيب التشغيل
enum PlayOrder { forward, reverse, shuffle }

/// عنصر وسائط موحّد (كلاسنا الخاص — لا يتعارض مع jab.MediaItem)
class MediaItem {
  final String title;
  final String path;
  final bool isVideo;
  final Duration? duration;
  final String? artist;
  final String? album;

  const MediaItem({
    required this.title,
    required this.path,
    this.isVideo = false,
    this.duration,
    this.artist,
    this.album,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'path': path,
        'isVideo': isVideo,
      };
}

class PlayerProvider extends ChangeNotifier {
  // ═══════════ Audio ═══════════
  final AudioPlayer audioPlayer = AudioPlayer();

  List<MediaItem> audioQueue = [];
  List<MediaItem> originalAudioOrder = [];
  int audioIndex = 0;
  AudioRepeatMode audioRepeat = AudioRepeatMode.none;
  PlayOrder audioOrder = PlayOrder.forward;
  int _repeatCounter = 0;

  // ─── المفضلة ───
  Set<String> favorites = {};

  // ─── مؤقت النوم ───
  Timer? _sleepTimer;
  DateTime? _sleepEndTime;
  Duration? _remainingSleepTime;

  // ─── سرعة التشغيل ───
  double playbackSpeed = 1.0;

  // ─── استئناف آخر موضع ───
  Timer? _positionSaveTimer;

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
    playbackSpeed = await PlaybackStateService.loadSpeed();
    await audioPlayer.setSpeed(playbackSpeed);

    favorites = await FavoritesService.load();

    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onAudioComplete();
      }
    });

    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentPosition();
    });

    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // تحميل قائمة التشغيل — باستخدام ConcatenatingAudioSource
  // ═══════════════════════════════════════════════
  Future<void> loadAudioQueue(List<MediaItem> items,
      {int startIndex = 0}) async {
    audioQueue = List.from(items);
    originalAudioOrder = List.from(items);
    audioIndex = startIndex;
    _repeatCounter = 0;

    try {
      // بناء قائمة المصادر مع tags للإشعار
      final sources = items.map((item) {
        return AudioSource.uri(
          Uri.file(item.path),
          tag: jab.MediaItem(
            id: item.path,
            title: item.title,
            album: item.album ?? 'Media Center',
            artUri: Uri.parse(
                'https://qoarusrrbarbqhstqmae.supabase.co/storage/v1/object/public/banners/default.png'),
          ),
        );
      }).toList();

      final playlist = ConcatenatingAudioSource(children: sources);

      await audioPlayer.setAudioSource(
        playlist,
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );
      await audioPlayer.setSpeed(playbackSpeed);
      await audioPlayer.play();
    } catch (e) {
      debugPrint('loadAudioQueue error: $e');
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════
  // استئناف آخر موضع تشغيل
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

  // ═══════════════════════════════════════════════
  // التنقل
  // ═══════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════
  // التحكم في التشغيل
  // ═══════════════════════════════════════════════
  Future<void> togglePlay() async {
    if (audioPlayer.playing) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
  }

  // ═══════════════════════════════════════════════
  // الإعدادات
  // ═══════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════
  // المفضلة
  // ═══════════════════════════════════════════════
  Future<bool> toggleFavorite(String path) async {
    final added = await FavoritesService.toggle(path);
    favorites = await FavoritesService.load();
    notifyListeners();
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

  // ═══════════════════════════════════════════════
  // ═══════════ Video ═══════════
  // ═══════════════════════════════════════════════
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
    videoController =
        VideoPlayerController.file(File(videoQueue[videoIndex].path));
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

  // ═══════════════════════════════════════════════
  @override
  void dispose() {
    _positionSaveTimer?.cancel();
    _sleepTimer?.cancel();
    audioPlayer.dispose();
    videoController?.dispose();
    super.dispose();
  }
}
