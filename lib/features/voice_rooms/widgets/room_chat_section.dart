import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/themed_text_field.dart';
import '../data/models/room_message_model.dart';

class RoomChatSection extends StatefulWidget {
  final double height;
  final List<RoomMessageModel> messages;
  final String currentUserId;
  final ValueChanged<String> onSendMessage;
  final Map<String, Map<String, dynamic>> userProfiles;
  final bool isChatBanned;
  final bool isFullHeight;
  final bool isMuted;
  final bool isSpeakerMuted;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onSpeakerMuteToggle;
  
  const RoomChatSection({
    super.key,
    this.height = 300,
    required this.messages,
    required this.currentUserId,
    required this.onSendMessage,
    this.userProfiles = const {},
    this.isChatBanned = false,
    this.isFullHeight = false,
    this.isMuted = false,
    this.isSpeakerMuted = false,
    this.onMuteToggle,
    this.onSpeakerMuteToggle,
  });

  @override
  State<RoomChatSection> createState() => _RoomChatSectionState();
}

class _RoomChatSectionState extends State<RoomChatSection> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }
  
  @override
  void didUpdateWidget(covariant RoomChatSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSend() {
    if (widget.isChatBanned) return;
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Container(
      height: widget.isFullHeight ? null : widget.height,
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withOpacity(0.95),
        borderRadius: widget.isFullHeight 
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar (only show if not full height/integrated)
          if (!widget.isFullHeight)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
          
          // Messages List
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(Spacing.base),
              itemCount: widget.messages.length,
              separatorBuilder: (context, index) => const SizedBox(height: Spacing.md),
              itemBuilder: (context, index) {
                final msg = widget.messages[index];
                final isMe = msg.userId == widget.currentUserId;
                final profile = widget.userProfiles[msg.userId];
                final name = profile?['name'] ?? 'User';
                final avatarUrl = profile?['profile_pic'] ?? profile?['avatar_url'] as String?;
                
                return Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: colors.surfaceAlt,
                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: textTheme.labelSmall?.copyWith(color: colors.textPrimary),
                              )
                            : null,
                      ),
                      const SizedBox(width: Spacing.sm),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(
                                name,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: Spacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? colors.primary : colors.surface,
                              borderRadius: BorderRadius.circular(Radii.lg).copyWith(
                                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(Radii.lg),
                                bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(Radii.lg),
                              ),
                              border: isMe ? null : Border.all(color: colors.border),
                            ),
                            child: Text(
                              msg.content,
                              style: textTheme.bodyMedium?.copyWith(
                                color: isMe ? Colors.white : colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Input Area (Compact & Modern bottom action bar)
          Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 6,
              bottom: 6 + MediaQuery.of(context).padding.bottom, 
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                // Integrated Microphone Mute/Unmute
                if (widget.onMuteToggle != null) ...[
                  GestureDetector(
                    onTap: widget.onMuteToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isMuted 
                            ? colors.surfaceAlt 
                            : colors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isMuted ? colors.border : colors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        widget.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: widget.isMuted ? colors.textSecondary : colors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                
                // Integrated Room Speaker Mute/Unmute
                if (widget.onSpeakerMuteToggle != null) ...[
                  GestureDetector(
                    onTap: widget.onSpeakerMuteToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isSpeakerMuted 
                            ? colors.surfaceAlt 
                            : colors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isSpeakerMuted ? colors.border : colors.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        widget.isSpeakerMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: widget.isSpeakerMuted ? colors.textSecondary : colors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                
                // Rounded Chat Input Field
                Expanded(
                  child: ThemedTextField(
                    controller: _controller,
                    hintText: widget.isChatBanned
                        ? 'Banned from chatting by host'
                        : 'Say something...',
                    maxLines: 1,
                    onSubmitted: (_) => _handleSend(),
                    enabled: !widget.isChatBanned,
                  ),
                ),
                const SizedBox(width: 6),

                // Music Icon
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Music feature coming soon!', style: TextStyle(color: colors.textPrimary)),
                        backgroundColor: colors.surface,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                IconButton(
                  onPressed: widget.isChatBanned ? null : _handleSend,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.send_rounded,
                    color: widget.isChatBanned ? colors.textMuted : colors.primary,
                    size: 20,
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
