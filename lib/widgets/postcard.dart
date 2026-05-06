import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:sanlink/features/profile/profile_screen.dart';
import 'package:sanlink/widgets/profile_avatar.dart';
import 'package:sanlink/services/post_service.dart';
import 'package:sanlink/core/theme/app_theme.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> postData;

  const PostCard({super.key, required this.postData});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  final postService = PostService();

  bool isLiked = false;
  int likeCount = 0;
  bool isSaved = false;
  List<Map<String, dynamic>> comments = [];
  bool showComments = false;

  final TextEditingController commentController = TextEditingController();
  VideoPlayerController? _videoController;
  late AnimationController _likeAnimCtrl;

  @override
  void initState() {
    super.initState();
    _likeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    initMedia();
    loadLikes();
    loadSaved();
    loadComments();
  }

  void initMedia() {
    final mediaType = widget.postData['media_type'];
    final mediaUrl = widget.postData['media_url'];

    if (mediaType == 'video' && mediaUrl != null) {
      _videoController = VideoPlayerController.network(mediaUrl)
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    commentController.dispose();
    _likeAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> loadLikes() async {
    final liked = await postService.isLiked(widget.postData['id']);
    final count = await postService.getLikesCount(widget.postData['id']);
    if (mounted) {
      setState(() {
        isLiked = liked;
        likeCount = count;
      });
    }
  }

  Future<void> toggleLike() async {
    HapticFeedback.lightImpact();
    // Optimistic update
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
    if (isLiked) {
      _likeAnimCtrl.forward(from: 0);
    }

    try {
      if (isLiked) {
        await postService.likePost(widget.postData['id']);
      } else {
        await postService.unlikePost(widget.postData['id']);
      }
    } catch (_) {
      // Revert on error
      loadLikes();
    }
  }

  Future<void> loadSaved() async {
    final saved = await postService.isSaved(widget.postData['id']);
    if (mounted) setState(() => isSaved = saved);
  }

  Future<void> toggleSave() async {
    HapticFeedback.lightImpact();
    setState(() => isSaved = !isSaved);
    try {
      if (isSaved) {
        await postService.savePost(widget.postData['id']);
      } else {
        await postService.unsavePost(widget.postData['id']);
      }
    } catch (_) {
      loadSaved();
    }
  }

  Future<void> loadComments() async {
    final res = await postService.getComments(widget.postData['id']);
    if (mounted) setState(() => comments = res);
  }

  Future<void> submitComment() async {
    if (commentController.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    await postService.addComment(
      widget.postData['id'],
      commentController.text,
    );
    commentController.clear();
    loadComments();
  }

  void sharePost() async {
    final content = widget.postData['content'] ?? '';
    try {
      await Share.share(content, subject: "Check this post!");
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Copied to clipboard!")),
        );
      }
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = widget.postData['users'];
    final mediaType = widget.postData['media_type'];
    final mediaUrl = widget.postData['media_url'];

    final name = user?['name'] ?? 'Unknown';
    final avatar = user?['profile_pic'] ?? user?['avatar_url'];
    final frameUrl = user?['selected_frame']?['image_url'];
    final timeStr = _formatTime(widget.postData['created_at']?.toString());

    return Padding(
      padding: const EdgeInsets.all(Spacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── USER ROW ──────────────────────────────────
          _buildUserRow(colors, name, avatar, frameUrl, timeStr),

          // ─── CONTENT ───────────────────────────────────
          if (widget.postData['content'] != null &&
              widget.postData['content'].toString().isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            Text(
              widget.postData['content'],
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],

          // ─── MEDIA ─────────────────────────────────────
          if (mediaUrl != null) ...[
            const SizedBox(height: Spacing.md),
            _buildMedia(colors, mediaType, mediaUrl),
          ],

          // ─── ACTION BAR ────────────────────────────────
          const SizedBox(height: Spacing.md),
          _buildActionBar(colors),

          // ─── COMMENTS ──────────────────────────────────
          if (showComments) ...[
            Divider(color: colors.border, height: 24),
            _buildComments(colors),
          ],
        ],
      ),
    );
  }

  Widget _buildUserRow(
    AppColorsExtension colors,
    String name,
    String? avatar,
    String? frameUrl,
    String timeStr,
  ) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _navigateToProfile(),
          child: ProfileAvatar(
            avatarUrl: avatar,
            frameUrl: frameUrl,
            size: 42,
            name: name,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _navigateToProfile(),
                child: Text(
                  name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        _buildMoreMenu(colors),
      ],
    );
  }

  void _navigateToProfile() {
    final user = widget.postData['users'];
    if (user != null) {
      final profileData = {
        ...Map<String, dynamic>.from(user ?? {}),
        'id': widget.postData['user_id']?.toString(),
      };
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userData: profileData),
        ),
      );
    }
  }

  Widget _buildMoreMenu(AppColorsExtension colors) {
    final currentUserId = postService.supabase.auth.currentUser?.id;
    final isOwner = widget.postData['user_id'] == currentUserId;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: colors.textMuted, size: 20),
      elevation: 8,
      onSelected: (value) async {
        switch (value) {
          case 'delete':
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            await postService.deletePost(widget.postData['id']);
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Post deleted')),
            );
            break;
          case 'copy_link':
            final link =
                "https://sanlink.app/post/${widget.postData['id']}";
            await Clipboard.setData(ClipboardData(text: link));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied!')),
              );
            }
            break;
          case 'copy_text':
            await Clipboard.setData(
              ClipboardData(text: widget.postData['content'] ?? ''),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post content copied!')),
              );
            }
            break;
          case 'share':
            sharePost();
            break;
          case 'report':
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Thank you! This post has been reported.')),
              );
            }
            break;
        }
      },
      itemBuilder: (_) => [
        _menuItem('copy_link', Icons.link_rounded, 'Copy Link', colors),
        _menuItem('copy_text', Icons.copy_rounded, 'Copy Text', colors),
        _menuItem('share', Icons.share_rounded, 'Share', colors),
        if (!isOwner)
          _menuItem('report', Icons.report_gmailerrorred_rounded, 'Report',
              colors,
              iconColor: colors.orange),
        if (isOwner)
          _menuItem('delete', Icons.delete_outline_rounded, 'Delete', colors,
              iconColor: colors.red, textColor: colors.red),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    AppColorsExtension colors, {
    Color? iconColor,
    Color? textColor,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? colors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(
      AppColorsExtension colors, String? mediaType, String mediaUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: mediaType == 'video' && _videoController != null
          ? _videoController!.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_videoController!),
                      // Gradient scrim
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity:
                              _videoController!.value.isPlaying ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoController!.value.isPlaying
                                ? _videoController!.pause()
                                : _videoController!.play();
                          });
                        },
                        child: AnimatedOpacity(
                          opacity:
                              _videoController!.value.isPlaying ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  ),
                )
          : Image.network(
              mediaUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: colors.textMuted,
                    size: 40,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildActionBar(AppColorsExtension colors) {
    return Row(
      children: [
        // Like
        _ActionButton(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: likeCount > 0 ? '$likeCount' : '',
          color: isLiked ? colors.red : colors.textSecondary,
          onTap: toggleLike,
        ),
        const SizedBox(width: Spacing.xs),

        // Comment
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: comments.isNotEmpty ? '${comments.length}' : '',
          color: colors.textSecondary,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => showComments = !showComments);
          },
        ),
        const SizedBox(width: Spacing.xs),

        // Share
        _ActionButton(
          icon: Icons.send_rounded,
          color: colors.textSecondary,
          onTap: sharePost,
        ),

        const Spacer(),

        // Bookmark
        _ActionButton(
          icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: isSaved ? colors.primary : colors.textSecondary,
          onTap: toggleSave,
        ),
      ],
    );
  }

  Widget _buildComments(AppColorsExtension colors) {
    return Column(
      children: [
        // Comment list
        ...comments.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(
                    avatarUrl: c['users']?['avatar_url'],
                    frameUrl: c['users']?['selected_frame']?['image_url'],
                    size: 30,
                    name: c['users']?['name'],
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['users']?['name'] ?? 'Unknown',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c['comment'] ?? '',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )),

        // Comment input
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.xxl),
                  border: Border.all(color: colors.border),
                ),
                child: TextField(
                  controller: commentController,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write a comment...',
                    hintStyle: TextStyle(
                      color: colors.textMuted,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            GestureDetector(
              onTap: submitComment,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}