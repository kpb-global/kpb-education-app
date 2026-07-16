import 'package:flutter/material.dart';
import '../app_tokens.dart';

// ── Admission Meter Gauge ───────────────────────────────────────────────────
class AdmissionMeter extends StatelessWidget {
  const AdmissionMeter({
    super.key,
    required this.score,
    this.size = 46,
    this.strokeWidth = 4,
    this.showLabel = true,
  });

  final int score;
  final double size;
  final double strokeWidth;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutExpo,
      tween: Tween(begin: 0, end: score.toDouble()),
      builder: (context, value, child) {
        final currentScore = value.toInt();
        Color currentColor;
        if (value < 50) {
          currentColor = KpbColors.error;
        } else if (value < 80) {
          currentColor = KpbColors.warning;
        } else {
          currentColor = KpbColors.success;
        }

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: strokeWidth,
                // Piste translucide : lisible sur cartes claires ET sur les
                // rails hero sombres où la jauge est embarquée.
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : KpbColors.textFaint.withValues(alpha: 0.2),
              ),
              CircularProgressIndicator(
                value: value / 100,
                strokeWidth: strokeWidth,
                color: currentColor,
                strokeCap: StrokeCap.round,
              ),
              if (showLabel)
                Text(
                  '$currentScore%',
                  style: TextStyle(
                    color: currentColor,
                    fontSize: size * 0.28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staggered Slide Animation
// Correctly delays each item by index * delayMs before animating in.
// ─────────────────────────────────────────────────────────────────────────────
