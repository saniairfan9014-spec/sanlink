import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AudienceUserTile extends StatelessWidget {
  final String userName;
  final String imageUrl;
  final String? subtitle;
  final bool isOnline;
  final VoidCallback? onTap;
  final bool isGridMode;

  const AudienceUserTile({
    super.key,
    required this.userName,
    required this.imageUrl,
    this.subtitle,
    this.isOnline = true,
    this.onTap,
    this.isGridMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    if (isGridMode) {
      return GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(imageUrl),
                ),
                if (isOnline)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.bg, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              userName,
              style: textTheme.labelMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage(imageUrl),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.bg, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        userName,
        style: textTheme.titleSmall?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            )
          : null,
      trailing: Icon(Icons.more_horiz, color: colors.textMuted, size: 20),
    );
  }
}
