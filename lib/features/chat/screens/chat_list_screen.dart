import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanlink/core/theme/app_theme.dart';
import 'package:sanlink/core/theme/app_animations.dart';
import 'package:sanlink/features/chat/services/chat_service.dart';
import 'package:sanlink/features/chat/screens/direct_chat_screen.dart';
import 'package:sanlink/widgets/profile_avatar.dart';

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
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();

    _requestsChannel = chatService.subscribeToRequests(() {
      _loadRequests();
      _loadChats();
    });

    _messagesChannel = chatService.subscribeToAllMessages(() {
      _loadChats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_requestsChannel != null) chatService.unsubscribe(_requestsChannel!);
    if (_messagesChannel != null) chatService.unsubscribe(_messagesChannel!);
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadChats(), _loadRequests()]);
  }

  Future<void> _loadChats() async {
    if (mounted) setState(() => _isLoadingChats = true);
    final chats = await chatService.getUserChats();
    if (mounted) setState(() { _chats = chats; _isLoadingChats = false; });
  }

  Future<void> _loadRequests() async {
    if (mounted) setState(() => _isLoadingRequests = true);
    final requests = await chatService.getIncomingRequests();
    if (mounted) setState(() { _requests = requests; _isLoadingRequests = false; });
  }

  Future<void> _acceptRequest(String requestId, String fromUserId, String name) async {
    HapticFeedback.lightImpact();
    final chatId = await chatService.acceptRequest(requestId);
    if (mounted) {
      if (chatId != null) {
        Navigator.push(context, AppAnimations.slideRoute(
          DirectChatScreen(chatId: chatId, friendName: name),
        )).then((_) => _loadAll());
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
        SnackBar(content: const Text('Request ignored'), backgroundColor: context.colors.textSecondary, behavior: SnackBarBehavior.floating),
      );
    }
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: false,
        title: ShaderMask(
          shaderCallback: (bounds) => AppGradients.primaryAccent.createShader(bounds),
          child: Text('Messages', style: context.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
        actions: [
          if (_requests.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 20),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: colors.red, borderRadius: BorderRadius.circular(12)),
                child: Text('${_requests.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.textPrimary,
          unselectedLabelColor: colors.textSecondary,
          tabs: [
            const Tab(text: 'Chats'),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Requests'),
              if (_requests.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: colors.red, shape: BoxShape.circle),
                  child: Text('${_requests.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ])),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // CHATS TAB
          RefreshIndicator(
            color: colors.primary, backgroundColor: colors.surface,
            onRefresh: _loadChats,
            child: _isLoadingChats
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : _chats.isEmpty
                    ? _EmptyState(icon: Icons.chat_bubble_outline, message: 'No chats yet.')
                    : ListView.builder(
                        itemCount: _chats.length,
                        itemBuilder: (context, index) => _ChatTile(
                          chat: _chats[index],
                          chatService: chatService,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final chat = _chats[index];
                            final friend = chat['friend'];
                            Navigator.push(context, AppAnimations.slideRoute(
                              DirectChatScreen(
                                chatId: chat['chat_id'],
                                friendName: friend['name'] ?? 'Unknown User',
                                friendAvatar: friend['avatar_url'],
                                friendFrame: chat['frame_url'],
                              ),
                            )).then((_) => _loadChats());
                          },
                        ),
                      ),
          ),
          // REQUESTS TAB
          RefreshIndicator(
            color: colors.primary, backgroundColor: colors.surface,
            onRefresh: _loadRequests,
            child: _isLoadingRequests
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : _requests.isEmpty
                    ? _EmptyState(icon: Icons.person_add_disabled, message: 'No pending requests.')
                    : ListView.builder(
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          final req = _requests[index];
                          final sender = req['from_user'];
                          final senderName = sender != null ? (sender['name'] ?? 'Unknown User') : 'Unknown User';
                          return _RequestTile(
                            senderName: senderName,
                            senderEmail: sender?['email'] ?? '',
                            avatarUrl: sender?['avatar_url'],
                            frameUrl: req['frame_url'],
                            onAccept: () => _acceptRequest(req['id'], sender?['id'] ?? '', senderName),
                            onReject: () => _rejectRequest(req['id']),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Tile ────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final ChatService chatService;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.chatService, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final friend = chat['friend'];
    final lastMessage = chat['last_message'];
    final friendName = friend['name'] ?? 'Unknown User';
    final unreadCount = chat['unread_count'] ?? 0;
    final isUnread = unreadCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isUnread ? colors.primary.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: isUnread ? Border.all(color: colors.primary.withValues(alpha: 0.15)) : null,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: ProfileAvatar(
          avatarUrl: friend['avatar_url'],
          frameUrl: chat['frame_url'],
          size: 48,
          name: friendName,
          showOnlineRing: isUnread,
          isOnline: isUnread,
        ),
        title: Row(children: [
          Expanded(child: Text(friendName, style: TextStyle(
            color: isUnread ? Colors.white : colors.textPrimary,
            fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
            fontSize: 15,
          ))),
          if (lastMessage != null)
            Text(_formatTime(lastMessage['created_at']), style: TextStyle(
              color: isUnread ? colors.primary : colors.textMuted,
              fontSize: 11,
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            )),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            if (lastMessage != null && lastMessage['sender_id'] == chatService.currentUserId) ...[
              _StatusIcon(status: lastMessage['status'] ?? 'sent'),
              const SizedBox(width: 4),
            ],
            Expanded(child: Text(
              lastMessage != null ? lastMessage['message'] : 'Started a chat',
              style: TextStyle(
                color: isUnread ? colors.textPrimary : colors.textSecondary,
                fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(unreadCount > 9 ? '9+' : '$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      if (diff.inDays < 7) return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
      return '${date.day}/${date.month}';
    } catch (_) { return ''; }
  }
}

// ─── Request Tile ─────────────────────────────────────────────────────────────
class _RequestTile extends StatelessWidget {
  final String senderName;
  final String senderEmail;
  final String? avatarUrl;
  final String? frameUrl;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _RequestTile({required this.senderName, required this.senderEmail, this.avatarUrl, this.frameUrl, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: ProfileAvatar(avatarUrl: avatarUrl, frameUrl: frameUrl, size: 44, name: senderName),
      title: Text(senderName, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
      subtitle: Text(senderEmail, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: onReject,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: colors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: colors.red.withValues(alpha: 0.3))),
            child: Icon(Icons.close_rounded, color: colors.red, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAccept,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Row(children: [
              Icon(Icons.check_rounded, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text("Accept", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Status Icon ──────────────────────────────────────────────────────────────
class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (status == 'read') return Icon(Icons.done_all_rounded, color: colors.accent, size: 14);
    if (status == 'delivered') return Icon(Icons.done_all_rounded, color: colors.textSecondary, size: 14);
    return Icon(Icons.check_rounded, color: colors.textSecondary, size: 14);
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: colors.border),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: colors.textSecondary, fontSize: 16)),
      ])),
    ]);
  }
}
