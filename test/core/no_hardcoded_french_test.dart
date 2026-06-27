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
  const baseline = <String, int>{};

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
