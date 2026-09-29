import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'screens/login_screen.dart';
import 'supabase_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    // ignore: deprecated_member_use
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );
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
