import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI guardrail (ratchet) for the "credibly bilingual" promise: an accented-
/// French string literal that reaches the UI renders French to English users.
/// The goal is ZERO — move such strings to AppTranslations and use `.tr`.
///
/// Coverage (KPB-89): the whole `lib/app` tree, and both the `Text()` widget
/// *and* the common text-bearing named parameters that render copy through
/// KPB's component library (`title:`, `subtitle:`, `label:`, `text:`, `hint:`,
/// `tooltip:`, `message:`). `pw.Text` (PDF) and dotted receivers are excluded
/// via the `(?<![\w.])` guard.
///
/// This test ratchets: it FAILS if a file gains a NEW hardcoded-French string,
/// and the per-file [baseline] may only ever be lowered. The migration is
/// complete, so the baseline is empty — keep it that way.
void main() {
  // Remaining hardcoded-French per file. MUST only shrink (target: stays 0).
  const baseline = <String, int>{};

  test('no NEW hardcoded accented-French in UI strings (ratchet, target 0)',
      () {
    final dir = Directory('lib/app');
    final accented = RegExp('[àâäéèêëîïôöùûüÿçœÀÂÄÉÈÊËÎÏÔÖÛÜÇŒ]');
    // Text('...') / Text("...")
    final textLiteral = RegExp(
      "(?<![\\w.])Text\\(\\s*(?:const\\s+)?(['\"])((?:(?!\\1).)*)\\1",
    );
    // title: '...' / label: "..." / text: '...' etc.
    final paramLiteral = RegExp(
      "(?<![\\w.])(?:title|subtitle|label|text|hint|tooltip|message)\\s*:"
      "\\s*(?:const\\s+)?(['\"])((?:(?!\\1).)*)\\1",
    );

    final counts = <String, int>{};
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      var n = 0;
      for (final m in textLiteral.allMatches(content)) {
        if (accented.hasMatch(m.group(2) ?? '')) n++;
      }
      for (final m in paramLiteral.allMatches(content)) {
        if (accented.hasMatch(m.group(2) ?? '')) n++;
      }
      if (n > 0) counts[entity.path] = n;
    }

    final regressions = <String>[];
    counts.forEach((path, n) {
      final allowed = baseline[path] ?? 0;
      if (n > allowed) {
        regressions.add('$path: $n hardcoded-French UI string(s) '
            '(baseline $allowed)');
      }
    });

    expect(
      regressions,
      isEmpty,
      reason: 'New hardcoded accented-French UI string — move it to '
          'AppTranslations and use .tr (do NOT raise the baseline):\n'
          '${regressions.join('\n')}',
    );
  });
}
