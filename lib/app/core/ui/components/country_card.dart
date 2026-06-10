import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';


// ── Country Card ──────────────────────────────────────────────────────────────
class CountryCard extends StatelessWidget {
  const CountryCard({
    super.key,
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.width = 160,
    this.isSaved = false,
    this.onSave,
  });

  final String flag;
  final String name;
  final String subtitle;
  final VoidCallback onTap;
  final double width;
  final bool isSaved;
  final VoidCallback? onSave;

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
            // Flag area
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.surfaceBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KpbRadius.lg),
                ),
              ),
              child: Center(
                child: Text(flag, style: const TextStyle(fontSize: 44)),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: KpbTextStyles.caption.copyWith(color: c.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Field Card ────────────────────────────────────────────────────────────────
