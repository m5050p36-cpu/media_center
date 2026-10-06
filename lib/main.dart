import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'providers/player_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'widgets/mini_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
  };

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.mediahub.mediacenter.channel.audio',
      androidNotificationChannelName: 'Media Center Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      preloadArtwork: false,
    );
    debugPrint('✅ Background audio service initialized');
  } catch (e) {
    debugPrint('⚠️ Background audio init failed: $e');
  }

  runZonedGuarded(() async {
    try {
      await SupabaseService.initialize();
      runApp(const MediaCenterApp());
    } catch (e, st) {
      debugPrint('FATAL: $e\n$st');
      runApp(ErrorApp(error: e.toString(), stack: st.toString()));
    }
  }, (error, stack) {
    debugPrint('Zone error: $error\n$stack');
  });
}

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
            title: 'Media Center',
            debugShowCheckedModeBanner: false,
            themeMode: theme.mode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            locale: lang.locale,
            // 🔥 استخدام Navigator مع إضافة الـ MiniPlayer
            builder: (context, child) {
              return Stack(
                children: [
                  if (child != null) child,
                  // MiniPlayer ثابت أسفل جميع الصفحات
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(top: false, child: MiniPlayer()),
                  ),
                ],
              );
            },
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  final String stack;
  const ErrorApp({super.key, required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B1B2E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  const Text('حدث خطأ في التشغيل',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.black,
                    child: SelectableText(error,
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
