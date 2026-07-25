// ─────────────────────────────────────────────────────────────────────────────
// "Mon plan" — unified progress score (KPB-164).
//
// The student's investment is real but scattered: profile fields, orientation
// result, dossier, requested documents. Each surface shows its own slice, so
// nothing conveys "you have work in progress here". This engine folds them into
// ONE percentage and ONE next action — the Zeigarnik pull that brings people
// back, because abandoning now means losing visible progress.
//
// Pure and synchronous: no widgets, no network, no controller. Everything it
// reports is derived from real data — a block that cannot apply yet (documents
// before any dossier exists) is EXCLUDED from the denominator rather than shown
// as 0 %, so the score never lies about what is actually outstanding.
// ─────────────────────────────────────────────────────────────────────────────

import '../config/app_routes.dart';
import '../models/app_models.dart';

/// The four tracked areas of progress, in priority order — the first incomplete
/// one becomes the single "next action".
enum MyPlanBlock { profile, orientation, dossier, documents }

/// One block's state. [progress] is 0..1; [applicable] is false when the block
/// cannot be acted on yet and is therefore left out of the score entirely.
class MyPlanBlockState {
  const MyPlanBlockState({
    required this.block,
    required this.progress,
    required this.applicable,
    required this.titleKey,
    required this.route,
  });

  final MyPlanBlock block;
  final double progress;
  final bool applicable;

  /// Translation key for the action label (resolved by the UI, never here).
  final String titleKey;

  /// In-app route for the action, ready for deep linking.
  final String route;

  bool get isComplete => progress >= 1.0;
}

class MyPlan {
  const MyPlan({required this.percent, required this.blocks, this.nextBlock});

  /// Weighted completion across applicable blocks, 0..1.
  final double percent;
  final List<MyPlanBlockState> blocks;

  /// The single next action, or null when everything applicable is done.
  final MyPlanBlockState? nextBlock;

  int get percentRounded => (percent * 100).round();
  bool get isComplete => nextBlock == null;
}

abstract final class MyPlanEngine {
  /// Profile counts double: it feeds matching everywhere, and it is the one
  /// block that moves in small increments (13 fields), which keeps the score
  /// responsive to little edits instead of jumping only on milestones.
  static const _weights = <MyPlanBlock, double>{
    MyPlanBlock.profile: 2,
    MyPlanBlock.orientation: 1,
    MyPlanBlock.dossier: 1,
    MyPlanBlock.documents: 2,
  };

  static MyPlan compute({
    required UserProfile? profile,
    required bool hasOrientationResult,
    required List<StudentCase> cases,
  }) {
    // A guest / profile-less user has no plan to speak of.
    if (profile == null) {
      return const MyPlan(percent: 0, blocks: <MyPlanBlockState>[]);
    }

    final activeCases = cases
        .where((c) =>
            c.status != CaseStatus.completed &&
            c.status != CaseStatus.cancelled &&
            c.status != CaseStatus.rejected)
        .toList();

    // Documents: aggregated across active dossiers. Only applicable once an
    // advisor has actually requested something — otherwise there is nothing to
    // do and counting it as 0 % would invent an outstanding task.
    final requests = activeCases.expand((c) => c.documentRequests).toList();
    final provided = requests.where((r) => r.isProvided).length;

    final firstCaseRoute = activeCases.isEmpty
        ? AppRoutes.caseCreate
        : '/cases/${activeCases.first.id}';

    final blocks = <MyPlanBlockState>[
      MyPlanBlockState(
        block: MyPlanBlock.profile,
        progress: profile.completionScore.clamp(0.0, 1.0),
        applicable: true,
        titleKey: 'my_plan_step_profile',
        route: AppRoutes.profile,
      ),
      MyPlanBlockState(
        block: MyPlanBlock.orientation,
        progress: hasOrientationResult ? 1 : 0,
        applicable: true,
        titleKey: 'my_plan_step_orientation',
        route: AppRoutes.orientation,
      ),
      MyPlanBlockState(
        block: MyPlanBlock.dossier,
        progress: activeCases.isEmpty ? 0 : 1,
        applicable: true,
        titleKey: 'my_plan_step_dossier',
        route: activeCases.isEmpty ? AppRoutes.caseCreate : firstCaseRoute,
      ),
      MyPlanBlockState(
        block: MyPlanBlock.documents,
        progress: requests.isEmpty ? 0 : provided / requests.length,
        applicable: requests.isNotEmpty,
        titleKey: 'my_plan_step_documents',
        route: firstCaseRoute,
      ),
    ];

    var weighted = 0.0;
    var totalWeight = 0.0;
    for (final b in blocks) {
      if (!b.applicable) continue;
      final w = _weights[b.block] ?? 1;
      weighted += w * b.progress;
      totalWeight += w;
    }
    final percent = totalWeight == 0 ? 0.0 : weighted / totalWeight;

    // Exactly one next action: the first applicable, incomplete block in the
    // declared priority order.
    MyPlanBlockState? next;
    for (final b in blocks) {
      if (b.applicable && !b.isComplete) {
        next = b;
        break;
      }
    }

    return MyPlan(
      percent: percent.clamp(0.0, 1.0),
      blocks: blocks,
      nextBlock: next,
    );
  }
}
