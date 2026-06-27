import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/app_tokens.dart';
import '../ai_advisor/ai_chat_screen.dart';

class CoachFab extends StatelessWidget {
  const CoachFab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    if (!controller.isStudent || controller.isGuestMode) {
      return const SizedBox.shrink();
    }

    // The floating bottom nav is ~68px high + 24px page padding; we add the
    // device safe-area inset so the FAB stays clear of the home indicator on
    // iPhones with notch/dynamic island. Old constant 96 sat behind the bar.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      right: KpbSpacing.pagePad,
      bottom: 92 + bottomInset,
      child: FloatingActionButton.extended(
        heroTag: 'kpb_coach_fab',
        backgroundColor: KpbColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.psychology_rounded),
        label: Text('coach_ai'.tr),
        onPressed: () => _openCoach(context, controller),
      ),
    );
  }

  /// Gate the coach behind explicit, separately-stored AI-processing consent
  /// (KPB-66). The first time, ask; once granted we persist the timestamp so we
  /// never re-prompt. Declining keeps the rest of the app usable.
  Future<void> _openCoach(BuildContext context, AppController controller) async {
    final profile = controller.profile;
    if (profile != null && !profile.hasAiConsent) {
      final granted = await _askAiConsent(context);
      if (granted != true) return;
      controller.updateProfile(
        profile.copyWith(aiConsentedAt: DateTime.now()),
      );
    }
    await Get.to(() => const AiChatScreen());
  }

  Future<bool?> _askAiConsent(BuildContext context) {
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
}
