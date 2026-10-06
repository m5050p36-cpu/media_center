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
  String _searchQuery = '';
  String _sortBy = 'name'; // name, duration, date

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

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
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'path':
        sorted.sort((a, b) => a.path.compareTo(b.path));
        break;
    }
    setState(() => _sortedAudio = sorted);
  }

  void _filterSearch(String query) {
    setState(() {
      _searchQuery = query;
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

  @override
  Widget build(BuildContext context) {
    final t = I18n.of(context);
    final p = context.watch<PlayerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _searchQuery.isEmpty
            ? Text(t.get('audio'))
            : TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'بحث...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _filterSearch,
              ),
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
            icon: Icon(_searchQuery.isEmpty ? Icons.search : Icons.close),
            onPressed: () {
              if (_searchQuery.isEmpty) {
                setState(() => _searchQuery = 'search_placeholder');
              } else {
                _filterSearch('');
              }
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
            const Tab(text: 'المفضلة', icon: Icon(Icons.favorite, size: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _searchQuery.isNotEmpty
                    ? _listView(_searchResults, t)
                    : _listView(_sortedAudio, t),
                _foldersView(t),
                _listView(p.favoriteTracks, t, isFavorites: true),
              ],
            ),
          ),
          if (p.currentAudio != null) _playerBar(p, t),
        ],
      ),
    );
  }

  Widget _listView(List<MediaItem> items, S t, {bool isFavorites = false}) {
    if (items.isEmpty) {
      return Center(
        child: Text(isFavorites ? 'لا توجد مفضلة' : t.get('no_audio')),
      );
    }
    final p = context.watch<PlayerProvider>();
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final isCurrent = p.currentAudio?.path == it.path;
        final isFav = p.isFavorite(it.path);
        return ListTile(
          tileColor: isCurrent
              ? AppTheme.primary.withValues(alpha: 0.15)
              : null,
          leading: Icon(
            isCurrent ? Icons.equalizer : Icons.music_note,
            color: isCurrent ? AppTheme.primary : null,
          ),
          title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            it.album ?? '',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : null,
            ),
            onPressed: () async {
              await p.toggleFavorite(it.path);
            },
          ),
          onTap: () => p.loadAudioQueue(items, startIndex: i),
        );
      },
    );
  }

  Widget _foldersView(S t) {
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
            return ListTile(
              contentPadding:
                  const EdgeInsets.only(left: 40, right: 16),
              leading: const Icon(Icons.music_note,
                  size: 18, color: AppTheme.primary),
              title:
                  Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => context.read<PlayerProvider>().loadAudioQueue(
                    e.value,
                    startIndex: e.value.indexOf(it),
                  ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _playerBar(PlayerProvider p, S t) {
    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── شريط التقدم ───
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
          const SizedBox(height: 4),

          // ─── أزرار التحكم ───
          Row(
            children: [
              // Shuffle
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

              // Previous
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: p.previousAudio,
              ),

              // Play / Pause
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

              // Next
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: () => p.nextAudio(),
              ),

              // Repeat
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
                      value: AudioRepeatMode.once, child: Text('تكرار مرة')),
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

          // ─── العنوان + أدوات إضافية ───
          Row(
            children: [
              Expanded(
                child: Text(
                  p.currentAudio?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),

              // سرعة التشغيل
              IconButton(
                tooltip: 'السرعة',
                icon: const Icon(Icons.speed, size: 20),
                onPressed: () => _showSpeedDialog(p),
              ),

              // مؤقت النوم
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
              ),

              // المفضلة
              IconButton(
                tooltip: 'مفضلة',
                icon: Icon(
                  p.isFavorite(p.currentAudio?.path ?? '')
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: p.isFavorite(p.currentAudio?.path ?? '')
                      ? Colors.redAccent
                      : null,
                  size: 20,
                ),
                onPressed: () async {
                  final path = p.currentAudio?.path;
                  if (path != null) await p.toggleFavorite(path);
                },
              ),
            ],
          ),

          // مؤشر مؤقت النوم
          if (p.isSleepTimerActive && p.remainingSleepTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⏰ ${_formatDuration(p.remainingSleepTime!)}',
                style: const TextStyle(
                    fontSize: 11, color: Colors.orangeAccent),
              ),
            ),
        ],
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
        return Icons.repeat_on;
      case AudioRepeatMode.thrice:
        return Icons.repeat_on;
      case AudioRepeatMode.loopAll:
        return Icons.all_inclusive;
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ═══════════════════════════════════════════════
  // حوار سرعة التشغيل
  // ═══════════════════════════════════════════════
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
                value: p.playbackSpeed,
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
                          selected: p.playbackSpeed == v,
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

  // ═══════════════════════════════════════════════
  // حوار مؤقت النوم
  // ═══════════════════════════════════════════════
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.isSleepTimerActive && p.remainingSleepTime != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'متوقف بعد: ${_formatDuration(p.remainingSleepTime!)}',
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold),
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
        actions: [
          if (p.isSleepTimerActive)
            TextButton(
              onPressed: () {
                p.cancelSleepTimer();
                Navigator.pop(context);
              },
              child: const Text('إلغاء المؤقت',
                  style: TextStyle(color: Colors.redAccent)),
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
