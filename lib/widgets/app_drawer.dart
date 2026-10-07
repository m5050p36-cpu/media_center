import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/i18n.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/admin_banners_screen.dart';
import '../screens/login_screen.dart';
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
                  // ─── الصورة الرمزية ───
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

            // ═══ العناصر ═══
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
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

                  if (auth.isAdmin)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings,
                          color: AppTheme.primary),
                      title: Text(
                        t.get('admin_panel'),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminBannersScreen()),
                        );
                      },
                    ),

                  const Divider(),

                  SwitchListTile(
                    secondary: Icon(
                      theme.isDark ? Icons.dark_mode : Icons.light_mode,
                    ),
                    title: Text(t.get('theme')),
                    subtitle: Text(
                      theme.isDark ? t.get('dark_mode') : t.get('light_mode'),
                    ),
                    value: theme.isDark,
                    onChanged: (_) => theme.toggle(),
                  ),

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

                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(t.get('about')),
                    subtitle: const Text('v1.0.1'),
                  ),

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
                      'v1.0.1 • AR Music & Video',
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

  // ═══════════════════════════════════════════════
  // الصورة الرمزية في الدرج
  // ═══════════════════════════════════════════════
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
}
