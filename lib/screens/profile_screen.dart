import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/i18n.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final t = I18n.of(context);
    final p = auth.profile;

    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.get('profile'))),
        body: const Center(child: Text('لا توجد بيانات')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('profile')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'تعديل',
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProfileEditScreen()),
              );
              // لا حاجة لعمل شيء — Provider يتحدث تلقائياً
              if (result == true) {
                debugPrint('✅ Profile updated');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ═══ الصورة الرمزية ═══
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
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildAvatar(p.avatarUrl, p.fullName),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ الاسم ═══
          Center(
            child: Text(
              p.fullName?.isNotEmpty == true ? p.fullName! : 'بدون اسم',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (p.isAdmin)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified,
                        color: AppTheme.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      p.role.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 30),

          // ═══ بطاقة المعلومات ═══
          _infoCard(
            icon: Icons.person_outline,
            label: t.get('full_name'),
            value: p.fullName ?? '-',
          ),
          _infoCard(
            icon: Icons.email_outlined,
            label: t.get('email'),
            value: p.email ?? '-',
          ),
          _infoCard(
            icon: Icons.shield_outlined,
            label: 'الصلاحية',
            value: _roleLabel(p.role),
            color: p.isAdmin ? AppTheme.primary : null,
          ),

          const SizedBox(height: 20),

          // ═══ زر تعديل ═══
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileEditScreen()),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('تعديل الملف الشخصي',
                  style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url, String? name) {
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) =>
            p == null ? child : _placeholder(name),
        errorBuilder: (_, __, ___) => _placeholder(name),
      );
    }
    return _placeholder(name);
  }

  Widget _placeholder(String? name) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'superuser':
        return 'مدير أعلى';
      case 'admin':
        return 'مشرف';
      default:
        return 'مستخدم';
    }
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.primary),
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
