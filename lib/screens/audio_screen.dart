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
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final t = I18n.of(context);

    // ─── 1) تحميل من الذاكرة المؤقتة ───
    final cached = await CacheService.loadAudioFiles();
    if (cached.isNotEmpty) {
      _applyData(cached);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.get('loaded_from_cache')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }

    // ─── 2) هل نحتاج إعادة فحص؟ ───
    final shouldRescan = await CacheService.shouldRescan();
    if (!shouldRescan && cached.isNotEmpty) return;

    // ─── 3) فحص فعلي ───
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
      );
      all.add(item);
      final f = (m['folder'] as String?) ?? 'Other';
      folders.putIfAbsent(f, () => []).add(item);
    }
    if (!mounted) return;
    setState(() {
      _allAudio = all;
      _folders = folders;
    });
  }

  bool _isAudio(String p) {
    final e = p.toLowerCase();
    return e.endsWith('.mp3') ||
        e.endsWith('.m4a') ||
        e.endsWith('.wav') ||
        e.endsWith('.aac') ||
        e.endsWith('.ogg');
  }

  @override
  Widget build(BuildContext context) {
    final t = I18n.of(context);
    final p = context.watch<PlayerProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('audio')),
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
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_listView(_allAudio, t), _foldersView(t)],
            ),
          ),
          if (p.currentAudio != null) _playerBar(p, t),
        ],
      ),
    );
  }

  Widget _listView(List<MediaItem> items, S t) {
    if (items.isEmpty) {
      return Center(child: Text(t.get('no_audio')));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return ListTile(
          leading: const Icon(Icons.music_note, color: AppTheme.primary),
          title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => context
              .read<PlayerProvider>()
              .loadAudioQueue(items, startIndex: i),
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
                    onSeek: (d) => p.audioPlayer.seek(d),
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
          Row(
            children: [
              IconButton(
                icon: Icon(
                  p.audioOrder == PlayOrder.shuffle
                      ? Icons.shuffle
                      : Icons.repeat,
                  color: p.audioOrder == PlayOrder.shuffle
                      ? AppTheme.primary
                      : null,
                ),
                onPressed: () {
                  final next = p.audioOrder == PlayOrder.shuffle
                      ? PlayOrder.forward
                      : PlayOrder.shuffle;
                  p.setAudioOrder(next);
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: p.previousAudio,
              ),
              IconButton(
                iconSize: 42,
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
                icon: const Icon(Icons.repeat, color: AppTheme.primary),
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
          Text(
            p.currentAudio?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
