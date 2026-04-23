// /Users/irfanhussain/Documents/flutter /sanlink/lib/features/chat/services/chat_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient supabase = Supabase.instance.client;

  String? get currentUserId => supabase.auth.currentUser?.id;

  // sendChatRequest(String toUserId)
  Future<String?> sendChatRequest(String toUserId) async {
    final me = currentUserId;
    if (me == null) return "User not logged in";
    if (me == toUserId) return "Cannot send request to yourself";

    // 1. Check if they are already friends
    final isFriend = await areFriends(toUserId);
    if (isFriend) return "You are already friends";

    // 2. Check if a request already exists in EITHER direction
    final existing = await supabase
        .from('chat_requests')
        .select()
        .or('and(from_user_id.eq.$me,to_user_id.eq.$toUserId),and(from_user_id.eq.$toUserId,to_user_id.eq.$me)')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      final status = existing['status'];
      if (status == 'pending') return "A request is already pending";
      if (status == 'accepted') return "You are already friends";
      // If rejected, we allow sending again
    }

    // 3. Create new request
    await supabase.from('chat_requests').insert({
      'from_user_id': me,
      'to_user_id': toUserId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    
    return null; // success
  }

  // Check if two users are already friends
  Future<bool> areFriends(String otherUserId) async {
    final me = currentUserId;
    if (me == null) return false;

    final data = await supabase
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', me);
    
    if (data.isEmpty) return false;

    final myChatIds = (data as List).map((m) => m['chat_id']).toList();
    
    final common = await supabase
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', otherUserId)
        .filter('chat_id', 'in', myChatIds)
        .maybeSingle();
        
    return common != null;
  }

  // getIncomingRequests()
  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final me = currentUserId;
    if (me == null) return [];
    
    // ✅ FIX: Using user's confirmed join syntax for from_user
    final data = await supabase
        .from('chat_requests')
        .select('*, from_user:from_user_id(id, name, email, avatar_url, profile_pic)')
        .eq('to_user_id', me)
        .eq('status', 'pending');
        
    return List<Map<String, dynamic>>.from(data);
  }

  // acceptRequest(String requestId, String fromUserId)
  Future<String?> acceptRequest(String requestId, String fromUserId) async {
    final me = currentUserId;
    if (me == null) return null;
    
    String? roomId;

    // 1. Check if a chat room already exists between these two
    final existingChatId = await getCommonChatId(me, fromUserId);
    
    if (existingChatId != null) {
      roomId = existingChatId;
      // Just update the request status
      await supabase.from('chat_requests').update({'status': 'accepted'}).eq('id', requestId);
    } else {
      // 2. Create new room if doesn't exist
      final roomData = await supabase.from('chat_rooms').insert({
        'is_private': true, 
      }).select().single();
      roomId = roomData['id'];

      await supabase.from('chat_members').insert([
        {'chat_id': roomId, 'user_id': me},
        {'chat_id': roomId, 'user_id': fromUserId},
      ]);

      // 3. Update request status
      await supabase.from('chat_requests').update({'status': 'accepted'}).eq('id', requestId);
    }

    // 4. Send a system message to announce the connection
    if (roomId != null) {
      await sendSystemMessage(roomId, "You are now connected! Say hi 👋");
    }

    return roomId;
  }

  Future<String?> getCommonChatId(String user1, String user2) async {
    final u1Chats = await supabase.from('chat_members').select('chat_id').eq('user_id', user1);
    final u1Ids = (u1Chats as List).map((m) => m['chat_id']).toList();
    
    if (u1Ids.isEmpty) return null;

    final common = await supabase
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', user2)
        .filter('chat_id', 'in', u1Ids)
        .maybeSingle();
        
    return common?['chat_id'];
  }

  // rejectRequest(String requestId)
  Future<void> rejectRequest(String requestId) async {
    await supabase.from('chat_requests').update({'status': 'rejected'}).eq('id', requestId);
  }

  // getUserChats()
  Future<List<Map<String, dynamic>>> getUserChats() async {
    final me = currentUserId;
    if (me == null) return [];

    // 1. Get all memberships for me, including the other member's user data
    // We use a complex join to get the "friend" in one go if possible, 
    // but standard Supabase JS style join is simpler here.
    final myMemberships = await supabase
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', me);
    
    if (myMemberships.isEmpty) return [];
    
    final chatIds = (myMemberships as List).map((m) => m['chat_id']).toList();

    // 2. Get all other members for these chats
    final others = await supabase
        .from('chat_members')
        .select('chat_id, user_id, users(*)')
        .filter('chat_id', 'in', chatIds)
        .neq('user_id', me);
    
    List<Map<String, dynamic>> chats = [];
    Set<String> processedFriends = {};

    for (var member in others) {
      final chatId = member['chat_id'];
      final friend = member['users'];
      final friendId = member['user_id'];

      // Prevent duplicate friend entries
      if (processedFriends.contains(friendId)) continue;
      processedFriends.add(friendId);
      
      // 3. Get last message for this room
      final lastMsgData = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // 4. Get unread count (messages from others that are not 'read')
      final unreadData = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .neq('sender_id', me)
          .neq('status', 'read');
      final unreadCount = (unreadData as List).length;
          
      chats.add({
        'chat_id': chatId,
        'friend': friend,
        'last_message': lastMsgData,
        'unread_count': unreadCount,
      });
    }

    // Sort chats by latest message time (most recent first)
    chats.sort((a, b) {
      final aTime = a['last_message']?['created_at'] as String?;
      final bTime = b['last_message']?['created_at'] as String?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    
    return chats;
  }

  // Get total unread message count across all chats
  Future<int> getTotalUnreadCount() async {
    final me = currentUserId;
    if (me == null) return 0;

    final myMemberships = await supabase
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', me);
    
    if (myMemberships.isEmpty) return 0;
    
    final chatIds = (myMemberships as List).map((m) => m['chat_id']).toList();

    final unreadData = await supabase
        .from('messages')
        .select()
        .filter('chat_id', 'in', chatIds)
        .neq('sender_id', me)
        .neq('status', 'read');

    return (unreadData as List).length;
  }

  // getMessages(String chatId)
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final data = await supabase
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // sendMessage(String chatId, String message)
  Future<void> sendMessage(String chatId, String message) async {
    final me = currentUserId;
    if (me == null || message.trim().isEmpty) return;
    
    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': me, // ✅ DB column is sender_id
      'message': message.trim(), // ✅ DB column is message
      'status': 'sent', // default status
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // sendSystemMessage(String chatId, String message)
  Future<void> sendSystemMessage(String chatId, String message) async {
    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': null, // Null indicates a system message
      'message': message.trim(),
      'status': 'sent',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // markAsRead(String chatId)
  Future<void> markAsRead(String chatId) async {
    final me = currentUserId;
    if (me == null) return;

    await supabase
        .from('messages')
        .update({'status': 'read'})
        .eq('chat_id', chatId)
        .neq('sender_id', me) // ✅ DB column is sender_id
        .neq('status', 'read');
  }

  // subscribeToMessages(String chatId, Function callback)
  RealtimeChannel subscribeToMessages(String chatId, void Function(Map<String, dynamic>) callback) {
    return supabase
        .channel('public:messages:chat_id=$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // Track inserts AND updates (status changes)
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              callback(payload.newRecord);
            } else if (payload.eventType == PostgresChangeEvent.update) {
              callback(payload.newRecord); // Send updated record (e.g. read status)
            }
          },
        )
        .subscribe();
  }

  // subscribeToRequests(Function callback)
  RealtimeChannel subscribeToRequests(void Function() callback) {
    final me = currentUserId;
    return supabase
        .channel('public:chat_requests:to_user_id=$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user_id',
            value: me,
          ),
          callback: (payload) {
            callback();
          },
        )
        .subscribe();
  }

  // unsubscribe(RealtimeChannel channel)
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await supabase.removeChannel(channel);
  }

  // searchUsers(String query)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final me = currentUserId;
    if (me == null || query.trim().isEmpty) return [];
    
    final data = await supabase
        .from('users')
        .select('id, name, email, avatar_url, profile_pic')
        .ilike('name', '%${query.trim()}%')
        .neq('id', me)
        .limit(20);
        
    return List<Map<String, dynamic>>.from(data);
  }
}
