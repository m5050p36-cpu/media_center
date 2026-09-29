import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MediaCenterApp());
}

class MediaCenterApp extends StatelessWidget {
  const MediaCenterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: MaterialApp(
        title: 'Media Center',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const LoginScreen(),
      ),
    );
  }
}
