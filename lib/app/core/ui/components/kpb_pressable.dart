import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── KpbPressable ──────────────────────────────────────────────────────────────
// Wraps any tappable surface with a subtle press-scale + haptic tick. Gives the
// whole app a tactile, "alive" feel without each call site reimplementing it.
class KpbPressable extends StatefulWidget {
  const KpbPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<KpbPressable> createState() => _KpbPressableState();
}

class _KpbPressableState extends State<KpbPressable> {
  bool _down = false;

  void _set(bool v) {
    if (mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
