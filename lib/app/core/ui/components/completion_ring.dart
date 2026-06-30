import 'package:flutter/material.dart';

// ── Profile Completion Ring ───────────────────────────────────────────────────
class CompletionRing extends StatelessWidget {
  const CompletionRing({
    super.key,
    required this.value,
    this.size = 64,
    this.strokeWidth = 6,
    this.color = Colors.white,
  });

  final double value; // 0.0 – 1.0
  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: strokeWidth,
            backgroundColor: color.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation(color),
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
