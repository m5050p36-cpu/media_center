import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/i18n.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/about_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/login_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final t = I18n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ═══ الهيدر ═══
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildDrawerAvatar(auth),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.isGuest
                        ? t.get('guest')
                        : (auth.userName ?? 'User'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!auth.isGuest && auth.userEmail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      auth.userEmail!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (auth.isAdmin) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        auth.profile?.role.toUpperCase() ?? 'ADMIN',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ═══ الملف الشخصي ═══
                  if (!auth.isGuest)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(t.get('profile')),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        );
                      },
                    ),

                  // ═══ لوحة الإدارة (عنصر واحد) ═══
                  if (auth.isAdmin)
                    ListTile(
                      leading: const Icon(
                        Icons.admin_panel_settings,
                        color: AppTheme.primary,
                      ),
                      title: Text(
                        t.get('admin_panel'),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminPanelScreen(),
                          ),
                        );
                      },
                    ),

                  const Divider(),

                  // ═══ الثيم ═══
                  ListTile(
                    leading: Icon(
                      theme.isDark ? Icons.dark_mode : Icons.light_mode,
                      color: theme.accentColor,
                    ),
                    title: Text(t.get('theme')),
                    subtitle: Text(theme.label),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showThemePicker(context, theme);
                    },
                  ),

                  // ═══ اللغة ═══
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(t.get('language')),
                    subtitle: Text(
                      lang.isArabic ? t.get('arabic') : t.get('english'),
                    ),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ar', label: Text('ع')),
                        ButtonSegment(value: 'en', label: Text('EN')),
                      ],
                      selected: {lang.locale.languageCode},
                      onSelectionChanged: (s) => lang.setLocale(s.first),
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),

                  const Divider(),

                  // ═══ حول ═══
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(t.get('about')),
                    subtitle: const Text('الإصدار 1.0.2'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AboutScreen()),
                      );
                    },
                  ),

                  // ═══ سياسة الخصوصية ═══
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('سياسة الخصوصية'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen()),
                      );
                    },
                  ),

                  const Divider(),

                  // ═══ تسجيل الخروج / الدخول ═══
                  ListTile(
                    leading: Icon(
                      auth.isGuest ? Icons.login : Icons.logout,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      auth.isGuest ? t.get('login') : t.get('logout'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () async {
                      if (auth.isGuest) {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                      } else {
                        await auth.signOut();
                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (_) => false,
                          );
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'v1.0.2 • AR Music & Video',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? AppTheme.subDark : AppTheme.subLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerAvatar(AuthProvider auth) {
    final url = auth.userAvatar;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) =>
            p == null ? child : _drawerAvatarPlaceholder(auth),
        errorBuilder: (_, __, ___) => _drawerAvatarPlaceholder(auth),
      );
    }
    return _drawerAvatarPlaceholder(auth);
  }

  Widget _drawerAvatarPlaceholder(AuthProvider auth) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          (auth.userName?.isNotEmpty == true
                  ? auth.userName![0]
                  : (auth.isGuest ? '?' : 'U'))
              .toUpperCase(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }


  void _showThemePicker(BuildContext context, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'اختر الثيم',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...AppThemeType.values.map((type) {
                final selected = theme.type == type;
                return ListTile(
                  leading: _themeDot(type),
                  title: Text(_themeName(type)),
                  trailing: selected
                      ? Icon(Icons.check_circle,
                          color: theme.accentColor)
                      : null,
                  onTap: () async {
                    await theme.setTheme(type);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeDot(AppThemeType type) {
    Color color;
    switch (type) {
      case AppThemeType.dark:
        color = const Color(0xFF6C63FF);
        break;
      case AppThemeType.light:
        color = const Color(0xFFF5F5FA);
        break;
      case AppThemeType.amoled:
        color = const Color(0xFF000000);
        break;
      case AppThemeType.ocean:
        color = const Color(0xFF0EA5E9);
        break;
      case AppThemeType.sunset:
        color = const Color(0xFFF97316);
        break;
      case AppThemeType.forest:
        color = const Color(0xFF10B981);
        break;
      case AppThemeType.rose:
        color = const Color(0xFFEC4899);
        break;
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
    );
  }

  String _themeName(AppThemeType type) {
    switch (type) {
      case AppThemeType.dark:
        return 'داكن (افتراضي)';
      case AppThemeType.light:
        return 'نهاري';
      case AppThemeType.amoled:
        return 'AMOLED (أسود كامل)';
      case AppThemeType.ocean:
        return 'محيطي (أزرق)';
      case AppThemeType.sunset:
        return 'غروب (برتقالي)';
      case AppThemeType.forest:
        return 'غابة (أخضر)';
      case AppThemeType.rose:
        return 'وردي';
    }
  }

}
