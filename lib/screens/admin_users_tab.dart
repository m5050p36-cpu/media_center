import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../services/admin_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});
  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
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

  // ═══════════════════════════════════════════════
  // 🔐 تغيير كلمة المرور مباشرة (بدون بريد)
  // ═══════════════════════════════════════════════
  Future<void> _changePassword(ProfileModel user) async {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;
    bool saving = false;

    // 🔥 احتفظ بـ messenger الرئيسي قبل الحوار
    final mainMessenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (builderCtx, setSt) {
          // 🔥 messenger داخل الحوار
          final dialogMessenger = ScaffoldMessenger.of(builderCtx);

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.lock_reset, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تغيير كلمة المرور',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // المستخدم المستهدف
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.fullName ?? user.email ?? '-',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: passCtrl,
                    obscureText: obscure1,
                    enabled: !saving,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscure1
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setSt(() => obscure1 = !obscure1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscure2,
                    enabled: !saving,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      prefixIcon: const Icon(Icons.check_circle_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscure2
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setSt(() => obscure2 = !obscure2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    '⚠️ سيتم تغيير كلمة المرور فوراً دون إرسال بريد',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final pass = passCtrl.text;
                        final confirm = confirmCtrl.text;

                        // ─── التحقق ───
                        if (pass.isEmpty) {
                          dialogMessenger.showSnackBar(_errSnack(
                              'أدخل كلمة المرور'));
                          return;
                        }
                        if (pass.length < 6) {
                          dialogMessenger.showSnackBar(_errSnack(
                              'كلمة المرور يجب أن تكون 6 أحرف على الأقل'));
                          return;
                        }
                        if (pass != confirm) {
                          dialogMessenger.showSnackBar(
                              _errSnack('كلمتا المرور غير متطابقتين'));
                          return;
                        }

                        setSt(() => saving = true);

                        try {
                          await AdminService.changeUserPassword(
                            userId: user.id,
                            newPassword: pass,
                          );

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }

                          mainMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('✅ تم تغيير كلمة المرور بنجاح'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          if (builderCtx.mounted) {
                            setSt(() => saving = false);
                            dialogMessenger.showSnackBar(
                                _errSnack('$e'));
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(saving ? 'جارٍ الحفظ...' : 'تغيير فوراً'),
              ),
            ],
          );
        },
      ),
    );
  }

  SnackBar _errSnack(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      );

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
    return Column(
      children: [
        // ═══ شريط البحث ═══
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'بحث بالبريد أو الاسم...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
              ),
              filled: true,
              fillColor: Theme.of(context).cardTheme.color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ═══ القائمة ═══
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('$_error',
                            style:
                                const TextStyle(color: Colors.redAccent)),
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
                                  contentPadding:
                                      const EdgeInsets.symmetric(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(u.email ?? '-',
                                          style: const TextStyle(
                                              fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _roleColor(u.role)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                        _changePassword(u);
                                      } else if (v == 'role') {
                                        _changeRole(u);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'password',
                                        child: Row(
                                          children: [
                                            Icon(Icons.lock_reset,
                                                size: 18),
                                            SizedBox(width: 8),
                                            Text('تغيير كلمة المرور'),
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
        ),
      ],
    );
  }
}
