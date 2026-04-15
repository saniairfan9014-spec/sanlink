// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanlink/services/post_service.dart';

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

  String? avatarUrl;
  bool uploadingAvatar = false;
  bool saving = false;

  bool _nameChanged = false;
  bool _bioChanged = false;
  bool _usernameChanged = false;

  late AnimationController _rotateAnim;

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
                ? const CircularProgressIndicator()
                : const Icon(Icons.check),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 20),

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