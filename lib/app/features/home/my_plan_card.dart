import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/my_plan_engine.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/app_tokens.dart';

/// Home "Mon plan" card (KPB-164): one unified progress figure plus THE single
/// next action, deep-linked. Self-hides for guests (no profile ⇒ no plan) and
/// once everything applicable is done, so it never nags with a finished plan.
class MyPlanCard extends StatefulWidget {
  const MyPlanCard({super.key});

  @override
  State<MyPlanCard> createState() => _MyPlanCardState();
}

class _MyPlanCardState extends State<MyPlanCard> {
  int? _loggedPercent;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (c) {
        final plan = MyPlanEngine.compute(
          profile: c.profile,
          hasOrientationResult: c.latestOrientationSession != null,
          cases: c.cases,
        );
        final next = plan.nextBlock;
        if (c.profile == null || next == null) return const SizedBox.shrink();

        // One event per distinct percentage: PostHog derives the weekly delta
        // from the series, so we don't keep a local "last week" copy that could
        // drift from reality.
        if (_loggedPercent != plan.percentRounded) {
          _loggedPercent = plan.percentRounded;
          AnalyticsService.instance.logMyPlanProgress(
            percent: plan.percentRounded,
            nextStep: next.block.name,
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: KpbSpacing.lg),
          child: Material(
            color: KpbColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Get.toNamed(next.route),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'my_plan_title'.tr,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: KpbColors.brandNavy,
                            ),
                          ),
                        ),
                        Text(
                          '${plan.percentRounded} %',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: KpbColors.actionPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: plan.percent,
                        minHeight: 7,
                        backgroundColor: KpbColors.actionPrimarySoft,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          KpbColors.actionPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.arrow_forward_rounded,
                            size: 16, color: KpbColors.actionPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'my_plan_next_step'
                                .trParams({'step': next.titleKey.tr}),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: KpbColors.brandNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
