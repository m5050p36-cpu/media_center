import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'privacy_policy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appVersion = '1.0.2';
  static const int appVersionCode = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ═══ الشعار ═══
          Center(
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 25,
                    spreadRadius: 3,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icon/app_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.play_circle_fill,
                  size: 80,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ═══ اسم التطبيق ═══
          const Center(
            child: Text(
              'AR مشغل موسيقى & فيديوهات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ═══ الإصدار ═══
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'الإصدار $appVersion',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // ═══ الوصف ═══
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'تطبيق متكامل لتشغيل الصوتيات والفيديوهات بواجهة عصرية.\n'
              'يدعم التشغيل في الخلفية، قوائم التشغيل، المفضلة، المؤثرات، '
              'والمزيد من الميزات الاحترافية.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.7),
            ),
          ),

          const SizedBox(height: 20),

          // ═══ معلومات ═══
          _buildInfoTile(
            icon: Icons.code,
            title: 'المطور',
            value: 'MediaHub Team',
          ),
          _buildInfoTile(
            icon: Icons.calendar_today,
            title: 'تاريخ الإصدار',
            value: 'أكتوبر 2026',
          ),
          _buildInfoTile(
            icon: Icons.storage,
            title: 'قاعدة البيانات',
            value: 'Supabase',
          ),
          _buildInfoTile(
            icon: Icons.phone_android,
            title: 'Flutter SDK',
            value: '3.27+',
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),

          // ═══ الروابط ═══
          _buildLinkTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),

          _buildLinkTile(
            context,
            icon: Icons.telegram,
            title: 'الدعم الفني',
            onTap: () async {
              final uri = Uri.parse('https://t.me/Ra16bot');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),

          _buildLinkTile(
            context,
            icon: Icons.star_outline,
            title: 'تقييم التطبيق',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريباً...')),
              );
            },
          ),

          _buildLinkTile(
            context,
            icon: Icons.share_outlined,
            title: 'مشاركة التطبيق',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريباً...')),
              );
            },
          ),

          const SizedBox(height: 30),

          // ═══ حقوق النشر ═══
          Center(
            child: Column(
              children: [
                Text(
                  '© 2026 MediaHub',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'جميع الحقوق محفوظة',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_left, size: 20),
      onTap: onTap,
    );
  }
}
