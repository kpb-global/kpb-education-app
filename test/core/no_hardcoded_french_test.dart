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

  // The accented-French test above cannot see ACCENT-FREE French ("Voir tout",
  // "Dossiers actifs", "Nouveau dossier"…) — the exact class the KPB-89 wave-2
  // audit found leaking en masse. This companion ratchet catches a curated set
  // of high-signal, accent-free French UI words. Words are matched whole-word
  // and case-insensitively, so snake_case `.tr` keys are immune (underscores
  // are word chars → no boundary), only hardcoded French phrases match. The
  // list is deliberately conservative (no English homographs like "note",
  // "message", "contact", "charger", "payer") to stay false-positive-free.
  test('no NEW hardcoded accent-free French in UI strings (ratchet, target 0)',
      () {
    // Per-file allowance. MUST only shrink (target: stays 0).
    const baseline = <String, int>{};

    const frWords = <String>[
      'Voir',
      'Annuler',
      'Continuer',
      'Envoyer',
      'Rechercher',
      'Partager',
      'Modifier',
      'Supprimer',
      'Ajouter',
      'Fermer',
      'Choisir',
      'Valider',
      'Confirmer',
      'Refuser',
      'Accepter',
      'Terminer',
      'Commencer',
      'Acheter',
      'Devenir',
      'Enregistrer',
      'Quitter',
      'Contacter',
      'Postuler',
      'Consulter',
      'Comparer',
      'Bourse',
      'Bourses',
      'Dossier',
      'Dossiers',
      'Compte',
      'Connexion',
      'Accueil',
      'Bienvenue',
      'Nouveau',
      'Nouvelle',
      'Suivant',
      'Retour',
    ];
    final french =
        RegExp('\\b(?:${frWords.join('|')})\\b', caseSensitive: false);
    final textLiteral = RegExp(
      "(?<![\\w.])Text\\(\\s*(?:const\\s+)?(['\"])((?:(?!\\1).)*)\\1",
    );
    final paramLiteral = RegExp(
      "(?<![\\w.])(?:title|subtitle|label|text|hint|tooltip|message)\\s*:"
      "\\s*(?:const\\s+)?(['\"])((?:(?!\\1).)*)\\1",
    );

    final dir = Directory('lib/app');
    final counts = <String, int>{};
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      var n = 0;
      for (final m in textLiteral.allMatches(content)) {
        if (french.hasMatch(m.group(2) ?? '')) n++;
      }
      for (final m in paramLiteral.allMatches(content)) {
        if (french.hasMatch(m.group(2) ?? '')) n++;
      }
      if (n > 0) counts[entity.path] = n;
    }

    final regressions = <String>[];
    counts.forEach((path, n) {
      final allowed = baseline[path] ?? 0;
      if (n > allowed) {
        regressions.add('$path: $n accent-free-French UI string(s) '
            '(baseline $allowed)');
      }
    });

    expect(
      regressions,
      isEmpty,
      reason: 'New hardcoded accent-free-French UI string — move it to '
          'AppTranslations and use .tr (do NOT raise the baseline):\n'
          '${regressions.join('\n')}',
    );
  });
}
