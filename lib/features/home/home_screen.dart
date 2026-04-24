import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import '../../services/post_service.dart';
import 'package:sanlink/widgets/postcard.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanlink/features/chat/screens/chat_list_screen.dart';
import '../games/games_screen.dart';
import '../profile/profile_screen.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sanlink/features/home/notifications_screen.dart';
import 'package:sanlink/features/games/services/game_service.dart';
import 'package:sanlink/features/chat/services/chat_service.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────


// ─── HomeScreen ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final supabase = SupabaseService().client;
  final postService = PostService();
  final chatService = ChatService();
  final gameService = GameService();
  final TextEditingController controller = TextEditingController();

  List<Map<String, dynamic>> posts = [];
  Map<String, dynamic>? currentUserData;
  LevelInfo? _levelInfo;
  bool loading = true;
  int _currentIndex = 0;
  int _totalUnreadCount = 0;
  Timer? _unreadTimer;

  late AnimationController _navGlowController;
  late AnimationController _fabPulseController;
  late Animation<double> _fabPulse;

  @override
  void initState() {
    super.initState();
    fetchPosts();
    fetchCurrentUser();
    _fetchUnreadCount();
    _fetchUserLevel();

    // Refresh unread count every 15 seconds
    _unreadTimer = Timer.periodic(Duration(seconds: 15), (_) {
      _fetchUnreadCount();
    });

    _navGlowController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _fabPulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _fabPulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _fabPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _navGlowController.dispose();
    _fabPulseController.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> fetchPosts() async {
    setState(() => loading = true);
    try {
      posts = await postService.getPosts();
    } catch (e) {
      debugPrint("Error fetching posts: $e");
    }
    setState(() => loading = false);
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final count = await chatService.getTotalUnreadCount();
      if (mounted) setState(() => _totalUnreadCount = count);
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  Future<void> _fetchUserLevel() async {
    try {
      final level = await gameService.getUserLevelInfo();
      if (mounted) setState(() => _levelInfo = level);
    } catch (e) {
      debugPrint('Error fetching user level: $e');
    }
  }

  Future<void> fetchCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await supabase.from('users').select().eq('id', user.id).maybeSingle();
      if (res != null) {
        if (mounted) setState(() => currentUserData = res);
      }
    } catch (e) {
      debugPrint("Error fetching current user: $e");
    }
  }

  Future<void> createPost() async {
    if (controller.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    await postService.createPost(controller.text.trim());
    controller.clear();
    await fetchPosts();
  }

  Future<void> pickMedia() async {
    HapticFeedback.mediumImpact();
    final picker = ImagePicker();

    final pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaPickerSheet(picker: picker),
    );

    if (pickedFile == null) return;

    final fileName = pickedFile.name.toLowerCase();
    final isVideo = fileName.endsWith('.mp4') ||
        fileName.endsWith('.mov') ||
        fileName.endsWith('.avi') ||
        fileName.endsWith('.webm') ||
        fileName.endsWith('.mkv');

    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaPreviewSheet(
        filePath: pickedFile.path,
        isVideo: isVideo,
        initialCaption: controller.text.trim(),
      ),
    );

    if (result == null) return; // User cancelled

    final caption = result['caption'] as String? ?? '';

    try {
      final contentType = isVideo ? 'video/mp4' : 'image/jpeg';

      String? mediaUrl;
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        mediaUrl = await postService.uploadMedia(
          fileBytes: bytes,
          fileName: pickedFile.name,
          contentType: contentType,
        );
      } else {
        mediaUrl = await postService.uploadMedia(
          filePath: pickedFile.path,
          fileName: pickedFile.name,
          contentType: contentType,
        );
      }

      if (mediaUrl == null) return;

      await postService.createPostWithMedia(
        content: caption,
        mediaUrl: mediaUrl,
        mediaType: isVideo ? 'video' : 'image',
      );

      controller.clear();
      await fetchPosts();
    } catch (e) {
      debugPrint("Media upload error: $e");
    }
  }

  // ─── Feed ──────────────────────────────────────────────────────────────────
  Widget _buildFeedScreen() {
    return Column(
      children: [
        // Header
        _FeedHeader(
          xpText: _levelInfo != null ? '${_levelInfo!.currentXp} XP' : '...',
          onNotification: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsScreen()),
            );
          },
        ),

        // Compose bar
        _ComposeBar(
          userData: currentUserData,
          controller: controller,
          onPost: createPost,
          onMedia: pickMedia,
        ),

        SizedBox(height: 4),

        // Posts
        Expanded(
          child: loading
              ? _LoadingFeed()
              : posts.isEmpty
              ? _EmptyFeed()
              : RefreshIndicator(
            color: context.colors.primary,
            backgroundColor: context.colors.surface,
            onRefresh: fetchPosts,
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 100),
              itemCount: posts.length,
              itemBuilder: (context, index) => _AnimatedPostCard(
                index: index,
                postData: posts[index],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return _buildFeedScreen();
      case 1:
        return ChatListScreen();
      case 2:
        return GamesScreen();

      case 3:
      // Pass current user data to ProfileScreen
        final fallbackUser = {
          'id': supabase.auth.currentUser?.id ?? '',
          'name': supabase.auth.currentUser?.email ?? 'Unknown',
        };
        return ProfileScreen(userData: currentUserData ?? fallbackUser);
      default:
        return SizedBox();
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(4, (i) => _getScreen(i)),
      ),

      // Floating "+" post button
      floatingActionButton: ScaleTransition(
        scale: _fabPulse,
        child: GestureDetector(
          onTap: () => _showPostSheet(context),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [context.colors.primary, context.colors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.primaryGlow,
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: context.colors.accentGlow,
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(Icons.add_rounded,
                color: Colors.white, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom Nav
      bottomNavigationBar: _GamifiedBottomNav(
        currentIndex: _currentIndex,
        chatUnreadCount: _totalUnreadCount,
        onTap: (i) {
          if (i < 4) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = i);
            if (i != 1) _fetchUnreadCount();
          }
        },
      ),
    );
  }

  void _showPostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostSheet(
        controller: controller,
        onPost: createPost,
        onMedia: pickMedia,
      ),
    );
  }
}

// ─── Feed Header ──────────────────────────────────────────────────────────────
class _FeedHeader extends StatelessWidget {
  final String xpText;
  final VoidCallback onNotification;

  const _FeedHeader({
    required this.xpText,
    required this.onNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: context.colors.bg,
        border: Border(
          bottom: BorderSide(color: context.colors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Logo / Brand
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [context.colors.primary, context.colors.accent],
            ).createShader(bounds),
            child: Text(
              'SANLINK',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ),

          Spacer(),

          // XP Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.gold.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, color: context.colors.gold, size: 14),
                SizedBox(width: 4),
                Text(
                  xpText,
                  style: TextStyle(
                    color: context.colors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 10),

          // Notification bell
          GestureDetector(
            onTap: onNotification,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.border),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_outlined,
                      color: context.colors.textSecondary, size: 18),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: context.colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Compose Bar ──────────────────────────────────────────────────────────────
class _ComposeBar extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final TextEditingController controller;
  final VoidCallback onPost;
  final VoidCallback onMedia;

  _ComposeBar({
    this.userData,
    required this.controller,
    required this.onPost,
    required this.onMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.primaryGlow.withOpacity(0.15),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar placeholder
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.surfaceAlt,
              image: userData != null && userData!['avatar_url'] != null
                  ? DecorationImage(
                      image: NetworkImage(userData!['avatar_url']),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: userData == null || userData!['avatar_url'] == null 
                  ? LinearGradient(
                      colors: [context.colors.primary, context.colors.accent],
                    )
                  : null,
            ),
            child: userData == null || userData!['avatar_url'] == null 
                ? Icon(Icons.person, color: Colors.white, size: 18)
                : null,
          ),
          SizedBox(width: 10),

          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: "What's your move today?",
                hintStyle: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),

          // Media button
          GestureDetector(
            onTap: onMedia,
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.image_outlined,
                  color: context.colors.textSecondary, size: 18),
            ),
          ),
          SizedBox(width: 6),

          // Send button
          GestureDetector(
            onTap: onPost,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.colors.primary, Color(0xFF9B7CFF)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primaryGlow,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(Icons.send_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Post Card Wrapper ───────────────────────────────────────────────
class _AnimatedPostCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> postData;

  _AnimatedPostCard({required this.index, required this.postData});

  @override
  State<_AnimatedPostCard> createState() => _AnimatedPostCardState();
}

class _AnimatedPostCardState extends State<_AnimatedPostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.index * 60),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: PostCard(postData: widget.postData),
          ),
        ),
      ),
    );
  }
}

// ─── Loading State ────────────────────────────────────────────────────────────
class _LoadingFeed extends StatelessWidget {
  _LoadingFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Loading the arena...',
            style: TextStyle(color: context.colors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyFeed extends StatelessWidget {
  _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(Icons.auto_awesome,
                color: context.colors.textMuted, size: 32),
          ),
          SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Be the first to make a move!',
            style: TextStyle(color: context.colors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Gamified Bottom Nav ──────────────────────────────────────────────────────
class _GamifiedBottomNav extends StatelessWidget {
  final int currentIndex;
  final int chatUnreadCount;
  final ValueChanged<int> onTap;

  _GamifiedBottomNav({
    required this.currentIndex,
    required this.chatUnreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: context.colors.surface,
      elevation: 0,
      notchMargin: 10,
      shape: CircularNotchedRectangle(),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap),
            _NavItem(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                index: 1,
                currentIndex: currentIndex,
                badgeCount: chatUnreadCount,
                onTap: onTap),
            SizedBox(width: 48), // FAB gap
            _NavItem(
                icon: Icons.sports_esports_rounded,
                label: 'Games',
                index: 2,
                currentIndex: currentIndex,
                onTap: onTap),
            _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final int badgeCount;
  final ValueChanged<int> onTap;

  _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
          color: context.colors.primaryGlow,
          borderRadius: BorderRadius.circular(14),
        )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color:
                  isActive ? context.colors.primary : context.colors.textMuted,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.colors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : badgeCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w500,
                color:
                isActive ? context.colors.primary : context.colors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Media Picker Sheet ───────────────────────────────────────────────────────
class _MediaPickerSheet extends StatelessWidget {
  final ImagePicker picker;
  _MediaPickerSheet({required this.picker});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Add to Post',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          _SheetTile(
            icon: Icons.image_rounded,
            iconColor: context.colors.primary,
            title: 'Photo from Gallery',
            subtitle: '+50 XP',
            onTap: () async {
              final file =
              await picker.pickImage(source: ImageSource.gallery);
              Navigator.pop(context, file);
            },
          ),
          _SheetTile(
            icon: Icons.videocam_rounded,
            iconColor: context.colors.accent,
            title: 'Video from Gallery',
            subtitle: '+100 XP',
            onTap: () async {
              final file =
              await picker.pickVideo(source: ImageSource.gallery);
              Navigator.pop(context, file);
            },
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _SheetTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
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
        style: TextStyle(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.gold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.gold.withOpacity(0.3)),
        ),
        child: Text(
          subtitle,
          style: TextStyle(
            color: context.colors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Media Preview + Caption Sheet ────────────────────────────────────────────
class _MediaPreviewSheet extends StatefulWidget {
  final String filePath;
  final bool isVideo;
  final String initialCaption;

  const _MediaPreviewSheet({
    required this.filePath,
    required this.isVideo,
    this.initialCaption = '',
  });

  @override
  State<_MediaPreviewSheet> createState() => _MediaPreviewSheetState();
}

class _MediaPreviewSheetState extends State<_MediaPreviewSheet> {
  late TextEditingController _captionController;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndPost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.colors.border),
        ),
        title: ShaderMask(
          shaderCallback: (b) => LinearGradient(
            colors: [context.colors.primary, context.colors.accent],
          ).createShader(b),
          child: Text(
            'Confirm Post',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ),
        content: Text(
          'Are you sure you want to publish this post?',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: context.colors.textMuted)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.colors.primary, Color(0xFF9B7CFF)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primaryGlow,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                'Post It!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isPosting = true);
      Navigator.pop(context, {'caption': _captionController.text.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: context.colors.primaryGlow.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12),
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title row
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => LinearGradient(
                        colors: [context.colors.primary, context.colors.accent],
                      ).createShader(b),
                      child: Text(
                        widget.isVideo ? '🎬 Video Post' : '📸 Photo Post',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.colors.gold.withOpacity(0.3)),
                      ),
                      child: Text(
                        widget.isVideo ? '+100 XP' : '+50 XP',
                        style: TextStyle(
                          color: context.colors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Media preview
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: widget.isVideo
                      ? Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_rounded, color: context.colors.accent, size: 48),
                              SizedBox(height: 8),
                              Text('Video Selected', style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        )
                      : Container(
                          constraints: BoxConstraints(maxHeight: 220),
                          width: double.infinity,
                          child: Image.file(
                            File(widget.filePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 160,
                              color: context.colors.surfaceAlt,
                              child: Center(
                                child: Icon(Icons.image_rounded, color: context.colors.primary, size: 48),
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              SizedBox(height: 12),

              // Caption field
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _captionController,
                  maxLines: 3,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add a caption...',
                    hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 15),
                    filled: true,
                    fillColor: context.colors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.colors.primary),
                    ),
                  ),
                ),
              ),

              // Action buttons
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Cancel button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    Spacer(),

                    // Post button
                    GestureDetector(
                      onTap: _isPosting ? null : _confirmAndPost,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [context.colors.primary, Color(0xFF9B7CFF)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.primaryGlow,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isPosting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.send_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Post',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Full Post Sheet ──────────────────────────────────────────────────────────
class _PostSheet extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onPost;
  final VoidCallback onMedia;

  _PostSheet({
    required this.controller,
    required this.onPost,
    required this.onMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: context.colors.primaryGlow.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => LinearGradient(
                        colors: [context.colors.primary, context.colors.accent],
                      ).createShader(b),
                      child: Text(
                        'New Post',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                        Border.all(color: context.colors.gold.withOpacity(0.3)),
                      ),
                      child: Text(
                        '+25 XP',
                        style: TextStyle(
                          color: context.colors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: "Share your victory, challenge, or story...",
                    hintStyle: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: context.colors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.colors.primary),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Media button
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onMedia();
                      },
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Icon(Icons.image_outlined,
                            color: context.colors.textSecondary, size: 20),
                      ),
                    ),

                    Spacer(),

                    // Post button
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onPost();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [context.colors.primary, Color(0xFF9B7CFF)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.primaryGlow,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Post It',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}