import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final supabase = Supabase.instance.client;

  /// 🔹 SEND MESSAGE
  Future<void> sendMessage({
    required String chatId,
    String? message,
    String? mediaUrl,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': user.id,
      'message': message,
      'media_url': mediaUrl,
    });
  }

  /// 🔹 GET MESSAGES
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final data = await supabase
        .from('messages')
        .select('*, users(name)')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  }

  /// 🔹 UPLOAD MEDIA
  Future<String?> uploadMedia({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final ext = fileName.split('.').last;
    final newFileName =
        '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    if (kIsWeb) {
      if (fileBytes == null) return null;
      await supabase.storage
          .from('chat-media')
          .uploadBinary(newFileName, fileBytes);
    } else {
      if (filePath == null) return null;
      final file = File(filePath);
      await supabase.storage.from('chat-media').upload(newFileName, file);
    }

    return supabase.storage.from('chat-media').getPublicUrl(newFileName);
  }

  /// 🔹 REALTIME MESSAGES
  RealtimeChannel subscribeToMessages(
      String chatId,
      Function(Map<String, dynamic>) onNewMessage,
      ) {
    final channel = supabase.channel('messages_channel_$chatId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'chat_id',
        value: chatId,
      ),
      callback: (payload) {
        final newMsg = payload.newRecord;
        onNewMessage(newMsg);
      },
    );

    channel.subscribe();
    return channel;
  }

  /// 🔹 UNSUBSCRIBE
  void unsubscribe(RealtimeChannel channel) {
    supabase.removeChannel(channel);
  }

  // =========================================================
  // 🔥 NEW FUNCTIONS FOR CHAT LIST SCREEN
  // =========================================================

  /// 🔹 GET FRIEND REQUESTS
  Future<List<Map<String, dynamic>>> getFriendRequests() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final data = await supabase
        .from('friend_requests')
        .select('id, sender_id, users(name)')
        .eq('receiver_id', user.id)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(data).map((e) {
      return {
        'id': e['id'],
        'sender_id': e['sender_id'],
        'name': e['users']?['name'] ?? 'User',
      };
    }).toList();
  }

  /// 🔹 ACCEPT REQUEST
  Future<void> acceptRequest(String requestId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 1. get request
    final req = await supabase
        .from('friend_requests')
        .select()
        .eq('id', requestId)
        .single();

    final senderId = req['sender_id'];
    final receiverId = req['receiver_id'];

    // 2. update status
    await supabase
        .from('friend_requests')
        .update({'status': 'accepted'}).eq('id', requestId);

    // 3. create friendship
    await supabase.from('friends').insert({
      'user1_id': senderId,
      'user2_id': receiverId,
    });

    // 4. create chat
    await supabase.from('chats').insert({
      'user1': senderId,
      'user2': receiverId,
    });
  }

  /// 🔹 REJECT REQUEST
  Future<void> rejectRequest(String requestId) async {
    await supabase
        .from('friend_requests')
        .update({'status': 'rejected'}).eq('id', requestId);
  }

  /// 🔹 Send Friend Request
  Future<void> sendRequest(String toUserId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 🔸 check already exists (avoid duplicate)
    final existing = await supabase
        .from('friend_requests')
        .select()
        .eq('sender_id', user.id)
        .eq('receiver_id', toUserId)
        .maybeSingle();

    if (existing != null) {
      print("Request already sent");
      return;
    }

    await supabase.from('friend_requests').insert({
      'sender_id': user.id,
      'receiver_id': toUserId,
      'status': 'pending',
    });
  }

  /// 🔹 GET USER CHATS (ONLY FRIENDS)
  Future<List<Map<String, dynamic>>> getUserChats() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final data = await supabase
        .from('chats')
        .select()
        .or('user1.eq.${user.id},user2.eq.${user.id}');

    List<Map<String, dynamic>> chats = [];

    for (var chat in data) {
      final otherUserId =
      chat['user1'] == user.id ? chat['user2'] : chat['user1'];

      // get other user name
      final userData = await supabase
          .from('users')
          .select('name')
          .eq('id', otherUserId)
          .maybeSingle();

      if (userData == null) continue;

      // get last message
      final lastMsg = await supabase
          .from('messages')
          .select('message')
          .eq('chat_id', chat['id'])
          .order('created_at', ascending: false)
          .limit(1);

      chats.add({
        'chat_id': chat['id'],
        'name': userData['name'] ?? 'Friend',
        'last_message':
        lastMsg.isNotEmpty ? lastMsg[0]['message'] ?? '' : '',
      });
    }

    return chats;
  }
}