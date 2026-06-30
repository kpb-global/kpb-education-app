import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

// ── Field Card ────────────────────────────────────────────────────────────────
class FieldCard extends StatelessWidget {
  const FieldCard({
    super.key,
    required this.name,
    required this.description,
    required this.accentColor,
    required this.onTap,
    this.width = 180,
    this.careers = const [],
    this.isSaved = false,
    this.onSave,
    this.matchScore,
  });

  final String name;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;
  final double width;
  final List<String> careers;
  final bool isSaved;
  final VoidCallback? onSave;
  final int? matchScore;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: KpbRadius.lgBr,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color header
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KpbRadius.lg),
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                  ),
                  if (matchScore != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: KpbRadius.pillBr,
                        ),
                        child: Text(
                          '$matchScore%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Description
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  description,
                  style: KpbTextStyles.bodySm,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scholarship Card ──────────────────────────────────────────────────────────
