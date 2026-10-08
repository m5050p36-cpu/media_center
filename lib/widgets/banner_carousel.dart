import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/banner_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});
  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  List<BannerModel>? _banners;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    // ⚡ لا ننتظر — الواجهة تُبنى فوراً
    final data = await SupabaseService().fetchActiveBanners();
    if (mounted) setState(() => _banners = data);
  }

  @override
  Widget build(BuildContext context) {
    // ⚡ عرض placeholder حتى تحميل البيانات
    if (_banners == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_banners!.isEmpty) return const SizedBox.shrink();

    return CarouselSlider(
      options: CarouselOptions(
        height: 180,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 4),
        enlargeCenterPage: true,
        viewportFraction: 0.92,
      ),
      items: _banners!.map((b) => _buildBanner(b)).toList(),
    );
  }

  Widget _buildBanner(BannerModel b) {
    return GestureDetector(
      onTap: () async {
        if (b.targetUrl == null || b.targetUrl!.isEmpty) return;
        final uri = Uri.tryParse(b.targetUrl!);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ⚡ cached_network_image — تخزين تلقائي
            CachedNetworkImage(
              imageUrl: b.imageUrl,
              fit: BoxFit.cover,
              memCacheHeight: 400,
              memCacheWidth: 800,
              placeholder: (_, __) => Container(
                color: AppTheme.card,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.card,
                child: const Icon(Icons.broken_image,
                    color: AppTheme.sub, size: 40),
              ),
            ),
            if (b.title != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Text(
                    b.title!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
