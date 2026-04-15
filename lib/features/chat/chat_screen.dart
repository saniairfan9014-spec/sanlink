import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanlink/services/chat_service.dart';

// ─── Design Tokens (matching home_screen) ─────────────────────────────────────
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

// ──────────────────────────────────────────────────────────────────────────────
// CHAT LIST SCREEN  (inbox + pending requests)
// ──────────────────────────────────────────────────────────────────────────────
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
    _tab = TabController(length: 2, vsync: this);
    _load();
    _subscribeRequests();
  }

  Future<void> _load() async {
    await Future.wait([_loadRequests(), _loadChats()]);
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingReqs = true);
    final data = await _service.getFriendRequests();
    if (mounted) setState(() { _requests = data; _loadingReqs = false; });
  }

  Future<void> _loadChats() async {
    setState(() => _loadingChats = true);
    final data = await _service.getUserChats();
    if (mounted) setState(() { _chats = data; _loadingChats = false; });
  }

  void _subscribeRequests() {
    final uid = _service.supabase.auth.currentUser?.id;
    if (uid == null) return;
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
          callback: (_) => _loadRequests(),
        )
        .subscribe();
  }

  Future<void> _accept(Map<String, dynamic> req) async {
    HapticFeedback.lightImpact();
    await _service.acceptRequest(req['id']);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(_snack(
        '✅  Now friends with ${req['name']}',
        _C.green,
      ));
    }
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    HapticFeedback.lightImpact();
    await _service.rejectRequest(req['id']);
    await _loadRequests();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(_snack('Request ignored', _C.textMuted));
    }
  }

  SnackBar _snack(String msg, Color color) => SnackBar(
        content: Text(msg,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      );

  void _openChat(Map<String, dynamic> chat) {
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
    _tab.dispose();
    if (_reqChannel != null) _service.supabase.removeChannel(_reqChannel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [_C.primary, _C.accent],
                    ).createShader(b),
                    child: const Text('Messages',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3)),
                  ),
                  const Spacer(),
                  if (_requests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: _C.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _C.red.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_add_rounded,
                              size: 12, color: _C.red),
                          const SizedBox(width: 4),
                          Text('${_requests.length}',
                              style: const TextStyle(
                                  color: _C.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ─── Tabs ────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              height: 40,
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_C.primary, Color(0xFF9B7CFF)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: _C.textMuted,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  const Tab(text: 'Chats'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Requests'),
                        if (_requests.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                                color: _C.red, shape: BoxShape.circle),
                            child: Center(
                              child: Text('${_requests.length}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── Tab Views ───────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ChatsTab(
                    chats: _chats,
                    loading: _loadingChats,
                    onTap: _openChat,
                    onRefresh: _loadChats,
                  ),
                  _RequestsTab(
                    requests: _requests,
                    loading: _loadingReqs,
                    onAccept: _accept,
                    onReject: _reject,
                    onRefresh: _loadRequests,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CHATS TAB
// ──────────────────────────────────────────────────────────────────────────────
class _ChatsTab extends StatelessWidget {
  final List<Map<String, dynamic>> chats;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onTap;
  final Future<void> Function() onRefresh;

  const _ChatsTab({
    required this.chats,
    required this.loading,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2));
    }
    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _C.surface,
                shape: BoxShape.circle,
                border: Border.all(color: _C.border),
              ),
              child: const Icon(Icons.forum_outlined,
                  color: _C.textMuted, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('No conversations yet',
                style: TextStyle(
                    color: _C.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Accept a request to start chatting',
                style: TextStyle(color: _C.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _C.primary,
      backgroundColor: _C.surface,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: chats.length,
        itemBuilder: (context, i) => _ChatTile(
          chat: chats[i],
          onTap: () => onTap(chats[i]),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = chat['name'] ?? 'Friend';
    final lastMsg = chat['last_message'] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [_C.primary, _C.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: _C.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    (lastMsg != null && lastMsg.isNotEmpty)
                        ? lastMsg
                        : 'Tap to start chatting…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _C.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _C.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// REQUESTS TAB
// ──────────────────────────────────────────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final bool loading;
  final Function(Map<String, dynamic>) onAccept;
  final Function(Map<String, dynamic>) onReject;
  final Future<void> Function() onRefresh;

  const _RequestsTab({
    required this.requests,
    required this.loading,
    required this.onAccept,
    required this.onReject,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2));
    }
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _C.surface,
                shape: BoxShape.circle,
                border: Border.all(color: _C.border),
              ),
              child: const Icon(Icons.people_outline,
                  color: _C.textMuted, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('No pending requests',
                style: TextStyle(
                    color: _C.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _C.primary,
      backgroundColor: _C.surface,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: requests.length,
        itemBuilder: (context, i) => _RequestTile(
          req: requests[i],
          onAccept: () => onAccept(requests[i]),
          onReject: () => onReject(requests[i]),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final Map<String, dynamic> req;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _RequestTile(
      {required this.req, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final name = req['name'] ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _C.primary.withValues(alpha: 0.8),
                  _C.accent.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: _C.primary.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: _C.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 3),
                const Text('Wants to be friends',
                    style: TextStyle(color: _C.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Actions
          Row(
            children: [
              _ReqBtn(
                icon: Icons.check_rounded,
                color: _C.green,
                onTap: onAccept,
              ),
              const SizedBox(width: 8),
              _ReqBtn(
                icon: Icons.close_rounded,
                color: _C.textMuted,
                onTap: onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReqBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ReqBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DIRECT CHAT SCREEN  (real-time messaging)
// ──────────────────────────────────────────────────────────────────────────────
class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String friendName;

  const DirectChatScreen(
      {super.key, required this.chatId, required this.friendName});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _service = ChatService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  String? get _myId => _service.supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeMessages();
  }

  Future<void> _fetchMessages() async {
    final data = await _service.getMessages(widget.chatId);
    if (mounted) {
      setState(() {
        _messages = data;
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _subscribeMessages() {
    _channel = _service.subscribeToMessages(widget.chatId, (msg) {
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    _ctrl.clear();
    await _service.sendMessage(chatId: widget.chatId, message: text);
    setState(() => _sending = false);
  }

  @override
  void dispose() {
    if (_channel != null) _service.unsubscribe(_channel!);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _initial(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _C.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [_C.primary, _C.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Center(
                child: Text(_initial(widget.friendName),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.friendName,
                    style: const TextStyle(
                        color: _C.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const Text('Online',
                    style: TextStyle(color: _C.green, fontSize: 11)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _C.border),
        ),
      ),
      body: Column(
        children: [
          // ─── Messages ────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: _C.primary, strokeWidth: 2))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.waving_hand_rounded,
                                color: _C.primary, size: 36),
                            const SizedBox(height: 10),
                            Text('Say hi to ${widget.friendName}!',
                                style: const TextStyle(
                                    color: _C.textSecondary, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final isMe = msg['sender_id'] == _myId;
                          return _MessageBubble(
                            text: msg['message'] ?? '',
                            isMe: isMe,
                            showAvatar: !isMe,
                            initial: _initial(widget.friendName),
                          );
                        },
                      ),
          ),

          // ─── Input Bar ───────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: const BoxDecoration(
              color: _C.surface,
              border: Border(top: BorderSide(color: _C.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _C.surfaceAlt,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _C.border),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(
                          color: _C.textPrimary, fontSize: 14),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: TextStyle(
                            color: _C.textMuted, fontSize: 14),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_C.primary, Color(0xFF9B7CFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _C.primaryGlow,
                          blurRadius: 12,
                        )
                      ],
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MESSAGE BUBBLE
// ──────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool showAvatar;
  final String initial;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.showAvatar,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [_C.primary, _C.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.70),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [_C.primary, Color(0xFF9B7CFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                color: isMe ? null : _C.surfaceAlt,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: isMe
                    ? [
                        BoxShadow(
                            color: _C.primaryGlow,
                            blurRadius: 8)
                      ]
                    : null,
                border: isMe
                    ? null
                    : Border.all(color: _C.border, width: 0.8),
              ),
              child: Text(
                text,
                style: TextStyle(
                    color: isMe ? Colors.white : _C.textPrimary,
                    fontSize: 14,
                    height: 1.4),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}