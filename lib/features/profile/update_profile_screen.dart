// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanlink/services/post_service.dart';
import 'package:sanlink/features/games/services/game_service.dart';
import 'package:sanlink/widgets/profile_avatar.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
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
  static const error = Color(0xFFFF5370);
  static const gold = Color(0xFFFFD700);
}

class UpdateProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final void Function(Map<String, dynamic> updatedData)? onProfileUpdated;

  const UpdateProfileScreen({
    super.key,
    required this.userData,
    this.onProfileUpdated,
  });

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen>
    with SingleTickerProviderStateMixin {
  final postService = PostService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _usernameController;
  final _gameService = GameService();

  String? avatarUrl;
  String? selectedFrameUrl;
  List<Map<String, dynamic>> _frames = [];
  int _userLevel = 1;
  bool _loadingFrames = true;
  bool uploadingAvatar = false;
  bool saving = false;

  bool _nameChanged = false;
  bool _bioChanged = false;
  bool _usernameChanged = false;

  late AnimationController _rotateAnim;

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        postService.getFrames(),
        _gameService.getUserLevelInfo(),
      ]);

      if (mounted) {
        setState(() {
          _frames = results[0] as List<Map<String, dynamic>>;
          _userLevel = (results[1] as LevelInfo).level;
          _loadingFrames = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading update data: $e");
      if (mounted) setState(() => _loadingFrames = false);
    }
  }

  @override
  void initState() {
    super.initState();

    debugPrint('🚀 UpdateProfileScreen initialized');

    _rotateAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // ✅ FIXED (profile_pic instead of avatar_url)
    avatarUrl = widget.userData['profile_pic'];
    selectedFrameUrl = widget.userData['profile_frame'];

    _loadData();

    _nameController =
        TextEditingController(text: widget.userData['name'] ?? '');
    _bioController =
        TextEditingController(text: widget.userData['bio'] ?? '');
    _usernameController =
        TextEditingController(text: widget.userData['username'] ?? '');

    _nameController.addListener(() {
      debugPrint('✏️ Name changed: ${_nameController.text}');
      setState(() => _nameChanged = true);
    });

    _bioController.addListener(() {
      debugPrint('✏️ Bio changed (not saved in DB)');
      setState(() => _bioChanged = true);
    });

    _usernameController.addListener(() {
      debugPrint('✏️ Username changed (not saved in DB)');
      setState(() => _usernameChanged = true);
    });
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing UpdateProfileScreen');
    _rotateAnim.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _nameChanged || _bioChanged || _usernameChanged || uploadingAvatar;

  // ─── PICK AVATAR ───────────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    debugPrint('📸 Avatar pick started');

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      debugPrint('⚠️ No image selected');
      return;
    }

    debugPrint('✅ Image selected: ${pickedFile.name}');
    setState(() => uploadingAvatar = true);

    try {
      String? mediaUrl;

      if (kIsWeb) {
        debugPrint('🌐 Uploading (WEB)');
        final bytes = await pickedFile.readAsBytes();
        mediaUrl = await postService.uploadMedia(
          fileBytes: bytes,
          fileName: pickedFile.name,
        );
      } else {
        debugPrint('📱 Uploading (MOBILE)');
        mediaUrl = await postService.uploadMedia(
          filePath: pickedFile.path,
          fileName: pickedFile.name,
        );
      }

      debugPrint('🌍 Uploaded URL: $mediaUrl');

      if (mediaUrl != null) {
        // ✅ update DB column
        final userId = postService.supabase.auth.currentUser!.id;

        await postService.supabase
            .from('users')
            .update({'profile_pic': mediaUrl})
            .eq('id', userId);

        debugPrint('✅ Profile picture updated in users table');

        if (mounted) setState(() => avatarUrl = mediaUrl);
      }
    } catch (e) {
      debugPrint('❌ Avatar upload error: $e');
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
      debugPrint('🔚 Avatar upload finished');
    }
  }

  // ─── SAVE ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    debugPrint('💾 Save started');

    if (!(_formKey.currentState?.validate() ?? false)) {
      debugPrint('⚠️ Validation failed');
      return;
    }

    setState(() => saving = true);

    try {
      final userId = postService.supabase.auth.currentUser!.id;
      debugPrint('👤 User ID: $userId');

      final updates = {
        'name': _nameController.text.trim(),
        if (avatarUrl != null) 'profile_pic': avatarUrl,
        'profile_frame': selectedFrameUrl,
      };

      debugPrint('📝 Updates (DB-safe): $updates');

      await postService.supabase
          .from('users') // ✅ FIXED TABLE
          .update(updates)
          .eq('id', userId);

      debugPrint('✅ Profile updated successfully');

      if (mounted) {
        widget.onProfileUpdated?.call({
          ...widget.userData,
          ...updates,
        });

        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Save error: $e');
    } finally {
      if (mounted) setState(() => saving = false);
      debugPrint('🔚 Save finished');
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 Building UpdateProfileScreen');

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            onPressed: _save,
            icon: saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: ProfileAvatar(
                      avatarUrl: avatarUrl,
                      frameUrl: selectedFrameUrl,
                      size: 130,
                      name: _nameController.text,
                    ),
                  ),
                  if (uploadingAvatar)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: CircularProgressIndicator(color: _C.primary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                "Tap to change avatar",
                style: TextStyle(color: _C.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 30),

            // ── FRAME SELECTION ──
            const Text(
              "AVATAR FRAMES",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: _loadingFrames
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _frames.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "No Frame" option
                    final isActive = selectedFrameUrl == null;
                    return GestureDetector(
                      onTap: () => setState(() => selectedFrameUrl = null),
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: _C.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive ? _C.primary : _C.border,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.block, color: _C.textMuted),
                            const SizedBox(height: 4),
                            Text("None",
                                style: TextStyle(
                                  color: isActive ? _C.primary : _C.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                      ),
                    );
                  }

                  final frame = _frames[index - 1];
                  final frameUrl = frame['image_url'] as String;
                  final minLevel = frame['min_level'] as int;
                  final isLocked = _userLevel < minLevel;
                  final isActive = selectedFrameUrl == frameUrl;

                  return GestureDetector(
                    onTap: isLocked
                        ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Unlocks at Level $minLevel")),
                      );
                    }
                        : () => setState(() => selectedFrameUrl = frameUrl),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive ? _C.primary : _C.border,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: isLocked ? 0.3 : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.network(frameUrl, fit: BoxFit.contain),
                            ),
                          ),
                          if (isLocked)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_rounded, size: 20, color: _C.gold),
                                const SizedBox(height: 4),
                                Text("LVL $minLevel",
                                    style: const TextStyle(
                                      color: _C.gold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    )),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),
            
            const Text(
              "GENERAL INFO",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
              v == null || v.isEmpty ? 'Enter name' : null,
            ),

            // ⚠️ still visible but NOT saved
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),

            // ⚠️ still visible but NOT saved
            TextFormField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}