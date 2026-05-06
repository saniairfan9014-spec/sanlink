import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

/// A premium gradient button with glow shadow, loading state, and haptic feedback.
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData? icon;
  final double? width;
  final double height;
  final LinearGradient? gradient;
  final double borderRadius;
  final bool outlined;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.icon,
    this.width,
    this.height = 52,
    this.gradient,
    this.borderRadius = 14,
    this.outlined = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disabled = widget.onTap == null || widget.loading;
    final grad = widget.gradient ?? AppGradients.primary;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: widget.outlined ? null : (disabled ? LinearGradient(colors: [colors.surfaceAlt, colors.surfaceAlt]) : grad),
            color: widget.outlined ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.outlined
                ? Border.all(
                    color: disabled ? colors.textMuted.withOpacity(0.3) : colors.border,
                    width: 1.5,
                  )
                : null,
            boxShadow: widget.outlined || disabled
                ? null
                : [
                    BoxShadow(
                      color: colors.primaryGlow,
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: widget.loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: widget.outlined ? colors.primary : Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: widget.outlined
                              ? (disabled ? colors.textMuted : colors.textPrimary)
                              : Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.outlined
                              ? (disabled ? colors.textMuted : colors.textPrimary)
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
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
