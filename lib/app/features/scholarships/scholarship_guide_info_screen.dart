import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/ui/app_tokens.dart';

/// Store-safe editorial presentation of the scholarship guide.
///
/// Deliberately contains no price, promotion, external purchase URL or wording
/// that directs a student to pay elsewhere.
class ScholarshipGuideInfoScreen extends StatelessWidget {
  const ScholarshipGuideInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        title: Text('scholarship_guide_short_title'.tr),
        backgroundColor: KpbColors.canvas,
        surfaceTintColor: KpbColors.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [KpbColors.actionPrimaryPressed, KpbColors.brandNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'scholarship_guide_title'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'scholarship_guide_intro'.tr,
                  style: const TextStyle(
                    color: KpbColors.actionOnDark,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'scholarship_guide_inside_title'.tr,
            style: KpbTextStyles.title,
          ),
          const SizedBox(height: 12),
          for (final entry in const [
            ('scholarship_guide_item_opportunities', Icons.travel_explore),
            ('scholarship_guide_item_documents', Icons.description_outlined),
            ('scholarship_guide_item_recommendations', Icons.people_outline),
            ('scholarship_guide_item_steps', Icons.checklist_rounded),
            ('scholarship_guide_item_bonus', Icons.workspace_premium_outlined),
          ])
            _GuideItem(label: entry.$1.tr, icon: entry.$2),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KpbColors.actionPrimarySoft,
              border: Border.all(
                  color: KpbColors.actionPrimary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: KpbColors.actionPrimary,
                  size: 22,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'scholarship_guide_author'.tr,
                    style: const TextStyle(
                      color: KpbColors.heroIndigo,
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: KpbColors.border),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: KpbColors.actionPrimary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: KpbColors.gray700,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
