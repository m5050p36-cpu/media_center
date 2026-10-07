import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_service.dart';
import '../theme/app_theme.dart';

class VersionCheckDialog {
  /// يعرض الحوار إذا كان الإصدار الحالي غير مدعوم
  static Future<void> check(
    BuildContext context, {
    required int currentVersionCode,
  }) async {
    try {
      final latest = await VersionService.fetchLatest();
      if (latest == null) return;

      // إذا كان الإصدار الحالي أقل من آخر إصدار مفعّل
      if (currentVersionCode < latest.versionCode) {
        if (!context.mounted) return;
        await _showUpdateDialog(
          context,
          latest: latest,
          forceUpdate: latest.forceUpdate,
        );
      }
    } catch (_) {}
  }

  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required AppVersionInfo latest,
    required bool forceUpdate,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (_) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          icon: Icon(
            forceUpdate ? Icons.warning_amber : Icons.system_update,
            color: forceUpdate ? Colors.orangeAccent : AppTheme.primary,
            size: 48,
          ),
          title: Text(
            forceUpdate ? 'تحديث إجباري' : 'يتوفر تحديث جديد',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الإصدار ${latest.versionName}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (latest.releaseNotes != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    latest.releaseNotes!,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                forceUpdate
                    ? 'يجب تحديث التطبيق للمتابعة'
                    : 'نوصي بالتحديث للحصول على أفضل تجربة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لاحقاً'),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                final url = latest.downloadUrl;
                if (url != null && url.isNotEmpty) {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                }
                if (!forceUpdate && context.mounted) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
