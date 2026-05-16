import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class VoiceControls extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onMuteToggle;
  final VoidCallback onLeave;
  final VoidCallback onRequestMic;

  const VoiceControls({
    super.key,
    required this.isMuted,
    required this.onMuteToggle,
    required this.onLeave,
    required this.onRequestMic,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.xl,
        right: Spacing.xl,
        bottom: MediaQuery.of(context).padding.bottom + Spacing.lg,
      ),
      child: GlassCard(
        borderRadius: Radii.pill,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xl,
          vertical: Spacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ControlButton(
              icon: isMuted ? Icons.mic_off : Icons.mic,
              label: isMuted ? 'Unmute' : 'Mute',
              isActive: !isMuted,
              onTap: onMuteToggle,
              color: isMuted ? colors.surfaceAlt : colors.primary,
              iconColor: isMuted ? colors.textPrimary : Colors.white,
            ),
            _ControlButton(
              icon: Icons.back_hand,
              label: 'Request',
              onTap: onRequestMic,
              color: colors.surfaceAlt,
              iconColor: colors.textPrimary,
            ),
            _ControlButton(
              icon: Icons.exit_to_app,
              label: 'Leave',
              onTap: onLeave,
              color: colors.red.withOpacity(0.15),
              iconColor: colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.iconColor,
    this.isActive = false,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 22),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              widget.label,
              style: textTheme.labelSmall?.copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
