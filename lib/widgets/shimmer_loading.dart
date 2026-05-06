import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';

/// Shimmer skeleton for a post card in the feed.
class ShimmerPostCard extends StatelessWidget {
  const ShimmerPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User row
            Row(
              children: [
                const _ShimmerCircle(size: 40),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ShimmerBox(width: 120, height: 14),
                    SizedBox(height: 6),
                    _ShimmerBox(width: 80, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content lines
            const _ShimmerBox(width: double.infinity, height: 12),
            const SizedBox(height: 8),
            const _ShimmerBox(width: 200, height: 12),
            const SizedBox(height: 16),
            // Image placeholder
            const _ShimmerBox(width: double.infinity, height: 180, radius: 12),
            const SizedBox(height: 16),
            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _ShimmerBox(width: 60, height: 24, radius: 12),
                _ShimmerBox(width: 60, height: 24, radius: 12),
                _ShimmerBox(width: 60, height: 24, radius: 12),
                _ShimmerBox(width: 60, height: 24, radius: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for a chat list tile.
class ShimmerChatTile extends StatelessWidget {
  const ShimmerChatTile({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const _ShimmerCircle(size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _ShimmerBox(width: 140, height: 14),
                  SizedBox(height: 8),
                  _ShimmerBox(width: 200, height: 11),
                ],
              ),
            ),
            const _ShimmerBox(width: 32, height: 10),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for the profile header.
class ShimmerProfileHeader extends StatelessWidget {
  const ShimmerProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: Column(
        children: [
          const SizedBox(height: 20),
          const _ShimmerCircle(size: 120),
          const SizedBox(height: 20),
          const _ShimmerBox(width: 160, height: 22),
          const SizedBox(height: 10),
          const _ShimmerBox(width: 100, height: 14),
          const SizedBox(height: 24),
          const _ShimmerBox(width: 220, height: 12),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const _ShimmerBox(
              width: double.infinity,
              height: 70,
              radius: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading feed: multiple shimmer post cards
class ShimmerFeedLoading extends StatelessWidget {
  final int count;
  const ShimmerFeedLoading({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => const ShimmerPostCard(),
    );
  }
}

// ─── Primitives ───────────────────────────────────────────────────────────────

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ShimmerCircle extends StatelessWidget {
  final double size;
  const _ShimmerCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
