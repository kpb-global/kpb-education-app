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
        label: const Text('Coach IA'),
        onPressed: () => Get.to(() => const AiChatScreen()),
      ),
    );
  }
}
