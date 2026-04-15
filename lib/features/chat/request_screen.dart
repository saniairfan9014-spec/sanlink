import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

// ─── DEBUG LOGGER ─────────────────────────────────────────────
void _log(String tag, String msg) {
  debugPrint("[$tag] $msg");
}

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
    _log("REQUESTS", "Screen initState");
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    _log("REQUESTS", "Fetching requests...");

    setState(() => loading = true);

    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      _log("REQUESTS", "ERROR: currentUserId is null");
      setState(() => loading = false);
      return;
    }

    try {
      final response = await supabase
          .from('chat_requests')
          .select('*, from_user:users(id,name,email)')
          .eq('to_user_id', currentUserId)
          .eq('status', 'pending');

      requests = List<Map<String, dynamic>>.from(response);

      _log("REQUESTS", "Loaded ${requests.length} requests");

      setState(() => loading = false);
    } catch (e) {
      _log("REQUESTS", "ERROR fetching requests: $e");
      setState(() => loading = false);
    }
  }

  Future<void> acceptRequest(Map<String, dynamic> request) async {
    _log("REQUESTS", "Accept clicked → requestId=${request['id']}");

    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      _log("REQUESTS", "ERROR: user not logged in");
      return;
    }

    final fromUserId = request['from_user_id'];

    try {
      // 1. Create chat room
      _log("REQUESTS", "Creating chat room...");
      final chatRoom = await supabase
          .from('chat_rooms')
          .insert({})
          .select()
          .single();

      final chatId = chatRoom['id'];
      _log("REQUESTS", "Chat room created → chatId=$chatId");

      // 2. Add members
      _log("REQUESTS", "Adding chat members...");
      await supabase.from('chat_members').insert([
        {'chat_id': chatId, 'user_id': currentUserId},
        {'chat_id': chatId, 'user_id': fromUserId},
      ]);

      _log("REQUESTS", "Members added successfully");

      // 3. Update request status
      _log("REQUESTS", "Updating request status → accepted");
      await supabase
          .from('chat_requests')
          .update({'status': 'accepted'})
          .eq('id', request['id']);

      _log("REQUESTS", "Request marked as accepted");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "You are now friends with ${request['from_user']['name']}!",
            ),
          ),
        );
      }

      fetchRequests(); // refresh
    } catch (e) {
      _log("REQUESTS", "ERROR accepting request: $e");
    }
  }

  Future<void> rejectRequest(Map<String, dynamic> request) async {
    _log("REQUESTS", "Reject clicked → requestId=${request['id']}");

    try {
      await supabase
          .from('chat_requests')
          .update({'status': 'rejected'})
          .eq('id', request['id']);

      _log("REQUESTS", "Request rejected successfully");

      fetchRequests();
    } catch (e) {
      _log("REQUESTS", "ERROR rejecting request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    _log("REQUESTS", "build called → loading=$loading");

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (requests.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No pending requests")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Friend Requests"),
      ),
      body: ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          final fromUser = request['from_user'];

          return ListTile(
            leading: CircleAvatar(
              child: Text(
                (fromUser['name'] ?? 'U')[0].toUpperCase(),
              ),
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