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

    return Positioned(
      right: KpbSpacing.pagePad,
      bottom: 96,
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
