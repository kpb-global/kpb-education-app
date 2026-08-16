import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import 'ai_chat_screen.dart';

/// Shared AI-processing consent gate (IA-T4).
///
/// The FAB used to be the only caller. Home Copilot, the "ask the advisor"
/// home CTA, the tools drawer, student-tools cards and case-detail review
/// all have to go through here — otherwise a student who never tapped the
/// FAB would hit the server 403 with no dialog.
///
/// Returns `true` when the student already consented, or just accepted.
/// Returns `false` on decline or if there is no profile (nothing to stamp).
///
/// The profile PATCH is **awaited** before returning. `updateProfile` used
/// to fire-and-forget the push; navigating immediately after accept would
/// race the PATCH and the next Groq call would 403 `ai_consent_required`.
Future<bool> ensureAiConsent(
  BuildContext context,
  AppController controller,
) async {
  final profile = controller.profile;
  if (profile == null) return false;
  if (profile.hasAiConsent) return true;

  final granted = await askAiConsent(context);
  if (granted != true) return false;
  if (!context.mounted) return false;

  await controller.updateProfile(
    profile.copyWith(aiConsentedAt: DateTime.now()),
  );
  return true;
}

Future<bool?> askAiConsent(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('ai_consent_title'.tr),
      content: Text('ai_consent_body'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('ai_consent_decline'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('ai_consent_accept'.tr),
        ),
      ],
    ),
  );
}

Future<void> openAiChatIfConsented(
  BuildContext context,
  AppController controller,
) async {
  if (!await ensureAiConsent(context, controller)) return;
  await Get.to(() => const AiChatScreen());
}

Future<void> openAiToolIfConsented(
  BuildContext context,
  Widget Function() page,
) async {
  final controller = Get.find<AppController>();
  if (!await ensureAiConsent(context, controller)) return;
  await Get.to(page);
}
