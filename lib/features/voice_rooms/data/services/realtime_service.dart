import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/room_model.dart';
import '../models/room_member_model.dart';
import '../models/room_message_model.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService();
});

class RealtimeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream all active rooms directly from Supabase
  Stream<List<RoomModel>> watchActiveRooms() {
    return _supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('is_live', true)
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => RoomModel.fromJson(json)).toList());
  }

  Stream<RoomModel> subscribeToRoom(String roomId) {
    return _supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((list) => list.isNotEmpty ? RoomModel.fromJson(list.first) : throw Exception('Room not found'));
  }

  Stream<List<RoomMemberModel>> subscribeToMembers(String roomId) {
    return _supabase
        .from('room_members')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('joined_at', ascending: true)
        .map((list) => list.map((json) => RoomMemberModel.fromJson(json)).toList());
  }

  Stream<List<RoomMessageModel>> subscribeToMessages(String roomId) {
    return _supabase
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((list) => list.map((json) => RoomMessageModel.fromJson(json)).toList());
  }

  void dispose() {
    // Supabase streams are handled automatically when listeners detach
  }
}
