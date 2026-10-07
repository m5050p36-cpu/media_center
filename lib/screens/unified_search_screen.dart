import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/cache_service.dart';
import '../theme/app_theme.dart';
import 'full_player_screen.dart';
import 'video_player_screen.dart';

class UnifiedSearchScreen extends StatefulWidget {
  const UnifiedSearchScreen({super.key});
  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<MediaItem> _allAudio = [];
  List<MediaItem> _allVideos = [];
  List<MediaItem> _audioResults = [];
  List<MediaItem> _videoResults = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final audio = await CacheService.loadAudioFiles();
      final video = await CacheService.loadVideoFiles();

      setState(() {
        _allAudio = audio
            .map((m) => MediaItem(
                  title: m['title'] as String,
                  path: m['path'] as String,
                  album: (m['folder'] as String?) ?? 'Other',
                ))
            .toList();
        _allVideos = video
            .map((m) => MediaItem(
                  title: m['title'] as String,
                  path: m['path'] as String,
                  album: (m['album'] as String?) ?? 'Other',
                  isVideo: true,
                ))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _performSearch(String query) {
    setState(() => _query = query);

    if (query.trim().isEmpty) {
      _audioResults = [];
      _videoResults = [];
      return;
    }

    final q = query.toLowerCase().trim();

    _audioResults = _allAudio
        .where((item) =>
            item.title.toLowerCase().contains(q) ||
            (item.album?.toLowerCase().contains(q) ?? false) ||
            item.path.toLowerCase().contains(q))
        .toList();

    _videoResults = _allVideos
        .where((item) =>
            item.title.toLowerCase().contains(q) ||
            (item.album?.toLowerCase().contains(q) ?? false) ||
            item.path.toLowerCase().contains(q))
        .toList();
  }

  void _playAudio(int index) {
    final p = context.read<PlayerProvider>();
    p.loadAudioQueue(_audioResults, startIndex: index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FullPlayerScreen()),
    );
  }

  void _playVideo(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          items: _videoResults,
          startIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          focusNode: _focusNode,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'ابحث في كل الوسائط...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.5),
            ),
          ),
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchCtrl.clear();
                _performSearch('');
              },
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(
              icon: const Icon(Icons.music_note, size: 20),
              text: 'الصوتيات (${_audioResults.length})',
            ),
            Tab(
              icon: const Icon(Icons.movie, size: 20),
              text: 'الفيديوهات (${_videoResults.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tab,
                  children: [
                    _buildResults(
                      _audioResults,
                      Icons.music_note,
                      _playAudio,
                      'لا توجد نتائج صوتية',
                    ),
                    _buildResults(
                      _videoResults,
                      Icons.movie,
                      _playVideo,
                      'لا توجد نتائج للفيديو',
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 100,
            color: AppTheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          const Text(
            'ابحث في مكتبتك',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'اكتب اسماً أو مجلداً للبحث في الصوتيات والفيديوهات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildStats(),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statCard(Icons.music_note, '${_allAudio.length}', 'صوتية',
            AppTheme.primary),
        const SizedBox(width: 16),
        _statCard(Icons.movie, '${_allVideos.length}', 'فيديو',
            AppTheme.accent),
      ],
    );
  }

  Widget _statCard(IconData icon, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    List<MediaItem> items,
    IconData icon,
    void Function(int) onTap,
    String emptyMsg,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 60,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              emptyMsg,
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary),
            ),
            title: _highlightMatch(item.title, _query),
            subtitle: item.album != null
                ? _highlightMatch(item.album!, _query,
                    style: const TextStyle(fontSize: 11))
                : null,
            trailing: const Icon(Icons.play_arrow_rounded),
            onTap: () => onTap(i),
          ),
        );
      },
    );
  }

  /// تمييز النص المطابق باللون
  Widget _highlightMatch(
    String text,
    String query, {
    TextStyle? style,
  }) {
    if (query.isEmpty) {
      return Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style);
    }

    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final idx = lower.indexOf(q);

    if (idx == -1) {
      return Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style);
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style ??
            DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + q.length),
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
    );
  }
}
