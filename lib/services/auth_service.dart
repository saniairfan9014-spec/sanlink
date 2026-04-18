import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class AuthService {
  final supabase = SupabaseService().client;

  // Getter for current user
  User? get currentUser => supabase.auth.currentUser;

  // ✅ Signup with name
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final result = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) return "Signup failed. Please try again.";

      // Insert into 'users' table
      await supabase.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });

      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unexpected error occurred: ${e.toString()}";
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
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unexpected error occurred: ${e.toString()}";
    }
  }

  // ✅ Logout
  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}