import 'package:flutter/material.dart';
import '../models/banner_model.dart';
import '../services/image_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class BannerEditorScreen extends StatefulWidget {
  final BannerModel? existing;
  const BannerEditorScreen({super.key, this.existing});

  @override
  State<BannerEditorScreen> createState() => _BannerEditorScreenState();
}

class _BannerEditorScreenState extends State<BannerEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '0');
  final _imageUrlCtrl = TextEditingController();

  bool _active = true;
  String? _imageUrl;
  PickedImageInfo? _pickedImage;
  bool _saving = false;
  bool _uploading = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _titleCtrl.text = e.title ?? '';
      _urlCtrl.text = e.targetUrl ?? '';
      _orderCtrl.text = e.displayOrder.toString();
      _active = e.isActive;
      _imageUrl = e.imageUrl;
      _imageUrlCtrl.text = e.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _orderCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool fromCamera) async {
    final picked = fromCamera
        ? await ImageService.pickFromCamera()
        : await ImageService.pickFromGallery();

    if (picked == null) return;

    if (picked.sizeBytes > 500 * 1024) {
      final result = await _askCompressDialog(picked);
      if (result == null) return;
      if (!mounted) return;
      setState(() {
        _pickedImage = result;
        _imageUrl = null;
        _imageUrlCtrl.clear();
      });
    } else {
      if (!mounted) return;
      setState(() {
        _pickedImage = picked;
        _imageUrl = null;
        _imageUrlCtrl.clear();
      });
    }
  }

  Future<PickedImageInfo?> _askCompressDialog(PickedImageInfo original) async {
    int quality = 85;
    int maxDim = 1920;
    PickedImageInfo? preview;
    bool previewing = false;

    return showDialog<PickedImageInfo>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.compress, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('الصورة كبيرة الحجم'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الحجم الأصلي: ${original.sizeText}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('الجودة: $quality%'),
                Slider(
                  value: quality.toDouble(),
                  min: 30,
                  max: 100,
                  divisions: 14,
                  label: '$quality%',
                  onChanged: (v) => setSt(() => quality = v.toInt()),
                ),
                Text('أقصى بعد: $maxDim px'),
                Slider(
                  value: maxDim.toDouble(),
                  min: 720,
                  max: 3840,
                  divisions: 26,
                  label: '$maxDim',
                  onChanged: (v) => setSt(() => maxDim = v.toInt()),
                ),
                const SizedBox(height: 12),
                if (preview != null) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('بعد الضغط:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    preview!.sizeText +
                        (preview!.sizeBytes < original.sizeBytes
                            ? ' (وفّر ${((1 - preview!.sizeBytes / original.sizeBytes) * 100).toStringAsFixed(0)}%)'
                            : ' (لا يوجد تحسّن)'),
                    style: const TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(preview!.file,
                        height: 120, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: previewing
                        ? null
                        : () async {
                            setSt(() => previewing = true);
                            final c = await ImageService.compress(
                              original,
                              quality: quality,
                              maxWidth: maxDim,
                              maxHeight: maxDim,
                            );
                            setSt(() {
                              preview = c;
                              previewing = false;
                            });
                          },
                    icon: previewing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.visibility),
                    label: const Text('معاينة نتيجة الضغط'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, original),
              child: const Text('رفع الأصل'),
            ),
            ElevatedButton(
              onPressed: () async {
                final c = await ImageService.compress(
                  original,
                  quality: quality,
                  maxWidth: maxDim,
                  maxHeight: maxDim,
                );
                if (ctx.mounted) Navigator.pop(ctx, c);
              },
              child: const Text('ضغط وحفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _previewFullscreen() {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: _buildImageWidget(fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget({BoxFit fit = BoxFit.cover}) {
    if (_pickedImage != null) {
      return Image.file(_pickedImage!.file, fit: fit);
    }
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Image.network(
        _imageUrl!,
        fit: fit,
        loadingBuilder: (_, child, p) => p == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
      );
    }
    return const Center(
      child: Icon(Icons.image_outlined, size: 60, color: Colors.grey),
    );
  }

  bool get _hasImage =>
      _pickedImage != null || (_imageUrl != null && _imageUrl!.isNotEmpty);

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('أدخل عنوان البنر');
      return;
    }
    if (!_hasImage) {
      _snack('اختر صورة من الجهاز أو الصق رابطاً');
      return;
    }

    setState(() => _saving = true);

    try {
      String finalImageUrl = _imageUrl ?? '';

      if (_pickedImage != null) {
        setState(() => _uploading = true);
        finalImageUrl = await ImageService.upload(_pickedImage!);
        setState(() => _uploading = false);
      }

      final banner = BannerModel(
        id: widget.existing?.id ?? '',
        title: _titleCtrl.text.trim(),
        imageUrl: finalImageUrl,
        targetUrl: _urlCtrl.text.trim(),
        isActive: _active,
        displayOrder: int.tryParse(_orderCtrl.text.trim()) ?? 0,
      );

      final service = SupabaseService();
      if (isEditing) {
        await service.updateBanner(widget.existing!.id, banner.toMap());
      } else {
        await service.addBanner(banner);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('save error: $e');
      if (mounted) _snack('فشل الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل البنر' : 'بنر جديد'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'حفظ',
              onPressed: _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hasImage
                    ? AppTheme.primary.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImageWidget(),
                if (_hasImage)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen,
                            color: Colors.white),
                        tooltip: 'معاينة بكامل الشاشة',
                        onPressed: _previewFullscreen,
                      ),
                    ),
                  ),
                if (_pickedImage != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _pickedImage!.isCompressed
                            ? Colors.orange.shade800
                            : AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _pickedImage!.isCompressed
                            ? 'مضغوطة ${_pickedImage!.sizeText}'
                            : 'أصلية ${_pickedImage!.sizeText}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pickImage(false),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('من المعرض'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pickImage(true),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('من الكاميرا'),
                ),
              ),
            ],
          ),

          if (_hasImage)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _pickedImage = null;
                          _imageUrl = null;
                          _imageUrlCtrl.clear();
                        }),
                icon:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text('حذف الصورة',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          TextField(
            controller: _imageUrlCtrl,
            enabled: _pickedImage == null,
            onChanged: (v) => setState(() {
              _imageUrl = v.trim().isEmpty ? null : v.trim();
            }),
            decoration: const InputDecoration(
              labelText: 'أو الصق رابط صورة (URL)',
              prefixIcon: Icon(Icons.link),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'الرابط عند الضغط (اختياري)',
              prefixIcon: Icon(Icons.open_in_new),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _orderCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ترتيب العرض',
              prefixIcon: Icon(Icons.sort),
            ),
          ),
          const SizedBox(height: 8),

          SwitchListTile(
            title: const Text('مفعّل'),
            subtitle: Text(_active ? 'البنر ظاهر' : 'البنر مخفي'),
            value: _active,
            onChanged: _saving ? null : (v) => setState(() => _active = v),
            activeThumbColor: AppTheme.primary,
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _uploading
                    ? 'جارٍ رفع الصورة...'
                    : (_saving ? 'جارٍ الحفظ...' : 'حفظ البنر'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
