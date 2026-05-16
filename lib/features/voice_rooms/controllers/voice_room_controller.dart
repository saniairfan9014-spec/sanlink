import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../data/repositories/voice_room_repository.dart';
import '../data/models/room_model.dart';
import '../data/models/room_member_model.dart';
import '../data/models/room_message_model.dart';

class VoiceRoomState {
  final bool isLoading;
  final RoomModel? room;
  final List<RoomMemberModel> members;
  final List<RoomMessageModel> messages;
  final bool isMuted;
  final String? error;

  const VoiceRoomState({
    this.isLoading = false,
    this.room,
    this.members = const [],
    this.messages = const [],
    this.isMuted = true,
    this.error,
  });

  VoiceRoomState copyWith({
    bool? isLoading,
    RoomModel? room,
    List<RoomMemberModel>? members,
    List<RoomMessageModel>? messages,
    bool? isMuted,
    String? error,
  }) {
    return VoiceRoomState(
      isLoading: isLoading ?? this.isLoading,
      room: room ?? this.room,
      members: members ?? this.members,
      messages: messages ?? this.messages,
      isMuted: isMuted ?? this.isMuted,
      error: error ?? this.error,
    );
  }
}

final voiceRoomControllerProvider =
    StateNotifierProvider<VoiceRoomController, VoiceRoomState>((ref) {
  return VoiceRoomController(
    repository: ref.watch(voiceRoomRepositoryProvider),
  );
});

class VoiceRoomController extends StateNotifier<VoiceRoomState> {
  final VoiceRoomRepository _repository;
  StreamSubscription? _roomSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _messagesSub;
  StreamSubscription? _speakingSub;

  VoiceRoomController({required VoiceRoomRepository repository})
      : _repository = repository,
        super(const VoiceRoomState());

  Future<void> initRoom(String roomId, String currentUserId, String token, String channelName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Setup listeners
      _roomSub = _repository.watchRoom(roomId).listen((room) {
        state = state.copyWith(room: room);
      });
      
      _membersSub = _repository.watchMembers(roomId).listen((members) {
        state = state.copyWith(members: members);
      });
      
      _messagesSub = _repository.watchMessages(roomId).listen((messagesList) {
        state = state.copyWith(messages: messagesList);
      });
      
      _speakingSub = _repository.watchSpeakingStatus().listen((isSpeaking) {
        // Here we would map the speaking status to the current user in members list
      });

      // Join logic
      await _repository.joinRoom(
        roomId: roomId,
        userId: currentUserId,
        token: token,
        channelName: channelName,
        role: RoomRole.listener,
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleMute() async {
    final newMutedState = !state.isMuted;
    await _repository.muteMic(newMutedState);
    state = state.copyWith(isMuted: newMutedState);
  }

  Future<void> requestMic(String roomId, String userId) async {
    await _repository.requestMic(roomId, userId);
  }

  Future<void> claimSeat(String roomId, String userId, String userName, String? avatarUrl, int seatIndex) async {
    await _repository.claimSeat(roomId, userId, userName, avatarUrl, seatIndex);
  }

  Future<void> sendMessage(String roomId, String userId, String content) async {
    await _repository.sendMessage(roomId, userId, content);
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    _roomSub?.cancel();
    _membersSub?.cancel();
    _messagesSub?.cancel();
    _speakingSub?.cancel();
    await _repository.leaveRoom(roomId, userId);
    state = const VoiceRoomState(); // Reset state
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _membersSub?.cancel();
    _messagesSub?.cancel();
    _speakingSub?.cancel();
    super.dispose();
  }
}
