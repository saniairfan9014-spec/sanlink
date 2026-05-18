import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_model.dart';
import '../models/room_member_model.dart';

final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

class RoomService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<RoomModel> createRoom({
    required String title,
    String? description,
    required String category,
    required String hostId,
    required String channelName,
  }) async {
    // 1. Insert into rooms table
    final response = await _supabase.from('rooms').insert({
      'title': title,
      'description': description,
      'category': category,
      'host_id': hostId,
      'channel_name': channelName,
      'is_live': true,
      'listeners_count': 0,
    }).select().single();
    
    final room = RoomModel.fromJson(response);
    
    // 2. Insert host into room_members table
    await _supabase.from('room_members').insert({
      'room_id': room.id,
      'user_id': hostId,
      'role': 'host',
      'mic_seat': 1,
      'is_muted': false,
    });

    return room;
  }

  Future<bool> claimSeat(String roomId, String userId, String userName, String? avatarUrl, int seatIndex) async {
    try {
      final response = await _supabase.rpc('claim_mic_seat', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_seat_index': seatIndex,
      });
      return response == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> leaveSeat(String roomId, String userId) async {
    await _supabase.rpc('leave_mic_seat', params: {
      'p_room_id': roomId,
      'p_user_id': userId,
    });
  }

  Future<void> lockSeat(String roomId, int seatIndex) async {
    final roomData = await _supabase.from('rooms').select('locked_seats').eq('id', roomId).single();
    final List<dynamic> current = roomData['locked_seats'] ?? [];
    final List<int> updated = List<int>.from(current);
    if (!updated.contains(seatIndex)) {
      updated.add(seatIndex);
      await _supabase.from('rooms').update({'locked_seats': updated}).eq('id', roomId);
    }
  }

  Future<void> unlockSeat(String roomId, int seatIndex) async {
    final roomData = await _supabase.from('rooms').select('locked_seats').eq('id', roomId).single();
    final List<dynamic> current = roomData['locked_seats'] ?? [];
    final List<int> updated = List<int>.from(current);
    if (updated.contains(seatIndex)) {
      updated.remove(seatIndex);
      await _supabase.from('rooms').update({'locked_seats': updated}).eq('id', roomId);
    }
  }

  Future<void> updateRoomStatus(String roomId, bool isLive) async {
    await _supabase.from('rooms').update({'is_live': isLive}).eq('id', roomId);
  }

  Future<void> updateRoom({
    required String roomId,
    required String title,
    String? description,
    required String category,
  }) async {
    await _supabase.from('rooms').update({
      'title': title,
      'description': description,
      'category': category,
    }).eq('id', roomId);
  }

  Future<void> joinRoom(RoomMemberModel member) async {
    // Only send columns that exist in the DB schema
    await _supabase.from('room_members').upsert({
      'room_id': member.roomId,
      'user_id': member.userId,
      'role': member.role.name,
      'mic_seat': member.micSeat,
      'is_muted': member.isMuted,
    }, onConflict: 'room_id, user_id');
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    await _supabase.from('room_members').delete().eq('room_id', roomId).eq('user_id', userId);
  }
  
  Future<void> updateMemberRole(String roomId, String userId, RoomRole role) async {
    await _supabase.from('room_members').update({'role': role.name}).eq('room_id', roomId).eq('user_id', userId);
  }
  
  Future<void> sendMessage(String roomId, String userId, String content) async {
    if (content.trim().isEmpty) return;
    await _supabase.from('room_messages').insert({
      'room_id': roomId,
      'sender_id': userId,
      'message': content.trim(),
    });
  }
}
