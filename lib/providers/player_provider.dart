import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

/// وضعيات تكرار الصوت (تم تغيير الاسم لتفادي التعارض مع Flutter)
enum AudioRepeatMode { none, once, twice, thrice, loopAll }

/// ترتيب التشغيل
enum PlayOrder { forward, reverse, shuffle }

/// عنصر وسائط موحّد
class MediaItem {
  final String title;
  final String path;
  final bool isVideo;
  const MediaItem({
    required this.title,
    required this.path,
    this.isVideo = false,
  });
}

class PlayerProvider extends ChangeNotifier {
  // ═══════════ Audio ═══════════
  final AudioPlayer audioPlayer = AudioPlayer();
  List<MediaItem> audioQueue = [];
  int audioIndex = 0;
  AudioRepeatMode audioRepeat = AudioRepeatMode.none;
  PlayOrder audioOrder = PlayOrder.forward;
  int _repeatCounter = 0;

  MediaItem? get currentAudio =>
      audioQueue.isEmpty ? null : audioQueue[audioIndex];

  PlayerProvider() {
    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onAudioComplete();
      }
    });
  }

  Future<void> loadAudioQueue(List<MediaItem> items,
      {int startIndex = 0}) async {
    audioQueue = items;
    audioIndex = startIndex;
    _repeatCounter = 0;
    await _playCurrentAudio();
  }

  Future<void> _playCurrentAudio() async {
    if (audioQueue.isEmpty) return;
    try {
      await audioPlayer.setFilePath(audioQueue[audioIndex].path);
      await audioPlayer.play();
    } catch (e) {
      debugPrint('Audio error: $e');
    }
    notifyListeners();
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
      case AudioRepeatMode.none:
        await nextAudio(auto: true);
        break;
    }
  }

  Future<void> nextAudio({bool auto = false}) async {
    if (audioQueue.isEmpty) return;
    if (!auto && audioOrder == PlayOrder.shuffle) {
      audioIndex = _randomIndex();
    } else {
      switch (audioOrder) {
        case PlayOrder.reverse:
          audioIndex =
              (audioIndex - 1 + audioQueue.length) % audioQueue.length;
          break;
        default:
          audioIndex = (audioIndex + 1) % audioQueue.length;
      }
    }
    _repeatCounter = 0;
    await _playCurrentAudio();
  }

  Future<void> previousAudio() async {
    if (audioQueue.isEmpty) return;
    if (audioOrder == PlayOrder.shuffle) {
      audioIndex = _randomIndex();
    } else {
      audioIndex = (audioIndex - 1 + audioQueue.length) % audioQueue.length;
    }
    await _playCurrentAudio();
  }

  int _randomIndex() {
    if (audioQueue.length <= 1) return 0;
    int idx;
    do {
      idx = DateTime.now().microsecondsSinceEpoch % audioQueue.length;
    } while (idx == audioIndex);
    return idx;
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

  Future<void> togglePlay() async {
    if (audioPlayer.playing) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play();
    }
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

  @override
  void dispose() {
    audioPlayer.dispose();
    videoController?.dispose();
    super.dispose();
  }
}
