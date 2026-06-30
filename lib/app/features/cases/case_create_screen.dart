import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/ui/app_tokens.dart';
import 'case_tunnel_flow.dart';

/// Full-screen entry for the `/new-case` route (deep links, CTAs).
/// Accepts optional `Get.arguments` map: `type` ([CaseType]), `title` ([String]), `contextLabel` ([String]).
class CaseCreateScreen extends StatelessWidget {
  const CaseCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    // Guest gating: a case needs a signed-in profile. Previously a guest could
    // walk through the 5-step tunnel and the submit silently failed (StateError
    // caught → "Profil incomplet" snackbar with no redirect). Block at the
    // entry point — clearer signal, no wasted form filling.
    if (controller.isGuestMode || controller.profile == null) {
      return const _GuestCaseGate();
    }

    final args = Get.arguments;
    CaseType type = CaseType.consultation;
    String title = 'new_case'.tr;
    String contextLabel = 'KPB Education';
    String? countryId;
    String? institutionId;
    String? programId;

    if (args is Map) {
      final t = args['type'];
      if (t is CaseType) type = t;
      final tt = args['title'];
      if (tt is String && tt.isNotEmpty) title = tt;
      final cl = args['contextLabel'];
      if (cl is String && cl.isNotEmpty) contextLabel = cl;
      final cId = args['countryId'];
      if (cId is String && cId.isNotEmpty) countryId = cId;
      final iId = args['institutionId'];
      if (iId is String && iId.isNotEmpty) institutionId = iId;
      final pId = args['programId'];
      if (pId is String && pId.isNotEmpty) programId = pId;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('create_case'.tr),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back<void>(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: CaseTunnelFlow(
            prefill: CaseTunnelPrefill(
              title: title,
              contextLabel: contextLabel,
              initialType: type,
              countryId: countryId,
              institutionId: institutionId,
              programId: programId,
            ),
            onClose: () => Get.back<void>(),
            onSubmitted: () => Get.back<void>(),
          ),
        ),
      ),
    );
  }
}

/// Shown when a guest tries to enter the case-creation tunnel.
/// Directs them to sign in instead of letting them fill 5 steps and fail at submit.
class _GuestCaseGate extends StatelessWidget {
  const _GuestCaseGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('create_case'.tr),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back<void>(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.pagePad, vertical: KpbSpacing.lg),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_outlined,
                    size: 64, color: KpbColors.blue),
                const SizedBox(height: KpbSpacing.lg),
                Text(
                  'guest_case_gate_title'.tr,
                  style: KpbTextStyles.headline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  'guest_case_gate_body'.tr,
                  style: KpbTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: KpbSpacing.xl),
                FilledButton.icon(
                  icon: const Icon(Icons.login_rounded),
                  label: Text('guest_case_gate_cta'.tr),
                  onPressed: () => Get.offAll(() => const AppBootScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
