import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/themed_text_field.dart';
import '../data/models/room_message_model.dart';

class RoomChatSection extends StatefulWidget {
  final double height;
  final List<RoomMessageModel> messages;
  final String currentUserId;
  final ValueChanged<String> onSendMessage;
  
  const RoomChatSection({
    super.key,
    this.height = 300,
    required this.messages,
    required this.currentUserId,
    required this.onSendMessage,
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
      height: widget.height,
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
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
                
                return Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${msg.userId}'),
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
                                msg.userId,
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
          
          // Input Area
          Container(
            padding: const EdgeInsets.only(
              left: Spacing.base,
              right: Spacing.xs,
              top: Spacing.sm,
              bottom: Spacing.md, 
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ThemedTextField(
                    controller: _controller,
                    hintText: 'Type a message...',
                    maxLines: 1,
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                IconButton(
                  onPressed: _handleSend,
                  icon: Icon(Icons.send_rounded, color: colors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
