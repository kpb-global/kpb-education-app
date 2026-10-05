// LIV-T1 / LIV-T2 : un numéro déjà consommé ne reprend pas la place du courant.
//
// Le ledger est la source. Remettre +48 dans pubspec.yaml doit rougir avec
// « 48 consommé sur TestFlight le 12/08/2026 ». +49 est le seul vert.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _versionLine =
    RegExp(r'^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$', multiLine: true);
final _consumedLine = RegExp(r'^-\s+`(\d+)`\s+—\s+(.+)$', multiLine: true);
final _currentLine = RegExp(r'^-\s+`(\d+)`\s+—\s+', multiLine: true);

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final ledger = File('docs/release-ledger.md').readAsStringSync();

  test('pubspec porte le numéro courant, jamais un numéro consommé', () {
    final version = _versionLine.firstMatch(pubspec);
    expect(version, isNotNull, reason: 'pubspec.yaml sans version+build.');
    final build = int.parse(version!.group(1)!);

    final consumedHalf = ledger.split('## Courant').first;
    final consumed = <int, String>{};
    for (final m in _consumedLine.allMatches(consumedHalf)) {
      consumed[int.parse(m.group(1)!)] = m.group(2)!.trim();
    }
    expect(consumed, isNotEmpty, reason: 'Ledger sans numéros consommés.');
    expect(consumed.containsKey(48), isTrue,
        reason: '48 doit rester listé : TestFlight du 12/08/2026.');

    final currentHalf = ledger.split('## Courant').last;
    final current = _currentLine.firstMatch(currentHalf);
    expect(current, isNotNull, reason: 'Ledger sans numéro courant.');
    final currentBuild = int.parse(current!.group(1)!);

    final reason = consumed[build];
    expect(
      reason,
      isNull,
      reason: reason == null ? '' : '$build $reason',
    );
    expect(build, currentBuild,
        reason: 'pubspec +$build mais le ledger dit courant $currentBuild.');
  });

  // Décision du propriétaire du 05/10/2026 : « 56 » = on n'envoie QUE la 56. La 55
  // (téléversée sur App Store Connect le 04/10, jamais soumise, AAB jamais importé
  // dans Play) est ABANDONNÉE : son numéro est CONSOMMÉ, la 56 en est le successeur.
  test('la 55 est consommée, jamais soumise, remplacée par la 56', () {
    final consumedHalf = ledger.split('## Courant').first;
    final consumed = <int, String>{
      for (final m in _consumedLine.allMatches(consumedHalf))
        int.parse(m.group(1)!): m.group(2)!,
    };
    final reason55 = consumed[55];
    expect(reason55, isNotNull,
        reason: 'la 55 doit figurer sous « Consommés » : téléversée sur App '
            'Store Connect le 04/10/2026, son numéro ne se réutilise pas.');
    // La ligne d'un numéro consommé continue sur les lignes indentées qui la
    // suivent : on lit le paragraphe entier.
    final start = consumedHalf.indexOf(RegExp(r'^-\s+`55`', multiLine: true));
    final paragraph = consumedHalf
        .substring(start)
        .split(RegExp(r'\n(?=-\s+`\d+`)'))
        .first
        .replaceAll(RegExp(r'\s+'), ' ');
    for (final needle in [
      '04/10/2026',
      'jamais soumise',
      'remplacée par la 56',
      '37322572087',
      'jamais importé',
    ]) {
      expect(paragraph, contains(needle),
          reason: 'la ligne « 55 » du registre ne dit plus « $needle »');
    }
  });

  // La ligne du numéro COURANT a deux états, et le registre prescrit lui-même le
  // passage de l'un à l'autre (en-tête du registre ; checklist de la 56, étape 7) :
  //
  //  · AVANT l'archive : « EN COURS (archive à faire) », « non téléversée » et le
  //    marqueur `<RELEASE>`. Jamais un SHA : le vrai n'existe qu'après la fusion de
  //    la dernière PR (la 51 a porté le dépôt trois jours sans archive).
  //  · APRÈS l'envoi : « téléversée le JJ/MM/AAAA » ET le SHA de 40 caractères, et
  //    plus AUCUN des trois marqueurs « avant ».
  //
  // Un état MIXTE (SHA posé mais « non téléversée » gardée, ou l'inverse) est le
  // registre qui ment : il rougit. Un test qui n'accepterait que « avant » ferait
  // échouer la PR de report que la checklist ordonne — et inciterait à laisser le
  // registre dire « non téléversée » pour garder la CI verte.
  //
  // Un numéro ne passe sous « Consommés » que lorsque le numéro SUIVANT est
  // préparé (registre) ; avant cela, il n'est jamais sous « Consommés » : c'est
  // le premier test ci-dessus qui le garde, pour le build de pubspec.yaml.
  group('la ligne du numéro courant', () {
    const sha = 'a3f9c2e17b4d58a06e9d1c2b3f4a5b6c7d8e9f01';
    final dated = RegExp(r'téléversée le \d{2}/\d{2}/\d{4}');
    final fullSha = RegExp(r'\b[0-9a-f]{40}\b');
    const before = [
      'EN COURS (archive à faire)',
      'non téléversée',
      '`<RELEASE>`'
    ];

    /// Les écarts de la ligne [entry] (espaces normalisés) avec l'un des deux états.
    List<String> problems(String entry, {required String label}) {
      final flat = entry.replaceAll(RegExp(r'\s+'), ' ');
      final out = <String>[];
      if (!flat.contains(label)) out.add('ne dit plus « $label »');
      final hasSha = fullSha.hasMatch(flat);
      final isDated = dated.hasMatch(flat);
      final markers = [
        for (final m in before)
          if (flat.contains(m)) m
      ];
      if (isDated || hasSha) {
        // État APRÈS : tout ou rien.
        if (!isDated) out.add('SHA posé mais pas « téléversée le JJ/MM/AAAA »');
        if (!hasSha) out.add('« téléversée le » sans le SHA de 40 caractères');
        for (final m in markers) {
          out.add('état mixte : « $m » gardé alors que la build est envoyée');
        }
      } else {
        // État AVANT : les trois marqueurs, et aucun SHA.
        for (final m in before) {
          if (!markers.contains(m)) out.add('ne dit plus « $m »');
        }
      }
      return out;
    }

    test('l\'état « avant l\'archive » passe', () {
      final entry = '- `56` — **`2.3.0 (56)`, EN COURS (archive à faire) : '
          'non téléversée, non soumise.**\n  Commit à archiver : `<RELEASE>` — '
          'À RENSEIGNER.';
      expect(problems(entry, label: '2.3.0 (56)'), isEmpty);
    });

    test('l\'état « après l\'envoi » prescrit par la checklist passe', () {
      final entry = '- `56` — **`2.3.0 (56)`, téléversée le 06/10/2026, non '
          'soumise.**\n  Commit archivé : `RELEASE` = `$sha`.';
      expect(problems(entry, label: '2.3.0 (56)'), isEmpty,
          reason: 'la PR de report du SHA doit passer la CI');
    });

    test('un état mixte rougit, dans les deux sens', () {
      const label = '2.3.0 (56)';
      // SHA posé, « non téléversée » gardée : le registre ment.
      final shaOnly = '- `56` — `2.3.0 (56)`, EN COURS (archive à faire) : non '
          'téléversée. Commit à archiver : `<RELEASE>` = `$sha`.';
      expect(problems(shaOnly, label: label), isNotEmpty);
      // « téléversée le » sans SHA.
      const dateOnly = '- `56` — `2.3.0 (56)`, téléversée le 06/10/2026. '
          'Commit à archiver : `<RELEASE>`.';
      expect(problems(dateOnly, label: label), isNotEmpty);
      // Marqueur « avant » oublié après l'envoi.
      final leftover = '- `56` — `2.3.0 (56)`, téléversée le 06/10/2026, '
          'EN COURS (archive à faire). Commit archivé : `RELEASE` = `$sha`.';
      expect(problems(leftover, label: label), isNotEmpty);
      // Marqueur « avant » partiel avant l'envoi.
      const partial = '- `56` — `2.3.0 (56)`, EN COURS (archive à faire) : '
          'non téléversée. Commit à archiver : à renseigner.';
      expect(problems(partial, label: label), isNotEmpty);
    });

    test('la ligne courante du registre est dans l\'un des deux états', () {
      final version = _versionLine.firstMatch(pubspec)!;
      final build = int.parse(version.group(1)!);
      final name = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+', multiLine: true)
          .firstMatch(pubspec)!
          .group(1)!;

      final currentHalf = ledger.split('## Courant').last;
      final line = RegExp(r'^-\s+`(\d+)`\s+—.*?(?=^\S|^#|(?![\s\S]))',
              multiLine: true, dotAll: true)
          .firstMatch(currentHalf);
      expect(line, isNotNull, reason: 'Ledger sans numéro courant.');
      expect(int.parse(line!.group(1)!), build,
          reason: 'le numéro courant du registre ne suit pas pubspec +$build.');

      final entry = line.group(0)!;
      expect(problems(entry, label: '$name ($build)'), isEmpty,
          reason: 'la ligne courante ($build) n\'est dans aucun des deux états '
              '(avant l\'archive / après l\'envoi)');

      // Avant l'archive, un SHA de 40 caractères posé comme RELEASE serait
      // inventé : le vrai n'existe qu'après la fusion de la dernière PR.
      if (!dated.hasMatch(entry.replaceAll(RegExp(r'\s+'), ' '))) {
        expect(
          RegExp(r'RELEASE`?\s*(=|:)\s*`?[0-9a-f]{40}').hasMatch(ledger),
          isFalse,
          reason: 'un SHA de 40 caractères est posé comme RELEASE avant '
              'l\'archive',
        );
      }

      // Ce qui ne change pas d'un état à l'autre, propre à la préparation de
      // la 56 : le registre cesse de le dire quand la 57 prend la place.
      if (build == 56) {
        final flat = entry.replaceAll(RegExp(r'\s+'), ' ');
        for (final needle in [
          'remplace la 55',
          '0641601', // le backend de production, couplage tolerates-old
        ]) {
          expect(flat, contains(needle),
              reason: 'la ligne courante (56) ne dit plus « $needle »');
        }
        // Les papiers de la 56 sont listés sous la ligne courante.
        for (final needle in [
          'docs/mise-a-jour-56-checklist.md',
          'docs/release-56-store-pack.md',
          'docs/device-qa-build56.md',
          'eefHelpBubble',
          'eefPrivateSchools',
        ]) {
          expect(currentHalf, contains(needle),
              reason: 'le registre ne renvoie plus à « $needle » sous Courant');
        }
      }
    });
  });

  // ITMS-90062 : App Store Connect refuse une version marketing non strictement
  // supérieure à celle EN VENTE. La version en vente se lit dans le REGISTRE (ligne
  // « Version marketing EN VENTE ») et non dans ce fichier : une constante ici ne
  // suivrait jamais la mise en vente de la 2.3.0, et le test ne garderait plus
  // rien.
  test('la version marketing reste strictement supérieure à celle en vente',
      () {
    final m = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+', multiLine: true)
        .firstMatch(pubspec);
    expect(m, isNotNull);
    final name = [for (var i = 1; i <= 3; i++) int.parse(m!.group(i)!)];

    final sale = RegExp(
      r'^Version marketing EN VENTE\s*:\s*`(\d+)\.(\d+)\.(\d+)`',
      multiLine: true,
    ).firstMatch(ledger);
    expect(sale, isNotNull,
        reason: 'le registre n\'a plus la ligne « Version marketing EN VENTE : '
            '`X.Y.Z` » : le test ne sait plus ce qui est en vente.');
    final onSale = [for (var i = 1; i <= 3; i++) int.parse(sale!.group(i)!)];

    var greater = false;
    for (var i = 0; i < 3; i++) {
      if (name[i] != onSale[i]) {
        greater = name[i] > onSale[i];
        break;
      }
    }
    expect(greater, isTrue,
        reason: '${name.join('.')} n\'est pas > ${onSale.join('.')} '
            '(en vente d\'après le registre) : ITMS-90062.');
  });
}
