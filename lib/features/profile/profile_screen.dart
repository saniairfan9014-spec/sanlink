import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanlink/services/post_service.dart';
import 'package:sanlink/widgets/postcard.dart';
import 'package:sanlink/features/profile/update_profile_screen.dart'; // ← add this import

// ─── Design Tokens ────────────────────────────────────────────────────────────
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
  static const gold = Color(0xFFFFD700);
}

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ProfileScreen({super.key, required this.userData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final postService = PostService();

  List<Map<String, dynamic>> userPosts = [];
  bool loadingPosts = true;
  bool isFriend = false;
  bool requestSent = false;
  bool sendingRequest = false;
  bool uploadingAvatar = false;
  String? avatarUrl;

  late AnimationController _headerAnim;
  late AnimationController _rotateAnim;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _rotateAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    avatarUrl = widget.userData['avatar_url'];
    _loadAll();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userData['id'] != oldWidget.userData['id'] ||
        widget.userData['avatar_url'] != oldWidget.userData['avatar_url']) {
      setState(() {
        avatarUrl = widget.userData['avatar_url'];
      });
      if (widget.userData['id'] != oldWidget.userData['id']) {
        _loadAll();
      }
    }
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _rotateAnim.dispose();
    super.dispose();
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
      debugPrint("🔍 [ProfileScreen] Fetching posts for UID: $uid");
      if (uid == null || uid.isEmpty) {
        userPosts = [];
      } else {
        userPosts = await postService.getPostsByUser(uid);
      }
    } catch (e) {
      debugPrint('Error fetching user posts: $e');
      userPosts = [];
    }
    if (mounted) setState(() => loadingPosts = false);
  }

  Future<void> checkFriendStatus() async {
    final uid = widget.userData['id'] as String?;
    if (uid == null || uid.isEmpty) return;
    final result = await postService.areFriends(uid);
    if (mounted) setState(() => isFriend = result);
  }

  Future<void> checkRequestStatus() async {
    final toUserId = widget.userData['id'] as String?;
    if (toUserId == null || toUserId.isEmpty) return;
    final currentUser = postService.supabase.auth.currentUser;
    if (currentUser == null) return;

    final existing = await postService.supabase
        .from('friend_requests')
        .select()
        .eq('sender_id', currentUser.id)
        .eq('receiver_id', toUserId)
        .maybeSingle();

    if (mounted && existing != null) {
      setState(() => requestSent = true);
    }
  }

  Future<void> sendRequest() async {
    final toUserId = widget.userData['id'] as String?;
    if (toUserId == null || toUserId.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => sendingRequest = true);
    await postService.sendFriendRequest(toUserId);
    if (mounted) {
      setState(() {
        requestSent = true;
        sendingRequest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Friend request sent!'),
          backgroundColor: _C.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> pickAndUploadAvatar() async {
    HapticFeedback.mediumImpact();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => uploadingAvatar = true);

    try {
      String? mediaUrl;
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        mediaUrl = await postService.uploadMedia(
          fileBytes: bytes,
          fileName: pickedFile.name,
        );
      } else {
        mediaUrl = await postService.uploadMedia(
          filePath: pickedFile.path,
          fileName: pickedFile.name,
        );
      }

      if (mediaUrl != null) {
        await postService.updateProfilePicture(mediaUrl);
        if (mounted) {
          setState(() => avatarUrl = mediaUrl);
        }
      }
    } catch (e) {
      debugPrint("Avatar upload error: $e");
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  // ─── Navigate to Update Profile Screen ──────────────────────────────────────
  void _navigateToEditProfile() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpdateProfileScreen(
          userData: widget.userData,
          onProfileUpdated: (updatedData) {
            // Refresh avatar & name if updated on the edit screen
            if (mounted) {
              setState(() {
                if (updatedData['avatar_url'] != null) {
                  avatarUrl = updatedData['avatar_url'];
                }
              });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userData;
    final currentUserId = postService.supabase.auth.currentUser?.id;
    final isCurrentUser = user['id'] == currentUserId;
    final name = user['name']?.toString() ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
        slivers: [
          // ─── Collapsible Header ────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: _C.surface,
            expandedHeight: 240,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _C.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            // ── Edit Profile icon in AppBar actions (visible when collapsed) ──
            actions: [
              if (isCurrentUser)
                IconButton(
                  tooltip: 'Edit Profile',
                  icon: const Icon(Icons.edit_rounded,
                      color: _C.textSecondary, size: 20),
                  onPressed: _navigateToEditProfile,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: FadeTransition(
                opacity: _headerFade,
                child: Stack(
                  children: [
                    // Background gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A0F3A), Color(0xFF0A0A0F)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    // ── Premium Avatar with Camera + Edit icons ──────────────
                    Positioned(
                      top: 50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Rotating gradient ring
                            RotationTransition(
                              turns: _rotateAnim,
                              child: Container(
                                width: 116,
                                height: 116,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      _C.primary,
                                      _C.accent,
                                      _C.gold,
                                      _C.primary,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _C.primaryGlow,
                                      blurRadius: 30,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Inner dark ring
                            Container(
                              width: 106,
                              height: 106,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _C.bg,
                              ),
                            ),

                            // Avatar image / initial
                            GestureDetector(
                              onTap: isCurrentUser ? pickAndUploadAvatar : null,
                              child: Container(
                                width: 98,
                                height: 98,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _C.surfaceAlt,
                                  image: avatarUrl != null
                                      ? DecorationImage(
                                    image: NetworkImage(avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                      : null,
                                ),
                                child: avatarUrl == null
                                    ? Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                                    : null,
                              ),
                            ),

                            // Upload spinner
                            if (uploadingAvatar)
                              const SizedBox(
                                width: 98,
                                height: 98,
                                child: CircularProgressIndicator(
                                  color: _C.primary,
                                  strokeWidth: 2.5,
                                ),
                              )

                            // 📷 Camera icon — bottom-right of avatar
                            else if (isCurrentUser)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: pickAndUploadAvatar,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: _C.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _C.primary, width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: _C.primaryGlow,
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: _C.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Name row with ✏️ Edit icon ────────────────────────────
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: _C.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              // ✏️ Edit icon — navigates to UpdateProfileScreen
                              if (isCurrentUser) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _navigateToEditProfile,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: _C.surfaceAlt,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _C.border, width: 1),
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      size: 13,
                                      color: _C.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (isCurrentUser)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                'You',
                                style: TextStyle(
                                    color: _C.accent, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Stats + Action Row ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: _C.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          value: loadingPosts ? '–' : '${userPosts.length}',
                          label: 'Posts',
                        ),
                        Container(width: 1, height: 32, color: _C.border),
                        _StatItem(
                          value: isFriend ? '✓' : '–',
                          label: 'Friends',
                        ),
                      ],
                    ),
                  ),

                  // Add Friend button (hidden if friends or self)
                  if (!isCurrentUser && !isFriend)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: requestSent
                              ? _StatusChip(
                            key: const ValueKey('sent'),
                            icon: Icons.check_circle_outline,
                            label: 'Request Sent',
                            color: _C.textSecondary,
                          )
                              : _AddFriendButton(
                            key: const ValueKey('add'),
                            loading: sendingRequest,
                            onTap: sendRequest,
                          ),
                        ),
                      ),
                    ),

                  // Edit Profile button (only for current user, below stats)
                  if (isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _navigateToEditProfile,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: _C.surfaceAlt,
                              borderRadius: BorderRadius.circular(14),
                              border:
                              Border.all(color: _C.border, width: 0.5),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_rounded,
                                    color: _C.textSecondary, size: 15),
                                SizedBox(width: 8),
                                Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    color: _C.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  Container(height: 0.5, color: _C.border),
                ],
              ),
            ),
          ),

          // ─── Posts Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.grid_on_rounded,
                      color: _C.primary, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Posts',
                    style: TextStyle(
                      color: _C.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (!loadingPosts)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.primaryGlow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${userPosts.length}',
                          style: const TextStyle(
                            color: _C.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Posts List ────────────────────────────────────────────────────
          if (loadingPosts)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: _C.primary, strokeWidth: 2),
              ),
            )
          else if (userPosts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _C.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.border),
                      ),
                      child: const Icon(Icons.photo_library_outlined,
                          color: _C.textMuted, size: 28),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No posts yet',
                      style: TextStyle(
                        color: _C.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isCurrentUser
                          ? 'Share your first post!'
                          : '$name hasn\'t posted yet',
                      style: const TextStyle(
                          color: _C.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.border, width: 0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: PostCard(postData: userPosts[i]),
                  ),
                ),
                childCount: userPosts.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _C.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: _C.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusChip(
      {super.key,
        required this.icon,
        required this.label,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFriendButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _AddFriendButton(
      {super.key, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_C.primary, Color(0xFF9B7CFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x557C5CFC), blurRadius: 14, spreadRadius: 2),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Add Friend',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}