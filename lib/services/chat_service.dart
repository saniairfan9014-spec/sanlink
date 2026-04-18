// lib/features/chat/services/chat_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final supabase = Supabase.instance.client;

  String? get currentUserId => supabase.auth.currentUser?.id;

  // ─── FRIEND REQUESTS ──────────────────────────────────────────

  /// Send a chat/friend request to another user
  Future<void> sendChatRequest(String toUserId) async {
    final me = currentUserId;
    if (me == null) return;

    // Check if request already exists
    final existing = await supabase
        .from('chat_requests')
        .select()
        .eq('from_user_id', me)       // ✅ correct column
        .eq('to_user_id', toUserId)   // ✅ correct column
        .maybeSingle();

    if (existing != null) return; // already sent

    await supabase.from('chat_requests').insert({
      'from_user_id': me,          // ✅ correct column name
      'to_user_id': toUserId,      // ✅ correct column name
      'status': 'pending',
    });
  }

  /// Get all pending friend requests for current user
  Future<List<Map<String, dynamic>>> getFriendRequests() async {
    final me = currentUserId;
    if (me == null) return [];

    final response = await supabase
        .from('chat_requests')
    // ✅ FIX: Use FK column name in join: 'from_user_id' → users table
        .select('id, from_user_id, from_user:from_user_id(id, name, email)')
        .eq('to_user_id', me)       // ✅ correct column
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response).map((req) {
      // Flatten for easy access in UI
      final fromUser = req['from_user'] as Map<String, dynamic>? ?? {};
      return {
        'id': req['id'],
        'from_user_id': req['from_user_id'],
        'name': fromUser['name'] ?? 'User',
        'email': fromUser['email'] ?? '',
        'avatar_url': fromUser['avatar_url'],
      };
    }).toList();
  }

  /// Accept a friend request → creates chat room + adds members
  Future<void> acceptRequest(String requestId) async {
    final me = currentUserId;
    if (me == null) return;

    // Get the request to find from_user_id
    final request = await supabase
        .from('chat_requests')
        .select()
        .eq('id', requestId)
        .single();

    final fromUserId = request['from_user_id'] as String;

    // 1. Create private chat room
    final chatRoom = await supabase
        .from('chat_rooms')
        .insert({'is_private': true})
        .select()
        .single();

    final chatId = chatRoom['id'] as String;

    // 2. Add both members
    await supabase.from('chat_members').insert([
      {'chat_id': chatId, 'user_id': me},
      {'chat_id': chatId, 'user_id': fromUserId},
    ]);

    // 3. Mark request as accepted
    await supabase
        .from('chat_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);
  }

  /// Reject a friend request
  Future<void> rejectRequest(String requestId) async {
    await supabase
        .from('chat_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
  }

  // ─── CHATS ────────────────────────────────────────────────────

  /// Get all chat rooms the current user is part of
  Future<List<Map<String, dynamic>>> getUserChats() async {
    final me = currentUserId;
    if (me == null) return [];

    // Get chat_ids the user is a member of
    final memberRows = await supabase
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', me);

    final chatIds = (memberRows as List)
        .map((r) => r['chat_id'] as String)
        .toList();

    if (chatIds.isEmpty) return [];

    final List<Map<String, dynamic>> chats = [];

    for (final chatId in chatIds) {
      // Find the other member in this chat
      final otherMembers = await supabase
          .from('chat_members')
          .select('user_id, users:user_id(id, name, avatar_url)')
          .eq('chat_id', chatId)
          .neq('user_id', me);

      if (otherMembers.isEmpty) continue;

      final otherUser = (otherMembers[0]['users'] as Map<String, dynamic>?) ?? {};

      // Get last message
      final lastMsgRow = await supabase
          .from('messages')
          .select('message, created_at')   // ✅ 'message' column, not 'content'
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      chats.add({
        'chat_id': chatId,
        'name': otherUser['name'] ?? 'Friend',
        'avatar_url': otherUser['avatar_url'],
        'last_message': lastMsgRow?['message'] ?? '',  // ✅ 'message' column
        'last_message_time': lastMsgRow?['created_at'],
      });
    }

    return chats;
  }

  // ─── MESSAGES ─────────────────────────────────────────────────

  /// Get all messages for a chat room
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final response = await supabase
        .from('messages')
        .select()           // gets all columns including: message, sender_id, created_at, media_url
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Send a message
  Future<void> sendMessage(String chatId, String text) async {
    final me = currentUserId;
    if (me == null) return;

    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': me,      // ✅ correct column name (messages table)
      'message': text,       // ✅ correct column name (NOT 'content')
    });
  }

  /// Subscribe to new messages in a chat room
  RealtimeChannel subscribeToMessages(
      String chatId,
      void Function(Map<String, dynamic>) onMessage,
      ) {
    return supabase
        .channel('messages_$chatId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'chat_id',
        value: chatId,
      ),
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord.isNotEmpty) {
          onMessage(Map<String, dynamic>.from(newRecord));
        }
      },
    )
        .subscribe();
  }

  /// Unsubscribe from a realtime channel
  void unsubscribe(RealtimeChannel channel) {
    supabase.removeChannel(channel);
  }

  // ─── SEARCH USERS ─────────────────────────────────────────────

  /// Search users by name
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final me = currentUserId;

    final response = await supabase
        .from('users')
        .select('id, name, email, avatar_url')
        .ilike('name', '%$query%')
        .limit(20);

    final results = List<Map<String, dynamic>>.from(response);

    // Exclude self
    return results.where((u) => u['id'] != me).toList();
  }

  // ─── ARE FRIENDS ──────────────────────────────────────────────

  /// Check if current user and another user are friends (accepted request)
  Future<bool> areFriends(String otherUserId) async {
    final me = currentUserId;
    if (me == null) return false;

    final result = await supabase
        .from('chat_requests')
        .select()
        .eq('status', 'accepted')
        .or('and(from_user_id.eq.$me,to_user_id.eq.$otherUserId),and(from_user_id.eq.$otherUserId,to_user_id.eq.$me)')
        .maybeSingle();

    return result != null;
  }
}