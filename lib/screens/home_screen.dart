import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/i18n.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/banner_carousel.dart';
import 'audio_screen.dart';
import 'video_screen.dart';
import 'login_screen.dart';
import '../widgets/version_check_dialog.dart';
import '../screens/about_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final t = I18n.of(context);

    // ═══ فحص الإصدار عند أول بناء ═══
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionCheckDialog.check(
        context,
        currentVersionCode: AboutScreen.appVersionCode,
      );
    });

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(t.get('app_name')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BannerCarousel(),
          const SizedBox(height: 24),
          Text(
            t.get('home'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            icon: Icons.library_music,
            title: t.get('audio'),
            subtitle: '${t.get('all_audio')} • ${t.get('folders')}',
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
            title: t.get('videos'),
            subtitle: '${t.get('all_videos')} • ${t.get('albums')}',
            color: AppTheme.accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VideoScreen()),
            ),
          ),
          const SizedBox(height: 24),
          if (auth.isGuest)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline,
                    color: AppTheme.primary),
                title: Text(t.get('continue_guest')),
                subtitle: Text(t.get('login')),
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: Text(t.get('login')),
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
          color: Theme.of(context).cardTheme.color,
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
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
