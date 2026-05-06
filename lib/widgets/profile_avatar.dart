import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// A polished profile avatar with gradient border ring, frame overlay, and styled fallback.
class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? frameUrl;
  final double size;
  final String? name;
  final bool showOnlineRing;
  final bool isOnline;

  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    this.frameUrl,
    this.size = 50,
    this.name,
    this.showOnlineRing = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial =
        (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '?';
    final avatarSize = size * 0.78;
    final ringWidth = size * 0.04;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gradient ring (always shown subtly, brighter when online)
          if (showOnlineRing)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isOnline
                    ? LinearGradient(
                        colors: [colors.primary, colors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: !isOnline
                    ? Border.all(
                        color: colors.border,
                        width: ringWidth,
                      )
                    : null,
              ),
            ),

          // Avatar
          Container(
            width: showOnlineRing ? avatarSize : size * 0.88,
            height: showOnlineRing ? avatarSize : size * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceAlt,
              border: showOnlineRing
                  ? Border.all(color: colors.bg, width: ringWidth)
                  : null,
              image: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: (avatarUrl == null || avatarUrl!.isEmpty)
                  ? LinearGradient(
                      colors: [
                        colors.primary.withOpacity(0.7),
                        colors.accent.withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: (avatarUrl == null || avatarUrl!.isEmpty)
                ? Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (showOnlineRing ? avatarSize : size * 0.88) * 0.38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                : null,
          ),

          // Frame overlay
          if (frameUrl != null && frameUrl!.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                frameUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),

          // Online indicator dot
          if (showOnlineRing && isOnline)
            Positioned(
              right: size * 0.02,
              bottom: size * 0.02,
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.bg, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: colors.green.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
