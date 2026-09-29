import 'dart:io';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
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
    final status = await Permission.audio.request();
    if (!status.isGranted) return;

    final dirs = [
      Directory('/storage/emulated/0/Music'),
      Directory('/storage/emulated/0/Download'),
      Directory('/storage/emulated/0/Audio'),
    ];
    final List<MediaItem> all = [];
    final Map<String, List<MediaItem>> folders = {};

    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File && _isAudio(e.path)) {
          final item = MediaItem(title: e.path.split('/').last, path: e.path);
          all.add(item);
          final folderName = e.parent.path.split('/').last;
          folders.putIfAbsent(folderName, () => []).add(item);
        }
      }
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
    final p = context.watch<PlayerProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الصوتيات'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'جميع الصوتيات'), Tab(text: 'المجلدات')],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_listView(_allAudio), _foldersView()],
            ),
          ),
          if (p.currentAudio != null) _playerBar(p),
        ],
      ),
    );
  }

  Widget _listView(List<MediaItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('لا توجد ملفات صوتية',
            style: TextStyle(color: AppTheme.sub)),
      );
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

  Widget _foldersView() {
    if (_folders.isEmpty) {
      return const Center(
        child: Text('لا توجد مجلدات', style: TextStyle(color: AppTheme.sub)),
      );
    }
    return ListView(
      children: _folders.entries.map((e) {
        return ExpansionTile(
          leading: const Icon(Icons.folder, color: Color(0xFFFFB84D)),
          title: Text(e.key),
          subtitle: Text('${e.value.length} ملف'),
          children: e.value.map((it) {
            return ListTile(
              contentPadding:
                  const EdgeInsets.only(left: 40, right: 16),
              leading: const Icon(Icons.music_note,
                  size: 18, color: AppTheme.primary),
              title:
                  Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => context
                  .read<PlayerProvider>()
                  .loadAudioQueue(e.value, startIndex: e.value.indexOf(it)),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _playerBar(PlayerProvider p) {
    return Container(
      color: AppTheme.card,
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
                    baseBarColor: AppTheme.sub.withValues(alpha: 0.3),
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
                      : AppTheme.sub,
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
                  p.audioPlayer.playing ? Icons.pause_circle : Icons.play_circle,
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
                      value: AudioRepeatMode.twice, child: Text('تكرار مرتين')),
                  PopupMenuItem(
                      value: AudioRepeatMode.thrice, child: Text('تكرار 3 مرات')),
                  PopupMenuItem(
                      value: AudioRepeatMode.loopAll, child: Text('تكرار الكل')),
                ],
              ),
            ],
          ),
          Text(
            p.currentAudio?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.sub),
          ),
        ],
      ),
    );
  }
}
