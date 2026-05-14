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

  bool _isPlayingAudio = false;

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

    final isText = mediaType == null || mediaType == '';
    final isPhoto = mediaType == 'image';
    final isVideo = mediaType == 'video';
    final isAudio = mediaType == 'audio';

    Widget badge = const SizedBox();
    if (isText) badge = _buildBadge("📝 Text", const Color(0xFF6C63FF));
    else if (isPhoto) badge = _buildBadge("📷 Photo", Colors.green);
    else if (isVideo) badge = _buildBadge("🎬 Video", Colors.blue);
    else if (isAudio) badge = _buildBadge("🎵 Audio", Colors.amber);

    return Container(
      decoration: isText ? const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF6C63FF), width: 3)),
      ) : null,
      padding: const EdgeInsets.all(Spacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── USER ROW + BADGE ─────────────────────────
          _buildUserRow(colors, name, avatar, frameUrl, timeStr, badge),

          const SizedBox(height: Spacing.sm),

          // ─── SPECIFIC CONTENT UI ───────────────────────
          if (isText)
            _buildTextPost(colors),
          if (isPhoto)
            _buildPhotoPost(colors, mediaUrl),
          if (isVideo)
            _buildVideoPost(colors, mediaUrl),
          if (isAudio)
            _buildAudioPost(colors),

          // ─── ACTION BAR ────────────────────────────────
          const SizedBox(height: Spacing.sm),
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

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildUserRow(
    AppColorsExtension colors,
    String name,
    String? avatar,
    String? frameUrl,
    String timeStr,
    Widget badge,
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
        badge,
        const SizedBox(width: 8),
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

  Widget _buildTextPost(AppColorsExtension colors) {
    final content = widget.postData['content']?.toString() ?? '';
    if (content.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Text(
        content,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildPhotoPost(AppColorsExtension colors, String? mediaUrl) {
    final content = widget.postData['content']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.isNotEmpty) ...[
          Text(
            content,
            style: TextStyle(color: colors.textPrimary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: Spacing.md),
        ],
        if (mediaUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              mediaUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: colors.surfaceAlt,
                child: Center(child: Icon(Icons.broken_image_rounded, color: colors.textMuted)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoPost(AppColorsExtension colors, String? mediaUrl) {
    final content = widget.postData['content']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.isNotEmpty) ...[
          Text(
            content,
            style: TextStyle(color: colors.textPrimary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: Spacing.md),
        ],
        if (mediaUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _videoController != null && _videoController!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : Container(
                        height: 200,
                        color: colors.surfaceAlt,
                        child: Center(child: CircularProgressIndicator(color: colors.primary)),
                      ),
                // Play Icon Overlay
                GestureDetector(
                  onTap: () {
                    if (_videoController == null) return;
                    setState(() {
                      _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                    });
                  },
                  child: AnimatedOpacity(
                    opacity: _videoController?.value.isPlaying == true ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                ),
                // Duration text bottom-right
                if (_videoController != null && _videoController!.value.isInitialized)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(_videoController!.value.duration),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${duration.inHours}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildAudioPost(AppColorsExtension colors) {
    final content = widget.postData['content']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.isNotEmpty) ...[
          Text(
            content,
            style: TextStyle(color: colors.textPrimary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: Spacing.md),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _isPlayingAudio = !_isPlayingAudio);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C63FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Custom waveform
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(20, (index) {
                    final heights = [10.0, 15.0, 25.0, 12.0, 30.0, 18.0, 22.0, 14.0, 28.0, 16.0, 20.0, 26.0, 12.0, 24.0, 18.0, 22.0, 14.0, 28.0, 15.0, 10.0];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 4,
                      height: _isPlayingAudio ? heights[index] : 4.0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(_isPlayingAudio ? 1.0 : 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "1:24", // mock duration
                style: TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
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