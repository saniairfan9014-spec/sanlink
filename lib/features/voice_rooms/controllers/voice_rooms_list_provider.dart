import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/room_model.dart';
import '../data/repositories/voice_room_repository.dart';

final activeRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final repository = ref.watch(voiceRoomRepositoryProvider);
  return repository.watchActiveRooms();
});
