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
}
