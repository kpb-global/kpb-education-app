import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/app_models.dart';
import 'case_tunnel_flow.dart';

class CaseComposerSheet extends StatelessWidget {
  const CaseComposerSheet({
    super.key,
    required this.caseType,
    required this.title,
    required this.contextLabel,
    this.countryId,
    this.institutionId,
    this.programId,
  });

  final CaseType caseType;
  final String title;
  final String contextLabel;
  final String? countryId;
  final String? institutionId;
  final String? programId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: CaseTunnelFlow(
          prefill: CaseTunnelPrefill(
            title: title,
            contextLabel: contextLabel,
            initialType: caseType,
            countryId: countryId,
            institutionId: institutionId,
            programId: programId,
          ),
          onClose: () => Navigator.of(context).pop(),
          onSubmitted: () {
            Navigator.of(context).pop();
            Get.snackbar(
              'KPB Education',
              'request_submitted'.tr,
              snackPosition: SnackPosition.BOTTOM,
            );
          },
        ),
      ),
    );
  }
}
