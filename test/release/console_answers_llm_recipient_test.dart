import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Retire les blocs cités (`> …`) et le code inline, pour ne jamais faire
/// échouer une assertion sur la PROSE qui explique justement la règle.
///
/// Le piège est connu sur ce dépôt : une garde a déjà « passé » parce qu'elle
/// trouvait sa propre chaîne dans un commentaire explicatif.
String _prose(String doc) =>
    doc.split('\n').where((l) => !l.trimLeft().startsWith('>')).join('\n');

void main() {
  group('La fiche consoles nomme le bon destinataire des invites IA', () {
    final doc = _read('docs/CONSOLE_ANSWERS.md');
    final service = _read('backend/src/modules/ai/llm.service.ts');

    // ── Le destinataire ───────────────────────────────────────────────────
    //
    // §5 porte la mention « recopier au formulaire destinataires ». Un mauvais
    // nom n'y est pas une coquille : c'est une déclaration de sous-traitant
    // fausse, signée par le propriétaire.
    //
    // La fiche a nommé Groq pendant que la production routait vers OpenRouter,
    // et personne ne pouvait s'en apercevoir : rien ne rapprochait les deux.
    test('la table des sous-traitants nomme le défaut du code', () {
      // Le service prend OpenRouter dès que `LLM_API_KEY` est posée ; Groq
      // n'est atteint que par `LLM_PROVIDER=groq` ou les variables héritées.
      expect(service, contains("? 'groq'"),
          reason: 'la précédence du fournisseur a changé de forme — '
              'relire llm.service.ts avant de faire confiance à cette garde');
      expect(service, contains("name ?? 'openrouter'"),
          reason: 'le fournisseur par défaut n\'est plus OpenRouter : '
              'la fiche consoles doit suivre');

      expect(_prose(doc), contains('| OpenRouter (LLM) |'),
          reason: 'la table des destinataires ne nomme pas OpenRouter');
      expect(_prose(doc), isNot(contains('| Groq (LLM) |')),
          reason: 'la table nomme encore Groq comme destinataire actif');
    });

    // ── Le nombre de surfaces ─────────────────────────────────────────────
    //
    // Le questionnaire d'âge (IARC + Apple) demande combien de surfaces
    // produisent du texte libre. La fiche en comptait 2 alors que les quatre
    // outils IA avaient été démasqués — sous-déclarer se corrige mal après
    // publication.
    test('le compte des surfaces IA suit le démasquage des outils', () {
      final config = _read('lib/app/core/config/app_config.dart');
      final unmasked = config.contains(
          RegExp(r"'KPB_AI_TOOLS_ENABLED',\s*\n\s*defaultValue:\s*true"));

      if (unmasked) {
        expect(doc, contains('**Oui — 6 surfaces**'),
            reason: 'les outils IA sont actifs par défaut : le questionnaire '
                'd\'âge doit compter 6 surfaces génératives, pas 2');
      } else {
        expect(doc, contains('**Oui — 2 surfaces**'),
            reason: 'les outils IA sont masqués : la fiche sur-déclare');
      }
    });
  });

  // ── La garde ops doit pouvoir LIRE ce qu'elle compare ────────────────────
  //
  // `vps-ops` ne code plus le destinataire en dur : il l'extrait de la ligne
  // « (LLM) » du tableau des sous-traitants, puis compare au fournisseur
  // réellement résolu en production. Une constante s'était désynchronisée de
  // la fiche à la première migration, la garde annonçant « la fiche dit Groq »
  // APRÈS que la fiche eut été corrigée en OpenRouter.
  //
  // Deux façons de casser ça en silence : perdre la ligne, ou casser le
  // tableau qui la contient.
  group('Le destinataire IA reste extractible par l\'outillage', () {
    final doc = File('docs/CONSOLE_ANSWERS.md').readAsStringSync();

    test('la fiche porte une ligne « (LLM) » exploitable', () {
      final row =
          RegExp(r'^\| *([^|(]+)\(LLM\)', multiLine: true).firstMatch(doc);
      expect(row, isNotNull,
          reason: 'sans ligne « (LLM) », l\'étape ops échoue et plus rien ne '
              'compare la fiche à la production');
      final name = row!.group(1)!.replaceAll(RegExp(r'[ *]'), '').toLowerCase();
      expect(name, isNotEmpty);
    });

    // Le tableau avait été coupé en deux par une note en bloc-citation posée
    // au milieu : les cinq lignes suivantes se rendaient en texte brut, hors
    // du tableau. Un tableau rompu reste « lisible » à l'œil dans le source et
    // faux dans le rendu — et c'est ce rendu que l'on recopie dans le
    // formulaire du store.
    test('le tableau des sous-traitants n\'est pas coupé en deux', () {
      final start = doc.indexOf('| Sous-traitant | Région |');
      expect(start, greaterThan(-1));
      final rows = doc
          .substring(start)
          .split('\n')
          .takeWhile((l) => l.startsWith('|'))
          .toList();
      // en-tête + séparateur + les sous-traitants
      expect(rows.length, greaterThanOrEqualTo(16),
          reason: 'le tableau s\'arrête à ${rows.length} lignes : une ligne '
              'vide ou une note l\'a rompu, et les sous-traitants situés '
              'après ne se rendent plus comme des lignes de tableau');
      for (final needle in ['OneSignal', 'Mautic', 'WhatsApp', 'PostHog']) {
        expect(rows.any((r) => r.contains(needle)), isTrue,
            reason: '$needle est hors du tableau');
      }
    });
  });
}
