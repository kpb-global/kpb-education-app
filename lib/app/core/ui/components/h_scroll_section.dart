import 'package:flutter/material.dart';
import '../app_tokens.dart';

import 'section_header.dart';

// ── Horizontal Scroll Section ─────────────────────────────────────────────────
class HScrollSection extends StatelessWidget {
  const HScrollSection({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.actionLabel,
    this.onAction,
    this.itemWidth = 180,
    this.height = 200,
    this.textColor,
  });

  final String title;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double itemWidth;
  final double height;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          actionLabel: actionLabel,
          onAction: onAction,
          textColor: textColor,
        ),
        const SizedBox(height: KpbSpacing.sm),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.pagePad,
            ),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: KpbSpacing.sm),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

// ── Quick Action Button ───────────────────────────────────────────────────────
