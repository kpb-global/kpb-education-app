import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/ui/kpb_components.dart';
import '../../core/utils/whatsapp_utils.dart';

/// Ce que voit un compte qui n'est pas un compte étudiant — un parent arrivé par
/// un lien partagé, par exemple.
///
/// ## Pourquoi un écran, et pas un 403 traduit
///
/// L'espace écrit sur le profil de l'APPELANT : la déclaration d'intérêt prendrait
/// les nom, e-mail et téléphone d'un parent et les mettrait dans la liste d'appel
/// des étudiants. Le serveur refuse (403), mais sans cet écran le parent verrait
/// le hub, taperait, et recevrait « reconnecte-toi » — un message faux qui
/// l'enverrait se déconnecter. On lui dit la vérité avant, et on lui laisse une
/// sortie : un conseiller.
class EefStudentsOnlyScreen extends StatelessWidget {
  const EefStudentsOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('eef_title'.tr)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: KpbEmptyState(
            icon: Icons.school_outlined,
            title: 'eef_students_only_title'.tr,
            subtitle: 'eef_students_only_body'.tr,
            action: KpbButton(
              label: 'eef_hub_advisor_title'.tr,
              icon: Icons.support_agent_rounded,
              onTap: () => openWhatsAppOrToast(
                prefill:
                    kpbWhatsAppPrefill(custom: 'eef_hub_whatsapp_prefill'.tr),
                source: 'eef_students_only',
                contextType: 'eef_hub',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
