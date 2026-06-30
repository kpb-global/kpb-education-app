import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Staggered Slide Animation
// Correctly delays each item by index * delayMs before animating in.
// ─────────────────────────────────────────────────────────────────────────────
class StaggeredSlide extends StatefulWidget {
  const StaggeredSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.delayMs = 70,
  });

  final Widget child;
  final int index;
  final int delayMs;

  @override
  State<StaggeredSlide> createState() => _StaggeredSlideState();
}

class _StaggeredSlideState extends State<StaggeredSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = Duration(milliseconds: widget.index * widget.delayMs);
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KpbButton — Jobs Edition
// ─────────────────────────────────────────────────────────────────────────────
