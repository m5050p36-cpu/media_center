import 'package:flutter/material.dart';
import '../services/version_service.dart';
import '../theme/app_theme.dart';

class AdminVersionsTab extends StatefulWidget {
  const AdminVersionsTab({super.key});
  @override
  State<AdminVersionsTab> createState() => _AdminVersionsTabState();
}

class _AdminVersionsTabState extends State<AdminVersionsTab>
    with AutomaticKeepAliveClientMixin {
  List<AppVersionInfo> _versions = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await VersionService.fetchAll();
    if (!mounted) return;
    setState(() {
      _versions = data;
      _loading = false;
    });
  }

  Future<void> _addVersion() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isActive = true;
    bool forceUpdate = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إضافة إصدار جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رمز الإصدار (رقم)',
                    hintText: 'مثال: 4',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الإصدار',
                    hintText: 'مثال: 1.0.3',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رابط التحميل (اختياري)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات الإصدار',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('مفعّل'),
                  value: isActive,
                  onChanged: (v) => setSt(() => isActive = v),
                ),
                SwitchListTile(
                  title: const Text('فرض التحديث'),
                  subtitle: const Text('يجبر المستخدم على التحديث فوراً'),
                  value: forceUpdate,
                  onChanged: (v) => setSt(() => forceUpdate = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) return;
                try {
                  await VersionService.addVersion(
                    versionCode: int.parse(codeCtrl.text),
                    versionName: nameCtrl.text.trim(),
                    isActive: isActive,
                    forceUpdate: forceUpdate,
                    downloadUrl: urlCtrl.text.trim().isEmpty
                        ? null
                        : urlCtrl.text.trim(),
                    releaseNotes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) _load();
  }

  Future<void> _toggleActive(AppVersionInfo v) async {
    try {
      if (v.isActive) {
        await VersionService.deactivate(v.versionCode);
      } else {
        await VersionService.activate(v.versionCode);
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _delete(AppVersionInfo v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف الإصدار ${v.versionName}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await VersionService.delete(v.versionCode);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVersion,
        icon: const Icon(Icons.add),
        label: const Text('إصدار جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _versions.isEmpty
              ? const Center(child: Text('لا توجد إصدارات'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _versions.length,
                    itemBuilder: (_, i) {
                      final v = _versions[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: v.isActive
                                  ? AppTheme.primary
                                      .withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.android,
                              color: v.isActive
                                  ? AppTheme.primary
                                  : Colors.grey,
                            ),
                          ),
                          title: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                v.versionName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              _chip(
                                v.isActive ? 'مفعّل' : 'معطل',
                                v.isActive ? AppTheme.primary : Colors.grey,
                              ),
                              if (v.forceUpdate)
                                _chip('إجباري', Colors.redAccent),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Code: ${v.versionCode}',
                                  style: const TextStyle(fontSize: 11)),
                              if (v.releaseNotes != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    v.releaseNotes!,
                                    style: const TextStyle(
                                        fontSize: 12, height: 1.5),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'toggle') _toggleActive(v);
                              if (action == 'delete') _delete(v);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(
                                    v.isActive ? 'تعطيل' : 'تفعيل'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'حذف',
                                  style:
                                      TextStyle(color: Colors.redAccent),
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

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
