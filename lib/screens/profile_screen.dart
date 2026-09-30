import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/i18n.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final t = I18n.of(context);
    final p = auth.profile;

    return Scaffold(
      appBar: AppBar(title: Text(t.get('profile'))),
      body: p == null
          ? const Center(child: Text('لا توجد بيانات'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      (p.fullName?.isNotEmpty == true
                              ? p.fullName![0]
                              : 'U')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _card(Icons.person, t.get('full_name'),
                    p.fullName ?? '-'),
                _card(Icons.email, t.get('email'), p.email ?? '-'),
                _card(
                  Icons.shield,
                  'Role',
                  p.role.toUpperCase(),
                  color: p.isAdmin ? AppTheme.primary : null,
                ),
              ],
            ),
    );
  }

  Widget _card(IconData icon, String label, String value, {Color? color}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.primary),
        title: Text(label, style: const TextStyle(fontSize: 12)),
        subtitle: Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color)),
      ),
    );
  }
}
