import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FrameService {
  final SupabaseClient _client = Supabase.instance.client;
  SupabaseClient get client => _client;

  /// Fetch all frames
  Future<List<dynamic>> getAllFrames() async {
    final response = await _client
        .from('frames')
        .select()
        .order('required_level', ascending: true);

    return response;
  }

  /// Fetch user's unlocked frames
  Future<List<dynamic>> getUserFrames() async {
    final response = await _client
        .from('user_frames')
        .select();

    return response;
  }

  /// List frames directly from storage bucket (Discovery mode)
  Future<List<Map<String, dynamic>>> getBucketFrames() async {
    try {
      final List<FileObject> files = await _client
          .storage
          .from('frames')
          .list();

      return files.map((file) {
        final publicUrl = _client.storage.from('frames').getPublicUrl(file.name);
        return {
          'id': file.id ?? file.name,
          'name': file.name.split('.').first.replaceAll('_', ' ').toUpperCase(),
          'image_url': publicUrl,
          'required_level': 0, // Default to 0 for discovered frames
          'is_discovered': true,
        };
      }).toList();
    } catch (e) {
      print("Error listing bucket frames: $e");
      return [];
    }
  }

  /// Equip a frame
  Future<void> equipFrame(String frameId, String imageUrl) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Save locally as fallback (VERY IMPORTANT since DB columns might be missing)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_frame_${user.id}', imageUrl);
      
      // 2. Update the users table for immediate UI reflection (try, but don't fail if column missing)
      try {
        await _client.from('users').update({
          'profile_frame': imageUrl,
        }).eq('id', user.id);
      } catch (e) {
        print("Column profile_frame might be missing: $e");
      }

      // 3. Try calling RPC if it exists (for backend logic like stats)
      try {
        await _client.rpc(
          'equip_frame',
          params: {'p_frame_id': frameId},
        );
      } catch (e) {
        print("RPC equip_frame not found or failed, skipping... ($e)");
      }
    } catch (e) {
      print("Error in equipFrame process: $e");
      // Don't rethrow to avoid crashing the UI if discovery mode is active
    }
  }

  /// Get locally equipped frame URL
  Future<String?> getLocalEquippedFrame() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('local_frame_${user.id}');
  }
}