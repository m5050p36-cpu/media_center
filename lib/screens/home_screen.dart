import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_carousel.dart';
import 'audio_screen.dart';
import 'video_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Center'),
        actions: [
          if (!auth.isGuest)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BannerCarousel(),
          const SizedBox(height: 24),
          const Text('الأقسام',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            icon: Icons.library_music,
            title: 'الصوتيات',
            subtitle: 'جميع الصوتيات والمجلدات',
            color: AppTheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            icon: Icons.movie,
            title: 'الفيديوهات',
            subtitle: 'جميع الفيديوهات والألبومات',
            color: const Color(0xFF4ECDC4),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VideoScreen()),
            ),
          ),
          const SizedBox(height: 24),
          if (auth.isGuest)
            Card(
              color: AppTheme.card,
              child: ListTile(
                leading:
                    const Icon(Icons.info_outline, color: AppTheme.primary),
                title: const Text('أنت تتصفح كزائر'),
                subtitle: const Text('سجّل الدخول للاستفادة من كل الميزات'),
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('تسجيل'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.sub, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.sub),
          ],
        ),
      ),
    );
  }
}
