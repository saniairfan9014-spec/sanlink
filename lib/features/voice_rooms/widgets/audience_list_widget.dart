import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'audience_user_tile.dart';

class AudienceListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isGridMode;
  final ScrollPhysics? physics;
  final ValueChanged<Map<String, dynamic>>? onUserTap;

  const AudienceListWidget({
    super.key,
    required this.users,
    this.isGridMode = false,
    this.physics = const BouncingScrollPhysics(),
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Text(
            'No audience members yet',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ),
      );
    }

    if (isGridMode) {
      return GridView.builder(
        shrinkWrap: true,
        physics: physics ?? const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.base, vertical: Spacing.sm),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          crossAxisSpacing: Spacing.md,
          mainAxisSpacing: Spacing.lg,
        ),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return AudienceUserTile(
            userName: user['name'],
            imageUrl: user['image'],
            isOnline: user['isOnline'] ?? true,
            isGridMode: true,
            onTap: () {
              if (onUserTap != null) onUserTap!(user);
            },
          );
        },
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return AudienceUserTile(
          userName: user['name'],
          imageUrl: user['image'],
          subtitle: user['role'] ?? 'Listener',
          isOnline: user['isOnline'] ?? true,
          isGridMode: false,
          onTap: () {
            if (onUserTap != null) onUserTap!(user);
          },
        );
      },
    );
  }
}
