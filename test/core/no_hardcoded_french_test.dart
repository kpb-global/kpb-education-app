import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI guardrail (ratchet) for the "credibly bilingual" promise: an accented-
/// French string literal inside a Flutter `Text()` widget renders French to
/// English users. The goal is ZERO — move such strings to AppTranslations and
/// use `.tr`.
///
/// There is a large pre-existing backlog, so this test ratchets: it FAILS if a
/// file gains a NEW hardcoded-French `Text()` (or a brand-new file introduces
/// one), and the per-file [_baseline] may only ever be lowered as strings are
/// migrated. Lower the numbers (and delete zeroed entries) as you burn it down.
///
/// Only Flutter `Text(` widgets are checked; `pw.Text(` (PDF) and `RichText`
/// are excluded via the `(?<![\w.])` guard.
void main() {
  // Remaining hardcoded-French Text() per file. MUST only shrink. See KPB-51.
  const baseline = <String, int>{
    'lib/app/features/academy/academy_course_screen.dart': 2,
    'lib/app/features/ai_advisor/ai_chat_screen.dart': 1,
    'lib/app/features/alumni/alumni_apply_screen.dart': 1,
    'lib/app/features/alumni/alumni_directory_screen.dart': 1,
    'lib/app/features/auth/app_lock_screen.dart': 3,
    'lib/app/features/budget/budget_calculator_screen.dart': 4,
    'lib/app/features/cases/case_detail_screen.dart': 2,
    'lib/app/features/cases/case_status_timeline.dart': 1,
    'lib/app/features/cases/case_tunnel_flow.dart': 4,
    'lib/app/features/cases/document_review_screen.dart': 1,
    'lib/app/features/commercial/commercial_profile_screen.dart': 1,
    'lib/app/features/community/community_screen.dart': 3,
    'lib/app/features/eligibility/eligibility_simulator_screen.dart': 2,
    'lib/app/features/explore/country_detail_screen.dart': 2,
    'lib/app/features/explore/explore_screen.dart': 2,
    'lib/app/features/france/france_private_admission_screen.dart': 6,
    'lib/app/features/home/home_screen.dart': 8,
    'lib/app/features/housing/housing_estimator_screen.dart': 3,
    'lib/app/features/legal/legal_pages.dart': 4,
    'lib/app/features/onboarding/onboarding_screen.dart': 1,
    'lib/app/features/orientation/orientation_roadmap_screen.dart': 1,
    'lib/app/features/orientation/orientation_screen.dart': 5,
    'lib/app/features/parcours/parcours_screen.dart': 1,
    'lib/app/features/parent/parent_case_view_screen.dart': 1,
    'lib/app/features/parent/parent_dashboard_screen.dart': 2,
    'lib/app/features/profile/profile_screen.dart': 3,
    'lib/app/features/saved/saved_screen.dart': 2,
    'lib/app/features/scholarships/live_scholarships_screen.dart': 3,
    'lib/app/features/scholarships/scholarship_eligibility_screen.dart': 3,
    'lib/app/features/scholarships/scholarships_screen.dart': 2,
    'lib/app/features/search/search_screen.dart': 2,
    'lib/app/features/tools/document_scanner_screen.dart': 1,
    'lib/app/features/travel/flight_estimator_screen.dart': 2,
  };

  test('no NEW hardcoded accented-French inside Text() (ratchet, target 0)', () {
    final dir = Directory('lib/app/features');
    final accented = RegExp('[àâäéèêëîïôöùûüÿçœÀÂÄÉÈÊËÎÏÔÖÛÜÇŒ]');
    final textLiteral = RegExp(
      "(?<![\\w.])Text\\(\\s*(?:const\\s+)?(['\"])((?:(?!\\1).)*)\\1",
    );

    final counts = <String, int>{};
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      var n = 0;
      for (final m in textLiteral.allMatches(content)) {
        if (accented.hasMatch(m.group(2) ?? '')) n++;
      }
      if (n > 0) counts[entity.path] = n;
    }

    final regressions = <String>[];
    counts.forEach((path, n) {
      final allowed = baseline[path] ?? 0;
      if (n > allowed) {
        regressions.add('$path: $n hardcoded-French Text() (baseline $allowed)');
      }
    });

    expect(
      regressions,
      isEmpty,
      reason: 'New hardcoded accented-French inside Text() — move it to '
          'AppTranslations and use .tr (do NOT raise the baseline):\n'
          '${regressions.join('\n')}',
    );
  });
}
