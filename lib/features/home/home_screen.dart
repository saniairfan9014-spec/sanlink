import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import '../../services/post_service.dart';
import 'package:sanlink/widgets/postcard.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanlink/features/chat/chat_screen.dart';
import '../games/games_screen.dart';
import '../profile/profile_screen.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class AppColors {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surfaceAlt = Color(0xFF1C1C27);
  static const border = Color(0xFF2A2A3D);
  static const primary = Color(0xFF7C5CFC); // electric violet
  static const primaryGlow = Color(0x557C5CFC);
  static const accent = Color(0xFF00E5FF); // cyan flash
  static const accentGlow = Color(0x3300E5FF);
  static const gold = Color(0xFFFFD700);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF44445A);
}

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
  final TextEditingController controller = TextEditingController();

  List<Map<String, dynamic>> posts = [];
  Map<String, dynamic>? currentUserData;
  bool loading = true;
  int _currentIndex = 0;

  late AnimationController _navGlowController;
  late AnimationController _fabPulseController;
  late Animation<double> _fabPulse;

  @override
  void initState() {
    super.initState();
    fetchPosts();
    fetchCurrentUser();

    _navGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
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

      if (mediaUrl == null) return;

      final isVideo = pickedFile.path.endsWith('.mp4') ||
          pickedFile.path.endsWith('.mov') ||
          pickedFile.path.endsWith('.avi');

      await postService.createPostWithMedia(
        content: controller.text.trim(),
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
        _FeedHeader(),

        // Compose bar
        _ComposeBar(
          userData: currentUserData,
          controller: controller,
          onPost: createPost,
          onMedia: pickMedia,
        ),

        const SizedBox(height: 4),

        // Posts
        Expanded(
          child: loading
              ? const _LoadingFeed()
              : posts.isEmpty
              ? const _EmptyFeed()
              : RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: fetchPosts,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
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
        return const ChatListScreen();
      case 2:
        return const GamesScreen();

      case 3:
      // Pass current user data to ProfileScreen
        final fallbackUser = {
          'id': supabase.auth.currentUser?.id ?? '',
          'name': supabase.auth.currentUser?.email ?? 'Unknown',
        };
        return ProfileScreen(userData: currentUserData ?? fallbackUser);
      default:
        return const SizedBox();
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.accentGlow,
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded,
                color: Colors.white, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Bottom Nav
      bottomNavigationBar: _GamifiedBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i < 4) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = i);
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
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Logo / Brand
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
            ).createShader(bounds),
            child: const Text(
              'SANLINK',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ),

          const Spacer(),

          // XP Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withOpacity(0.4)),
            ),
            child: Row(
              children: const [
                Icon(Icons.bolt, color: AppColors.gold, size: 14),
                SizedBox(width: 4),
                Text(
                  '1,240 XP',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Notification bell
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.textSecondary, size: 18),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
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

// ─── Compose Bar ──────────────────────────────────────────────────────────────
class _ComposeBar extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final TextEditingController controller;
  final VoidCallback onPost;
  final VoidCallback onMedia;

  const _ComposeBar({
    this.userData,
    required this.controller,
    required this.onPost,
    required this.onMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 2),
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
              color: AppColors.surfaceAlt,
              image: userData != null && userData!['avatar_url'] != null
                  ? DecorationImage(
                      image: NetworkImage(userData!['avatar_url']),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: userData == null || userData!['avatar_url'] == null 
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    )
                  : null,
            ),
            child: userData == null || userData!['avatar_url'] == null 
                ? const Icon(Icons.person, color: Colors.white, size: 18)
                : null,
          ),
          const SizedBox(width: 10),

          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: "What's your move today?",
                hintStyle: TextStyle(
                  color: AppColors.textMuted,
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image_outlined,
                  color: AppColors.textSecondary, size: 18),
            ),
          ),
          const SizedBox(width: 6),

          // Send button
          GestureDetector(
            onTap: onPost,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF9B7CFF)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGlow,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
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

  const _AnimatedPostCard({required this.index, required this.postData});

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
      begin: const Offset(0, 0.08),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
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
  const _LoadingFeed();

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
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Loading the arena...',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

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
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.auto_awesome,
                color: AppColors.textMuted, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'No posts yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Be the first to make a move!',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Gamified Bottom Nav ──────────────────────────────────────────────────────
class _GamifiedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GamifiedBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: AppColors.surface,
      elevation: 0,
      notchMargin: 10,
      shape: const CircularNotchedRectangle(),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
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
                onTap: onTap),
            const SizedBox(width: 48), // FAB gap
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
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
          color: AppColors.primaryGlow,
          borderRadius: BorderRadius.circular(14),
        )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color:
              isActive ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w500,
                color:
                isActive ? AppColors.primary : AppColors.textMuted,
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
  const _MediaPickerSheet({required this.picker});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add to Post',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _SheetTile(
            icon: Icons.image_rounded,
            iconColor: AppColors.primary,
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
            iconColor: AppColors.accent,
            title: 'Video from Gallery',
            subtitle: '+100 XP',
            onTap: () async {
              final file =
              await picker.pickVideo(source: ImageSource.gallery);
              Navigator.pop(context, file);
            },
          ),
          const SizedBox(height: 8),
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

  const _SheetTile({
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
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
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

  const _PostSheet({
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
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ).createShader(b),
                    child: const Text(
                      'New Post',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                      Border.all(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: const Text(
                      '+25 XP',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller,
                maxLines: 4,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: "Share your victory, challenge, or story...",
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Media button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onMedia();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.textSecondary, size: 20),
                    ),
                  ),

                  const Spacer(),

                  // Post button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onPost();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF9B7CFF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGlow,
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
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
    );
  }
}