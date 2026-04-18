import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanlink/features/chat/services/chat_service.dart';

// 🔍 DEBUG LOGGER
void _log(String tag, String msg) {
  debugPrint("[$tag] $msg");
}

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

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String friendName;

  const DirectChatScreen({
    super.key,
    required this.chatId,
    required this.friendName,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final ChatService chatService = ChatService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _messageChannel;

  @override
  void initState() {
    super.initState();

    _log("INIT", "Chat opened for chatId: ${widget.chatId}");

    _loadMessages();

    _log("REALTIME", "Subscribing to messages...");

    _messageChannel =
        chatService.subscribeToMessages(widget.chatId, (newMsg) {
          _log("REALTIME_EVENT", "New payload: $newMsg");

          if (mounted) {
            setState(() {
              final index =
              _messages.indexWhere((m) => m['id'] == newMsg['id']);

              if (index != -1) {
                _log("UPDATE", "Updating existing message: ${newMsg['id']}");
                _messages[index] = newMsg;
              } else {
                _log("INSERT", "Adding new message: ${newMsg['id']}");
                _messages.add(newMsg);
              }
            });

            _scrollToBottom();
          }
        });
  }

  @override
  void dispose() {
    _log("DISPOSE", "Closing chat screen");

    _msgController.dispose();
    _scrollController.dispose();

    if (_messageChannel != null) {
      _log("REALTIME", "Unsubscribing from channel");
      chatService.unsubscribe(_messageChannel!);
    }

    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      _log("LOAD", "Fetching messages...");

      final msgs = await chatService.getMessages(widget.chatId);

      _log("LOAD_SUCCESS", "Fetched ${msgs.length} messages");

      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });

        _scrollToBottom();
      }
    } catch (e) {
      _log("ERROR", "Failed to load messages: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _log("SCROLL", "Scrolling to bottom");

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();

    if (text.isEmpty) {
      _log("SEND", "Empty message ignored");
      return;
    }

    _log("SEND", "Sending message: $text");

    HapticFeedback.lightImpact();
    _msgController.clear();

    final tempMsg = {
      'sender_id': chatService.currentUserId,
      'message': text,
      'created_at': DateTime.now().toIso8601String(),
      'chat_id': widget.chatId,
      'status': 'sent',
    };

    setState(() {
      _messages.add(tempMsg);
    });

    _scrollToBottom();

    try {
      await chatService.sendMessage(widget.chatId, text);
      _log("SEND_SUCCESS", "Message sent successfully");
    } catch (e) {
      _log("SEND_ERROR", "Failed to send message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendInitial =
    widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?';

    final me = chatService.currentUserId;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _C.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _C.surfaceAlt,
              radius: 18,
              child: Text(friendInitial,
                  style: const TextStyle(
                      color: _C.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.friendName,
                style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                child:
                CircularProgressIndicator(color: _C.primary))
                : _messages.isEmpty
                ? const Center(
              child: Text(
                'Say hi! 👋',
                style: TextStyle(
                    color: _C.textSecondary, fontSize: 16),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isSystem = msg['sender_id'] == null;
                final isMe = !isSystem && msg['sender_id'] == me;

                if (isSystem) {
                  return Center(
                    child: _SystemMessage(message: msg['message'] ?? ''),
                  );
                }

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin:
                    const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? _C.primary
                          : _C.surfaceAlt,
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg['message'] ?? '',
                      style: const TextStyle(
                          color: _C.textPrimary),
                    ),
                  ),
                );
              },
            ),
          ),

          // INPUT
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: _C.textPrimary),
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Type...',
                      hintStyle:
                      TextStyle(color: _C.textMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send,
                      color: _C.primary),
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String message;
  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final lower = message.toLowerCase();
    final isWarning = lower.contains('warning') || lower.contains('alert');
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isWarning ? _C.red.withOpacity(0.1) : _C.surfaceAlt.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning ? _C.red.withOpacity(0.3) : _C.border.withOpacity(0.2),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isWarning ? _C.red : _C.textSecondary,
          fontSize: 12,
          fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
          fontStyle: isWarning ? FontStyle.normal : FontStyle.italic,
        ),
      ),
    );
  }
}