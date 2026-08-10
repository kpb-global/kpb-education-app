import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../explore/explore_screen.dart';
import '../../core/ui/app_tokens.dart';

/// Écran Destinations — grille des pays (spec §4.1, M5).
class DestinationsScreen extends StatelessWidget {
  const DestinationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    // This screen is pushed from Home (Get.to) and had NO back affordance at
    // all — the target audience does not reliably know the iOS back-swipe
    // gesture, so a pinned breadcrumb back bar is required (owner review).
    // Guarded by canPop so nothing shows if it ever becomes a root tab.
    final canPop = Navigator.of(context).canPop();

    // Single "Pays"/"Countries" screen title (App-engagement handoff): the spec
    // uses one inline heading, not an app-bar "Destinations" title stacked above
    // it — so the heading IS the title (no redundant AppBar chrome).
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: GetBuilder<AppController>(
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canPop)
                _BackBar(crumb: 'nav_home'.tr, onBack: () => Get.back()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'dest_countries_heading'.tr,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: KpbColors.brandNavy,
                  ),
                ),
              ),
              Expanded(
                child: CountriesCatalogGrid(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned breadcrumb back bar — same motif as the country guide's breadcrumb
/// (`_Breadcrumb` in country_detail_screen.dart): sits outside the scroll view
/// so the back affordance never leaves the screen while scrolling.
class _BackBar extends StatelessWidget {
  const _BackBar({required this.crumb, required this.onBack});
  final String crumb;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        border: Border(bottom: BorderSide(color: KpbColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      // The whole row (circle + label) is one tap target: 30px alone is too
      // small for first-smartphone users.
      child: GestureDetector(
        onTap: onBack,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                    color: KpbColors.actionPrimary.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 15, color: KpbColors.actionPrimary),
            ),
            const SizedBox(width: 9),
            Text(
              crumb,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: KpbColors.actionPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
