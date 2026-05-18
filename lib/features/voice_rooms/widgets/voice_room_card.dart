import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class VoiceRoomCard extends StatelessWidget {
  final String title;
  final String hostName;
  final String hostImage;
  final int listenerCount;
  final int speakerCount;
  final String? roomImage;
  final VoidCallback onTap;

  const VoiceRoomCard({
    super.key,
    required this.title,
    required this.hostName,
    required this.hostImage,
    required this.listenerCount,
    required this.speakerCount,
    this.roomImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(Spacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room Cover Image DP Thumbnail
                Container(
                  width: 52,
                  height: 52,
                  margin: const EdgeInsets.only(right: Spacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: colors.border),
                    image: DecorationImage(
                      image: NetworkImage(
                        roomImage != null && roomImage!.isNotEmpty
                            ? roomImage!
                            : 'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?q=80&w=200',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: textTheme.titleMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sm,
                              vertical: Spacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(Radii.sm),
                              border: Border.all(color: colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: Spacing.xs),
                                Text(
                                  'LIVE',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.sm),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: NetworkImage(hostImage),
                          ),
                          const SizedBox(width: Spacing.xs),
                          Expanded(
                            child: Text(
                              'Hosted by $hostName',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.headset,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      '$listenerCount',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Icon(
                      Icons.mic,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      '$speakerCount',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: colors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
