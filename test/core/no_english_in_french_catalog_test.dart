// Garde de la revue du build 49, point 3 : « il y a beaucoup de parties en
// anglais, il faudra faire un check complet ».
//
// ## Pourquoi une SECONDE garde, alors qu'une garde i18n existait déjà
//
// `no_hardcoded_french_test.dart` surveille le FRANÇAIS qui fuit dans le build
// anglais. C'est l'exacte direction inverse du défaut signalé, et c'est
// pourquoi la suite est restée verte pendant qu'un tiers du catalogue embarqué
// s'affichait en anglais à un utilisateur francophone.
//
// Elle ne pouvait pas non plus le voir pour une seconde raison, indépendante :
// elle inspecte `Text(...)`, `title:`, `label:`… — la couche WIDGET. Le
// catalogue, lui, est de la DONNÉE : `LocalizedText(fr: …, en: …)`. Aucune de
// ses deux expressions régulières ne décrit cette forme.
//
// ## Ce que le contrôle mesure
//
// L'audit a montré que le dictionnaire de traduction est irréprochable (2198
// clés de chaque côté, aucune manquante, aucune prose anglaise côté français).
// Tout l'anglais visible venait d'ici : des valeurs anglaises logées dans le
// champ `fr:` du catalogue hors-ligne — visible au démarrage à froid, hors
// ligne, en cas d'échec de l'API, et EN PERMANENCE pour l'Espagne, les EAU, la
// Turquie et la Chine, qui n'ont aucune ligne côté serveur.
//
// ## Pourquoi seulement `duration` et `requirements`
//
// Parce que ce sont les deux champs de PROSE TRADUISIBLE. Les autres champs
// `LocalizedText` du catalogue portent légitimement de l'anglais côté français :
// `name` contient des intitulés officiels de diplômes (« Bachelor of Business
// Administration », « MSc - Luxury Management »), qu'on ne traduit pas — les
// traduire rendrait la fiche introuvable sur le site de l'école. Un contrôle
// qui les inclurait produirait des dizaines de faux positifs et finirait
// désactivé ; c'est ce qui arrive aux gardes trop larges.
//
// Le vocabulaire ci-dessous est donc étroit et sans homographe français.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mots anglais sans équivalent orthographique français, tels qu'ils ont été
  // RÉELLEMENT trouvés dans le champ `fr:` du catalogue. Pas de spéculation :
  // chaque entrée correspond à une chaîne qui s'affichait à l'écran.
  const englishMarkers = <String>[
    'year',
    'years',
    // `week`/`month` ont été ajoutés APRÈS coup : la première version de cette
    // liste ne portait que `year(s)` et laissait donc passer « 4 weeks », seule
    // occurrence de sa forme. Une liste de marqueurs construite sur ce qu'on a
    // déjà vu rate ce qu'on n'a pas encore vu — d'où les familles complètes.
    'week',
    'weeks',
    'month',
    'months',
    'day',
    'days',
    'degree',
    'transcript',
    'transcripts',
    'equivalent;',
    'Official',
    'Online',
    'Baccalaureate',
    'requirements',
    'Varies',
    'confirm',
    'pathway',
    'vary',
  ];

  // `fr:` d'un LocalizedText, dans un bloc `duration:` ou `requirements:`.
  final block = RegExp(
    r"(?:duration|requirements):\s*(?:\[.*?\n\s*\],|LocalizedText\(.*?\),)",
    dotAll: true,
  );
  final frValue = RegExp(r"fr:\s*'((?:[^'\\]|\\.)*)'", dotAll: true);
  final english = RegExp(
    '\\b(?:${englishMarkers.join('|')})\\b',
    caseSensitive: false,
  );

  test('aucun anglais dans le champ `fr:` du catalogue embarqué', () {
    final dir = Directory('lib/app/core/data/mock_catalog');
    expect(
      dir.existsSync(),
      isTrue,
      reason: 'le catalogue embarqué a changé de place : cette garde ne '
          'contrôle plus rien tant que le chemin n\'est pas corrigé',
    );

    final offenders = <String>[];
    var scanned = 0;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final b in block.allMatches(content)) {
        for (final m in frValue.allMatches(b.group(0)!)) {
          scanned++;
          final value = m.group(1)!;
          if (english.hasMatch(value)) {
            offenders.add('${entity.path}: "$value"');
          }
        }
      }
    }

    // Contre-garde : sans elle, un jour où l'expression régulière cesserait de
    // décrire la forme du catalogue, ce test rendrait « 0 infraction » et
    // passerait au vert en n'ayant RIEN lu. C'est exactement le mode de panne
    // qui a laissé le défaut vivre : un contrôle vert qui ne mesure rien.
    expect(
      scanned,
      greaterThan(200),
      reason: 'le harnais n\'a lu que $scanned valeurs `fr:` — la forme du '
          'catalogue a changé et les expressions régulières ne la décrivent '
          'plus. Corriger le harnais AVANT de croire son verdict.',
    );

    expect(
      offenders,
      isEmpty,
      reason: 'Texte anglais dans le champ `fr:` du catalogue hors-ligne. Un '
          'francophone le lit au démarrage à froid, hors ligne, et en '
          'permanence pour les pays absents du serveur :\n'
          '${offenders.join('\n')}',
    );
  });

  test('aucun littéral sur-échappé (contre-oblique parasite à l\'écran)', () {
    // `'…d\\\'études'` en source vaut `d\'études` à l'exécution : la
    // contre-oblique s'AFFICHE. 54 lignes du catalogue étaient dans ce cas,
    // dont 26 de français parfaitement correct.
    final bad = '${r'\\'}${r"\'"}';
    final offenders = <String>[];
    for (final entity
        in Directory('lib/app/core/data').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(bad)) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Apostrophe sur-échappée : la contre-oblique sera VISIBLE dans '
          'l\'app. Écrire \\\' et non \\\\\\\' :\n${offenders.join('\n')}',
    );
  });
}
