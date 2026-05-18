import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
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
  final bool isClaimingSeat;
  final String? claimError;
  final Map<String, Map<String, dynamic>> userProfiles;
  final Set<String> activePresenceUserIds;
  final bool isKicked;

  const VoiceRoomState({
    this.isLoading = false,
    this.room,
    this.members = const [],
    this.messages = const [],
    this.isMuted = true,
    this.error,
    this.isClaimingSeat = false,
    this.claimError,
    this.userProfiles = const {},
    this.activePresenceUserIds = const {},
    this.isKicked = false,
  });

  VoiceRoomState copyWith({
    bool? isLoading,
    RoomModel? room,
    List<RoomMemberModel>? members,
    List<RoomMessageModel>? messages,
    bool? isMuted,
    String? error,
    bool? isClaimingSeat,
    String? Function()? claimError,
    Map<String, Map<String, dynamic>>? userProfiles,
    Set<String>? activePresenceUserIds,
    bool? isKicked,
  }) {
    return VoiceRoomState(
      isLoading: isLoading ?? this.isLoading,
      room: room ?? this.room,
      members: members ?? this.members,
      messages: messages ?? this.messages,
      isMuted: isMuted ?? this.isMuted,
      error: error ?? this.error,
      isClaimingSeat: isClaimingSeat ?? this.isClaimingSeat,
      claimError: claimError != null ? claimError() : this.claimError,
      userProfiles: userProfiles ?? this.userProfiles,
      activePresenceUserIds: activePresenceUserIds ?? this.activePresenceUserIds,
      isKicked: isKicked ?? this.isKicked,
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
  RealtimeChannel? _usersRealtimeSub;
  RealtimeChannel? _presenceChannel;
  DateTime? _joinTime;

  VoiceRoomController({required VoiceRoomRepository repository})
      : _repository = repository,
        super(const VoiceRoomState());

  Future<void> _fetchProfilesForMembers(List<RoomMemberModel> members) async {
    final userIds = members.map((m) => m.userId).toSet().toList();
    if (userIds.isEmpty) return;

    final missingIds = userIds.where((id) => !state.userProfiles.containsKey(id)).toList();
    if (missingIds.isEmpty) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name, profile_pic')
          .inFilter('id', missingIds);

      final Map<String, Map<String, dynamic>> newProfiles = {...state.userProfiles};
      for (final raw in response) {
        if (raw['id'] != null) {
          newProfiles[raw['id'] as String] = raw;
        }
      }

      final updatedMembers = state.members.map((m) {
        final profile = newProfiles[m.userId];
        return m.copyWith(
          userName: profile?['name'] ?? m.userName,
          avatarUrl: profile?['profile_pic'] ?? profile?['avatar_url'] ?? m.avatarUrl,
        );
      }).toList();

      state = state.copyWith(
        userProfiles: newProfiles,
        members: updatedMembers,
      );
    } catch (e) {
      print('Error fetching user profiles in batch: $e');
    }
  }

  Future<void> _fetchProfilesForMessages(List<RoomMessageModel> messages) async {
    final senderIds = messages.map((m) => m.userId).toSet().toList();
    if (senderIds.isEmpty) return;

    final missingIds = senderIds.where((id) => !state.userProfiles.containsKey(id)).toList();
    if (missingIds.isEmpty) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name, profile_pic')
          .inFilter('id', missingIds);

      final Map<String, Map<String, dynamic>> newProfiles = {...state.userProfiles};
      for (final raw in response) {
        if (raw['id'] != null) {
          newProfiles[raw['id'] as String] = raw;
        }
      }
      state = state.copyWith(userProfiles: newProfiles);
    } catch (e) {
      print('Error fetching user profiles for messages: $e');
    }
  }

  Future<void> initRoom(String roomId, String currentUserId, String token, String channelName) async {
    _joinTime = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
    state = state.copyWith(isLoading: true, error: null, messages: const []);
    try {
      // Setup listeners
      _roomSub = _repository.watchRoom(roomId).listen((room) {
        state = state.copyWith(
          room: room,
          isKicked: room.kickedUserIds.contains(currentUserId),
        );
      });
      
      _membersSub = _repository.watchMembers(roomId).listen((members) {
        final initialMembers = members.map((m) {
          final profile = state.userProfiles[m.userId];
          return m.copyWith(
            userName: profile?['name'] ?? m.userName,
            avatarUrl: profile?['profile_pic'] ?? profile?['avatar_url'] ?? m.avatarUrl,
          );
        }).toList();
        
        // Sync Agora state with the local user's role and mute status dynamically
        final currentMember = initialMembers.firstWhereOrNull((m) => m.userId == currentUserId);
        if (currentMember != null) {
          _repository.changeRole(currentMember.role);
          _repository.muteMic(currentMember.isMuted);
          state = state.copyWith(isMuted: currentMember.isMuted);
        }

        state = state.copyWith(members: initialMembers);
        _fetchProfilesForMembers(members);
      });
      
      _messagesSub = _repository.watchMessages(roomId).listen((messagesList) {
        final sessionMessages = messagesList.where((m) {
          if (_joinTime == null) return false;
          return m.createdAt.toUtc().isAfter(_joinTime!);
        }).toList();
        state = state.copyWith(messages: sessionMessages);
        _fetchProfilesForMessages(sessionMessages);
      });
      
      _speakingSub = _repository.watchSpeakingStatus().listen((speakingUids) {
        final updatedMembers = state.members.map((m) {
          final int agoraUid = m.userId.hashCode.abs() & 0x7FFFFFFF;
          final bool isSpeaking = speakingUids.contains(agoraUid);
          return m.copyWith(isSpeaking: isSpeaking);
        }).toList();
        state = state.copyWith(members: updatedMembers);
      });

      // Realtime subscription for user profile updates
      _usersRealtimeSub = Supabase.instance.client
          .channel('public:users')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            callback: (payload) {
              final record = payload.newRecord;
              if (record != null && record['id'] != null) {
                final userId = record['id'] as String;
                final Map<String, Map<String, dynamic>> updatedProfiles = {
                  ...state.userProfiles,
                  userId: record,
                };
                
                final updatedMembers = state.members.map((m) {
                  if (m.userId == userId) {
                    return m.copyWith(
                      userName: record['name'] ?? m.userName,
                      avatarUrl: record['profile_pic'] ?? record['avatar_url'] ?? m.avatarUrl,
                    );
                  }
                  return m;
                }).toList();

                state = state.copyWith(
                  userProfiles: updatedProfiles,
                  members: updatedMembers,
                );
              }
            },
          )
          .subscribe();

      // Presence subscription
      _presenceChannel = Supabase.instance.client.channel('presence:$roomId');
      
      _presenceChannel!.onPresenceSync((payload) {
        final stateList = _presenceChannel!.presenceState();
        final Set<String> uniqueUserIds = {};
        for (final singleState in stateList) {
          for (final presence in singleState.presences) {
            final payloadMap = presence.payload;
            final userId = payloadMap['user_id'] as String?;
            if (userId != null) {
              uniqueUserIds.add(userId);
            }
          }
        }
        state = state.copyWith(activePresenceUserIds: uniqueUserIds);
      }).subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            await _presenceChannel!.track({
              'user_id': currentUserId,
              'status': 'online',
              'joined_at': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            print('Error tracking presence: $e');
          }
        }
      });

      // Determine starting role: Host if creator, listener otherwise
      final roomData = await Supabase.instance.client
          .from('rooms')
          .select('host_id')
          .eq('id', roomId)
          .maybeSingle();
      final isHost = roomData != null && roomData['host_id'] == currentUserId;
      final initialRole = isHost ? RoomRole.host : RoomRole.listener;

      // Join logic
      await _repository.joinRoom(
        roomId: roomId,
        userId: currentUserId,
        token: token,
        channelName: channelName,
        role: initialRole,
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleMute() async {
    final newMutedState = !state.isMuted;
    await _repository.muteMic(newMutedState);
    
    final room = state.room;
    final user = Supabase.instance.client.auth.currentUser;
    if (room != null && user != null) {
      await _repository.updateMemberMute(room.id, user.id, newMutedState);
    }
    state = state.copyWith(isMuted: newMutedState);
  }

  Future<void> requestMic(String roomId, String userId) async {
    await _repository.requestMic(roomId, userId);
  }

  Future<void> claimSeat(String roomId, String userId, String userName, String? avatarUrl, int seatIndex) async {
    if (state.isClaimingSeat) return;
    state = state.copyWith(isClaimingSeat: true, claimError: () => null);
    try {
      final success = await _repository.claimSeat(roomId, userId, userName, avatarUrl, seatIndex);
      if (success) {
        await _repository.changeRole(RoomRole.speaker);
      } else {
        state = state.copyWith(claimError: () => 'Seat is already taken or locked!');
      }
    } catch (e) {
      state = state.copyWith(claimError: () => e.toString());
    } finally {
      state = state.copyWith(isClaimingSeat: false);
    }
  }

  Future<void> leaveSeat(String roomId, String userId) async {
    try {
      await _repository.leaveSeat(roomId, userId);
      await _repository.changeRole(RoomRole.listener);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> lockSeat(String roomId, int seatIndex) async {
    try {
      await _repository.lockSeat(roomId, seatIndex);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> unlockSeat(String roomId, int seatIndex) async {
    try {
      await _repository.unlockSeat(roomId, seatIndex);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearClaimError() {
    state = state.copyWith(claimError: () => null);
  }

  Future<void> sendMessage(String roomId, String userId, String content) async {
    await _repository.sendMessage(roomId, userId, content);
  }

  Future<void> updateRoomInfo(String roomId, String title, String? description, String category) async {
    try {
      await _repository.updateRoom(
        roomId: roomId,
        title: title,
        description: description,
        category: category,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> banChatUser(String roomId, String userId) async {
    final room = state.room;
    if (room == null) return;

    final List<String> currentBans = List<String>.from(room.bannedChatUserIds);
    if (currentBans.contains(userId)) {
      currentBans.remove(userId);
    } else {
      currentBans.add(userId);
    }

    final newDescription = RoomModel.formatDescription(
      cleanDescription: room.cleanDescription ?? '',
      coverImageUrl: room.coverImageUrl,
      bannedChatUserIds: currentBans,
      kickedUserIds: room.kickedUserIds,
    );

    try {
      await _repository.updateRoom(
        roomId: roomId,
        title: room.title,
        description: newDescription,
        category: room.category,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> kickUser(String roomId, String userId) async {
    final room = state.room;
    if (room == null) return;

    final List<String> currentKicks = List<String>.from(room.kickedUserIds);
    if (!currentKicks.contains(userId)) {
      currentKicks.add(userId);
    }

    final newDescription = RoomModel.formatDescription(
      cleanDescription: room.cleanDescription ?? '',
      coverImageUrl: room.coverImageUrl,
      bannedChatUserIds: room.bannedChatUserIds,
      kickedUserIds: currentKicks,
    );

    try {
      // 1. Persist the kick list in room description
      await _repository.updateRoom(
        roomId: roomId,
        title: room.title,
        description: newDescription,
        category: room.category,
      );
      
      // 2. Completely remove their member record from the room members table
      await _repository.leaveRoom(roomId, userId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    _roomSub?.cancel();
    _membersSub?.cancel();
    _messagesSub?.cancel();
    _speakingSub?.cancel();
    _usersRealtimeSub?.unsubscribe();
    
    // Clean up presence tracking
    _presenceChannel?.untrack();
    if (_presenceChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_presenceChannel!);
      } catch (e) {
        print('Error removing presence channel: $e');
      }
      _presenceChannel = null;
    }
    
    _joinTime = null;
    await _repository.leaveRoom(roomId, userId);
    state = const VoiceRoomState(); // Reset state
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _membersSub?.cancel();
    _messagesSub?.cancel();
    _speakingSub?.cancel();
    _usersRealtimeSub?.unsubscribe();
    
    // Clean up presence tracking
    _presenceChannel?.untrack();
    if (_presenceChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_presenceChannel!);
      } catch (e) {
        print('Error removing presence channel in dispose: $e');
      }
      _presenceChannel = null;
    }
    
    _joinTime = null;
    super.dispose();
  }
}
