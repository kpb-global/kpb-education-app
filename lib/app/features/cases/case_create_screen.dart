import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/app_models.dart';
import 'case_composer_sheet.dart';

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

    if (args is Map) {
      final t = args['type'];
      if (t is CaseType) type = t;
      final tt = args['title'];
      if (tt is String && tt.isNotEmpty) title = tt;
      final cl = args['contextLabel'];
      if (cl is String && cl.isNotEmpty) contextLabel = cl;
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: CaseComposerSheet(
            caseType: type,
            title: title,
            contextLabel: contextLabel,
          ),
        ),
      ),
    );
  }
}
