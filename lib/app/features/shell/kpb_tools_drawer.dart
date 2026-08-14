import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../budget/budget_calculator_screen.dart';
import '../cases/document_review_screen.dart';
import '../housing/housing_estimator_screen.dart';
import '../tools/cv_generator_screen.dart';
import '../tools/document_scanner_screen.dart';
import '../tools/impact_dashboard_screen.dart';
import '../tools/interview_simulator_screen.dart';
import '../tools/motivation_letters_screen.dart';
import '../travel/flight_estimator_screen.dart';

/// Global hamburger drawer for the KPB student tools.
///
/// Tab screens have their own Scaffolds, so the AppShell's drawer cannot be
/// reached via `Scaffold.of(context)` from inside a tab. Each AppShell instead
/// registers its own Scaffold key here on mount, so any descendant can call
/// [open] to surface the drawer regardless of how deeply it is nested.
class KpbToolsDrawer extends StatelessWidget {
  const KpbToolsDrawer({super.key});

  /// Scaffold key of the AppShell currently on screen. Each AppShell instance
  /// publishes its own key on mount ([registerShell]) and clears it on dispose
  /// ([unregisterShell]) — so if two shells briefly overlap during a route
  /// transition (e.g. `Get.offAllNamed('/')` firing while the boot shell is
  /// still a frame from being torn down, as happens when the app is foregrounded
  /// via a `kpb://` URL) they never share one GlobalKey, which would crash with
  /// "Duplicate GlobalKey [LabeledGlobalKey<ScaffoldState>]".
  static GlobalKey<ScaffoldState>? _activeShellKey;

  /// Publish [key] as the live shell. Called from `AppShell.initState`.
  static void registerShell(GlobalKey<ScaffoldState> key) {
    _activeShellKey = key;
  }

  /// Clear [key] if it is still the live shell. Called from `AppShell.dispose`.
  /// The identity check stops an outgoing shell's teardown from clobbering an
  /// incoming shell that already registered ahead of it.
  static void unregisterShell(GlobalKey<ScaffoldState> key) {
    if (identical(_activeShellKey, key)) _activeShellKey = null;
  }

  /// Open the drawer from anywhere inside the AppShell tree.
  static void open(BuildContext _) {
    _activeShellKey?.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final tools = _tools;
    return Drawer(
      backgroundColor: context.kpb.pageBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  KpbSpacing.lg, KpbSpacing.lg, KpbSpacing.md, KpbSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KpbColors.blue.withValues(alpha: 0.12),
                          borderRadius: KpbRadius.mdBr,
                        ),
                        child: const Icon(Icons.build_circle_outlined,
                            color: KpbColors.blue),
                      ),
                      const SizedBox(width: KpbSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('tools_drawer_title'.tr,
                                style: KpbTextStyles.title),
                            Text(
                              'tools_drawer_subtitle'.tr,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.kpb.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: KpbSpacing.sm),
                itemCount: tools.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, i) {
                  final t = tools[i];
                  return ListTile(
                    leading: Icon(t.icon, color: t.color),
                    title: Text(t.labelKey.tr,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer
                      Get.to<void>(t.builder);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Les outils RÉELLEMENT offerts par le tiroir, sous une forme publique.
  ///
  /// Exposé pour que la matrice d'écrans (test/core/ui/screen_matrix_test.dart)
  /// se pilote sur CETTE liste et non sur une copie. Deux conséquences voulues :
  /// un outil ajouté ici est couvert automatiquement, et le compte reflète les
  /// drapeaux — il y a 9 entrées littérales mais 8 à l'exécution, `tools_flight`
  /// étant derrière `AppConfig.flightEstimatorEnabled`, un
  /// `bool.fromEnvironment` qu'un test ne peut pas basculer. Une matrice qui
  /// écrirait « 9 » en dur échouerait pour cette seule raison.
  @visibleForTesting
  static List<({String labelKey, Widget Function() builder})>
      get toolsForTest => _tools
          .map((tool) => (labelKey: tool.labelKey, builder: tool.builder))
          .toList(growable: false);

  static final List<_ToolEntry> _tools = <_ToolEntry>[
    _ToolEntry(
      labelKey: 'tools_cv',
      icon: Icons.description_outlined,
      color: KpbColors.blue,
      builder: () => const CvGeneratorScreen(),
    ),
    _ToolEntry(
      labelKey: 'tools_motivation_letter',
      icon: Icons.edit_note_outlined,
      color: KpbColors.blueMid,
      builder: () => const MotivationLettersScreen(),
    ),
    _ToolEntry(
      labelKey: 'tools_interview',
      icon: Icons.record_voice_over_outlined,
      color: KpbColors.navy,
      builder: () => const InterviewSimulatorScreen(),
    ),
    _ToolEntry(
      labelKey: 'tools_doc_scanner',
      icon: Icons.document_scanner_outlined,
      color: KpbColors.sky,
      builder: () => const DocumentScannerScreen(),
    ),
    _ToolEntry(
      labelKey: 'tools_doc_review',
      icon: Icons.auto_awesome_outlined,
      color: KpbColors.gold,
      builder: () => const DocumentReviewScreen(),
    ),
    _ToolEntry(
      labelKey: 'tools_budget',
      icon: Icons.savings_outlined,
      color: KpbColors.success,
      builder: () => const BudgetCalculatorScreen(),
    ),
    // Hidden while the backend has no Kayak key: the estimator can only
    // fail without it (revue vidéo du propriétaire — « ça ne sert à rien »).
    if (AppConfig.flightEstimatorEnabled)
      _ToolEntry(
        labelKey: 'tools_flight',
        icon: Icons.flight_takeoff_outlined,
        color: KpbColors.sky,
        builder: () => const FlightEstimatorScreen(),
      ),
    _ToolEntry(
      labelKey: 'tools_housing',
      icon: Icons.home_work_outlined,
      color: KpbColors.warning,
      builder: () => const HousingEstimatorScreen(),
    ),
    _ToolEntry(
      labelKey: 'tools_impact',
      icon: Icons.insights_outlined,
      color: KpbColors.gold,
      builder: () => const ImpactDashboardScreen(),
    ),
  ];
}

class _ToolEntry {
  const _ToolEntry({
    required this.labelKey,
    required this.icon,
    required this.color,
    required this.builder,
  });

  final String labelKey;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
}
