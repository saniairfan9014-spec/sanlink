// /Users/irfanhussain/Documents/flutter /sanlink/lib/features/chat/services/chat_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient supabase = Supabase.instance.client;

  String? get currentUserId => supabase.auth.currentUser?.id;

  // sendChatRequest(String toUserId)
  Future<void> sendChatRequest(String toUserId) async {
    final me = currentUserId;
    if (me == null || me == toUserId) return;

    final existing = await supabase
        .from('chat_requests')
        .select()
        .eq('from_user_id', me)
        .eq('to_user_id', toUserId)
        .maybeSingle();

    if (existing == null) {
      await supabase.from('chat_requests').insert({
        'from_user_id': me,
        'to_user_id': toUserId,
        'status': 'pending',
      });
    }
  }

  // getIncomingRequests()
  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final me = currentUserId;
    if (me == null) return [];
    
    // Select from chat_requests and join with users to get sender details
    final data = await supabase
        .from('chat_requests')
        .select('*, users!chat_requests_from_user_id_fkey(*)')
        .eq('to_user_id', me)
        .eq('status', 'pending');
        
    return List<Map<String, dynamic>>.from(data);
  }

  // acceptRequest(String requestId, String fromUserId)
  Future<void> acceptRequest(String requestId, String fromUserId) async {
    final me = currentUserId;
    if (me == null) return;
    
    // Insert into chat_rooms returning id
    final roomData = await supabase.from('chat_rooms').insert({}).select().single();
    final roomId = roomData['id'];

    // Insert 2 rows into chat_members
    await supabase.from('chat_members').insert([
      {'chat_id': roomId, 'user_id': me},
      {'chat_id': roomId, 'user_id': fromUserId},
    ]);

    // Update request status
    await supabase.from('chat_requests').update({'status': 'accepted'}).eq('id', requestId);
  }

  // rejectRequest(String requestId)
  Future<void> rejectRequest(String requestId) async {
    await supabase.from('chat_requests').update({'status': 'rejected'}).eq('id', requestId);
  }

  // getUserChats()
  Future<List<Map<String, dynamic>>> getUserChats() async {
    final me = currentUserId;
    if (me == null) return [];

    // Get all chat_members rows where user_id = me
    final myMemberships = await supabase.from('chat_members').select('chat_id').eq('user_id', me);
    
    List<Map<String, dynamic>> chats = [];
    
    for (var membership in myMemberships) {
      final chatId = membership['chat_id'];
      
      // Get the *other* member
      final otherMemberData = await supabase
          .from('chat_members')
          .select('user_id, users(*)')
          .eq('chat_id', chatId)
          .neq('user_id', me)
          .maybeSingle();
          
      if (otherMemberData != null) {
        final friend = otherMemberData['users'];
        
        // Get last message
        final messages = await supabase
            .from('messages')
            .select()
            .eq('chat_id', chatId)
            .order('created_at', ascending: false)
            .limit(1);
            
        chats.add({
          'chat_id': chatId,
          'friend': friend,
          'last_message': messages.isNotEmpty ? messages.first : null,
        });
      }
    }
    
    return chats;
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
      'user_id': me,
      'content': message.trim(),
    });
  }

  // subscribeToMessages(String chatId, Function callback)
  RealtimeChannel subscribeToMessages(String chatId, void Function(Map<String, dynamic>) callback) {
    return supabase
        .channel('public:messages:chat_id=$chatId')
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
            callback(payload.newRecord);
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
        .select()
        .ilike('name', '%${query.trim()}%')
        .neq('id', me)
        .limit(20);
        
    return List<Map<String, dynamic>>.from(data);
  }
}
