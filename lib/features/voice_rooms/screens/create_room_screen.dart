import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/themed_text_field.dart';
import '../../../widgets/gradient_button.dart';
import '../data/repositories/voice_room_repository.dart';
import 'voice_room_screen.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedCategory = 'Casual';
  final List<String> _categories = [
    'Casual',
    'Gaming',
    'Music',
    'Tech Talk',
    'Language Learning',
    'Crypto'
  ];

  bool _isLoading = false;

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final channelName = 'room_${DateTime.now().millisecondsSinceEpoch}';
      final repository = ref.read(voiceRoomRepositoryProvider);

      final room = await repository.createRoom(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        category: _selectedCategory,
        hostId: user.id,
        channelName: channelName,
      );

      if (mounted) {
        Navigator.pop(context); // Close create screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoiceRoomScreen(
              roomId: room.id,
              channelName: room.channelName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating room: $e', style: TextStyle(color: Colors.white)),
            backgroundColor: context.colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          'Start a Room',
          style: textTheme.titleLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.xl),
          children: [
            // Title Input
            Text(
              'ROOM TITLE',
              style: textTheme.labelSmall?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: Spacing.xs),
            ThemedTextField(
              controller: _titleController,
              hintText: 'What do you want to talk about?',
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: Spacing.xl),

            // Description Input
            Text(
              'DESCRIPTION (OPTIONAL)',
              style: textTheme.labelSmall?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: Spacing.xs),
            ThemedTextField(
              controller: _descriptionController,
              hintText: 'Add some details...',
              maxLines: 3,
            ),
            const SizedBox(height: Spacing.xl),

            // Category Selection
            Text(
              'CATEGORY',
              style: textTheme.labelSmall?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: Spacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: colors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: colors.surface,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                  style: textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: Spacing.xxxl),

            // Submit Button
            GradientButton(
              label: 'Create Room',
              icon: Icons.rocket_launch,
              loading: _isLoading,
              onTap: _createRoom,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
