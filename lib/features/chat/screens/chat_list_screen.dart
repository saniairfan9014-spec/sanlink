// /Users/irfanhussain/Documents/flutter /sanlink/lib/features/chat/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanlink/features/chat/services/chat_service.dart';
import 'package:sanlink/features/chat/screens/direct_chat_screen.dart';

class _C {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surfaceAlt = Color(0xFF1C1C27);
  static const border = Color(0xFF2A2A3D);
  static const primary = Color(0xFF7C5CFC);
  static const primaryGlow = Color(0x337C5CFC);
  static const accent = Color(0xFF00E5FF);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF44445A);
  static const green = Color(0xFF00E676);
  static const red = Color(0xFFFF4757);
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final ChatService chatService = ChatService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoadingChats = true;
  bool _isLoadingRequests = true;
  
  RealtimeChannel? _requestsChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
    
    _requestsChannel = chatService.subscribeToRequests(() {
      _loadRequests();
      _loadChats(); // Also refresh chats in case a request was accepted
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_requestsChannel != null) {
      chatService.unsubscribe(_requestsChannel!);
    }
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadChats(), _loadRequests()]);
  }

  Future<void> _loadChats() async {
    if (mounted) setState(() => _isLoadingChats = true);
    final chats = await chatService.getUserChats();
    if (mounted) {
      setState(() {
        _chats = chats;
        _isLoadingChats = false;
      });
    }
  }

  Future<void> _loadRequests() async {
    if (mounted) setState(() => _isLoadingRequests = true);
    final requests = await chatService.getIncomingRequests();
    if (mounted) {
      setState(() {
        _requests = requests;
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _acceptRequest(String requestId, String fromUserId, String name) async {
    HapticFeedback.lightImpact();
    final chatId = await chatService.acceptRequest(requestId, fromUserId);
    
    if (mounted) {
      if (chatId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectChatScreen(
              chatId: chatId,
              friendName: name,
            ),
          ),
        ).then((_) => _loadAll());
      } else {
        _loadAll();
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    HapticFeedback.lightImpact();
    await chatService.rejectRequest(requestId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request ignored'),
          backgroundColor: _C.textSecondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: false,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_C.primary, _C.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Messages',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        actions: [
          if (_requests.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 20),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(12)),
                child: Text('${_requests.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _C.primary,
          labelColor: _C.textPrimary,
          unselectedLabelColor: _C.textSecondary,
          tabs: [
            const Tab(text: 'Chats'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: _C.red, shape: BoxShape.circle),
                      child: Text('${_requests.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // CHATS TAB
          RefreshIndicator(
            color: _C.primary,
            backgroundColor: _C.surface,
            onRefresh: _loadChats,
            child: _isLoadingChats
                ? const Center(child: CircularProgressIndicator(color: _C.primary))
                : _chats.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 64, color: _C.border),
                                SizedBox(height: 16),
                                Text('No chats yet.', style: TextStyle(color: _C.textSecondary, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _chats.length,
                        itemBuilder: (context, index) {
                          final chat = _chats[index];
                          final friend = chat['friend'];
                          final lastMessage = chat['last_message'];
                          final friendName = friend['name'] ?? 'Unknown User';
                          final friendInitial = friendName.isNotEmpty ? friendName[0].toUpperCase() : '?';
                          final unreadCount = chat['unread_count'] ?? 0;
                          
                          return ListTile(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DirectChatScreen(
                                    chatId: chat['chat_id'],
                                    friendName: friendName,
                                  ),
                                ),
                              ).then((_) => _loadChats());
                            },
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  backgroundColor: _C.surfaceAlt,
                                  child: Text(friendInitial, style: const TextStyle(color: _C.textPrimary, fontWeight: FontWeight.bold)),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: _C.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                      child: Center(
                                        child: Text(
                                          unreadCount > 99 ? '99+' : '$unreadCount',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              friendName,
                              style: TextStyle(
                                color: _C.textPrimary,
                                fontWeight: unreadCount > 0 ? FontWeight.w900 : FontWeight.bold,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                if (lastMessage != null && lastMessage['sender_id'] == chatService.currentUserId) ...[
                                  _StatusIcon(status: lastMessage['status'] ?? 'sent'),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    lastMessage != null ? lastMessage['message'] : 'Started a chat',
                                    style: TextStyle(
                                      color: unreadCount > 0 ? _C.textPrimary : (lastMessage?['sender_id'] == null ? _C.accent : _C.textSecondary),
                                      fontStyle: lastMessage?['sender_id'] == null ? FontStyle.italic : FontStyle.normal,
                                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            trailing: unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _C.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      unreadCount > 99 ? '99+' : '$unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
          ),

          // REQUESTS TAB
          RefreshIndicator(
            color: _C.primary,
            backgroundColor: _C.surface,
            onRefresh: _loadRequests,
            child: _isLoadingRequests
                ? const Center(child: CircularProgressIndicator(color: _C.primary))
                : _requests.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add_disabled, size: 64, color: _C.border),
                                SizedBox(height: 16),
                                Text('No pending requests.', style: TextStyle(color: _C.textSecondary, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          final req = _requests[index];
                          final sender = req['from_user'];
                          final senderName = sender != null ? (sender['name'] ?? 'Unknown User') : 'Unknown User';
                          final senderInitial = senderName.isNotEmpty ? senderName[0].toUpperCase() : '?';
                          
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: _C.surfaceAlt,
                              child: Text(senderInitial, style: const TextStyle(color: _C.textPrimary, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(senderName, style: const TextStyle(color: _C.textPrimary, fontWeight: FontWeight.bold)),
                            subtitle: Text(sender['email'] ?? '', style: const TextStyle(color: _C.textSecondary)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // REJECT BUTTON
                                GestureDetector(
                                  onTap: () => _rejectRequest(req['id']),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: _C.surfaceAlt,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _C.red.withOpacity(0.3)),
                                    ),
                                    child: const Icon(Icons.close_rounded, color: _C.red, size: 16),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // ACCEPT BUTTON
                                GestureDetector(
                                  onTap: () => _acceptRequest(req['id'], sender?['id'] ?? '', senderName),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [_C.primary, Color(0xFF9B7BFF)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _C.primary.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                        SizedBox(width: 5),
                                        Text(
                                          "Accept",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'read') {
      return const Icon(Icons.done_all_rounded, color: _C.accent, size: 14);
    } else if (status == 'delivered') {
      return const Icon(Icons.done_all_rounded, color: _C.textSecondary, size: 14);
    } else {
      return const Icon(Icons.check_rounded, color: _C.textSecondary, size: 14);
    }
  }
}
