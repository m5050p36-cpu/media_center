import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Header('مقدمة'),
          _Paragraph(
            'نحن في "AR مشغل موسيقى & فيديوهات" نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. '
            'توضح هذه السياسة كيفية جمعنا واستخدامنا وحمايتنا لمعلوماتك عند استخدام التطبيق.',
          ),
          _Header('1. المعلومات التي نجمعها'),
          _Bullet('البريد الإلكتروني: لتسجيل الدخول وإنشاء الحساب.'),
          _Bullet('الاسم الكامل: لعرضه في ملفك الشخصي.'),
          _Bullet('الصورة الرمزية: إذا قمت برفعها (اختياري).'),
          _Bullet('الملفات المحلية: نقرأ ملفات الصوت والفيديو من جهازك لعرضها فقط، ولا نرفعها إلى أي خادم.'),
          _Header('2. كيف نستخدم معلوماتك'),
          _Bullet('لتشغيل التطبيق وتقديم خدماته.'),
          _Bullet('لمزامنة بياناتك بين أجهزتك (اختياري).'),
          _Bullet('لتحسين تجربة المستخدم وتقديم الدعم.'),
          _Header('3. تخزين البيانات'),
          _Paragraph(
            'تُخزَّن بيانات حسابك بشكل آمن على خوادم Supabase مع تشفير كامل. '
            'الملفات المحلية (الصوت والفيديو) تبقى على جهازك ولا يتم رفعها.',
          ),
          _Header('4. مشاركة المعلومات'),
          _Paragraph(
            'لا نشارك بياناتك مع أي طرف ثالث لأغراض تجارية. '
            'قد نشاركها فقط عند طلب قانوني رسمي.',
          ),
          _Header('5. حقوقك'),
          _Bullet('الوصول إلى بياناتك وتعديلها من خلال الملف الشخصي.'),
          _Bullet('حذف حسابك نهائياً عند الطلب.'),
          _Bullet('طلب نسخة من بياناتك المخزنة.'),
          _Header('6. الأمان'),
          _Paragraph(
            'نستخدم تشفير TLS/SSL لجميع الاتصالات، وكلمات مرور مشفرة (bcrypt)، '
            'وسياسات RLS صارمة في قاعدة البيانات.',
          ),
          _Header('7. الكوكيز والتتبع'),
          _Paragraph(
            'التطبيق لا يستخدم كوكيز أو أدوات تتبع خارجية. '
            'لا نستخدم Google Analytics أو أي خدمات مشابهة.',
          ),
          _Header('8. الأطفال'),
          _Paragraph(
            'التطبيق غير موجّه للأطفال تحت 13 عاماً. '
            'لا نجمع بيانات من الأطفال عن قصد.',
          ),
          _Header('9. تحديثات السياسة'),
          _Paragraph(
            'قد نقوم بتحديث هذه السياسة من وقت لآخر. '
            'سيتم إشعارك بالتغييرات الجوهرية داخل التطبيق.',
          ),
          _Header('10. تواصل معنا'),
          _Paragraph(
            'لأي استفسار حول سياسة الخصوصية، يمكنك التواصل معنا عبر:',
          ),
          SizedBox(height: 12),
          _ContactButton(),
          SizedBox(height: 40),
          Center(
            child: Text(
              'آخر تحديث: أكتوبر 2026',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.7),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.parse('https://t.me/Ra16bot');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.telegram),
        label: const Text('تواصل مع الدعم'),
      ),
    );
  }
}
