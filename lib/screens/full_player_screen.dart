import 'dart:io';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/i18n.dart';
import '../providers/language_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  bool _showQueue = false;

  @override
  void initState() {
    super.initState();
    MiniPlayer.hide();
  }

  @override
  void dispose() {
    MiniPlayer.show();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final lang = context.watch<LanguageProvider>();
    final t = I18n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = p.currentAudio;

    if (current == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(t.get('no_audio'))),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppTheme.primary.withValues(alpha: 0.35),
                    AppTheme.bgDark,
                    AppTheme.bgDark,
                  ]
                : [
                    AppTheme.primary.withValues(alpha: 0.25),
                    AppTheme.bgLight,
                    AppTheme.bgLight,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ═══ الشريط العلوي ═══
              _buildTopBar(t, lang),

              // ═══ المحتوى ═══
              Expanded(
                child: _showQueue
                    ? _buildQueueView(p, t)
                    : _buildPlayerView(p, t, lang, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // الشريط العلوي
  // ═══════════════════════════════════════════════
  Widget _buildTopBar(dynamic t, LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _showQueue ? 'قائمة التشغيل' : 'قيد التشغيل',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          IconButton(
            icon: Icon(_showQueue ? Icons.music_note : Icons.queue_music),
            onPressed: () => setState(() => _showQueue = !_showQueue),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // العرض الرئيسي للمشغل
  // ═══════════════════════════════════════════════
  Widget _buildPlayerView(
      PlayerProvider p, dynamic t, LanguageProvider lang, bool isDark) {
    final current = p.currentAudio!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // ═══ صورة الغلاف (مع Hero Animation) ═══
          Hero(
            tag: 'album_art_${current.path}',
            child: _buildAlbumArt(current),
          ),

          const SizedBox(height: 30),

          // ═══ العنوان والفنان ═══
          _buildTitleSection(p, current, lang),

          const SizedBox(height: 24),

          // ═══ شريط التقدم ═══
          _buildProgressBar(p),

          const SizedBox(height: 16),

          // ═══ الأزرار الرئيسية ═══
          _buildMainControls(p, t),

          const SizedBox(height: 20),

          // ═══ الأزرار الثانوية ═══
          _buildSecondaryControls(p, t),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // صورة الغلاف
  // ═══════════════════════════════════════════════
  Widget _buildAlbumArt(MediaItem current) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: current.albumArt != null && current.albumArt!.isNotEmpty
            ? _buildArtImage(current.albumArt!)
            : _buildPlaceholderArt(current),
      ),
    );
  }

  Widget _buildArtImage(String url) {
    // إذا كان رابط إنترنت
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) => p == null
            ? child
            : _buildLoadingArt(),
        errorBuilder: (_, __, ___) => _buildDefaultArt(),
      );
    }
    // إذا كان ملف محلي
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildDefaultArt(),
    );
  }

  Widget _buildLoadingArt() {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.2),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildPlaceholderArt(MediaItem current) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.accent,
            AppTheme.primary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note, size: 100, color: Colors.white),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              current.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultArt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.accent],
        ),
      ),
      child: const Icon(Icons.music_note, size: 100, color: Colors.white),
    );
  }

  // ═══════════════════════════════════════════════
  // العنوان + الفنان + زر المفضلة
  // ═══════════════════════════════════════════════
  Widget _buildTitleSection(
      PlayerProvider p, MediaItem current, LanguageProvider lang) {
    final isFav = p.isFavorite(current.path);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                current.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                current.artist ?? current.album ?? 'Media Center',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          iconSize: 32,
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.redAccent : null,
          ),
          onPressed: () async {
            final added = await p.toggleFavorite(current.path);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(added ? 'أُضيفت للمفضلة ❤️' : 'أُزيلت من المفضلة'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // شريط التقدم
  // ═══════════════════════════════════════════════
  Widget _buildProgressBar(PlayerProvider p) {
    return StreamBuilder<Duration>(
      stream: p.audioPlayer.positionStream,
      builder: (_, posSnap) {
        return StreamBuilder<Duration?>(
          stream: p.audioPlayer.durationStream,
          builder: (_, durSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final dur = durSnap.data ?? Duration.zero;
            return ProgressBar(
              progress: pos,
              total: dur,
              onSeek: p.seek,
              baseBarColor:
                  Theme.of(context).dividerColor.withValues(alpha: 0.3),
              progressBarColor: AppTheme.primary,
              bufferedBarColor:
                  AppTheme.primary.withValues(alpha: 0.3),
              thumbColor: AppTheme.primary,
              barHeight: 4,
              thumbRadius: 7,
              timeLabelTextStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // الأزرار الرئيسية (shuffle, prev, play, next, repeat)
  // ═══════════════════════════════════════════════
  Widget _buildMainControls(PlayerProvider p, dynamic t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        IconButton(
          iconSize: 26,
          tooltip: 'عشوائي',
          icon: Icon(
            Icons.shuffle,
            color: p.audioOrder == PlayOrder.shuffle
                ? AppTheme.primary
                : Theme.of(context).iconTheme.color,
          ),
          onPressed: () {
            p.setAudioOrder(
              p.audioOrder == PlayOrder.shuffle
                  ? PlayOrder.forward
                  : PlayOrder.shuffle,
            );
          },
        ),

        // Previous
        IconButton(
          iconSize: 38,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: p.previousAudio,
        ),

        // Play/Pause (كبير في المنتصف)
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: p.togglePlay,
              child: Icon(
                p.audioPlayer.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // Next
        IconButton(
          iconSize: 38,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: () => p.nextAudio(),
        ),

        // Repeat
        PopupMenuButton<AudioRepeatMode>(
          iconSize: 26,
          tooltip: 'وضع التكرار',
          icon: Icon(
            _repeatIcon(p.audioRepeat),
            color: p.audioRepeat != AudioRepeatMode.none
                ? AppTheme.primary
                : Theme.of(context).iconTheme.color,
          ),
          onSelected: p.setAudioRepeat,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: AudioRepeatMode.none,
              child: Row(children: [
                Icon(Icons.repeat, size: 20),
                SizedBox(width: 12),
                Text('بدون تكرار'),
              ]),
            ),
            PopupMenuItem(
              value: AudioRepeatMode.once,
              child: Row(children: [
                Icon(Icons.repeat_one, size: 20),
                SizedBox(width: 12),
                Text('تكرار مرة'),
              ]),
            ),
            PopupMenuItem(
              value: AudioRepeatMode.twice,
              child: Row(children: [
                Icon(Icons.repeat, size: 20),
                SizedBox(width: 12),
                Text('تكرار مرتين'),
              ]),
            ),
            PopupMenuItem(
              value: AudioRepeatMode.thrice,
              child: Row(children: [
                Icon(Icons.repeat, size: 20),
                SizedBox(width: 12),
                Text('تكرار 3 مرات'),
              ]),
            ),
            PopupMenuItem(
              value: AudioRepeatMode.loopAll,
              child: Row(children: [
                Icon(Icons.all_inclusive, size: 20),
                SizedBox(width: 12),
                Text('تكرار الكل'),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // الأزرار الثانوية (سرعة + نوم)
  // ═══════════════════════════════════════════════
  Widget _buildSecondaryControls(PlayerProvider p, dynamic t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // سرعة التشغيل
        _buildPillButton(
          icon: Icons.speed,
          label: '${p.playbackSpeed}x',
          onTap: () => _showSpeedSheet(p),
        ),

        // مؤقت النوم
        _buildPillButton(
          icon: p.isSleepTimerActive
              ? Icons.bedtime
              : Icons.bedtime_outlined,
          label: p.isSleepTimerActive && p.remainingSleepTime != null
              ? _formatDuration(p.remainingSleepTime!)
              : 'مؤقت',
          color: p.isSleepTimerActive ? Colors.orangeAccent : null,
          onTap: () => _showSleepTimerSheet(p),
        ),

        // تكرار الحالي
        _buildPillButton(
          icon: Icons.replay,
          label: 'من البداية',
          onTap: () {
            p.audioPlayer.seek(Duration.zero);
          },
        ),
      ],
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (color ?? AppTheme.primary).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _repeatIcon(AudioRepeatMode mode) {
    switch (mode) {
      case AudioRepeatMode.none:
        return Icons.repeat;
      case AudioRepeatMode.once:
        return Icons.repeat_one;
      case AudioRepeatMode.twice:
        return Icons.repeat;
      case AudioRepeatMode.thrice:
        return Icons.repeat;
      case AudioRepeatMode.loopAll:
        return Icons.all_inclusive;
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ═══════════════════════════════════════════════
  // قائمة التشغيل
  // ═══════════════════════════════════════════════
  Widget _buildQueueView(PlayerProvider p, dynamic t) {
    if (p.audioQueue.isEmpty) {
      return Center(child: Text(t.get('no_audio')));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: p.audioQueue.length,
      itemBuilder: (_, i) {
        final item = p.audioQueue[i];
        final isCurrent = i == p.audioIndex;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppTheme.primary.withValues(alpha: 0.15)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: Icon(
              isCurrent ? Icons.equalizer : Icons.music_note,
              color: isCurrent ? AppTheme.primary : null,
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : null,
                color: isCurrent ? AppTheme.primary : null,
              ),
            ),
            subtitle: item.album != null
                ? Text(item.album!,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)
                : null,
            trailing: isCurrent
                ? const Icon(Icons.volume_up,
                    color: AppTheme.primary, size: 20)
                : null,
            onTap: () {
              p.audioPlayer.seek(Duration.zero, index: i);
              p.audioPlayer.play();
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // Bottom Sheet: سرعة التشغيل
  // ═══════════════════════════════════════════════
  void _showSpeedSheet(PlayerProvider p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سرعة التشغيل',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '${p.playbackSpeed.toStringAsFixed(2)}x',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              Slider(
                value: p.playbackSpeed.clamp(0.5, 3.0),
                min: 0.5,
                max: 3.0,
                divisions: 25,
                label: '${p.playbackSpeed.toStringAsFixed(2)}x',
                onChanged: (v) async {
                  await p.setPlaybackSpeed(v);
                  setSt(() {});
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
                    .map((v) => ChoiceChip(
                          label: Text('${v}x'),
                          selected: (p.playbackSpeed - v).abs() < 0.01,
                          onSelected: (_) async {
                            await p.setPlaybackSpeed(v);
                            setSt(() {});
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // Bottom Sheet: مؤقت النوم
  // ═══════════════════════════════════════════════
  void _showSleepTimerSheet(PlayerProvider p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'مؤقت النوم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (p.isSleepTimerActive && p.remainingSleepTime != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'متوقف بعد: ${_formatDuration(p.remainingSleepTime!)}',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                (const Duration(minutes: 5), '5 د'),
                (const Duration(minutes: 10), '10 د'),
                (const Duration(minutes: 15), '15 د'),
                (const Duration(minutes: 30), '30 د'),
                (const Duration(hours: 1), 'ساعة'),
                (const Duration(hours: 2), 'ساعتان'),
              ].map((e) {
                return ActionChip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(e.$2),
                  onPressed: () {
                    p.startSleepTimer(e.$1);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            if (p.isSleepTimerActive)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton.icon(
                  onPressed: () {
                    p.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.cancel_outlined,
                      color: Colors.redAccent),
                  label: const Text(
                    'إلغاء المؤقت',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
