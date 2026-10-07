import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<ProfileModel> _users = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _users = (data as List)
            .map((e) => ProfileModel.fromMap(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<ProfileModel> get _filtered {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users
        .where((u) =>
            (u.email ?? '').toLowerCase().contains(q) ||
            (u.fullName ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _sendPasswordReset(ProfileModel user) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      _snack('لا يوجد بريد لهذا المستخدم', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تعيين كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هل تريد إرسال رابط إعادة تعيين كلمة المرور إلى:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                email,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '📧 سيصل المستخدم بريد يحتوي رابطاً آمناً لإعادة تعيين كلمة المرور.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('إرسال'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      _snack('✅ تم إرسال رابط إعادة التعيين إلى $email', isError: false);
    } catch (e) {
      if (!mounted) return;
      _snack('فشل: $e', isError: true);
    }
  }

  Future<void> _changeRole(ProfileModel user) async {
    String newRole = user.role;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('تغيير صلاحية: ${user.fullName ?? user.email}'),
          content: SingleChildScrollView(
            child: RadioGroup<String>(
              groupValue: newRole,
              onChanged: (v) {
                if (v != null) setSt(() => newRole = v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  RadioListTile<String>(
                    title: Text('مستخدم'),
                    subtitle: Text('صلاحيات عادية'),
                    value: 'user',
                  ),
                  RadioListTile<String>(
                    title: Text('مشرف'),
                    subtitle: Text('إدارة البنرات فقط'),
                    value: 'admin',
                  ),
                  RadioListTile<String>(
                    title: Text('مدير أعلى'),
                    subtitle: Text('كل الصلاحيات'),
                    value: 'superuser',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, newRole),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == user.role) return;

    try {
      await SupabaseService.client
          .from('profiles')
          .update({'role': result})
          .eq('id', user.id);
      if (!mounted) return;
      _snack('✅ تم تحديث الصلاحية', isError: false);
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('فشل: $e', isError: true);
    }
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? Colors.redAccent : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'superuser':
        return Colors.purpleAccent;
      case 'admin':
        return AppTheme.primary;
      default:
        return Colors.blueGrey;
    }
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'بحث بالبريد أو الاسم...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardTheme.color,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('$_error',
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : filtered.isEmpty
                  ? const Center(child: Text('لا يوجد مستخدمون'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final u = filtered[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              leading: CircleAvatar(
                                backgroundColor: _roleColor(u.role)
                                    .withValues(alpha: 0.2),
                                child: Text(
                                  (u.fullName?.isNotEmpty == true
                                          ? u.fullName![0]
                                          : (u.email?.isNotEmpty == true
                                              ? u.email![0]
                                              : 'U'))
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: _roleColor(u.role),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                u.fullName?.isNotEmpty == true
                                    ? u.fullName!
                                    : 'بدون اسم',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(u.email ?? '-',
                                      style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _roleColor(u.role)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _roleLabel(u.role),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _roleColor(u.role),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'password') {
                                    _sendPasswordReset(u);
                                  } else if (v == 'role') {
                                    _changeRole(u);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'password',
                                    child: Row(
                                      children: [
                                        Icon(Icons.lock_reset, size: 18),
                                        SizedBox(width: 8),
                                        Text('إعادة تعيين كلمة المرور'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'role',
                                    child: Row(
                                      children: [
                                        Icon(Icons.shield_outlined,
                                            size: 18),
                                        SizedBox(width: 8),
                                        Text('تغيير الصلاحية'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
