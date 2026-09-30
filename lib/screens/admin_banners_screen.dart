import 'package:flutter/material.dart';
import '../i18n/i18n.dart';
import '../models/banner_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});
  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final _service = SupabaseService();
  List<BannerModel> _banners = [];
  bool _loading = true;
  String? _error;

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
          .from('banners')
          .select()
          .order('display_order', ascending: true);
      setState(() {
        _banners = (data as List).map((e) => BannerModel.fromMap(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete(BannerModel b) async {
    final t = I18n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.get('confirm_delete')),
        content: Text(b.title ?? b.id),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.get('delete'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteBanner(b.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t.get('success')),
              backgroundColor: Colors.green),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _showForm({BannerModel? existing}) async {
    final t = I18n.of(context);
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final imgCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final urlCtrl = TextEditingController(text: existing?.targetUrl ?? '');
    final orderCtrl =
        TextEditingController(text: (existing?.displayOrder ?? 0).toString());
    bool active = existing?.isActive ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null
              ? t.get('add_banner')
              : t.get('edit_banner')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: t.get('banner_title')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: imgCtrl,
                  decoration:
                      InputDecoration(labelText: t.get('banner_image_url')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration:
                      InputDecoration(labelText: t.get('banner_target_url')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(labelText: t.get('banner_order')),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: Text(t.get('banner_active')),
                  value: active,
                  onChanged: (v) => setSt(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.get('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (imgCtrl.text.trim().isEmpty) return;
                try {
                  final b = BannerModel(
                    id: existing?.id ?? '',
                    title: titleCtrl.text.trim(),
                    imageUrl: imgCtrl.text.trim(),
                    targetUrl: urlCtrl.text.trim(),
                    isActive: active,
                    displayOrder: int.tryParse(orderCtrl.text) ?? 0,
                  );
                  if (existing == null) {
                    await _service.addBanner(b);
                  } else {
                    await _service.updateBanner(existing.id, b.toMap());
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
              },
              child: Text(t.get('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = I18n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('manage_banners')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: Text(t.get('add_banner')),
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
              : _banners.isEmpty
                  ? Center(child: Text(t.get('no_albums')))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _banners.length,
                        itemBuilder: (_, i) {
                          final b = _banners[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  b.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    color: AppTheme.card,
                                    child: const Icon(Icons.image),
                                  ),
                                ),
                              ),
                              title: Text(b.title ?? '-'),
                              subtitle: Text(
                                '${t.get('banner_order')}: ${b.displayOrder}\n'
                                '${b.isActive ? "●" : "○"} ${b.targetUrl ?? ""}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    _showForm(existing: b);
                                  } else if (v == 'delete') {
                                    _delete(b);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                      value: 'edit',
                                      child: Text(t.get('edit_banner'))),
                                  PopupMenuItem(
                                      value: 'delete',
                                      child: Text(t.get('delete_banner'))),
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
