import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';

/// A sleek, vertical timeline showing the high-level progress of an application.
class CaseTimelineStepper extends StatelessWidget {
  const CaseTimelineStepper({super.key, required this.currentStatus});
  final CaseStatus currentStatus;

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final currentIndex = _getCurrentStepIndex();

    return Container(
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.lgBr,
        boxShadow: KpbShadow.card,
        border: Border.all(color: context.kpb.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progression',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isCompleted = index < currentIndex;
            final isActive = index == currentIndex;
            final isLast = index == steps.length - 1;
            
            // Handle rejected/cancelled state styling
            final isErrorState = isActive && (currentStatus == CaseStatus.rejected || currentStatus == CaseStatus.cancelled);

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Indicator Column
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        // Node
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isErrorState
                                ? KpbColors.error
                                : isCompleted
                                    ? KpbColors.success
                                    : isActive
                                        ? KpbColors.blue
                                        : context.kpb.gray200,
                            border: isActive && !isErrorState
                                ? Border.all(color: KpbColors.blue.withValues(alpha: 0.3), width: 4)
                                : null,
                          ),
                          child: isCompleted
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                              : isActive && isErrorState
                                  ? const Icon(Icons.close_rounded, color: Colors.white, size: 14)
                                  : null,
                        ),
                        // Line
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isCompleted ? KpbColors.success : context.kpb.gray200,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content Column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                              color: isErrorState
                                  ? KpbColors.error
                                  : isActive || isCompleted
                                      ? context.kpb.textPrimary
                                      : context.kpb.textMuted,
                            ),
                          ),
                          if (step.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              step.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive ? context.kpb.textSecondary : context.kpb.textMuted,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  int _getCurrentStepIndex() {
    switch (currentStatus) {
      case CaseStatus.draft:
      case CaseStatus.submitted:
        return 0; // Création
      case CaseStatus.underReview:
      case CaseStatus.documentsNeeded:
      case CaseStatus.counselorAssigned:
      case CaseStatus.awaitingStudent:
        return 1; // Analyse
      case CaseStatus.scheduled:
      case CaseStatus.inProgress:
      case CaseStatus.applicationSubmitted:
        return 2; // Traitement
      case CaseStatus.waitingDecision:
      case CaseStatus.awaitingPayment:
        return 3; // Décision
      case CaseStatus.completed:
      case CaseStatus.rejected:
      case CaseStatus.cancelled:
        return 4; // Finalisation
    }
  }

  List<_StepData> _buildSteps() {
    return [
      _StepData(
        title: 'Création du dossier',
        description: currentStatus == CaseStatus.draft
            ? 'Complétez votre profil pour soumettre la demande.'
            : 'Dossier soumis avec succès.',
      ),
      _StepData(
        title: 'Analyse et Conseiller',
        description: currentStatus == CaseStatus.documentsNeeded
            ? 'Des documents supplémentaires sont requis.'
            : currentStatus == CaseStatus.awaitingStudent
                ? 'Votre conseiller attend votre retour.'
                : 'Examen de votre profil par nos experts.',
      ),
      _StepData(
        title: 'Traitement',
        description: 'Préparation et soumission de vos candidatures.',
      ),
      _StepData(
        title: 'Décision',
        description: 'En attente des retours des institutions.',
      ),
      _StepData(
        title: 'Finalisation',
        description: currentStatus == CaseStatus.rejected
            ? 'Dossier refusé.'
            : currentStatus == CaseStatus.cancelled
                ? 'Dossier annulé.'
                : 'Procédure terminée avec succès !',
      ),
    ];
  }
}

class _StepData {
  final String title;
  final String description;

  const _StepData({required this.title, required this.description});
}
