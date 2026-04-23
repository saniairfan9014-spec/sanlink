import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'features/home/home_screen.dart';
import 'features/auth/login_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService().init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check for initial session
    final currentUser = SupabaseService().client.auth.currentUser;

    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Sanlink',
          themeMode: themeProvider.flutterThemeMode,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          debugShowCheckedModeBanner: false,
          home: const LoginScreen()
        );
      },
    );
  }
}