import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/agora_service.dart';
import '../services/realtime_service.dart';
import '../services/room_service.dart';
import '../models/room_model.dart';
import '../models/room_member_model.dart';
import '../models/room_message_model.dart';

final voiceRoomRepositoryProvider = Provider<VoiceRoomRepository>((ref) {
  return VoiceRoomRepository(
    agoraService: ref.watch(agoraServiceProvider),
    realtimeService: ref.watch(realtimeServiceProvider),
    roomService: ref.watch(roomServiceProvider),
  );
});

class VoiceRoomRepository {
  final AgoraService _agoraService;
  final RealtimeService _realtimeService;
  final RoomService _roomService;

  VoiceRoomRepository({
    required AgoraService agoraService,
    required RealtimeService realtimeService,
    required RoomService roomService,
  })  : _agoraService = agoraService,
        _realtimeService = realtimeService,
        _roomService = roomService;

  // Real-time Streams
  Stream<List<RoomModel>> watchActiveRooms() => _realtimeService.watchActiveRooms();

  Stream<RoomModel> watchRoom(String roomId) => _realtimeService.subscribeToRoom(roomId);
  Stream<List<RoomMemberModel>> watchMembers(String roomId) => _realtimeService.subscribeToMembers(roomId);
  Stream<List<RoomMessageModel>> watchMessages(String roomId) => _realtimeService.subscribeToMessages(roomId);
  Stream<bool> watchSpeakingStatus() => _agoraService.onSpeakingStatusChanged;

  // Actions
  Future<RoomModel> createRoom({
    required String title,
    String? description,
    required String category,
    required String hostId,
    required String channelName,
  }) => _roomService.createRoom(
    title: title,
    description: description,
    category: category,
    hostId: hostId,
    channelName: channelName,
  );

  Future<String?> uploadRoomCover({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    String? contentType,
  }) => _roomService.uploadRoomCover(
    filePath: filePath,
    fileBytes: fileBytes,
    fileName: fileName,
    contentType: contentType,
  );

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String token,
    required String channelName,
    required RoomRole role,
  }) async {
    final member = RoomMemberModel(
      id: '${roomId}_$userId',
      roomId: roomId,
      userId: userId,
      role: role,
      joinedAt: DateTime.now(),
    );
    await _roomService.joinRoom(member);
    await _agoraService.joinChannel(token, channelName, userId);
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    await _agoraService.leaveChannel();
    await _roomService.leaveRoom(roomId, userId);
  }

  Future<void> muteMic(bool mute) => _agoraService.muteMic(mute);

  Future<void> requestMic(String roomId, String userId) async {
    await _roomService.updateMemberRole(roomId, userId, RoomRole.speaker);
  }

  Future<bool> claimSeat(String roomId, String userId, String userName, String? avatarUrl, int seatIndex) async {
    return _roomService.claimSeat(roomId, userId, userName, avatarUrl, seatIndex);
  }

  Future<void> leaveSeat(String roomId, String userId) async {
    await _roomService.leaveSeat(roomId, userId);
  }

  Future<void> lockSeat(String roomId, int seatIndex) async {
    await _roomService.lockSeat(roomId, seatIndex);
  }

  Future<void> unlockSeat(String roomId, int seatIndex) async {
    await _roomService.unlockSeat(roomId, seatIndex);
  }

  Future<void> sendMessage(String roomId, String userId, String content) =>
      _roomService.sendMessage(roomId, userId, content);

  Future<void> updateRoom({
    required String roomId,
    required String title,
    String? description,
    required String category,
  }) async {
    await _roomService.updateRoom(
      roomId: roomId,
      title: title,
      description: description,
      category: category,
    );
  }

  Future<void> updateMemberMute(String roomId, String userId, bool isMuted) async {
    await _roomService.updateMemberMute(roomId, userId, isMuted);
  }
}
