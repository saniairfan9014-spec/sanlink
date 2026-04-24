import 'package:supabase_flutter/supabase_flutter.dart';

class FrameService {
  final SupabaseClient _client = Supabase.instance.client;

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

  /// Equip a frame using RPC
  Future<void> equipFrame(String frameId) async {
    final res = await _client.rpc(
      'equip_frame',
      params: {'p_frame_id': frameId},
    );

    if (res.error != null) {
      throw res.error!;
    }
  }
}