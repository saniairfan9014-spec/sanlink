import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class MicSeatWidget extends StatefulWidget {
  final int seatIndex;
  final String? userName;
  final String? imageUrl;
  final bool isSpeaking;
  final bool isMuted;
  final bool isLocked;
  final VoidCallback onTap;

  const MicSeatWidget({
    super.key,
    required this.seatIndex,
    this.userName,
    this.imageUrl,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isLocked = false,
    required this.onTap,
  });

  @override
  State<MicSeatWidget> createState() => _MicSeatWidgetState();
}

class _MicSeatWidgetState extends State<MicSeatWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final isEmpty = widget.userName == null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 55,
              height: 55,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Speaking ripple animation
                  if (widget.isSpeaking && !isEmpty && !widget.isLocked)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.cyanAccent.withOpacity(0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Locked state
                  if (widget.isLocked)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.4),
                        border: Border.all(
                          color: Colors.white24,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(Icons.lock_rounded, color: Colors.white54, size: 20),
                    )
                  // Empty state
                  else if (isEmpty)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.3),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(Icons.mic_none_rounded, color: Colors.white54, size: 22),
                    )
                  // Occupied state
                  else
                    ClipOval(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isSpeaking ? Colors.cyanAccent : Colors.transparent,
                            width: widget.isSpeaking ? 2 : 0,
                          ),
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                            ? Image.network(
                                widget.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.person,
                                  color: Colors.white54,
                                  size: 26,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: Colors.white54,
                                size: 26,
                              ),
                      ),
                    ),

                  // Mute indicator badge
                  if (!isEmpty && !widget.isLocked)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: widget.isMuted ? Colors.redAccent.withOpacity(0.9) : Colors.cyanAccent.withOpacity(0.9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black87, width: 2),
                        ),
                        child: Icon(
                          widget.isMuted ? Icons.mic_off : Icons.mic,
                          size: 10,
                          color: widget.isMuted ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // User name / Label
            Container(
              constraints: BoxConstraints(maxWidth: 65),
              child: Text(
                widget.isLocked ? 'Locked' : (isEmpty ? '${widget.seatIndex}' : widget.userName!),
                style: textTheme.labelSmall?.copyWith(
                  color: widget.isLocked || isEmpty ? Colors.white54 : Colors.white,
                  fontWeight: widget.isLocked || isEmpty ? FontWeight.normal : FontWeight.w600,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
