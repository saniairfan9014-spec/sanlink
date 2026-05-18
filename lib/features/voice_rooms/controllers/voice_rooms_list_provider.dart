import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/room_model.dart';
import '../data/repositories/voice_room_repository.dart';

final activeRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final repository = ref.watch(voiceRoomRepositoryProvider);
  return repository.watchActiveRooms();
});

final roomHostProfileProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, hostId) async {
  try {
    final response = await Supabase.instance.client
        .from('users')
        .select('id, name, profile_pic, avatar_url')
        .eq('id', hostId)
        .maybeSingle();
    return response;
  } catch (e) {
    print('Error fetching host profile for $hostId: $e');
    return null;
  }
});
