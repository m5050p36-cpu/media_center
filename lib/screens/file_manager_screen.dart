import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});
  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  List<FileSystemEntity> _items = [];
  bool _loading = true;
  String _currentPath = '/storage/emulated/0';
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _load('/storage/emulated/0');
  }

  Future<void> _load(String path) async {
    setState(() => _loading = true);
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        throw Exception('المجلد غير موجود');
      }

      final entries = await dir.list().toList();

      // ترتيب: مجلدات أولاً، ثم ملفات أبجدي
      entries.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      setState(() {
        _items = entries;
        _currentPath = path;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  void _open(Directory dir) {
    _history.add(_currentPath);
    _load(dir.path);
  }

  void _goBack() {
    if (_history.isEmpty) {
      if (_currentPath != '/storage/emulated/0') {
        _load('/storage/emulated/0');
      }
      return;
    }
    final prev = _history.removeLast();
    _load(prev);
  }

  String _fileName(String path) => path.split('/').last;

  Future<void> _delete(FileSystemEntity entity) async {
    final name = _fileName(entity.path);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف "$name"؟\n\n⚠️ لا يمكن التراجع'),
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
      await entity.delete(recursive: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحذف'),
          backgroundColor: Colors.green,
        ),
      );
      _load(_currentPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل: $e')),
      );
    }
  }

  Future<void> _rename(FileSystemEntity entity) async {
    final oldName = _fileName(entity.path);
    final ctrl = TextEditingController(text: oldName);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تسمية'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == oldName) return;

    try {
      final parent = entity.parent.path;
      final newPath = '$parent/$newName';
      await entity.rename(newPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إعادة التسمية'),
          backgroundColor: Colors.green,
        ),
      );
      _load(_currentPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل: $e')),
      );
    }
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مجلد جديد'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم المجلد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final dir = Directory('$_currentPath/$name');
      await dir.create();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء المجلد'),
          backgroundColor: Colors.green,
        ),
      );
      _load(_currentPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل: $e')),
      );
    }
  }

  bool _isMediaFile(String path) {
    final e = path.toLowerCase();
    return e.endsWith('.mp3') ||
        e.endsWith('.m4a') ||
        e.endsWith('.wav') ||
        e.endsWith('.aac') ||
        e.endsWith('.ogg') ||
        e.endsWith('.flac') ||
        e.endsWith('.mp4') ||
        e.endsWith('.mkv') ||
        e.endsWith('.avi') ||
        e.endsWith('.mov') ||
        e.endsWith('.webm');
  }

  IconData _fileIcon(String path) {
    final e = path.toLowerCase();
    if (e.endsWith('.mp3') ||
        e.endsWith('.m4a') ||
        e.endsWith('.wav') ||
        e.endsWith('.flac')) {
      return Icons.music_note;
    }
    if (e.endsWith('.mp4') ||
        e.endsWith('.mkv') ||
        e.endsWith('.avi') ||
        e.endsWith('.mov')) {
      return Icons.movie;
    }
    if (e.endsWith('.jpg') ||
        e.endsWith('.jpeg') ||
        e.endsWith('.png') ||
        e.endsWith('.webp')) {
      return Icons.image;
    }
    if (e.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (e.endsWith('.txt') || e.endsWith('.md')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _fileColor(String path) {
    final e = path.toLowerCase();
    if (e.endsWith('.mp3') || e.endsWith('.m4a') || e.endsWith('.flac')) {
      return AppTheme.primary;
    }
    if (e.endsWith('.mp4') || e.endsWith('.mkv')) {
      return AppTheme.accent;
    }
    if (e.endsWith('.jpg') || e.endsWith('.png')) {
      return Colors.orangeAccent;
    }
    return Colors.blueGrey;
  }

  Future<String> _formatSize(FileSystemEntity e) async {
    if (e is Directory) return 'مجلد';
    try {
      final size = await (e as File).length();
      if (size < 1024) return '$size B';
      if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
      if (size < 1024 * 1024 * 1024) {
        return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إدارة الملفات', style: TextStyle(fontSize: 16)),
            Text(
              _currentPath,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: _history.isNotEmpty || _currentPath != '/storage/emulated/0'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'مجلد جديد',
            onPressed: _createFolder,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(_currentPath),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('المجلد فارغ'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final isDir = item is Directory;
                    final name = _fileName(item.path);

                    return ListTile(
                      leading: isDir
                          ? const Icon(Icons.folder,
                              color: Color(0xFFFFB84D), size: 32)
                          : Icon(_fileIcon(item.path),
                              color: _fileColor(item.path), size: 28),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isDir ? FontWeight.bold : null,
                        ),
                      ),
                      subtitle: FutureBuilder<String>(
                        future: _formatSize(item),
                        builder: (_, snap) => Text(
                          snap.data ?? '',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'rename') _rename(item);
                          if (v == 'delete') _delete(item);
                        },
                        itemBuilder: (_) => [
                          if (!isDir && _isMediaFile(item.path))
                            const PopupMenuItem(
                              value: 'play',
                              child: Row(children: [
                                Icon(Icons.play_arrow, size: 18),
                                SizedBox(width: 8),
                                Text('تشغيل'),
                              ]),
                            ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('إعادة تسمية'),
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete,
                                  size: 18, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('حذف',
                                  style: TextStyle(color: Colors.redAccent)),
                            ]),
                          ),
                        ],
                      ),
                      onTap: isDir ? () => _open(item) : null,
                    );
                  },
                ),
    );
  }
}
