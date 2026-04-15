import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final supabase = SupabaseService().client;
  List<Map<String, dynamic>> requests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    setState(() => loading = true);
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final response = await supabase
          .from('chat_requests')
          .select('*, from_user:users(id,name,email)')
          .eq('to_user_id', currentUserId)
          .eq('status', 'pending');
      requests = List<Map<String, dynamic>>.from(response);
      setState(() => loading = false);
    } catch (e) {
      print("Error fetching requests: $e");
      setState(() => loading = false);
    }
  }

  Future<void> acceptRequest(Map<String, dynamic> request) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final fromUserId = request['from_user_id'];

    try {
      // 1. Create chat room
      final chatRoom = await supabase.from('chat_rooms').insert({}).select().single();

      final chatId = chatRoom['id'];

      // 2. Add members
      await supabase.from('chat_members').insert([
        {'chat_id': chatId, 'user_id': currentUserId},
        {'chat_id': chatId, 'user_id': fromUserId},
      ]);

      // 3. Update request status
      await supabase
          .from('chat_requests')
          .update({'status': 'accepted'})
          .eq('id', request['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You are now friends with ${request['from_user']['name']}!")),
      );

      fetchRequests(); // refresh list
    } catch (e) {
      print("Error accepting request: $e");
    }
  }

  Future<void> rejectRequest(Map<String, dynamic> request) async {
    try {
      await supabase
          .from('chat_requests')
          .update({'status': 'rejected'})
          .eq('id', request['id']);
      fetchRequests(); // refresh list
    } catch (e) {
      print("Error rejecting request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (requests.isEmpty) return const Center(child: Text("No pending requests"));

    return Scaffold(
      appBar: AppBar(title: const Text("Friend Requests")),
      body: ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          final fromUser = request['from_user'];
          return ListTile(
            leading: CircleAvatar(
              child: Text((fromUser['name'] ?? 'U')[0].toUpperCase()),
            ),
            title: Text(fromUser['name'] ?? 'No Name'),
            subtitle: Text(fromUser['email'] ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => acceptRequest(request),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => rejectRequest(request),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}