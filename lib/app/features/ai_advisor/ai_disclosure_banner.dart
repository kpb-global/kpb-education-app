import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/ui/app_tokens.dart';

/// Honest disclosure on the four AI tool screens (IA-T3). The consent
/// dialog is the legal gate; this banner repeats what actually leaves the
/// phone once the tools are unmasked (`KPB_AI_TOOLS_ENABLED`).
class AiDisclosureBanner extends StatelessWidget {
  const AiDisclosureBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KpbColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: KpbColors.actionPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ai_tools_disclosure'.tr,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: KpbColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
