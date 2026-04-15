import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sanlink/services/post_service.dart';

// ─── Design Tokens (matching app theme) ───────────────────────────────────────
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

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _usernameController;

  // State
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
    _rotateAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    avatarUrl = widget.userData['avatar_url'];
    _nameController =
        TextEditingController(text: widget.userData['name']?.toString() ?? '');
    _bioController =
        TextEditingController(text: widget.userData['bio']?.toString() ?? '');
    _usernameController = TextEditingController(
        text: widget.userData['username']?.toString() ?? '');

    _nameController.addListener(
            () => setState(() => _nameChanged = true));
    _bioController
        .addListener(() => setState(() => _bioChanged = true));
    _usernameController
        .addListener(() => setState(() => _usernameChanged = true));
  }

  @override
  void dispose() {
    _rotateAnim.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _nameChanged || _bioChanged || _usernameChanged || uploadingAvatar;

  // ─── Pick & upload avatar ──────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    HapticFeedback.mediumImpact();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
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
        if (mounted) setState(() => avatarUrl = mediaUrl);
      }
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) {
        _showSnack('Failed to upload photo. Try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  // ─── Save changes ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    setState(() => saving = true);

    try {
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'username': _usernameController.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      await postService.supabase
          .from('profiles')
          .update(updates)
          .eq('id', postService.supabase.auth.currentUser!.id);

      if (mounted) {
        widget.onProfileUpdated?.call({
          ...widget.userData,
          ...updates,
        });
        _showSnack('Profile updated successfully!');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save profile error: $e');
      if (mounted) {
        _showSnack('Failed to save. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _C.error : _C.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Confirm discard dialog ────────────────────────────────────────────────
  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _C.border),
        ),
        title: const Text('Discard changes?',
            style: TextStyle(color: _C.textPrimary, fontSize: 17)),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
          style: TextStyle(color: _C.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing',
                style: TextStyle(color: _C.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard',
                style: TextStyle(color: _C.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : widget.userData['name']?.toString() ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canLeave = await _confirmDiscard();
        if (canLeave && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.surface,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _C.textPrimary, size: 18),
            onPressed: () async {
              final canLeave = await _confirmDiscard();
              if (canLeave && context.mounted) Navigator.pop(context);
            },
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: _C.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _SaveButton(loading: saving, onTap: _save),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: _C.border),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 60),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar section ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  color: _C.surface,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: uploadingAvatar ? null : _pickAvatar,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Rotating gradient ring
                            RotationTransition(
                              turns: _rotateAnim,
                              child: Container(
                                width: 112,
                                height: 112,
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
                                      blurRadius: 24,
                                      spreadRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Dark ring
                            Container(
                              width: 102,
                              height: 102,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _C.bg,
                              ),
                            ),
                            // Avatar
                            Container(
                              width: 94,
                              height: 94,
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
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                                  : null,
                            ),
                            // Upload spinner or camera overlay
                            if (uploadingAvatar)
                              Container(
                                width: 94,
                                height: 94,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: _C.primary,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            else
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _C.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _C.bg, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: uploadingAvatar ? null : _pickAvatar,
                        child: const Text(
                          'Change Profile Photo',
                          style: TextStyle(
                            color: _C.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 0.5, color: _C.border),

                const SizedBox(height: 24),

                // ── Form fields ────────────────────────────────────────────
                _SectionLabel('BASIC INFO'),

                _ProfileField(
                  controller: _nameController,
                  label: 'Display Name',
                  hint: 'Your full name',
                  icon: Icons.person_outline_rounded,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name cannot be empty';
                    }
                    if (v.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                _ProfileField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: '@username',
                  icon: Icons.alternate_email_rounded,
                  prefixText: '@',
                  keyboardType: TextInputType.visiblePassword,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9_\.]')),
                    LengthLimitingTextInputFormatter(30),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Username cannot be empty';
                    }
                    if (v.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(v.trim())) {
                      return 'Only letters, numbers, _ and . allowed';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),
                _SectionLabel('ABOUT'),

                _ProfileField(
                  controller: _bioController,
                  label: 'Bio',
                  hint: 'Tell people about yourself…',
                  icon: Icons.notes_rounded,
                  maxLines: 4,
                  maxLength: 150,
                  validator: (v) {
                    if (v != null && v.length > 150) {
                      return 'Bio must be 150 characters or less';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // ── Save button (bottom) ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: saving ? null : _save,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding:
                        const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_C.primary, Color(0xFF9B7CFF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x557C5CFC),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: saving
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Discard button ─────────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final canLeave = await _confirmDiscard();
                      if (canLeave && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'Discard Changes',
                      style: TextStyle(
                        color: _C.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: _C.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Profile Field ─────────────────────────────────────────────────────────────
class _ProfileField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  State<_ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<_ProfileField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Icon(widget.icon, size: 13, color: _C.textMuted),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: _C.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Field
          Focus(
            onFocusChange: (f) => setState(() => _focused = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _C.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _focused ? _C.primary : _C.border,
                  width: _focused ? 1.5 : 0.5,
                ),
                boxShadow: _focused
                    ? const [
                  BoxShadow(
                    color: _C.primaryGlow,
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
                    : null,
              ),
              child: TextFormField(
                controller: widget.controller,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                validator: widget.validator,
                style: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(
                    color: _C.textMuted,
                    fontSize: 14,
                  ),
                  prefixText: widget.prefixText,
                  prefixStyle: const TextStyle(
                    color: _C.textSecondary,
                    fontSize: 15,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: widget.maxLines > 1 ? 14 : 13,
                  ),
                  border: InputBorder.none,
                  counterStyle: const TextStyle(
                    color: _C.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AppBar Save Button ────────────────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SaveButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : const LinearGradient(
            colors: [_C.primary, Color(0xFF9B7CFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          color: loading ? _C.surfaceAlt : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: loading
              ? null
              : const [
            BoxShadow(
              color: Color(0x447C5CFC),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: loading
            ? const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              color: _C.primary, strokeWidth: 2),
        )
            : const Text(
          'Save',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}