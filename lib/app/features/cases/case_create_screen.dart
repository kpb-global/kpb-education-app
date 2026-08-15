import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/components/kpb_guest_gate.dart';
import 'case_tunnel_flow.dart';

// Couleurs : tokens sémantiques centraux (KpbColors/KpbShadow — architecture §10.2).
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
          tooltip: 'a11y_close'.tr,
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
///
/// Ne reste ici que la CHROME — barre de titre et bouton de fermeture. Le mur
/// lui-même est le composant partagé, pour deux raisons.
///
/// La première est qu'il y en avait deux copies dans le dépôt. La seconde est
/// plus grave : **la version d'ici bouclait**. Son bouton faisait
/// `Get.offAll(AppBootScreen)` SANS appeler `leaveGuestForSignup`, or le routeur
/// de démarrage renvoie vers la coquille dès que `isGuestMode` est vrai — donc
/// l'invité qui appuyait sur « Se connecter » retombait exactement d'où il
/// venait, sans le moindre message. Le composant partagé quitte le mode invité
/// AVANT de naviguer, et journalise la conversion.
class _GuestCaseGate extends StatelessWidget {
  const _GuestCaseGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('create_case'.tr),
        leading: IconButton(
          tooltip: 'a11y_close'.tr,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back<void>(),
        ),
      ),
      body: const SafeArea(child: KpbGuestGate(source: 'case_create_gate')),
    );
  }
}
