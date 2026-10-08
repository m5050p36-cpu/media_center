import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/language_provider.dart';
import '../providers/player_provider.dart';
import '../services/brightness_service.dart';
import '../services/pip_service.dart';
import '../theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<MediaItem> items;
  final int startIndex;

  const VideoPlayerScreen({
    super.key,
    required this.items,
    required this.startIndex,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  bool _showControls = true;
  Timer? _hideTimer;

  // ✅ ثابت — يُقرأ مرة واحدة
  Size _screenSize = Size.zero;

  bool _isDraggingSeek = false;
  bool _isDraggingBrightness = false;
  bool _isDraggingVolume = false;

  Duration _seekTargetPosition = Duration.zero;
  double _brightnessValue = 0.5;
  double _volumeValue = 1.0;

  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragStartValue = 0;

  bool _showSeekIndicator = false;
  bool _seekForward = true;
  Timer? _seekIndicatorTimer;

  bool _pipAvailable = false;
  bool _disposed = false;

  // ✅ Timer دوري بدلاً من Streams
  Timer? _progressTimer;
  Duration _currentPos = Duration.zero;
  Duration _totalDur = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    BrightnessService.init();
    _brightnessValue = BrightnessService.current;

    PipService.isAvailable().then((v) {
      if (_disposed) return;
      setState(() => _pipAvailable = v);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideo();
    });

    _startHideTimer();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _progressTimer?.cancel();
    BrightnessService.reset();

    // ✅ أوقف الفيديو عند الخروج
    try {
      context.read<PlayerProvider>().stopVideo();
    } catch (_) {}

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // ✅ PiP تلقائي عند التصغير
    if (state == AppLifecycleState.inactive) {
      if (_pipAvailable && mounted && !_disposed) {
        PipService.enterPip(aspectX: 16, aspectY: 9);
      }
    }

    // ✅ أوقف التحديث عند عدم النشاط
    if (state == AppLifecycleState.paused) {
      _progressTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startProgressTimer();
    }
  }

  /// ⚡ Timer دوري يحدّث الوقت (4 مرات في الثانية)
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        if (_disposed || !mounted) return;
        final c = context.read<PlayerProvider>().videoController;
        if (c == null || !c.value.isInitialized) return;

        final newPos = c.value.position;
        final newDur = c.value.duration;

        // ✅ تحديث فقط عند التغير الفعلي
        if (newPos == _currentPos && newDur == _totalDur) return;

        setState(() {
          _currentPos = newPos;
          _totalDur = newDur;
        });
      },
    );
  }

  Future<void> _loadVideo() async {
    final p = context.read<PlayerProvider>();
    await p.loadVideoQueue(widget.items, startIndex: widget.startIndex);
    if (_disposed || !mounted) return;

    // ابدأ التحديث
    _startProgressTimer();

    // اقرأ القيم الأولية
    final c = p.videoController;
    if (c != null && c.value.isInitialized) {
      setState(() {
        _currentPos = c.value.position;
        _totalDur = c.value.duration;
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed || !mounted) return;
      setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_disposed) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  // ═══════ Implicit Gestures ═══════
  void _onVerticalDragStart(DragStartDetails d) {
    final screenWidth = _screenSize.width;
    _dragStartY = d.localPosition.dy;
    _dragStartX = d.localPosition.dx;

    if (d.localPosition.dx < screenWidth / 2) {
      _isDraggingBrightness = true;
      _dragStartValue = _brightnessValue;
    } else {
      _isDraggingVolume = true;
      _dragStartValue = _volumeValue;
    }
    _hideTimer?.cancel();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_screenSize.height == 0) return;
    final delta = (_dragStartY - d.localPosition.dy) / _screenSize.height;
    final newValue = (_dragStartValue + delta * 1.5).clamp(0.05, 1.0);

    if (_isDraggingBrightness) {
      setState(() => _brightnessValue = newValue);
      BrightnessService.setApplication(newValue);
    } else if (_isDraggingVolume) {
      setState(() => _volumeValue = newValue);
      context.read<PlayerProvider>().videoController?.setVolume(newValue);
    }
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    _isDraggingBrightness = false;
    _isDraggingVolume = false;
    _startHideTimer();
  }

  void _onHorizontalDragStart(DragStartDetails d) {
    final c = context.read<PlayerProvider>().videoController;
    if (c == null || _totalDur.inMilliseconds == 0) return;
    _isDraggingSeek = true;
    _dragStartX = d.localPosition.dx;
    _seekTargetPosition = _currentPos;
    _hideTimer?.cancel();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!_isDraggingSeek || _screenSize.width == 0) return;
    final delta = (d.localPosition.dx - _dragStartX) / _screenSize.width;
    final totalMs = _totalDur.inMilliseconds;
    if (totalMs == 0) return;
    final changeMs = (delta * totalMs * 0.5).round();
    final newMs =
        (_seekTargetPosition.inMilliseconds + changeMs).clamp(0, totalMs);
    setState(() {
      _seekTargetPosition = Duration(milliseconds: newMs);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    if (!_isDraggingSeek) return;
    _isDraggingSeek = false;
    context.read<PlayerProvider>().videoController?.seekTo(_seekTargetPosition);
    _startHideTimer();
  }

  void _onDoubleTapDown(TapDownDetails d) {
    final screenWidth = _screenSize.width;
    final c = context.read<PlayerProvider>().videoController;
    if (c == null) return;

    final isForward = d.localPosition.dx > screenWidth / 2;
    const duration = Duration(seconds: 10);

    final currentMs = _currentPos.inMilliseconds;
    final totalMs = _totalDur.inMilliseconds;
    final offsetMs = duration.inMilliseconds;

    int newMs = isForward ? currentMs + offsetMs : currentMs - offsetMs;
    newMs = newMs.clamp(0, totalMs);

    c.seekTo(Duration(milliseconds: newMs));

    setState(() {
      _seekForward = isForward;
      _showSeekIndicator = true;
    });

    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 700), () {
      if (_disposed || !mounted) return;
      setState(() => _showSeekIndicator = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ LayoutBuilder يقرأ الأبعاد مرة واحدة فقط
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_screenSize.width == 0) {
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
        }

        return Consumer<PlayerProvider>(
          builder: (context, p, _) {
            final c = p.videoController;

            if (c == null || !c.value.isInitialized) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return Scaffold(
              backgroundColor: Colors.black,
              body: GestureDetector(
                onTap: _toggleControls,
                onDoubleTapDown: _onDoubleTapDown,
                onVerticalDragStart: _onVerticalDragStart,
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                onHorizontalDragStart: _onHorizontalDragStart,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ✅ RepaintBoundary لعزل الفيديو
                    RepaintBoundary(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c),
                        ),
                      ),
                    ),

                    if (_isDraggingSeek) _buildSeekOverlay(),
                    if (_showSeekIndicator) _buildDoubleTapIndicator(),
                    if (_isDraggingBrightness)
                      _buildVerticalIndicator(
                        icon: Icons.brightness_6,
                        value: _brightnessValue,
                      ),
                    if (_isDraggingVolume)
                      _buildVerticalIndicator(
                        icon: _volumeValue == 0
                            ? Icons.volume_off
                            : Icons.volume_up,
                        value: _volumeValue,
                      ),

                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: _buildControls(p),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildControls(PlayerProvider p) {
    final c = p.videoController!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.25, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(p),
            Expanded(child: Center(child: _buildCenterControls(p))),
            _buildBottomBar(p, c),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(PlayerProvider p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              BrightnessService.reset();
              final player = context.read<PlayerProvider>();
              await player.stopVideo();
              if (_disposed || !mounted) return;
              Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: Text(
              p.currentVideo?.title ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt,
                color: Colors.white, size: 22),
            tooltip: 'نافذة عائمة',
            onPressed: _tryEnterPip,
          ),
          IconButton(
            icon: const Icon(Icons.replay, color: Colors.white70, size: 20),
            onPressed: () {
              p.videoController?.seekTo(Duration.zero);
              setState(() => _currentPos = Duration.zero);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _tryEnterPip() async {
    final available = await PipService.isAvailable();
    if (!available) {
      if (_disposed || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Picture-in-Picture غير مدعوم على هذا الجهاز'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    final ok = await PipService.enterPip(aspectX: 16, aspectY: 9);
    if (!ok && mounted && !_disposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تفعيل PiP')),
      );
    }
  }

  Widget _buildCenterControls(PlayerProvider p) {
    final c = p.videoController!;
    final isPlaying = c.value.isPlaying;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous, color: Colors.white),
          onPressed: () async {
            await p.previousVideo();
            if (_disposed || !mounted) return;
            _resetProgress();
          },
        ),
        const SizedBox(width: 30),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 52,
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
            onPressed: () async {
              await p.toggleVideoPlay();
              _startHideTimer();
              if (mounted && !_disposed) setState(() {});
            },
          ),
        ),
        const SizedBox(width: 30),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next, color: Colors.white),
          onPressed: () async {
            await p.nextVideo();
            if (_disposed || !mounted) return;
            _resetProgress();
          },
        ),
      ],
    );
  }

  void _resetProgress() {
    final c = context.read<PlayerProvider>().videoController;
    if (c != null && c.value.isInitialized) {
      setState(() {
        _currentPos = c.value.position;
        _totalDur = c.value.duration;
      });
    }
  }

  Widget _buildBottomBar(PlayerProvider p, VideoPlayerController c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _formatDuration(_currentPos),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14),
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                    thumbColor: AppTheme.primary,
                    overlayColor: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _currentPos.inMilliseconds
                        .toDouble()
                        .clamp(0, _totalDur.inMilliseconds.toDouble()),
                    max: _totalDur.inMilliseconds > 0
                        ? _totalDur.inMilliseconds.toDouble()
                        : 1.0,
                    onChanged: (v) {
                      c.seekTo(Duration(milliseconds: v.toInt()));
                      setState(() {
                        _currentPos = Duration(milliseconds: v.toInt());
                      });
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(_totalDur),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'عشوائي',
                icon: Icon(
                  Icons.shuffle,
                  color: p.videoOrder == PlayOrder.shuffle
                      ? AppTheme.primary
                      : Colors.white70,
                  size: 22,
                ),
                onPressed: () {
                  p.setVideoOrder(
                    p.videoOrder == PlayOrder.shuffle
                        ? PlayOrder.forward
                        : PlayOrder.shuffle,
                  );
                },
              ),
              IconButton(
                tooltip: 'تكرار الفيديو',
                icon: Icon(
                  Icons.loop,
                  color: p.videoLoop ? AppTheme.primary : Colors.white70,
                  size: 22,
                ),
                onPressed: () => p.setVideoLoop(!p.videoLoop),
              ),
              IconButton(
                tooltip: 'السرعة',
                icon: const Icon(Icons.speed, color: Colors.white70, size: 22),
                onPressed: () => _showVideoSpeedDialog(),
              ),
              IconButton(
                tooltip: 'إعادة تحميل',
                icon:
                    const Icon(Icons.refresh, color: Colors.white70, size: 22),
                onPressed: () async {
                  await p.loadVideoQueue(p.videoQueue,
                      startIndex: p.videoIndex);
                  if (_disposed || !mounted) return;
                  _resetProgress();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeekOverlay() {
    final diff = _seekTargetPosition - _currentPos;
    final seconds = diff.inSeconds;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${seconds >= 0 ? "+" : ""}${seconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDuration(_seekTargetPosition)} / ${_formatDuration(_totalDur)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoubleTapIndicator() {
    final isRtl = context.read<LanguageProvider>().isArabic;
    return Align(
      alignment: _seekForward
          ? (isRtl ? Alignment.centerLeft : Alignment.centerRight)
          : (isRtl ? Alignment.centerRight : Alignment.centerLeft),
      child: FractionallySizedBox(
        widthFactor: 0.4,
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(200),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _seekForward ? Icons.fast_forward : Icons.fast_rewind,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 6),
                const Text(
                  '10s',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalIndicator({
    required IconData icon,
    required double value,
  }) {
    final percent = (value * 100).round();
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$percent%',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _showVideoSpeedDialog() {
    final c = context.read<PlayerProvider>().videoController;
    if (c == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('سرعة الفيديو'),
        content: Wrap(
          spacing: 8,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
              .map((v) => ChoiceChip(
                    label: Text('${v}x'),
                    selected: c.value.playbackSpeed == v,
                    onSelected: (_) {
                      c.setPlaybackSpeed(v);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}
