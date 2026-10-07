import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_just_marquee/flutter_just_marquee.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/player_provider.dart';
import '../screens/full_player_screen.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  /// عدّاد الشاشات التي طلبت إخفاء الشريط
  static final ValueNotifier<int> _hiddenCount = ValueNotifier(0);

  static void hide() {
    _hiddenCount.value = _hiddenCount.value + 1;
  }

  static void show() {
    _hiddenCount.value = (_hiddenCount.value - 1).clamp(0, 999);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final lang = context.watch<LanguageProvider>();
    final current = p.currentAudio;

    if (current == null) return const SizedBox.shrink();

    return ValueListenableBuilder<int>(
      valueListenable: _hiddenCount,
      builder: (_, count, __) {
        if (count > 0) return const SizedBox.shrink();
        return _buildMiniPlayer(context, p, lang.isArabic, current);
      },
    );
  }

  Widget _buildMiniPlayer(
    BuildContext context,
    PlayerProvider p,
    bool isArabic,
    MediaItem current,
  ) {
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.95),
            AppTheme.accent.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ═══ شريط التقدم الرفيع ═══
          StreamBuilder<Duration>(
            stream: p.audioPlayer.positionStream,
            builder: (_, posSnap) {
              return StreamBuilder<Duration?>(
                stream: p.audioPlayer.durationStream,
                builder: (_, durSnap) {
                  final pos = posSnap.data ?? Duration.zero;
                  final dur = durSnap.data ?? Duration.zero;
                  final progress = dur.inMilliseconds > 0
                      ? pos.inMilliseconds / dur.inMilliseconds
                      : 0.0;
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 2.5,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    ),
                  );
                },
              );
            },
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // ═══ صورة الغلاف (قابلة للضغط → FullPlayer) ═══
                  GestureDetector(
                    onTap: () => _openFullPlayer(context),
                    child: Hero(
                      tag: 'album_art_${current.path}',
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildCoverImage(current),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ═══ النص المتحرك + الفنان (قابل للضغط → FullPlayer) ═══
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openFullPlayer(context),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Directionality(
                            textDirection: isArabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            child: FlutterMarquee(
                              height: 20,
                              text: current.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              startAfter: const Duration(milliseconds: 800),
                              pauseAfterRound: const Duration(seconds: 1),
                              velocity: 60,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            current.album ?? 'Media Center',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ═══ أزرار التحكم ═══
                  IconButton(
                    icon: const Icon(Icons.skip_previous,
                        color: Colors.white, size: 24),
                    onPressed: p.previousAudio,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'السابق',
                  ),
                  const SizedBox(width: 2),

                  IconButton(
                    iconSize: 36,
                    icon: Icon(
                      p.audioPlayer.playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white,
                    ),
                    onPressed: p.togglePlay,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: p.audioPlayer.playing ? 'إيقاف' : 'تشغيل',
                  ),
                  const SizedBox(width: 2),

                  IconButton(
                    icon: const Icon(Icons.skip_next,
                        color: Colors.white, size: 24),
                    onPressed: () => p.nextAudio(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'التالي',
                  ),

                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    onPressed: () {
                      p.audioPlayer.stop();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullPlayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FullPlayerScreen(),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // صورة الغلاف (مع 3 حالات: إنترنت / محلي / placeholder)
  // ═══════════════════════════════════════════════
  Widget _buildCoverImage(MediaItem item) {
    final art = item.albumArt;

    // ─── لا صورة → placeholder جميل ───
    if (art == null || art.isEmpty) {
      return _placeholderCover();
    }

    // ─── رابط إنترنت ───
    if (art.startsWith('http')) {
      return Image.network(
        art,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _placeholderCover();
        },
        errorBuilder: (_, __, ___) => _placeholderCover(),
      );
    }

    // ─── ملف محلي ───
    return Image.file(
      File(art),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholderCover(),
    );
  }

  Widget _placeholderCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.music_note,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
