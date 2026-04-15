import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Singleton
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient client;

  Future<void> init() async {
    await Supabase.initialize(
      url: 'https://odhzkmgxnujisjuixiju.supabase.co', // Replace with your Supabase URL
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9kaHprbWd4bnVqaXNqdWl4aWp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1OTg5OTksImV4cCI6MjA5MDE3NDk5OX0._jL60URYq8RosA5upDpzG_SMS3_yqSVsl_jQo-xw2R8', // Replace with your Supabase anon key
      debug: true,
    );

    client = Supabase.instance.client;
  }

  // Current user
  User? get currentUser => client.auth.currentUser;

  // Ensure user exists in custom 'users' table
  Future<void> ensureUserInTable() async {
    final user = currentUser;
    if (user == null) return;

    try {
      // Check if user exists
      final existing = await client
          .from('users')
          .select()
          .eq('id', user.id);

      if ((existing as List).isEmpty) {
        // Insert user
        await client.from('users').insert({
          'id': user.id,
          'email': user.email,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error ensuring user in table: $e');
    }
  }
}