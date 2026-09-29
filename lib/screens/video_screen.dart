import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<MediaItem> _allVideos = [];
  Map<String, List<MediaItem>> _albums = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final status = await Permission.videos.request();
    if (!status.isGranted) return;
    final dirs = [
      Directory('/storage/emulated/0/Movies'),
      Directory('/storage/emulated/0/DCIM'),
      Directory('/storage/emulated/0/Download'),
    ];
    final List<MediaItem> all = [];
    final Map<String, List<MediaItem>> albums = {};
    for (final d in dirs) {
      if (!await d.exists()) continue;
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is File && _isVideo(e.path)) {
          final item = MediaItem(title: e.path.split('/').last, path: e.path, isVideo: true);
          all.add(item);
          albums.putIfAbsent(e.parent.path.split('/').last, () => []).add(item);
        }
      }
    }
    setState(() {
      _allVideos = all;
      _albums = albums;
    });
  }

  bool _isVideo(String p) {
    final e = p.toLowerCase();
    return e.endsWith('.mp4') || e.endsWith('.mkv') || e.endsWith('.avi') || e.endsWith('.mov') || e.endsWith('.webm');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفيديوهات'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'جميع الفيديوهات'), Tab(text: 'الألبومات')],
        ),
      ),
      body: Column(
        children: [
          if (p.videoController != null && p.videoController!.value.isInitialized)
            AspectRatio(
              aspectRatio: p.videoController!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(p.videoController!),
                  _videoControls(p),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_listView(_allVideos), _albumsView()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoControls(PlayerProvider p) {
    final v = p.videoController!;
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(v.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: p.toggleVideoPlay,
          ),
          IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: p.previousVideo),
          IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: () => p.nextVideo()),
          IconButton(
            icon: Icon(p.videoOrder == PlayOrder.shuffle ? Icons.shuffle : Icons.repeat,
                color: p.videoOrder == PlayOrder.shuffle ? AppTheme.primary : Colors.white),
            onPressed: () => p.setVideoOrder(
              p.videoOrder == PlayOrder.shuffle ? PlayOrder.forward : PlayOrder.shuffle,
            ),
          ),
          IconButton(
            icon: Icon(p.videoLoop ? Icons.loop : Icons.repeat_one,
                color: p.videoLoop ? AppTheme.primary : Colors.white),
            onPressed: () => p.setVideoLoop(!p.videoLoop),
          ),
        ],
      ),
    );
  }

  Widget _listView(List<MediaItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد فيديوهات', style: TextStyle(color: AppTheme.sub)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return ListTile(
          leading: const Icon(Icons.movie, color: Color(0xFF4ECDC4)),
          title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => context.read<PlayerProvider>().loadVideoQueue(items, startIndex: i),
        );
      },
    );
  }

  Widget _albumsView() {
    if (_albums.isEmpty) {
      return const Center(child: Text('لا توجد ألبومات', style: TextStyle(color: AppTheme.sub)));
    }
    return ListView(
      children: _albums.entries.map((e) {
        return ExpansionTile(
          leading: const Icon(Icons.video_library, color: AppTheme.primary),
          title: Text(e.key),
          subtitle: Text('${e.value.length} ملف'),
          children: e.value.map((it) {
            return ListTile(
              contentPadding: const EdgeInsets.only(left: 40, right: 16),
              leading: const Icon(Icons.movie, size: 18, color: Color(0xFF4ECDC4)),
              title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => context.read<PlayerProvider>().loadVideoQueue(e.value, startIndex: e.value.indexOf(it)),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
