import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/controllers/app_controller.dart';
import '../../../core/data/roadmap_engine.dart';
import '../../../core/models/app_models.dart';
import '../../../core/ui/app_tokens.dart';

class RoadmapTimelineView extends StatelessWidget {
  const RoadmapTimelineView({
    super.key,
    required this.scholarship,
    required this.deadline,
  });

  final ScholarshipModel scholarship;
  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final steps = RoadmapEngine.getSteps();
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemBuilder: (context, index) {
        final step = steps[index];
        final date = RoadmapEngine.calculateDate(deadline, step.daysBeforeDeadline);
        final isLast = index == steps.length - 1;

        return GetBuilder<AppController>(
          builder: (controller) {
            final isCompleted = controller.isStepCompleted(scholarship.id, step.type);
            
            return _RoadmapStepTile(
              step: step,
              date: date,
              isCompleted: isCompleted,
              isLast: isLast,
              onToggle: () => controller.toggleRoadmapStep(scholarship.id, step.type),
              onAction: step.actionRoute != null ? () => _handleAction(step.actionRoute!) : null,
            );
          },
        );
      },
    );
  }

  void _handleAction(String route) {
     if (route == '/academy') {
        // Handle deep link to academy
        Get.snackbar('Academy', 'Redirection vers les tutoriels de rédaction...', backgroundColor: KpbColors.blue, colorText: Colors.white);
     } else if (route == '/consultation') {
        // Handle deep link to consultation
        Get.snackbar('Consultation', 'Redirection vers l\'expert KPB...', backgroundColor: KpbColors.stitchDeepPurple, colorText: Colors.white);
     }
  }
}

class _RoadmapStepTile extends StatelessWidget {
  const _RoadmapStepTile({
    required this.step,
    required this.date,
    required this.isCompleted,
    required this.isLast,
    required this.onToggle,
    this.onAction,
  });

  final RoadmapStepModel step;
  final DateTime date;
  final bool isCompleted;
  final bool isLast;
  final VoidCallback onToggle;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final color = isCompleted ? KpbColors.success : KpbColors.blue;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: The line and dot
          Column(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? color : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? color.withValues(alpha: 0.5) : Colors.white10,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Right: Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     children: [
                       Text(
                         controller.resolve(step.title),
                         style: TextStyle(
                           color: isCompleted ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                           fontWeight: FontWeight.w700,
                           fontSize: 15,
                           decoration: isCompleted ? TextDecoration.lineThrough : null,
                         ),
                       ),
                       const Spacer(),
                       Text(
                         '${date.day}/${date.month}',
                         style: TextStyle(
                           color: isCompleted ? Colors.white24 : KpbColors.blue.withValues(alpha: 0.8),
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 4),
                   Text(
                     controller.resolve(step.description),
                     style: TextStyle(
                       color: Colors.white.withValues(alpha: 0.4),
                       fontSize: 13,
                     ),
                   ),
                   if (!isCompleted && onAction != null) ...[
                     const SizedBox(height: 12),
                     SizedBox(
                       height: 32,
                       child: OutlinedButton(
                         onPressed: onAction,
                         style: OutlinedButton.styleFrom(
                           side: BorderSide(color: color.withValues(alpha: 0.3)),
                           foregroundColor: color,
                           padding: const EdgeInsets.symmetric(horizontal: 12),
                           shape: const RoundedRectangleBorder(borderRadius: KpbRadius.mdBr),
                         ),
                         child: Text(
                            step.type == RoadmapStepType.writing ? 'Voir les tutos' : 'Réserver un expert',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                         ),
                       ),
                     ),
                   ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
