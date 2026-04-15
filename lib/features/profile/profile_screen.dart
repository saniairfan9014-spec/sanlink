import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanlink/services/post_service.dart';
import 'package:sanlink/widgets/postcard.dart';
import 'package:sanlink/features/profile/update_profile_screen.dart';

// ─── DEBUG LOGGER ─────────────────────────────────────────────
void _log(String tag, String msg) {
  debugPrint("[$tag] $msg");
}

// ─── DESIGN TOKENS ────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surfaceAlt = Color(0xFF1C1C27);
  static const border = Color(0xFF2A2A3D);
  static const primary = Color(0xFF7C5CFC);
  static const accent = Color(0xFF00E5FF);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF44445A);
  static const green = Color(0xFF00E676);
  static const gold = Color(0xFFFFD700);
}

// ───────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ───────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileScreen({super.key, required this.userData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final postService = PostService();

  List<Map<String, dynamic>> userPosts = [];
  bool loadingPosts = true;

  bool isFriend = false;
  bool requestSent = false;
  bool sendingRequest = false;
  bool uploadingAvatar = false;

  String? avatarUrl;

  @override
  void initState() {
    super.initState();
    _log("PROFILE", "Opened: ${widget.userData}");
    avatarUrl = widget.userData['avatar_url'];
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      fetchUserPosts(),
      checkFriendStatus(),
      checkRequestStatus(),
    ]);
  }

  Future<void> fetchUserPosts() async {
    setState(() => loadingPosts = true);
    try {
      final uid = widget.userData['id']?.toString();
      if (uid == null || uid.isEmpty) {
        userPosts = [];
      } else {
        userPosts = await postService.getPostsByUser(uid);
      }
    } catch (e) {
      _log("PROFILE", "Posts error: $e");
      userPosts = [];
    }
    if (mounted) setState(() => loadingPosts = false);
  }

  Future<void> checkFriendStatus() async {
    final uid = widget.userData['id'] as String?;
    if (uid == null) return;
    final result = await postService.areFriends(uid);
    if (mounted) setState(() => isFriend = result);
  }

  Future<void> checkRequestStatus() async {
    final toUserId = widget.userData['id'] as String?;
    final currentUser = postService.supabase.auth.currentUser;

    if (toUserId == null || currentUser == null) return;

    try {
      // ✅ FIX: Use correct table 'chat_requests' and correct columns
      //         'from_user_id' and 'to_user_id' instead of sender_id/receiver_id
      final existing = await postService.supabase
          .from('chat_requests')           // ✅ was 'friend_requests' — WRONG
          .select()
          .eq('from_user_id', currentUser.id)  // ✅ was 'sender_id' — WRONG
          .eq('to_user_id', toUserId)           // ✅ was 'receiver_id' — WRONG
          .maybeSingle();

      if (mounted) {
        setState(() => requestSent = existing != null);
      }
    } catch (e) {
      _log("PROFILE", "checkRequestStatus error: $e");
    }
  }

  Future<void> sendRequest() async {
    final toUserId = widget.userData['id'] as String?;
    final currentUser = postService.supabase.auth.currentUser;

    if (toUserId == null || currentUser == null) return;

    setState(() => sendingRequest = true);

    try {
      // ✅ FIX: Directly insert into 'chat_requests' with correct column names
      //         instead of calling postService.sendFriendRequest()
      //         which was likely inserting into wrong table
      await postService.supabase.from('chat_requests').insert({
        'from_user_id': currentUser.id,   // ✅ correct column
        'to_user_id': toUserId,           // ✅ correct column
        'status': 'pending',
      });

      _log("PROFILE", "Request sent to $toUserId");
      setState(() => requestSent = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Friend request sent!")),
        );
      }
    } catch (e) {
      _log("PROFILE", "Request error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }

    if (mounted) setState(() => sendingRequest = false);
  }

  Future<void> pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => uploadingAvatar = true);

    try {
      String? url;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        url = await postService.uploadMedia(fileBytes: bytes, fileName: file.name);
      } else {
        url = await postService.uploadMedia(filePath: file.path, fileName: file.name);
      }

      if (url != null) {
        await postService.updateProfilePicture(url);
        setState(() => avatarUrl = url);
      }
    } catch (e) {
      _log("PROFILE", "Avatar error: $e");
    }

    if (mounted) setState(() => uploadingAvatar = false);
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpdateProfileScreen(
          userData: widget.userData,
          onProfileUpdated: (data) {
            _log("PROFILE", "Updated: $data");
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userData;
    final currentUserId = postService.supabase.auth.currentUser?.id;
    final isMe = user['id'] == currentUserId;

    final name = user['name'] ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: isMe ? pickAndUploadAvatar : null,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: _C.primary,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                          child: avatarUrl == null
                              ? Text(initial, style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                        if (uploadingAvatar)
                          const Positioned.fill(
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        if (isMe)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: _C.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: _C.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isFriend ? "✅ Friends" : "User",
                          style: const TextStyle(color: _C.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  if (isMe)
                    IconButton(
                      onPressed: _navigateToEditProfile,
                      icon: const Icon(Icons.edit, color: Colors.white),
                    ),
                ],
              ),
            ),

            // FRIEND BUTTON — only show for other users
            if (!isMe) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: requestSent ? _C.surfaceAlt : _C.primary,
                      foregroundColor: _C.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (requestSent || sendingRequest || isFriend) ? null : sendRequest,
                    icon: sendingRequest
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Icon(isFriend
                        ? Icons.people
                        : requestSent
                        ? Icons.check
                        : Icons.person_add),
                    label: Text(
                      isFriend
                          ? "Already Friends"
                          : requestSent
                          ? "Request Sent"
                          : "Add Friend",
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const Divider(color: Colors.white12),

            // POSTS
            Expanded(
              child: loadingPosts
                  ? const Center(child: CircularProgressIndicator())
                  : userPosts.isEmpty
                  ? const Center(
                child: Text(
                  "No posts yet",
                  style: TextStyle(color: Colors.white54),
                ),
              )
                  : ListView.builder(
                itemCount: userPosts.length,
                itemBuilder: (context, i) {
                  return PostCard(postData: userPosts[i]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}