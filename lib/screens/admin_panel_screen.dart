import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'admin_users_tab.dart';
import 'admin_banners_tab.dart';
import 'admin_versions_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(
              icon: Icon(Icons.group, size: 22),
              text: 'المستخدمون',
            ),
            Tab(
              icon: Icon(Icons.image, size: 22),
              text: 'البنرات',
            ),
            Tab(
              icon: Icon(Icons.system_update_alt, size: 22),
              text: 'الإصدارات',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          AdminUsersTab(),
          AdminBannersTab(),
          AdminVersionsTab(),
        ],
      ),
    );
  }
}
