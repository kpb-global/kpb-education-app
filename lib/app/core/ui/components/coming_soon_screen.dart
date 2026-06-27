import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app_tokens.dart';

/// Graceful placeholder for modules gated behind the MVP lock. A deep-link to a
/// not-yet-shipped feature (e.g. the live-scholarships aggregator) resolves
/// here instead of failing silently. Fully localized (FR/EN).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'coming_soon_title'.tr)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(KpbSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 56,
                color: KpbColors.warning,
              ),
              const SizedBox(height: KpbSpacing.md),
              Text(
                'coming_soon_title'.tr,
                style: KpbTextStyles.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KpbSpacing.sm),
              Text(
                'coming_soon_body'.tr,
                style: KpbTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
