import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanlink/features/chat/services/chat_service.dart';
import 'package:sanlink/services/post_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

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

// ─── Common Emojis ────────────────────────────────────────────
const _quickEmojis = [
  '😀', '😂', '🥰', '😎', '🤔', '😢', '🔥', '❤️',
  '👍', '👎', '🎉', '🙏', '💯', '✨', '😈', '💀',
  '🤣', '😍', '🥺', '😤', '🤗', '😴', '🤩', '😭',
  '👏', '🙌', '💪', '🤝', '✌️', '🤞', '🫶', '💔',
  '💥', '⭐', '🌟', '💫', '🎯', '🏆', '🎮', '🕹️',
];

// ─── Sticker Packs ────────────────────────────────────────────
const _stickerEmojis = [
  '🐶', '🐱', '🐻', '🦊', '🐼', '🐨', '🦁', '🐸',
  '🐵', '🦄', '🐲', '👻', '🤖', '👽', '🎃', '💩',
  '🌈', '🌸', '🍕', '🍔', '🎂', '🍦', '☕', '🍿',
  '⚽', '🏀', '🎸', '🎤', '🚀', '💎', '🗡️', '🛡️',
];

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

class _DirectChatScreenState extends State<DirectChatScreen>
    with TickerProviderStateMixin {
  final ChatService chatService = ChatService();
  final PostService _postService = PostService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _messageChannel;

  // Panel state
  bool _showEmojiPanel = false;
  bool _showStickerPanel = false;
  bool _isUploading = false;

  late AnimationController _panelAnimCtrl;
  late Animation<double> _panelAnim;

  @override
  void initState() {
    super.initState();

    _log("INIT", "Chat opened for chatId: ${widget.chatId}");

    _panelAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _panelAnim = CurvedAnimation(
      parent: _panelAnimCtrl,
      curve: Curves.easeOutCubic,
    );

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
    _panelAnimCtrl.dispose();

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

  // ─── Emoji & Sticker Panels ─────────────────────────────────
  void _toggleEmojiPanel() {
    HapticFeedback.selectionClick();
    setState(() {
      _showStickerPanel = false;
      _showEmojiPanel = !_showEmojiPanel;
    });
    if (_showEmojiPanel) {
      _panelAnimCtrl.forward(from: 0);
    } else {
      _panelAnimCtrl.reverse();
    }
  }

  void _toggleStickerPanel() {
    HapticFeedback.selectionClick();
    setState(() {
      _showEmojiPanel = false;
      _showStickerPanel = !_showStickerPanel;
    });
    if (_showStickerPanel) {
      _panelAnimCtrl.forward(from: 0);
    } else {
      _panelAnimCtrl.reverse();
    }
  }

  void _insertEmoji(String emoji) {
    final cursorPos = _msgController.selection.baseOffset;
    final text = _msgController.text;
    final before = cursorPos >= 0 ? text.substring(0, cursorPos) : text;
    final after = cursorPos >= 0 ? text.substring(cursorPos) : '';
    _msgController.text = '$before$emoji$after';
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: before.length + emoji.length),
    );
  }

  void _sendSticker(String sticker) {
    HapticFeedback.lightImpact();
    final tempMsg = {
      'sender_id': chatService.currentUserId,
      'message': sticker,
      'created_at': DateTime.now().toIso8601String(),
      'chat_id': widget.chatId,
      'status': 'sent',
      'msg_type': 'sticker',
    };
    setState(() {
      _messages.add(tempMsg);
      _showStickerPanel = false;
    });
    _scrollToBottom();
    chatService.sendMessage(widget.chatId, sticker);
  }

  void _closePanels() {
    if (_showEmojiPanel || _showStickerPanel) {
      setState(() {
        _showEmojiPanel = false;
        _showStickerPanel = false;
      });
      _panelAnimCtrl.reverse();
    }
  }

  // ─── Media Picking ──────────────────────────────────────────
  void _showMediaOptions() {
    HapticFeedback.mediumImpact();
    _closePanels();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaOptionsSheet(
        onPickImage: () => _pickAndSendMedia(isVideo: false, fromCamera: false),
        onPickVideo: () => _pickAndSendMedia(isVideo: true, fromCamera: false),
        onCamera: () => _pickAndSendMedia(isVideo: false, fromCamera: true),
      ),
    );
  }

  Future<void> _pickAndSendMedia({
    required bool isVideo,
    required bool fromCamera,
  }) async {
    Navigator.pop(context); // close sheet first

    XFile? file;
    if (isVideo) {
      file = await _picker.pickVideo(source: ImageSource.gallery);
    } else if (fromCamera) {
      file = await _picker.pickImage(source: ImageSource.camera);
    } else {
      file = await _picker.pickImage(source: ImageSource.gallery);
    }

    if (file == null) return;

    setState(() => _isUploading = true);

    try {
      final fileName = file.name.toLowerCase();
      final isVideoFile = fileName.endsWith('.mp4') ||
          fileName.endsWith('.mov') ||
          fileName.endsWith('.avi') ||
          fileName.endsWith('.webm') ||
          fileName.endsWith('.mkv');
      final contentType = isVideoFile ? 'video/mp4' : 'image/jpeg';

      String? mediaUrl;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        mediaUrl = await _postService.uploadMedia(
          fileBytes: bytes,
          fileName: file.name,
          contentType: contentType,
        );
      } else {
        mediaUrl = await _postService.uploadMedia(
          filePath: file.path,
          fileName: file.name,
          contentType: contentType,
        );
      }

      if (mediaUrl == null) {
        _log("MEDIA", "Upload returned null");
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      // Build a rich message with metadata tag
      final msgType = isVideoFile ? 'video' : 'image';
      final mediaMsg = '[media:$msgType]$mediaUrl';

      final tempMsg = {
        'sender_id': chatService.currentUserId,
        'message': mediaMsg,
        'created_at': DateTime.now().toIso8601String(),
        'chat_id': widget.chatId,
        'status': 'sent',
      };

      setState(() {
        _messages.add(tempMsg);
        _isUploading = false;
      });
      _scrollToBottom();

      await chatService.sendMessage(widget.chatId, mediaMsg);
      _log("MEDIA", "Media message sent: $msgType");
    } catch (e) {
      _log("MEDIA_ERROR", "Failed: $e");
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─── Message Parsing Helpers ────────────────────────────────
  bool _isMediaMessage(String? msg) {
    if (msg == null) return false;
    return msg.startsWith('[media:image]') || msg.startsWith('[media:video]');
  }

  String _getMediaType(String msg) {
    if (msg.startsWith('[media:video]')) return 'video';
    return 'image';
  }

  String _getMediaUrl(String msg) {
    if (msg.startsWith('[media:image]')) return msg.replaceFirst('[media:image]', '');
    if (msg.startsWith('[media:video]')) return msg.replaceFirst('[media:video]', '');
    return msg;
  }

  bool _isStickerMessage(String? msg) {
    if (msg == null || msg.isEmpty) return false;
    // Check if the message is a single emoji (sticker)
    final runes = msg.runes.toList();
    if (runes.length > 2) return false;
    // Basic check: if the string is <= 2 codepoints, it could be an emoji
    return _stickerEmojis.contains(msg) || _quickEmojis.contains(msg);
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
      body: GestureDetector(
        onTap: _closePanels,
        child: Column(
          children: [
            // ─── Messages List ──────────────────────────
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
                  final msgText = msg['message'] ?? '';

                  if (isSystem) {
                    return Center(
                      child: _SystemMessage(message: msgText),
                    );
                  }

                  // ── Media Message ──
                  if (_isMediaMessage(msgText)) {
                    final mediaType = _getMediaType(msgText);
                    final mediaUrl = _getMediaUrl(msgText);
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(
                          maxWidth:
                          MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? _C.primary.withOpacity(0.15) : _C.surfaceAlt,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMe
                                ? _C.primary.withOpacity(0.3)
                                : _C.border,
                          ),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: mediaType == 'image'
                            ? Image.network(
                          mediaUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              height: 150,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _C.primary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                          const SizedBox(
                            height: 100,
                            child: Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: _C.textMuted,
                                size: 32,
                              ),
                            ),
                          ),
                        )
                            : _ChatVideoPlayer(url: mediaUrl),
                      ),
                    );
                  }

                  // ── Sticker (big emoji) ──
                  if (_isStickerMessage(msgText)) {
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          msgText,
                          style: const TextStyle(fontSize: 56),
                        ),
                      ),
                    );
                  }

                  // ── Normal Text Message ──
                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(
                        maxWidth:
                        MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? _C.primary : _C.surfaceAlt,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                      ),
                      child: Text(
                        msgText,
                        style: const TextStyle(
                          color: _C.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Upload indicator ──
            if (_isUploading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _C.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Uploading media...',
                      style: TextStyle(
                        color: _C.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Input Bar ──────────────────────────────
            _buildInputBar(),

            // ─── Emoji Panel ────────────────────────────
            if (_showEmojiPanel)
              SizeTransition(
                sizeFactor: _panelAnim,
                child: _EmojiPanel(
                  onEmojiTap: _insertEmoji,
                ),
              ),

            // ─── Sticker Panel ──────────────────────────
            if (_showStickerPanel)
              SizeTransition(
                sizeFactor: _panelAnim,
                child: _StickerPanel(
                  onStickerTap: _sendSticker,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ── Emoji toggle ──
            _InputIconBtn(
              icon: _showEmojiPanel
                  ? Icons.keyboard_rounded
                  : Icons.emoji_emotions_outlined,
              color: _showEmojiPanel ? _C.primary : _C.textSecondary,
              onTap: _toggleEmojiPanel,
            ),

            // ── Text Field ──
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _C.surfaceAlt,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _C.border),
                ),
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 15,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  onTap: _closePanels,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: _C.textMuted,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // ── Sticker toggle ──
            _InputIconBtn(
              icon: Icons.sticky_note_2_outlined,
              color: _showStickerPanel ? _C.primary : _C.textSecondary,
              onTap: _toggleStickerPanel,
            ),

            // ── Attachment / Media ──
            _InputIconBtn(
              icon: Icons.attach_file_rounded,
              color: _C.textSecondary,
              onTap: _showMediaOptions,
            ),

            // ── Camera ──
            _InputIconBtn(
              icon: Icons.camera_alt_outlined,
              color: _C.textSecondary,
              onTap: () => _pickAndSendMedia(isVideo: false, fromCamera: true),
            ),

            // ── Send ──
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_C.primary, Color(0xFF9B7BFF)],
                  ),
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Input Icon Button ────────────────────────────────────────
class _InputIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InputIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

// ─── Emoji Panel ──────────────────────────────────────────────
class _EmojiPanel extends StatelessWidget {
  final ValueChanged<String> onEmojiTap;
  const _EmojiPanel({required this.onEmojiTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'EMOJIS',
              style: TextStyle(
                color: _C.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _quickEmojis.length,
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () => onEmojiTap(_quickEmojis[i]),
                  child: Center(
                    child: Text(
                      _quickEmojis[i],
                      style: const TextStyle(fontSize: 28),
                    ),
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

// ─── Sticker Panel ────────────────────────────────────────────
class _StickerPanel extends StatelessWidget {
  final ValueChanged<String> onStickerTap;
  const _StickerPanel({required this.onStickerTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'STICKERS',
              style: TextStyle(
                color: _C.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _stickerEmojis.length,
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () => onStickerTap(_stickerEmojis[i]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _C.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.border),
                    ),
                    child: Center(
                      child: Text(
                        _stickerEmojis[i],
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
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

// ─── Media Options Sheet ──────────────────────────────────────
class _MediaOptionsSheet extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onCamera;

  const _MediaOptionsSheet({
    required this.onPickImage,
    required this.onPickVideo,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _C.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share Media',
            style: TextStyle(
              color: _C.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _MediaOptionTile(
            icon: Icons.photo_library_rounded,
            iconColor: _C.primary,
            title: 'Photo from Gallery',
            onTap: onPickImage,
          ),
          _MediaOptionTile(
            icon: Icons.videocam_rounded,
            iconColor: _C.accent,
            title: 'Video from Gallery',
            onTap: onPickVideo,
          ),
          _MediaOptionTile(
            icon: Icons.camera_alt_rounded,
            iconColor: _C.green,
            title: 'Take a Photo',
            onTap: onCamera,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MediaOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _MediaOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: _C.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: _C.textMuted,
        size: 16,
      ),
    );
  }
}

// ─── Chat Video Player ────────────────────────────────────────
class _ChatVideoPlayer extends StatefulWidget {
  final String url;
  const _ChatVideoPlayer({required this.url});

  @override
  State<_ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<_ChatVideoPlayer> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _ctrl.value.aspectRatio,
            child: VideoPlayer(_ctrl),
          ),
          if (!_ctrl.value.isPlaying)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 32),
            ),
        ],
      ),
    );
  }
}

// ─── System Message ───────────────────────────────────────────
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