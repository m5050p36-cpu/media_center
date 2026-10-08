import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'providers/player_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_service.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';

void main() {
  // ═══ 1) تهيئة Flutter فوراً ═══
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
  };

  // ═══ 2) ابدأ التطبيق فوراً (بدون انتظار) ═══
  runApp(const MediaCenterApp());

  // ═══ 3) تهيئة الخدمات في الخلفية ═══
  _bootstrapServices();
}

/// تهيئة جميع الخدمات في الخلفية (بدون حجب UI)
Future<void> _bootstrapServices() async {
  // ─── 1) Widgets (سريع) ───
  try {
    await WidgetService.initialize();
  } catch (e) {
    debugPrint('Widget init error: $e');
  }

  // ─── 2) Audio Background ───
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.mediahub.mediacenter.channel.audio',
      androidNotificationChannelName: 'AR مشغل موسيقى & فيديوهات',
      androidNotificationChannelDescription: 'تشغيل الصوتيات في الخلفية',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
      preloadArtwork: false, // ⚡ لا نُحمّل الصور مسبقاً (يبطئ البدء)
      androidShowNotificationBadge: true,
      fastForwardInterval: const Duration(seconds: 30),
      rewindInterval: const Duration(seconds: 10),
    );
    debugPrint('✅ Background audio ready');
  } catch (e) {
    debugPrint('⚠️ Background audio init error: $e');
  }

  // ─── 3) Supabase (قد يأخذ وقتاً بسبب الشبكة) ───
  try {
    await SupabaseService.initialize();
    debugPrint('✅ Supabase ready');
    // إشعار الواجهة بأن التهيئة انتهت
    _initializationDone.value = true;
  } catch (e) {
    debugPrint('⚠️ Supabase init error: $e');
    // حتى لو فشل، نُظهر الواجهة
    _initializationDone.value = true;
  }
}

/// ValueNotifier يُخبر SplashScreen بأن التهيئة انتهت
final ValueNotifier<bool> _initializationDone = ValueNotifier(false);
ValueNotifier<bool> get initializationDone => _initializationDone;

class MediaCenterApp extends StatelessWidget {
  const MediaCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, theme, lang, _) {
          return MaterialApp(
            title: 'AR مشغل موسيقى & فيديوهات',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.byType(theme.type),
            locale: lang.locale,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
