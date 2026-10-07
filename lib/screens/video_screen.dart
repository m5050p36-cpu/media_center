import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../i18n/i18n.dart';
import '../i18n/strings.dart';
import '../providers/player_provider.dart';
import '../services/cache_service.dart';
import '../services/video_thumbnail_service.dart';
import '../theme/app_theme.dart';
import 'video_player_screen.dart';

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
  final Map<String, String?> _thumbnails = {};
  bool _scanning = false;
  bool _gridView = true;

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
    final cached = await CacheService.loadVideoFiles();
    if (cached.isNotEmpty) {
      _applyData(cached);
      _generateThumbnails(cached);
    }

    final shouldRescan = await CacheService.shouldRescan();
    if (!shouldRescan && cached.isNotEmpty) return;

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

    for (final d in dirs) {
      if (!await d.exists()) continue;
      await for (final e in d.list(recursive: true, followLinks: false)) {
        if (e is File && _isVideo(e.path)) {
          all.add({
            'title': e.path.split('/').last,
            'path': e.path,
            'album': e.parent.path.split('/').last,
          });
        }
      }
    }

    await CacheService.saveVideoFiles(all);
    _applyData(all);
    _generateThumbnails(all);
    if (mounted) setState(() => _scanning = false);
  }

  /// توليد الصور المصغرة بالتوازي (خلفية)
  void _generateThumbnails(List<Map<String, dynamic>> items) {
    // توليد الأول بالتوازي بمعدل 4
    const batchSize = 4;
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, items.length);
      final batch = items.sublist(i, end);
      _generateBatch(batch);
    }
  }

  Future<void> _generateBatch(List<Map<String, dynamic>> batch) async {
    for (final item in batch) {
      final path = item['path'] as String;
      if (_thumbnails.containsKey(path)) continue;

      final thumb = await VideoThumbnailService.generate(path);
      if (!mounted) return;
      setState(() => _thumbnails[path] = thumb);
    }
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

  void _openPlayer(List<MediaItem> items, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          items: items,
          startIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = I18n.of(context);
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
          // تبديل بين العرض الشبكي والقائمة
          IconButton(
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
            tooltip: _gridView ? 'عرض قائمة' : 'عرض شبكي',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await CacheService.clearAll();
              await VideoThumbnailService.clearCache();
              _thumbnails.clear();
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
        children: [
          _gridView ? _gridVideos(_allVideos, t) : _listVideos(_allVideos, t),
          _albumsView(t),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // عرض شبكي
  // ═══════════════════════════════════════════════
  Widget _gridVideos(List<MediaItem> items, S t) {
    if (items.isEmpty) {
      return Center(child: Text(t.get('no_videos')));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _videoCard(items, i),
    );
  }

  Widget _videoCard(List<MediaItem> items, int index) {
    final it = items[index];
    final thumb = _thumbnails[it.path];

    return GestureDetector(
      onTap: () => _openPlayer(items, index),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── الصورة المصغرة ───
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumb(thumb, it),
                  // أيقونة تشغيل في المنتصف
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ─── العنوان ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb(String? thumb, MediaItem item) {
    // لا صورة مصغرة → placeholder
    if (thumb == null || thumb.isEmpty) {
      return Container(
        color: Colors.black26,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Image.file(
      File(thumb),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _videoPlaceholder(),
    );
  }

  Widget _videoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie, color: Colors.white, size: 40),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // عرض قائمة
  // ═══════════════════════════════════════════════
  Widget _listVideos(List<MediaItem> items, S t) {
    if (items.isEmpty) {
      return Center(child: Text(t.get('no_videos')));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final thumb = _thumbnails[it.path];
        return ListTile(
          leading: Container(
            width: 80,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black26,
            ),
            clipBehavior: Clip.antiAlias,
            child: thumb == null
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Image.file(
                    File(thumb),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _videoPlaceholder(),
                  ),
          ),
          title: Text(it.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.play_arrow),
          onTap: () => _openPlayer(items, i),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // الألبومات
  // ═══════════════════════════════════════════════
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
              contentPadding:
                  const EdgeInsets.only(left: 40, right: 16),
              leading: const Icon(Icons.movie,
                  size: 18, color: AppTheme.accent),
              title: Text(it.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _openPlayer(e.value, e.value.indexOf(it)),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
