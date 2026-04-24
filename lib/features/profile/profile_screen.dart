import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanlink/services/post_service.dart';
import 'package:sanlink/widgets/postcard.dart';
import 'package:sanlink/features/profile/update_profile_screen.dart';
import 'package:sanlink/features/games/services/game_service.dart';
import 'package:sanlink/features/chat/services/chat_service.dart';
import 'package:sanlink/features/chat/screens/direct_chat_screen.dart';
import 'package:sanlink/features/frames/frames_screen.dart';
import 'package:sanlink/services/frame_service.dart';

void _log(String tag, String msg) => debugPrint("[$tag] $msg");

// ─── DESIGN TOKENS ────────────────────────────────────────────
class _C {
  static const bg            = Color(0xFF0A0A0F);
  static const surface       = Color(0xFF13131A);
  static const surfaceAlt    = Color(0xFF1C1C27);
  static const border        = Color(0xFF2A2A3D);
  static const primary       = Color(0xFF7C5CFC);
  static const primaryGlow   = Color(0x447C5CFC);
  static const accent        = Color(0xFF00E5FF);
  static const textPrimary   = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted     = Color(0xFF44445A);
  static const green         = Color(0xFF00E676);
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

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final postService = PostService();
  final chatService = ChatService();
  final _frameService = FrameService();

  List<Map<String, dynamic>> userPosts = [];
  bool loadingPosts    = true;
  bool isFriend        = false;
  bool requestSent     = false;
  bool sendingRequest  = false;
  bool uploadingAvatar = false;
  String? avatarUrl;
  Map<String, dynamic>? _userData;
  
  final GameService _gameService = GameService();
  List<GameStat> _gameStats = [];
  bool _loadingStats = true;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    avatarUrl = _userData?['avatar_url'] ?? _userData?['profile_pic'];
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _fadeCtrl.forward();
    _loadAll();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      loadingPosts = true;
      _loadingStats = true;
    });
    await Future.wait([
      _fetchProfileData(),
      fetchUserPosts(), 
      checkFriendStatus(), 
      checkRequestStatus(),
      _loadGameStats(),
      _loadLevelInfo(),
    ]);
  }

  Future<void> _fetchProfileData() async {
    final uid = widget.userData['id'] as String?;
    if (uid == null) return;
    try {
      final data = await postService.supabase
          .from('users')
          .select('name, bio, avatar_url, profile_pic') // Removed profile_frame to avoid crash
          .eq('id', uid)
          .single();
      
      // Check local fallback for frame
      final localFrame = await _frameService.getLocalEquippedFrame();
      
      if (mounted) {
        setState(() {
          _userData = {
            ...data,
            if (localFrame != null) 'profile_frame': localFrame,
          };
          avatarUrl = data['avatar_url'] ?? data['profile_pic'];
        });
      }
    } catch (e) {
      _log("PROFILE", "Fetch profile error: $e");
    }
  }

  LevelInfo? _levelInfo;
  bool _loadingLevel = true;

  Future<void> _loadLevelInfo() async {
    try {
      final info = await _gameService.getUserLevelInfo();
      if (mounted) {
        setState(() {
          _levelInfo = info;
          _loadingLevel = false;
        });
      }
    } catch (e) {
      _log("PROFILE", "Level info error: $e");
      if (mounted) setState(() => _loadingLevel = false);
    }
  }

  Future<void> _loadGameStats() async {
    final uid = widget.userData['id'] as String?;
    if (uid == null) return;
    try {
      final stats = await _gameService.getUserGameStats(uid);
      if (mounted) {
        setState(() {
          _gameStats = stats;
          _loadingStats = false;
        });
      }
    } catch (e) {
      _log("PROFILE", "Game stats error: $e");
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> fetchUserPosts() async {
    setState(() => loadingPosts = true);
    try {
      final uid = widget.userData['id']?.toString();
      userPosts = (uid == null || uid.isEmpty)
          ? []
          : await postService.getPostsByUser(uid);
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
      final existing = await postService.supabase
          .from('chat_requests')
          .select()
          .eq('from_user_id', currentUser.id)
          .eq('to_user_id', toUserId)
          .maybeSingle();
      if (mounted) setState(() => requestSent = existing != null);
    } catch (e) {
      _log("PROFILE", "checkRequestStatus error: $e");
    }
  }

  Future<void> sendRequest() async {
    final toUserId = widget.userData['id'] as String?;
    final currentUser = postService.supabase.auth.currentUser;
    if (toUserId == null || currentUser == null) return;

    setState(() => sendingRequest = true);
    HapticFeedback.mediumImpact();

    try {
      await postService.supabase.from('chat_requests').insert({
        'from_user_id': currentUser.id,
        'to_user_id': toUserId,
        'status': 'pending',
      });
      setState(() => requestSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text("Friend request sent!"),
            ]),
            backgroundColor: _C.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _log("PROFILE", "Request error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
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
        url = await postService.uploadMedia(
            fileBytes: bytes, fileName: file.name);
      } else {
        url = await postService.uploadMedia(
            filePath: file.path, fileName: file.name);
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

  @override
  Widget build(BuildContext context) {
    final user          = _userData ?? widget.userData;
    final currentUserId = postService.supabase.auth.currentUser?.id;
    final isMe          = user['id'] == currentUserId;
    final name          = user['name'] ?? 'User';
    final bio           = user['bio'] as String?;
    final avatarUrl     = user['profile_pic'] ?? user['avatar_url']; // Fallback
    final frameUrl      = user['profile_frame']; // Will be null if column missing
    final initial       = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: _C.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── APP BAR ─────────────────────────────────────────
            SliverAppBar(
              backgroundColor: _C.bg,
              pinned: true,
              elevation: 0,
              expandedHeight: 0,
              leading: Navigator.canPop(context)
                  ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _C.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              )
                  : null,
              title: Text(
                isMe ? "MY ARENA" : name.toUpperCase(),
                style: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              centerTitle: true,
              actions: [
                if (isMe) ...[
                  IconButton(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FramesScreen()),
                      );
                      if (mounted) _loadAll(); // Refresh to show new frame
                    },
                    icon: const Icon(Icons.style_outlined, color: _C.textSecondary, size: 22),
                    tooltip: "Frames Collection",
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      onPressed: _navigateToEditProfile,
                      icon: const Icon(Icons.settings_outlined, color: _C.textSecondary, size: 22),
                    ),
                  ),
                ],
              ],
            ),

            // ── PROFILE HEADER ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // ── AVATAR & FRAME ──
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow Background
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _C.primary.withOpacity(0.2),
                                  blurRadius: 40,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          
                          // Avatar
                          GestureDetector(
                            onTap: isMe ? pickAndUploadAvatar : null,
                            child: CircleAvatar(
                              radius: 54,
                              backgroundColor: _C.surfaceAlt,
                              backgroundImage: avatarUrl != null
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl == null
                                  ? Text(initial,
                                      style: const TextStyle(
                                          color: _C.textPrimary,
                                          fontSize: 38,
                                          fontWeight: FontWeight.w900))
                                  : null,
                            ),
                          ),

                          // Frame Overlay
                          if (frameUrl != null)
                            IgnorePointer(
                              child: SizedBox(
                                width: 140,
                                height: 140,
                                child: Image.network(
                                  frameUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const SizedBox(),
                                ),
                              ),
                            )
                          else if (isMe)
                            // Decorative Ring for "No Frame" state
                            IgnorePointer(
                              child: Container(
                                width: 116,
                                height: 116,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _C.primary.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),

                          // Level Badge
                          if (_levelInfo != null)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _C.primary,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _C.bg, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                    )
                                  ],
                                ),
                                child: Text(
                                  "LVL ${_levelInfo!.level}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            
                          if (uploadingAvatar)
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.5),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _C.primary),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── NAME & USERNAME ──
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (user['username'] != null)
                      Text(
                        "@${user['username']}",
                        style: const TextStyle(
                          color: _C.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ── BIO ──
                    if (bio != null && bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _C.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── LEVEL PROGRESS ──
                    if (_levelInfo != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("XP PROGRESS", style: TextStyle(color: _C.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                Text("${_levelInfo!.currentXp}/${_levelInfo!.nextLevelXp} XP", style: TextStyle(color: _C.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _levelInfo!.progress,
                                minHeight: 6,
                                backgroundColor: _C.surfaceAlt,
                                valueColor: const AlwaysStoppedAnimation<Color>(_C.primary),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30),

                    // ── STATS ROW ──
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _C.border),
                      ),
                      child: Row(
                        children: [
                          _StatCell(
                              value: loadingPosts ? "..." : userPosts.length.toString(),
                              label: "POSTS"),
                          _vDivider(),
                          _StatCell(
                              value: isFriend ? "1" : "0", // Placeholder for actual friend count
                              label: "FRIENDS"),
                          _vDivider(),
                          _StatCell(
                              value: _gameStats.length.toString(),
                              label: "GAMES"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── ACTION BUTTONS (other user's profile) ──
                    if (!isMe) ...[
                      Row(
                        children: [
                          // Friend / Request button
                          Expanded(
                            child: isFriend
                                ? _ActionBtn(
                                    onTap: null,
                                    icon: Icons.check_circle_rounded,
                                    label: 'Friends ✓',
                                    filled: false,
                                  )
                                : requestSent
                                    ? _ActionBtn(
                                        onTap: null,
                                        icon: Icons.schedule_rounded,
                                        label: 'Request Sent',
                                        filled: false,
                                      )
                                    : _ActionBtn(
                                        onTap: sendingRequest ? null : sendRequest,
                                        icon: Icons.person_add_rounded,
                                        label: 'Send Request',
                                        filled: true,
                                        loading: sendingRequest,
                                      ),
                          ),
                          const SizedBox(width: 12),
                          // Message button (only if friends)
                          if (isFriend)
                            Expanded(
                              child: _ActionBtn(
                                onTap: () async {
                                  final chatId = await chatService.getCommonChatId(
                                    currentUserId!,
                                    user['id'],
                                  );
                                  if (chatId != null && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DirectChatScreen(
                                          chatId: chatId,
                                          friendName: name,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: Icons.chat_bubble_rounded,
                                label: 'Message',
                                filled: true,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ] else
                      const SizedBox(height: 30),
                    
                    // ── GAME PERFORMANCE ──
                    _buildGamePerformance(),

                    const SizedBox(height: 30),

                    // ── CONTENT TABS HEADER ──
                    Container(
                      padding: const EdgeInsets.only(bottom: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _C.border, width: 1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.grid_view_rounded, color: _C.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            "POSTS COLLECTION",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${userPosts.length} ITEMS",
                            style: const TextStyle(color: _C.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── POSTS FEED ──
            if (loadingPosts)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _C.primary)),
              )
            else if (userPosts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_clear_outlined, color: _C.textMuted, size: 40),
                      const SizedBox(height: 12),
                      const Text("No activity recorded yet.", style: TextStyle(color: _C.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(postData: userPosts[i]),
                  ),
                  childCount: userPosts.length,
                ),
              ),
            
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  void _navigateToEditProfile() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpdateProfileScreen(
          userData: widget.userData,
          onProfileUpdated: (data) => _log("PROFILE", "Updated: $data"),
        ),
      ),
    );
    if (updated != null || mounted) {
      _loadAll(); // Refresh
    }
  }

  Widget _buildGamePerformance() {
    if (_loadingStats) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(12.0),
        child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary),
      ));
    }
    
    if (_gameStats.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.sports_esports_outlined, color: _C.textSecondary, size: 15),
            SizedBox(width: 6),
            Text("Game Performance",
                style: TextStyle(
                    color: _C.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _gameStats.length,
            itemBuilder: (context, index) {
              final stat = _gameStats[index];
              final gameName = _getGameName(stat.gameId);
              final gameIcon = _getGameIcon(stat.gameId);
              final gameColor = _getGameColor(stat.gameId);

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: gameColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(gameIcon, color: gameColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(gameName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          Text("${stat.winRate.toStringAsFixed(0)}% Win",
                              style: TextStyle(
                                  color: gameColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getGameName(String id) {
    if (id == 'tictactoe') return "Tic Tac Toe";
    if (id == 'quiz') return "Quiz Master";
    if (id == 'brickbreaker') return "Brick Breaker";
    if (id == 'snake') return "Snake Game";
    return id;
  }

  IconData _getGameIcon(String id) {
    if (id == 'tictactoe') return Icons.grid_3x3_rounded;
    if (id == 'quiz') return Icons.psychology_rounded;
    if (id == 'brickbreaker') return Icons.view_module_rounded;
    if (id == 'snake') return Icons.timeline_rounded;
    return Icons.games_rounded;
  }

  Color _getGameColor(String id) {
    if (id == 'tictactoe') return _C.primary;
    if (id == 'quiz') return _C.accent;
    if (id == 'brickbreaker') return const Color(0xFFFF6D00);
    if (id == 'snake') return const Color(0xFF00E676);
    return _C.primary;
  }

  Widget _vDivider() =>
      Container(width: 1, height: 32, color: _C.border);
}

// ─── STAT CELL ────────────────────────────────────────────────
class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: _C.textSecondary,
                  fontSize: 11,
                  letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

// ─── ACTION BUTTON ────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final bool filled;
  final bool loading;

  const _ActionBtn({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.filled,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: filled && !disabled
              ? const LinearGradient(
            colors: [_C.primary, Color(0xFF9B7BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: filled ? null : _C.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled
                ? Colors.transparent
                : disabled
                ? _C.textMuted.withOpacity(0.25)
                : _C.border,
          ),
          boxShadow: filled && !disabled
              ? const [
            BoxShadow(
                color: _C.primaryGlow,
                blurRadius: 16,
                offset: Offset(0, 4))
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(icon,
                  size: 17,
                  color: filled
                      ? Colors.white
                      : disabled
                      ? _C.textMuted
                      : _C.textPrimary),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                  color: filled
                      ? Colors.white
                      : disabled
                      ? _C.textMuted
                      : _C.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                )),
          ],
        ),
      ),
    );
  }
}