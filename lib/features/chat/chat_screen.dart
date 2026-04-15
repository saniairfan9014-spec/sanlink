import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanlink/services/chat_service.dart';
import 'package:sanlink/features/chat/screens/direct_chat_screen.dart';

// ─── DEBUG LOGGER ─────────────────────────────────────────────
void _log(String tag, String msg) {
  debugPrint("[$tag] $msg");
}

// ─── DESIGN TOKENS ────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surfaceAlt = Color(0xFF1C1C27);
  static const border = Color(0xFF2A2A3D);
  static const primary = Color(0xFF7C5CFC);
  static const accent = Color(0xFF00E5FF);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textMuted = Color(0xFF44445A);
  static const green = Color(0xFF00E676);
  static const red = Color(0xFFFF4757);
}

// ───────────────────────────────────────────────────────────────
// CHAT LIST SCREEN
// ───────────────────────────────────────────────────────────────
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final _service = ChatService();
  late TabController _tab;

  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _chats = [];

  bool _loadingChats = true;
  bool _loadingReqs = true;

  RealtimeChannel? _reqChannel;

  @override
  void initState() {
    super.initState();

    _log("CHAT_LIST", "initState");

    _tab = TabController(length: 2, vsync: this);

    _load();
    _subscribeRequests();
  }

  Future<void> _load() async {
    _log("CHAT_LIST", "Loading all data...");
    await Future.wait([_loadRequests(), _loadChats()]);
  }

  Future<void> _loadRequests() async {
    _log("REQUESTS", "Fetching requests...");
    setState(() => _loadingReqs = true);

    try {
      final data = await _service.getFriendRequests();

      if (!mounted) return;

      setState(() {
        _requests = data;
        _loadingReqs = false;
      });

      _log("REQUESTS", "Loaded ${data.length} requests");
    } catch (e) {
      _log("REQUESTS", "ERROR: $e");
      setState(() => _loadingReqs = false);
    }
  }

  Future<void> _loadChats() async {
    _log("CHAT_LIST", "Fetching chats...");
    setState(() => _loadingChats = true);

    try {
      final data = await _service.getUserChats();

      if (!mounted) return;

      setState(() {
        _chats = data;
        _loadingChats = false;
      });

      _log("CHAT_LIST", "Loaded ${data.length} chats");
    } catch (e) {
      _log("CHAT_LIST", "ERROR: $e");
      setState(() => _loadingChats = false);
    }
  }

  void _subscribeRequests() {
    final uid = _service.supabase.auth.currentUser?.id;

    if (uid == null) {
      _log("REQUESTS", "No user logged in");
      return;
    }

    _log("REQUESTS", "Realtime subscribed for $uid");

    _reqChannel = _service.supabase
        .channel('req_$uid')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'friend_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'receiver_id',
        value: uid,
      ),
      callback: (_) {
        _log("REQUESTS", "Realtime update received");
        _loadRequests();
      },
    )
        .subscribe();
  }

  Future<void> _accept(Map<String, dynamic> req) async {
    _log("REQUESTS", "Accept request ${req['id']}");

    await _service.acceptRequest(req['id']);
    await _load();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Friend added: ${req['name']}")),
    );
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    _log("REQUESTS", "Reject request ${req['id']}");

    await _service.rejectRequest(req['id']);
    await _loadRequests();
  }

  void _openChat(Map<String, dynamic> chat) {
    _log("CHAT_LIST", "Open chat ${chat['chat_id']}");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          chatId: chat['chat_id'],
          friendName: chat['name'],
        ),
      ),
    ).then((_) => _loadChats());
  }

  @override
  void dispose() {
    _log("CHAT_LIST", "dispose");

    _tab.dispose();
    if (_reqChannel != null) {
      _service.supabase.removeChannel(_reqChannel!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: TabBarView(
          controller: _tab,
          children: [
            _ChatsTab(
              chats: _chats,
              loading: _loadingChats,
              onTap: _openChat,
            ),
            _RequestsTab(
              requests: _requests,
              loading: _loadingReqs,
              onAccept: _accept,
              onReject: _reject,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// CHATS TAB (FIXED)
// ───────────────────────────────────────────────────────────────
class _ChatsTab extends StatelessWidget {
  final List<Map<String, dynamic>> chats;
  final bool loading;
  final Function(Map<String, dynamic>) onTap;

  const _ChatsTab({
    required this.chats,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chats.isEmpty) {
      return const Center(child: Text("No chats yet"));
    }

    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, i) {
        final chat = chats[i];

        return ListTile(
          title: Text(chat['name'] ?? 'Friend'),
          subtitle: Text(chat['last_message'] ?? ''),
          onTap: () => onTap(chat),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────
// REQUESTS TAB (FIXED)
// ───────────────────────────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final bool loading;
  final Function(Map<String, dynamic>) onAccept;
  final Function(Map<String, dynamic>) onReject;

  const _RequestsTab({
    required this.requests,
    required this.loading,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (requests.isEmpty) {
      return const Center(child: Text("No requests"));
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, i) {
        final req = requests[i];

        return ListTile(
          title: Text(req['name'] ?? 'User'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => onAccept(req),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => onReject(req),
              ),
            ],
          ),
        );
      },
    );
  }
}