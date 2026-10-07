import 'dart:io';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../i18n/i18n.dart';
import '../i18n/strings.dart';
import '../providers/player_provider.dart';
import '../services/cache_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'full_player_screen.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});
  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<MediaItem> _allAudio = [];
  Map<String, List<MediaItem>> _folders = {};
  List<MediaItem> _searchResults = [];
  List<MediaItem> _sortedAudio = [];
  bool _scanning = false;
  bool _searchMode = false;
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    MiniPlayer.hide();
    _tab = TabController(length: 3, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    MiniPlayer.show();
    _tab.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // تحميل الملفات
  // ═══════════════════════════════════════════════
  Future<void> _loadFiles() async {
    final cached = await CacheService.loadAudioFiles();
    if (cached.isNotEmpty) {
      _applyData(cached);
      if (mounted) {
        final t = I18n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.get('loaded_from_cache')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }

    final shouldRescan = await CacheService.shouldRescan();
    if (!shouldRescan && cached.isNotEmpty) return;

    if (mounted) setState(() => _scanning = true);

    final status = await Permission.audio.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _scanning = false);
      return;
    }

    final dirs = [
      Directory('/storage/emulated/0/Music'),
      Directory('/storage/emulated/0/Download'),
      Directory('/storage/emulated/0/Audio'),
    ];
    final List<Map<String, dynamic>> all = [];

    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File && _isAudio(e.path)) {
          all.add({
            'title': e.path.split('/').last,
            'path': e.path,
            'folder': e.parent.path.split('/').last,
          });
        }
      }
    }

    await CacheService.saveAudioFiles(all);
    _applyData(all);
    if (mounted) setState(() => _scanning = false);
  }

  void _applyData(List<Map<String, dynamic>> items) {
    final folders = <String, List<MediaItem>>{};
    final all = <MediaItem>[];
    for (final m in items) {
      final item = MediaItem(
        title: m['title'] as String,
        path: m['path'] as String,
        album: (m['folder'] as String?) ?? 'Other',
        albumArt: m['albumArt'] as String?,
      );
      all.add(item);
      final f = (m['folder'] as String?) ?? 'Other';
      folders.putIfAbsent(f, () => []).add(item);
    }
    if (!mounted) return;
    setState(() {
      _allAudio = all;
      _folders = folders;
      _sortAudio(_sortBy);
    });
  }

  void _sortAudio(String sortBy) {
    _sortBy = sortBy;
    final sorted = List<MediaItem>.from(_allAudio);
    switch (sortBy) {
      case 'name':
        sorted.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'path':
        sorted.sort((a, b) => a.path.compareTo(b.path));
        break;
    }
    setState(() => _sortedAudio = sorted);
  }

  void _filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        final q = query.toLowerCase();
        _searchResults = _allAudio
            .where((item) =>
                item.title.toLowerCase().contains(q) ||
                item.path.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  bool _isAudio(String p) {
    final e = p.toLowerCase();
    return e.endsWith('.mp3') ||
        e.endsWith('.m4a') ||
        e.endsWith('.wav') ||
        e.endsWith('.aac') ||
        e.endsWith('.ogg') ||
        e.endsWith('.flac');
  }

  // ═══════════════════════════════════════════════
  // تشغيل الأغنية
  // ═══════════════════════════════════════════════
  Future<void> _playTrack(
    List<MediaItem> items,
    int index,
    PlayerProvider p,
  ) async {
    await p.loadAudioQueue(items, startIndex: index);

    if (p.lastError != null && mounted) {
      debugPrint('⚠️ Queue playback failed, trying single: ${p.lastError}');
      final item = items[index];
      await p.playSingle(item, queue: items, index: index);

      if (!mounted) return;
      if (p.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(p.lastError!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // فتح شاشة التشغيل الكاملة
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FullPlayerScreen()),
      );
    }
  }

  // ═══════════════════════════════════════════════
  // 🔥 فتح الشاشة الكاملة من صورة الغلاف
  // ═══════════════════════════════════════════════
  Future<void> _openFromArt(
    List<MediaItem> items,
    int index,
    PlayerProvider p,
  ) async {
    final item = items[index];
    final isCurrent = p.currentAudio?.path == item.path;

    // إذا كانت هذه الأغنية تعمل حالياً → افتح الشاشة الكاملة مباشرة
    if (isCurrent) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FullPlayerScreen()),
        );
      }
      return;
    }

    // وإلا: شغّل الأغنية ثم افتح الشاشة الكاملة
    await _playTrack(items, index, p);
  }

  @override
  Widget build(BuildContext context) {
    final t = I18n.of(context);
    final p = context.watch<PlayerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _searchMode
            ? TextField(
                autofocus: true,
                style: TextStyle(
                  color:
                      Theme.of(context).appBarTheme.titleTextStyle?.color ??
                          Colors.white,
                ),
                decoration: const InputDecoration(
                  hintText: 'بحث...',
                  border: InputBorder.none,
                ),
                onChanged: _filterSearch,
              )
            : Text(t.get('audio')),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: Icon(_searchMode ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchMode = !_searchMode;
                if (!_searchMode) _filterSearch('');
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: _sortAudio,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'name', child: Text('الاسم')),
              PopupMenuItem(value: 'path', child: Text('المسار')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await CacheService.clearAll();
              _loadFiles();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: t.get('all_audio')),
            Tab(text: t.get('folders')),
            const Tab(
              text: 'المفضلة',
              icon: Icon(Icons.favorite, size: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (p.lastError != null)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.redAccent.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.lastError!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.redAccent),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _searchMode
                    ? _listView(_searchResults, t, p)
                    : _listView(_sortedAudio, t, p),
                _foldersView(t, p),
                _listView(p.favoriteTracks, t, p, isFavorites: true),
              ],
            ),
          ),

          if (p.currentAudio != null) _playerBar(p, t),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 🔥 صورة الغلاف (Album Art)
  // ═══════════════════════════════════════════════
  Widget _buildAlbumArt(MediaItem item, {double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _albumArtImage(item),
    );
  }

  Widget _albumArtImage(MediaItem item) {
    final art = item.albumArt;
    if (art == null || art.isEmpty) {
      return _placeholderArt();
    }

    // رابط إنترنت
    if (art.startsWith('http')) {
      return Image.network(
        art,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) =>
            p == null ? child : _placeholderArt(),
        errorBuilder: (_, __, ___) => _placeholderArt(),
      );
    }

    // ملف محلي
    return Image.file(
      File(art),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholderArt(),
    );
  }

  Widget _placeholderArt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.music_note,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // قائمة الأغاني
  // ═══════════════════════════════════════════════
  Widget _listView(
    List<MediaItem> items,
    S t,
    PlayerProvider p, {
    bool isFavorites = false,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFavorites ? Icons.favorite_border : Icons.music_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                isFavorites
                    ? 'لا توجد مفضلة'
                    : (_searchMode ? 'لا نتائج' : t.get('no_audio')),
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final isCurrent = p.currentAudio?.path == it.path;
        final isFav = p.isFavorite(it.path);

        return ListTile(
          tileColor:
              isCurrent ? AppTheme.primary.withValues(alpha: 0.15) : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          // 🔥 الصورة بدل الأيقونة — قابلة للضغط لفتح الشاشة الكاملة
          leading: GestureDetector(
            onTap: () => _openFromArt(items, i, p),
            child: Hero(
              tag: 'album_art_${it.path}',
              child: Stack(
                children: [
                  _buildAlbumArt(it),
                  // شارة "قيد التشغيل" على الصورة
                  if (isCurrent)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          title: Text(
            it.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : null,
              color: isCurrent ? AppTheme.primary : null,
            ),
          ),
          subtitle: Text(
            it.album ?? '',
            style: const TextStyle(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : null,
            ),
            onPressed: () async {
              final added = await p.toggleFavorite(it.path);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(added ? 'أُضيفت للمفضلة' : 'أُزيلت من المفضلة'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          onTap: () => _playTrack(items, i, p),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // عرض المجلدات
  // ═══════════════════════════════════════════════
  Widget _foldersView(S t, PlayerProvider p) {
    if (_folders.isEmpty) {
      return Center(child: Text(t.get('no_folders')));
    }
    return ListView(
      children: _folders.entries.map((e) {
        return ExpansionTile(
          leading: const Icon(Icons.folder, color: Color(0xFFFFB84D)),
          title: Text(e.key),
          subtitle: Text('${e.value.length} ${t.get('files')}'),
          children: e.value.map((it) {
            final isFav = p.isFavorite(it.path);
            final idx = e.value.indexOf(it);
            return ListTile(
              contentPadding:
                  const EdgeInsets.only(left: 40, right: 16, top: 4, bottom: 4),
              leading: GestureDetector(
                onTap: () => _openFromArt(e.value, idx, p),
                child: _buildAlbumArt(it, size: 44),
              ),
              title: Text(
                it.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.redAccent : null,
                  size: 18,
                ),
                onPressed: () async {
                  await p.toggleFavorite(it.path);
                },
              ),
              onTap: () => _playTrack(e.value, idx, p),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════
  // شريط المشغل السفلي (الأصلي — بجميع الميزات)
  // ═══════════════════════════════════════════════
  Widget _playerBar(PlayerProvider p, S t) {
    final current = p.currentAudio;
    if (current == null) return const SizedBox.shrink();

    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ═══ شريط التقدم ═══
          StreamBuilder<Duration>(
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
                    baseBarColor: Colors.grey.withValues(alpha: 0.3),
                    progressBarColor: AppTheme.primary,
                    thumbColor: AppTheme.primary,
                    barHeight: 3,
                    thumbRadius: 6,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 6),

          // ═══ صف العنوان + صورة الغلاف ═══
          Row(
            children: [
              // 🖼️ صورة الغلاف (قابلة للضغط → FullPlayer)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FullPlayerScreen()),
                  );
                },
                child: Hero(
                  tag: 'album_art_${current.path}',
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildSmallCover(current),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 📝 العنوان + المجلد
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FullPlayerScreen()),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        current.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        current.album ?? 'Media Center',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ⚡ سرعة التشغيل
              IconButton(
                tooltip: 'السرعة',
                icon: const Icon(Icons.speed, size: 20),
                onPressed: () => _showSpeedDialog(p),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

              // 🌙 مؤقت النوم
              IconButton(
                tooltip: 'مؤقت النوم',
                icon: Icon(
                  p.isSleepTimerActive
                      ? Icons.bedtime
                      : Icons.bedtime_outlined,
                  color: p.isSleepTimerActive ? Colors.orangeAccent : null,
                  size: 20,
                ),
                onPressed: () => _showSleepTimerDialog(p),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

              // ⛶ فتح الشاشة الكاملة
              IconButton(
                tooltip: 'شاشة كاملة',
                icon: const Icon(Icons.open_in_full, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FullPlayerScreen()),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ═══ صف أزرار التحكم الرئيسية ═══
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'عشوائي',
                icon: Icon(
                  Icons.shuffle,
                  color: p.audioOrder == PlayOrder.shuffle
                      ? AppTheme.primary
                      : null,
                ),
                onPressed: () {
                  p.setAudioOrder(
                    p.audioOrder == PlayOrder.shuffle
                        ? PlayOrder.forward
                        : PlayOrder.shuffle,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: p.previousAudio,
              ),
              IconButton(
                iconSize: 48,
                icon: Icon(
                  p.audioPlayer.playing
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  color: AppTheme.primary,
                ),
                onPressed: p.togglePlay,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: () => p.nextAudio(),
              ),
              PopupMenuButton<AudioRepeatMode>(
                icon: Icon(
                  _repeatIcon(p.audioRepeat),
                  color: p.audioRepeat != AudioRepeatMode.none
                      ? AppTheme.primary
                      : null,
                ),
                onSelected: p.setAudioRepeat,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: AudioRepeatMode.none,
                      child: Text('بدون تكرار')),
                  PopupMenuItem(
                      value: AudioRepeatMode.once,
                      child: Text('تكرار مرة')),
                  PopupMenuItem(
                      value: AudioRepeatMode.twice,
                      child: Text('تكرار مرتين')),
                  PopupMenuItem(
                      value: AudioRepeatMode.thrice,
                      child: Text('تكرار 3 مرات')),
                  PopupMenuItem(
                      value: AudioRepeatMode.loopAll,
                      child: Text('تكرار الكل')),
                ],
              ),
            ],
          ),

          if (p.isSleepTimerActive && p.remainingSleepTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⏰ ${_formatDuration(p.remainingSleepTime!)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // صورة غلاف صغيرة (مع 3 حالات)
  // ═══════════════════════════════════════════════
  Widget _buildSmallCover(MediaItem item) {
    final art = item.albumArt;

    if (art == null || art.isEmpty) return _smallPlaceholder();

    if (art.startsWith('http')) {
      return Image.network(
        art,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) =>
            p == null ? child : _smallPlaceholder(),
        errorBuilder: (_, __, ___) => _smallPlaceholder(),
      );
    }

    return Image.file(
      File(art),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _smallPlaceholder(),
    );
  }

  Widget _smallPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.music_note,
        color: Colors.white,
        size: 22,
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
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSpeedDialog(PlayerProvider p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.speed, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('سرعة التشغيل'),
          ],
        ),
        content: StatefulBuilder(
          builder: (ctx, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${p.playbackSpeed.toStringAsFixed(2)}x',
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog(PlayerProvider p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bedtime, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('مؤقت النوم'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.isSleepTimerActive && p.remainingSleepTime != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'متوقف بعد: ${_formatDuration(p.remainingSleepTime!)}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ...[
                (const Duration(minutes: 5), '5 دقائق'),
                (const Duration(minutes: 10), '10 دقائق'),
                (const Duration(minutes: 15), '15 دقيقة'),
                (const Duration(minutes: 30), '30 دقيقة'),
                (const Duration(hours: 1), 'ساعة'),
                (const Duration(hours: 2), 'ساعتان'),
              ].map((e) => ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(e.$2),
                    onTap: () {
                      p.startSleepTimer(e.$1);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          if (p.isSleepTimerActive)
            TextButton(
              onPressed: () {
                p.cancelSleepTimer();
                Navigator.pop(context);
              },
              child: const Text(
                'إلغاء المؤقت',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
