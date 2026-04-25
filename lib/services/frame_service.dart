import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FrameService {
  final SupabaseClient _client = Supabase.instance.client;
  SupabaseClient get client => _client;

  /// Fetch all available frames
  Future<List<Map<String, dynamic>>> getAllFrames() async {
    try {
      final response = await _client
          .from('frames')
          .select()
          .eq('is_active', true)
          .order('required_level', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error fetching all frames: $e");
      return [];
    }
  }

  /// Fetch user's unlocked frames
  Future<List<String>> getUnlockedFrameIds() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('user_frames')
          .select('frame_id')
          .eq('user_id', user.id);

      return (response as List).map((f) => f['frame_id'] as String).toList();
    } catch (e) {
      print("Error fetching user frames: $e");
      return [];
    }
  }

  /// Equip a frame
  Future<void> equipFrame(String frameId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Reset all frames for this user in user_frames
      await _client
          .from('user_frames')
          .update({'is_equipped': false})
          .eq('user_id', user.id);

      // 2. Set the selected frame as equipped in user_frames
      await _client
          .from('user_frames')
          .update({'is_equipped': true})
          .eq('user_id', user.id)
          .eq('frame_id', frameId);

      // 3. Update the users table for global access
      await _client
          .from('users')
          .update({'selected_frame': frameId})
          .eq('id', user.id);
      
      print("Frame $frameId equipped successfully ✅");
      
      // 4. Cache locally for better UX
      final prefs = await SharedPreferences.getInstance();
      final frameData = await _client.from('frames').select('image_url').eq('id', frameId).maybeSingle();
      if (frameData != null) {
        await prefs.setString('equipped_frame_url_${user.id}', frameData['image_url']);
      }
    } catch (e) {
      print("Error in equipFrame: $e");
      throw e;
    }
  }

  /// Get locally cached frame URL
  Future<String?> getLocalEquippedFrame() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('equipped_frame_url_${user.id}');
  }

  /// Check if user has unlocked a frame (basic frames are always unlocked)
  bool isFrameUnlocked(Map<String, dynamic> frame, List<String> unlockedIds, int userLevel) {
    final id = frame['id'];
    final rarity = frame['rarity']?.toString().toLowerCase();
    final reqLevel = frame['required_level'] ?? 1;

    // Common frames or level 1 frames are basic
    if (rarity == 'common' || reqLevel <= 1) return true;
    
    // Check if it's in the unlocked list
    return unlockedIds.contains(id) || userLevel >= reqLevel;
  }
}