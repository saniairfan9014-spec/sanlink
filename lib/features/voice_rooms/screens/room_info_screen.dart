import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';

class RoomInfoScreen extends StatelessWidget {
  const RoomInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    // Dummy data
    final speakers = [
      {'name': 'Alex Rivers', 'image': 'https://i.pravatar.cc/150?u=1'},
      {'name': 'Sarah Jenks', 'image': 'https://i.pravatar.cc/150?u=2'},
      {'name': 'Crypto Mike', 'image': 'https://i.pravatar.cc/150?u=3'},
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: CustomScrollView(
        slivers: [
          // Room Cover Image with AppBar
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: colors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1614680376593-902f74a61327?q=80&w=1000',
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
                  // Title and Category
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
                          'Music & Chill',
                          style: textTheme.labelSmall?.copyWith(color: colors.primary),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.calendar_today, size: 14, color: colors.textMuted),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        'Created 2 hrs ago',
                        style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Late Night Chill & Lofi 🎵',
                    style: textTheme.displaySmall?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),

                  // Host Info
                  Text(
                    'HOSTED BY',
                    style: textTheme.labelSmall?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: Spacing.sm),
                  GlassCard(
                    padding: const EdgeInsets.all(Spacing.sm),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=1'),
                      ),
                      title: Text(
                        'Alex Rivers',
                        style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
                      ),
                      subtitle: Text(
                        '@alex_r',
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.person_add, color: colors.primary),
                        onPressed: () {},
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(
                        icon: Icons.headset,
                        count: '124',
                        label: 'Listening',
                      ),
                      Container(width: 1, height: 40, color: colors.border),
                      _StatColumn(
                        icon: Icons.mic,
                        count: '3',
                        label: 'Speaking',
                      ),
                      Container(width: 1, height: 40, color: colors.border),
                      _StatColumn(
                        icon: Icons.share,
                        count: '12',
                        label: 'Shares',
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Speakers List
                  Text(
                    'CURRENT SPEAKERS',
                    style: textTheme.labelSmall?.copyWith(color: colors.textMuted),
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
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage: NetworkImage(speaker['image']!),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              speaker['name']!.split(' ')[0], // First name only
                              style: textTheme.labelMedium?.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),

                  // Rules
                  Text(
                    'ROOM RULES',
                    style: textTheme.labelSmall?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: Spacing.sm),
                  GlassCard(
                    padding: const EdgeInsets.all(Spacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _RuleItem(text: 'Be respectful to everyone.'),
                        const SizedBox(height: Spacing.xs),
                        const _RuleItem(text: 'No spamming the chat or mic requests.'),
                        const SizedBox(height: Spacing.xs),
                        const _RuleItem(text: 'Keep topics relevant to Music & Chill.'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: Spacing.xxxl),
                  
                  // Leave Button
                  GradientButton(
                    label: 'Leave Room',
                    icon: Icons.exit_to_app,
                    width: double.infinity,
                    gradient: LinearGradient(
                      colors: [colors.red.withOpacity(0.8), colors.red],
                    ),
                    onTap: () {
                      Navigator.pop(context);
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
          children: [
            Icon(icon, color: colors.primary, size: 20),
            const SizedBox(width: Spacing.xs),
            Text(
              count,
              style: textTheme.titleLarge?.copyWith(color: colors.textPrimary),
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

  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 18, color: context.colors.green),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
