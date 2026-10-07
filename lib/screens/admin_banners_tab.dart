import 'package:flutter/material.dart';
import '../models/banner_model.dart';
import '../services/image_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'banner_editor_screen.dart';

class AdminBannersTab extends StatefulWidget {
  const AdminBannersTab({super.key});
  @override
  State<AdminBannersTab> createState() => _AdminBannersTabState();
}

class _AdminBannersTabState extends State<AdminBannersTab>
    with AutomaticKeepAliveClientMixin {
  final _service = SupabaseService();
  List<BannerModel> _banners = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
        _banners =
            (data as List).map((e) => BannerModel.fromMap(e)).toList();
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف "${b.title ?? b.id}"؟'),
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
      if (b.imageUrl.contains('/storage/v1/object/public/banners/')) {
        await ImageService.delete(b.imageUrl);
      }
      await _service.deleteBanner(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحذف'),
          backgroundColor: Colors.green,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _openEditor({BannerModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BannerEditorScreen(existing: existing),
      ),
    );
    if (result == true) _load();
  }

  void _previewFullscreen(BannerModel b) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Image.network(
                  b.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white)),
                  errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          size: 80, color: Colors.white54)),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('بنر جديد'),
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
                  ? const Center(child: Text('لا توجد بنرات'))
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
                              contentPadding: const EdgeInsets.all(8),
                              leading: GestureDetector(
                                onTap: () => _previewFullscreen(b),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    b.imageUrl,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (_, child, p) =>
                                        p == null
                                            ? child
                                            : Container(
                                                width: 70,
                                                height: 70,
                                                color: AppTheme.card,
                                                child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2)),
                                              ),
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                      width: 70,
                                      height: 70,
                                      color: AppTheme.card,
                                      child: const Icon(Icons.image),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(b.title ?? '(بدون عنوان)'),
                              subtitle: Text(
                                'الترتيب: ${b.displayOrder} • ${b.isActive ? "● نشط" : "○ معطل"}\n'
                                '${b.targetUrl ?? ""}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: b.isActive
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    _openEditor(existing: b);
                                  } else if (v == 'delete') {
                                    _delete(b);
                                  } else if (v == 'preview') {
                                    _previewFullscreen(b);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'preview',
                                      child: Row(children: [
                                        Icon(Icons.fullscreen, size: 18),
                                        SizedBox(width: 8),
                                        Text('معاينة'),
                                      ])),
                                  PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('تعديل'),
                                      ])),
                                  PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete,
                                            size: 18,
                                            color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('حذف',
                                            style: TextStyle(
                                                color: Colors.redAccent)),
                                      ])),
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
