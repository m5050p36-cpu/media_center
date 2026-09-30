import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../i18n/i18n.dart';
import '../providers/player_provider.dart';
import '../services/cache_service.dart';
import '../theme/app_theme.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<MediaItem> _allVideos = [];
  Map<String, List<MediaItem>> _albums = {};
  bool _scanning = false;
  bool _showPlayer = false;

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

    // ─── 1) تحميل من الذاكرة المؤقتة أولاً ───
    final cached = await CacheService.loadVideoFiles();
    if (cached.isNotEmpty) {
      _applyData(cached);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.get('loaded_from_cache'))),
        );
      }
    }

    // ─── 2) هل نحتاج إعادة فحص؟ ───
    final shouldRescan = await CacheService.shouldRescan();
    if (!shouldRescan && cached.isNotEmpty) return;

    // ─── 3) فحص الأذونات والملفات ───
    if (mounted) setState(() => _scanning = true);

    final status = await Permission.videos.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _scanning = false);
      return;
    }

    final dirs = [
      Directory('/storage/emulated/0/Movies'),
      Directory('/storage/emulated/0/DCIM'),
      Directory('/storage/emulated/0/Download'),
    ];
    final List<Map<String, dynamic>> all = [];
    final Map<String, List<MediaItem>> albums = {};

    for (final d in dirs) {
      if (!await d.exists()) continue;
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is File && _isVideo(e.path)) {
          final m = {
            'title': e.path.split('/').last,
            'path': e.path,
            'album': e.parent.path.split('/').last,
          };
          all.add(m);
          albums.putIfAbsent(m['album']!, () => []).add(
                MediaItem(title: m['title']!, path: m['path']!, isVideo: true),
              );
        }
      }
    }

    await CacheService.saveVideoFiles(all);
    _applyData(all);
    if (mounted) setState(() => _scanning = false);
  }

  void _applyData(List<Map<String, dynamic>> items) {
    final albums = <String, List<MediaItem>>{};
    final all = <MediaItem>[];
    for (final m in items) {
      final item = MediaItem(
        title: m['title'] as String,
        path: m['path'] as String,
        isVideo: true,
      );
      all.add(item);
      final alb = (m['album'] as String?) ?? 'Other';
      albums.putIfAbsent(alb, () => []).add(item);
    }
    if (!mounted) return;
    setState(() {
      _allVideos = all;
      _albums = albums;
    });
  }

  bool _isVideo(String p) {
    final e = p.toLowerCase();
    return e.endsWith('.mp4') ||
        e.endsWith('.mkv') ||
        e.endsWith('.avi') ||
        e.endsWith('.mov') ||
        e.endsWith('.webm');
  }

  void _playVideo(List<MediaItem> items, int index) async {
    await context.read<PlayerProvider>().loadVideoQueue(items, startIndex: index);
    if (mounted) setState(() => _showPlayer = true);
  }

  void _closePlayer() {
    context.read<PlayerProvider>().videoController?.pause();
    setState(() => _showPlayer = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = I18n.of(context);
    final p = context.watch<PlayerProvider>();

    // ═══ شاشة المشغل الكاملة ═══
    if (_showPlayer && p.videoController != null) {
      return _fullScreenPlayer(p, t);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('videos')),
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
            Tab(text: t.get('all_videos')),
            Tab(text: t.get('albums')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_listView(_allVideos, t), _albumsView(t)],
      ),
    );
  }

  /// ═══ المشغل بملء الشاشة مع زر إغلاق واضح ═══
  Widget _fullScreenPlayer(PlayerProvider p, S t) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // الفيديو
            Center(
              child: AspectRatio(
                aspectRatio: p.videoController!.value.aspectRatio,
                child: VideoPlayer(p.videoController!),
              ),
            ),

            // زر الإغلاق — أعلى اليسار/اليمين
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  iconSize: 28,
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _closePlayer,
                  tooltip: t.get('close'),
                ),
              ),
            ),

            // شريط التحكم أسفل
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // عنوان الفيديو
                    Text(
                      p.currentVideo?.title ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // شريط التقدم
                    VideoProgressIndicator(
                      p.videoController!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppTheme.primary,
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // أزرار التحكم
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous,
                              color: Colors.white),
                          onPressed: p.previousVideo,
                        ),
                        IconButton(
                          iconSize: 48,
                          icon: Icon(
                            p.videoController!.value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            color: Colors.white,
                          ),
                          onPressed: p.toggleVideoPlay,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          onPressed: () => p.nextVideo(),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Shuffle',
                          icon: Icon(
                            Icons.shuffle,
                            color: p.videoOrder == PlayOrder.shuffle
                                ? AppTheme.primary
                                : Colors.white,
                          ),
                          onPressed: () => p.setVideoOrder(
                            p.videoOrder == PlayOrder.shuffle
                                ? PlayOrder.forward
                                : PlayOrder.shuffle,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Loop',
                          icon: Icon(
                            Icons.loop,
                            color: p.videoLoop
                                ? AppTheme.primary
                                : Colors.white,
                          ),
                          onPressed: () => p.setVideoLoop(!p.videoLoop),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listView(List<MediaItem> items, S t) {
    if (items.isEmpty) {
      return Center(child: Text(t.get('no_videos')));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return ListTile(
          leading: const Icon(Icons.movie, color: AppTheme.accent),
          title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.play_arrow),
          onTap: () => _playVideo(items, i),
        );
      },
    );
  }

  Widget _albumsView(S t) {
    if (_albums.isEmpty) {
      return Center(child: Text(t.get('no_albums')));
    }
    return ListView(
      children: _albums.entries.map((e) {
        return ExpansionTile(
          leading: const Icon(Icons.video_library, color: AppTheme.primary),
          title: Text(e.key),
          subtitle: Text('${e.value.length} ${t.get('files')}'),
          children: e.value.map((it) {
            return ListTile(
              contentPadding: const EdgeInsets.only(left: 40, right: 16),
              leading:
                  const Icon(Icons.movie, size: 18, color: AppTheme.accent),
              title:
                  Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _playVideo(e.value, e.value.indexOf(it)),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
