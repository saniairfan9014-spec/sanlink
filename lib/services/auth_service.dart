import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class AuthService {
  final supabase = SupabaseService().client;

  // ✅ Signup with name
  Future<String?> signUp(String email, String password, String name) async {
    try {
      final result = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) return "Signup failed";

      // Insert into 'users' table
      await supabase.from('users').insert({
        'id': user.id,
        'email': user.email,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });

      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  // ✅ Login / SignIn
  Future<String?> login(String email, String password) async {
    try {
      final result = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (result.user == null) return "Invalid email or password";

      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  // ✅ Logout
  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}