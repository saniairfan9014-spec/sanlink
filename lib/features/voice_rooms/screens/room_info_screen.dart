import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/themed_text_field.dart';
import '../controllers/voice_room_controller.dart';
import '../data/models/room_member_model.dart';
import '../data/models/room_model.dart';
import 'voice_room_screen.dart';

class RoomInfoScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const RoomInfoScreen({super.key, this.roomId});

  @override
  ConsumerState<RoomInfoScreen> createState() => _RoomInfoScreenState();
}

class _RoomInfoScreenState extends ConsumerState<RoomInfoScreen> {
  String get _currentUserId => Supabase.instance.client.auth.currentUser?.id ?? '';

  String _getCategoryCover(String category) {
    switch (category.toLowerCase()) {
      case 'music & chill':
      case 'music':
        return 'https://images.unsplash.com/photo-1614680376593-902f74a61327?q=80&w=1000';
      case 'gaming':
        return 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?q=80&w=1000';
      case 'chat':
      case 'social':
        return 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?q=80&w=1000';
      case 'tech':
      case 'education':
        return 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=1000';
      default:
        return 'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?q=80&w=1000';
    }
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().toUtc().difference(dateTime.toUtc());
    if (difference.inDays >= 1) return '${difference.inDays} days ago';
    if (difference.inHours >= 1) return '${difference.inHours} hrs ago';
    if (difference.inMinutes >= 1) return '${difference.inMinutes} mins ago';
    return 'Just now';
  }

  void _showEditRoomDialog(BuildContext context, RoomModel room, AppColorsExtension colors, TextTheme textTheme) {
    final titleController = TextEditingController(text: room.title);
    final descController = TextEditingController(text: room.description ?? '');
    String selectedCategory = room.category;
    final categories = ['Music & Chill', 'Gaming', 'Chat', 'Tech', 'Social', 'Education'];

    if (!categories.contains(selectedCategory)) {
      categories.add(selectedCategory);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.lg),
                side: BorderSide(color: colors.border),
              ),
              title: Text(
                'Edit Room Info',
                style: textTheme.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Title', style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: Spacing.xs),
                    ThemedTextField(
                      controller: titleController,
                      hintText: 'Enter room title...',
                    ),
                    const SizedBox(height: Spacing.md),
                    Text('Description', style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: Spacing.xs),
                    ThemedTextField(
                      controller: descController,
                      hintText: 'Enter room description...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: Spacing.md),
                    Text('Category', style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                    const SizedBox(height: Spacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: colors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          dropdownColor: colors.surface,
                          isExpanded: true,
                          style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCategory = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
                ),
                GradientButton(
                  label: 'Save Changes',
                  onTap: () {
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      ref.read(voiceRoomControllerProvider.notifier).updateRoomInfo(
                        room.id,
                        title,
                        descController.text.trim(),
                        selectedCategory,
                      );
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final state = ref.watch(voiceRoomControllerProvider);
    final room = state.room;

    // Loading / Error states
    if (state.isLoading || room == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final members = state.members;
    final hostProfile = state.userProfiles[room.hostId];
    
    // Role calculations
    final currentMember = members.firstWhereOrNull((m) => m.userId == _currentUserId);
    final isHost = room.hostId == _currentUserId;
    final isMember = currentMember != null && !isHost;
    final isGuest = currentMember == null && !isHost;

    // Active Speakers and Audience Lists
    final speakers = members.where((m) => m.role == RoomRole.host || m.role == RoomRole.speaker || m.micSeat != null).toList();
    final audience = members.where((m) => m.role == RoomRole.listener).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: CustomScrollView(
        slivers: [
          // Dynamic Room Cover Image with AppBar & Edit Actions
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: colors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (isHost)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  tooltip: 'Edit Room Details',
                  onPressed: () => _showEditRoomDialog(context, room, colors, textTheme),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _getCategoryCover(room.category),
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          colors.bg.withOpacity(0.8),
                          colors.bg,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Category tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(Radii.pill),
                          border: Border.all(color: colors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          room.category,
                          style: textTheme.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.calendar_today, size: 14, color: colors.textMuted),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        _timeAgo(room.createdAt),
                        style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    room.title,
                    style: textTheme.displaySmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (room.description != null && room.description!.isNotEmpty) ...[
                    const SizedBox(height: Spacing.sm),
                    Text(
                      room.description!,
                      style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: Spacing.lg),

                  // Host Info Section
                  Text(
                    'HOSTED BY',
                    style: textTheme.labelSmall?.copyWith(color: colors.textMuted, letterSpacing: 1),
                  ),
                  const SizedBox(height: Spacing.sm),
                  GlassCard(
                    padding: const EdgeInsets.all(Spacing.sm),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: colors.surfaceAlt,
                        backgroundImage: hostProfile != null && (hostProfile['profile_pic'] != null || hostProfile['avatar_url'] != null)
                            ? NetworkImage(hostProfile['profile_pic'] ?? hostProfile['avatar_url'])
                            : null,
                        child: hostProfile == null || (hostProfile['profile_pic'] == null && hostProfile['avatar_url'] == null)
                            ? Text(
                                (hostProfile?['name'] ?? 'H').isNotEmpty ? (hostProfile?['name'] ?? 'H')[0].toUpperCase() : 'H',
                                style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
                              )
                            : null,
                      ),
                      title: Text(
                        hostProfile?['name'] ?? 'Host loading...',
                        style: textTheme.titleMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '@${hostProfile?['name']?.toString().toLowerCase().replaceAll(' ', '_') ?? 'host'}',
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Dynamic Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(
                        icon: Icons.headset,
                        count: '${audience.length}',
                        label: 'Listening',
                      ),
                      Container(width: 1, height: 40, color: colors.border),
                      _StatColumn(
                        icon: Icons.mic,
                        count: '${speakers.length}',
                        label: 'Speaking',
                      ),
                      Container(width: 1, height: 40, color: colors.border),
                      _StatColumn(
                        icon: Icons.shield_outlined,
                        count: isHost ? 'Host' : (isMember ? 'Member' : 'Guest'),
                        label: 'Your Status',
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Speakers List
                  if (speakers.isNotEmpty) ...[
                    Text(
                      'CURRENT SPEAKERS',
                      style: textTheme.labelSmall?.copyWith(color: colors.textMuted, letterSpacing: 1),
                    ),
                    const SizedBox(height: Spacing.sm),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: speakers.length,
                        separatorBuilder: (context, index) => const SizedBox(width: Spacing.md),
                        itemBuilder: (context, index) {
                          final speaker = speakers[index];
                          final profile = state.userProfiles[speaker.userId];
                          final name = profile?['name'] ?? speaker.userName ?? 'User';
                          final avatarUrl = profile?['profile_pic'] ?? profile?['avatar_url'] ?? speaker.avatarUrl;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: colors.surfaceAlt,
                                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                name.split(' ')[0], // First name only
                                style: textTheme.labelMedium?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                  ],

                  // Room Rules Section
                  Text(
                    'ROOM RULES',
                    style: textTheme.labelSmall?.copyWith(color: colors.textMuted, letterSpacing: 1),
                  ),
                  const SizedBox(height: Spacing.sm),
                  GlassCard(
                    padding: const EdgeInsets.all(Spacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RuleItem(text: 'Be respectful to speakers and audience.', colors: colors),
                        const SizedBox(height: Spacing.xs),
                        _RuleItem(text: 'Keep comments on topic for this ${room.category} session.', colors: colors),
                        const SizedBox(height: Spacing.xs),
                        _RuleItem(text: 'Have fun and follow community guidelines!', colors: colors),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: Spacing.xxxl),
                  
                  // Action buttons matching User Status
                  if (isGuest)
                    GradientButton(
                      label: 'Join Room',
                      icon: Icons.login_rounded,
                      width: double.infinity,
                      onTap: () {
                        // Transitions guest into VoiceRoom Screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VoiceRoomScreen(
                              roomId: room.id,
                              channelName: room.channelName,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    GradientButton(
                      label: 'Leave Room',
                      icon: Icons.exit_to_app_rounded,
                      width: double.infinity,
                      gradient: LinearGradient(
                        colors: [colors.red.withOpacity(0.85), colors.red],
                      ),
                      onTap: () {
                        ref.read(voiceRoomControllerProvider.notifier).leaveRoom(room.id, _currentUserId);
                        Navigator.pop(context); // Pops RoomInfoScreen
                        Navigator.pop(context); // Pops VoiceRoomScreen
                      },
                    ),
                  const SizedBox(height: Spacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String count;
  final String label;

  const _StatColumn({
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.primary, size: 20),
            const SizedBox(width: Spacing.xs),
            Text(
              count,
              style: textTheme.titleMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;
  final AppColorsExtension colors;

  const _RuleItem({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 18, color: colors.green),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
