import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../services/post_service.dart';
import 'package:sanlink/features/profile/profile_screen.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> postData;

  const PostCard({super.key, required this.postData});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final postService = PostService();

  bool isLiked = false;
  int likeCount = 0;
  bool isSaved = false;
  List<Map<String, dynamic>> comments = [];
  bool showComments = false;

  final TextEditingController commentController = TextEditingController();
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
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
    if (isLiked) {
      await postService.unlikePost(widget.postData['id']);
    } else {
      await postService.likePost(widget.postData['id']);
    }
    loadLikes();
  }

  Future<void> loadSaved() async {
    final saved = await postService.isSaved(widget.postData['id']);
    if (mounted) setState(() => isSaved = saved);
  }

  Future<void> toggleSave() async {
    if (isSaved) {
      await postService.unsavePost(widget.postData['id']);
    } else {
      await postService.savePost(widget.postData['id']);
    }
    loadSaved();
  }

  Future<void> loadComments() async {
    final res = await postService.getComments(widget.postData['id']);
    if (mounted) setState(() => comments = res);
  }

  Future<void> submitComment() async {
    if (commentController.text.trim().isEmpty) return;

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

  @override
  Widget build(BuildContext context) {
    final user = widget.postData['users'];
    final mediaType = widget.postData['media_type'];
    final mediaUrl = widget.postData['media_url'];

    final name = user?['name'] ?? 'Unknown';
    final avatar = user?['profile_pic'] ?? user?['avatar_url'];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── USER ROW ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      backgroundImage:
                      avatar != null ? NetworkImage(avatar) : null,
                      child: avatar == null
                          ? Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(width: 8),

                    GestureDetector(
                      onTap: () {
                        if (user != null) {
                          final profileData = {
                            ...Map<String, dynamic>.from(user ?? {}),
                            'id': widget.postData['user_id']?.toString(),
                          };

                          debugPrint(
                              "🚀 Navigating profile ID: ${profileData['id']}");

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProfileScreen(userData: profileData),
                            ),
                          );
                        }
                      },
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                Builder(
                  builder: (context) {
                    final currentUserId = postService.supabase.auth.currentUser?.id;
                    final isOwner = widget.postData['user_id'] == currentUserId;

                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
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
                            final link = "https://sanlink.app/post/${widget.postData['id']}";
                            await Clipboard.setData(ClipboardData(text: link));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied to clipboard!')),
                              );
                            }
                            break;
                          case 'copy_text':
                            await Clipboard.setData(ClipboardData(text: widget.postData['content'] ?? ''));
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
                                const SnackBar(content: Text('Thank you! This post has been reported for review.')),
                              );
                            }
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'copy_link',
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Copy Link'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'copy_text',
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Copy Text'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Share'),
                            ],
                          ),
                        ),
                        if (!isOwner)
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.report_gmailerrorred_rounded,
                                    size: 18, color: Colors.orange),
                                SizedBox(width: 12),
                                Text('Report Post'),
                              ],
                            ),
                          ),
                        if (isOwner)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded,
                                    size: 18, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Delete Post',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(widget.postData['content'] ?? ''),

            const SizedBox(height: 8),

            // ─── MEDIA ───────────────────────────────
            if (mediaUrl != null) ...[
              if (mediaType == 'image')
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(mediaUrl),
                ),

              if (mediaType == 'video' && _videoController != null)
                _videoController!.value.isInitialized
                    ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_videoController!),
                      IconButton(
                        icon: Icon(
                          _videoController!.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                        onPressed: () {
                          setState(() {
                            _videoController!.value.isPlaying
                                ? _videoController!.pause()
                                : _videoController!.play();
                          });
                        },
                      ),
                    ],
                  ),
                )
                    : const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
            ],

            Text(
              widget.postData['created_at']?.toString() ?? '',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),

            const SizedBox(height: 8),

            // ─── ACTIONS ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : null,
                      ),
                      onPressed: toggleLike,
                    ),
                    Text("$likeCount"),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.comment),
                      onPressed: () => setState(() {
                        showComments = !showComments;
                      }),
                    ),
                    Text("${comments.length}"),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? Colors.blue : null,
                  ),
                  onPressed: toggleSave,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: sharePost,
                ),
              ],
            ),

            // ─── COMMENTS ───────────────────────────────
            if (showComments) ...[
              const Divider(),

              for (var c in comments)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundImage: c['users']?['avatar_url'] != null
                        ? NetworkImage(c['users']['avatar_url'])
                        : null,
                    child: c['users']?['avatar_url'] == null
                        ? const Icon(Icons.person, size: 12)
                        : null,
                  ),
                  title: Text(
                    c['users']?['name'] ?? 'Unknown',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    c['comment'] ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add comment...',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, size: 20),
                    onPressed: submitComment,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}