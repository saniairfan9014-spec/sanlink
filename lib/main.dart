import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'features/home/home_screen.dart';
import 'features/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check for initial session
    final currentUser = SupabaseService().client.auth.currentUser;

    return MaterialApp(
      title: 'Sanlink',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF7C5CFC),
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        fontFamily: 'Poppins',
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen()
    );
  }
}