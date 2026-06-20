import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/app_models.dart';
import 'case_tunnel_flow.dart';

/// Full-screen entry for the `/new-case` route (deep links, CTAs).
/// Accepts optional `Get.arguments` map: `type` ([CaseType]), `title` ([String]), `contextLabel` ([String]).
class CaseCreateScreen extends StatelessWidget {
  const CaseCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
