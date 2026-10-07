import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  PickedImageInfo? _newAvatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AuthProvider>().profile;
    _nameCtrl.text = p?.fullName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picked = source == ImageSource.gallery
        ? await ImageService.pickFromGallery()
        : await ImageService.pickFromCamera();
    if (picked == null) return;

    PickedImageInfo result = picked;
    if (picked.sizeBytes > 500 * 1024) {
      result = await ImageService.compress(
        picked,
        quality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );
    }

    if (!mounted) return;
    setState(() => _newAvatar = result);
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('الاسم لا يمكن أن يكون فارغاً', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      String? newAvatarUrl;
      if (_newAvatar != null) {
        final userId = auth.profile?.id;
        if (userId == null) {
          _snack('خطأ في هوية المستخدم', isError: true);
          setState(() => _saving = false);
          return;
        }
        newAvatarUrl = await ImageService.uploadAvatar(_newAvatar!, userId);
      }

      final ok = await auth.updateProfile(
        fullName: _nameCtrl.text.trim(),
        avatarUrl: newAvatarUrl,
      );

      if (!mounted) return;

      if (ok) {
        _snack('تم الحفظ بنجاح ✅', isError: false);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context, true);
      } else {
        _snack(auth.error ?? 'فشل الحفظ', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAvatar() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.profile?.id;
    if (userId == null) return;

    if (!mounted) return;
    setState(() => _saving = true);

    try {
      await ImageService.deleteAvatar(userId);
      final ok = await auth.updateProfile(avatarUrl: '');
      if (!mounted) return;
      if (ok) {
        setState(() => _newAvatar = null);
        _snack('تم حذف الصورة', isError: false);
      } else {
        _snack('فشل الحذف', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentAvatar = auth.profile?.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
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
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildAvatarPreview(currentAvatar),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: AppTheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _saving ? null : _showPickDialog,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              _newAvatar != null
                  ? 'صورة جديدة: ${_newAvatar!.sizeText}'
                  : 'اضغط الكاميرا لتغيير الصورة',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.7),
              ),
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            'الاسم الكامل',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'أدخل اسمك الكامل',
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppTheme.primary),
              filled: true,
              fillColor: Theme.of(context).cardTheme.color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'البريد الإلكتروني',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    auth.profile?.email ?? '-',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              ],
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPreview(String? currentAvatar) {
    if (_newAvatar != null) {
      return Image.file(_newAvatar!.file, fit: BoxFit.cover);
    }
    if (currentAvatar != null && currentAvatar.isNotEmpty) {
      return Image.network(
        currentAvatar,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) =>
            p == null ? child : _avatarPlaceholder(),
        errorBuilder: (_, __, ___) => _avatarPlaceholder(),
      );
    }
    return _avatarPlaceholder();
  }

  Widget _avatarPlaceholder() {
    final name = _nameCtrl.text.trim();
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  void _showPickDialog() {
    // اقرأ القيم قبل showModalBottomSheet
    final auth = context.read<AuthProvider>();
    final hasSavedAvatar = auth.profile?.avatarUrl?.isNotEmpty ?? false;
    final hasNewAvatar = _newAvatar != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
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
              'تغيير الصورة الرمزية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppTheme.primary),
              title: const Text('من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text('من الكاميرا'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.camera);
              },
            ),
            if (hasNewAvatar || hasSavedAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: const Text('حذف الصورة',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteAvatar();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
