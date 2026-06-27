import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';
import '../scholarships/widgets/roadmap_timeline_view.dart';

/// Sprint 5 — a dated application "parcours" generated from the orientation
/// result. Reuses the shared RoadmapEngine timeline (anchored on the next
/// intake) and ends with a one-tap "Créer mon dossier".
class OrientationRoadmapScreen extends StatelessWidget {
  const OrientationRoadmapScreen({
    super.key,
    required this.fieldLabel,
    this.programId,
    this.countryId,
  });

  /// Resolved name of the top recommended field (for context + case prefill).
  final String fieldLabel;

  /// Optional top matched program/country to pre-fill the case.
  final String? programId;
  final String? countryId;

  /// Next major intake (September), used to anchor the relative roadmap steps.
  static DateTime _nextIntake() {
    final now = DateTime.now();
    var target = DateTime(now.year, 9, 1);
    if (target.isBefore(now.add(const Duration(days: 60)))) {
      target = DateTime(now.year + 1, 9, 1);
    }
    return target;
  }

  static const _months = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  @override
  Widget build(BuildContext context) {
    final intake = _nextIntake();
    final intakeLabel = '${_months[intake.month - 1]} ${intake.year}';

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: const Text('Mon parcours'),
        backgroundColor: context.kpb.pageBg,
        foregroundColor: context.kpb.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          Text('Ton parcours de candidature', style: KpbTextStyles.titleLg),
          SizedBox(height: KpbSpacing.xs),
          Text(
            'roadmap_objective'.trParams({'intake': intakeLabel, 'field': fieldLabel}),
            style:
                KpbTextStyles.bodySm.copyWith(color: context.kpb.textSecondary),
          ),
          RoadmapTimelineView(completionKey: 'orientation', deadline: intake),
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            text: 'Créer mon dossier',
            icon: Icons.folder_open_rounded,
            bgColor: KpbColors.blue,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => CaseComposerSheet(
                caseType: CaseType.applicationSupport,
                title: 'Dossier de candidature',
                contextLabel: fieldLabel,
                programId: programId,
                countryId: countryId,
              ),
            ),
          ),
          const SizedBox(height: KpbSpacing.xl),
        ],
      ),
    );
  }
}
