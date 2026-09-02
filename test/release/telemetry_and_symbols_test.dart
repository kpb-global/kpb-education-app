import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Bloc `run:` de l'étape nommée, dans un job donné.
///
/// On découpe le YAML à la main plutôt que d'ajouter une dépendance : le fichier
/// est indenté de façon stable et le test doit rester lisible par la personne
/// qui relit la CI.
String _stepBlock(String yaml, String stepName) {
  final start = yaml.indexOf('      - name: $stepName\n');
  expect(start, isNot(-1),
      reason: 'Étape absente de flutter-ci.yml : $stepName');
  final rest = yaml.substring(start + 1);
  final next = rest.indexOf('\n      - ');
  return next == -1 ? rest : rest.substring(0, next);
}

void main() {
  group('Aucune release muette ni illisible', () {
    final ci = _read('.github/workflows/flutter-ci.yml');
    final pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj');
    final iosPreflight = _read('scripts/preflight-ios-archive.sh');
    final androidPreflight = _read('scripts/preflight-android-aab.sh');

    // ── Symboles ──────────────────────────────────────────────────────────
    //
    // Sans phase d'envoi des dSYM, les plantages remontent en adresses mémoire
    // brutes. La build 50 est partie chez les testeurs dans cet état : ses
    // rapports sont inexploitables, et aucun signal ne le disait.
    group('dSYM envoyés à Crashlytics', () {
      test('la phase existe et est branchée sur la cible Runner', () {
        final phase = RegExp(
          r'([0-9A-F]{24}) /\* Upload dSYMs to Crashlytics \*/ = \{',
        ).firstMatch(pbxproj);
        expect(phase, isNotNull,
            reason: 'Phase de build absente du projet Xcode');

        // Déclarée ET référencée : une phase orpheline ne s'exécute jamais.
        final id = phase!.group(1)!;
        expect(
          pbxproj,
          contains('$id /* Upload dSYMs to Crashlytics */,'),
          reason:
              'Phase déclarée mais absente de buildPhases : elle ne tournerait '
              'jamais.',
        );
      });

      test('elle téléverse vraiment, et échoue au lieu d\'avertir', () {
        expect(pbxproj, contains(r'FirebaseCrashlytics/upload-symbols'));
        expect(
          pbxproj,
          contains(r'GoogleService-Info.plist'),
          reason: 'upload-symbols a besoin du plist Firebase',
        );
        // Un avertissement dans un journal de build est ce qui laisse passer une
        // archive incomplète. Sur un archivage, l'absence de dSYM doit être
        // fatale.
        expect(
          pbxproj,
          contains(r'aucun dSYM produit'),
          reason: 'l\'absence de dSYM doit être une erreur, pas un warning',
        );
      });

      test('la Release produit bien un dSYM à envoyer', () {
        // La phase serait un mensonge si la configuration ne générait pas de
        // dSYM : elle échouerait à chaque archivage.
        //
        // On isole les blocs `name = Release;` au lieu de chercher la chaîne
        // n'importe où : la configuration Profile porte elle aussi
        // `dwarf-with-dsym`, donc une recherche globale passerait même avec une
        // Release retombée en `dwarf` — le test aurait couvert le défaut au
        // lieu de le montrer.
        final releaseBlocks = RegExp(
          r'isa = XCBuildConfiguration;(.*?)\n\t\t\tname = (\w+);',
          dotAll: true,
        )
            .allMatches(pbxproj)
            .where((m) => m.group(2) == 'Release')
            .map((m) => m.group(1)!)
            .where((block) => block.contains('DEBUG_INFORMATION_FORMAT'))
            .toList();
        expect(
          releaseBlocks,
          isNotEmpty,
          reason:
              'aucune configuration Release ne fixe DEBUG_INFORMATION_FORMAT',
        );
        for (final block in releaseBlocks) {
          expect(
            block,
            contains('DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"'),
            reason: 'sans dwarf-with-dsym, aucun dSYM n\'est produit',
          );
        }
      });
    });

    // ── Télémétrie ────────────────────────────────────────────────────────
    //
    // La build 50 iOS est partie sans clé PostHog : sa télémétrie produit est
    // perdue définitivement. Le préflight iOS a été durci ; le job Android
    // substituait encore le secret sans jamais le regarder.
    group('clé PostHog exigée sur les deux plateformes', () {
      test('le job AAB refuse une clé absente, mal formée ou trop courte', () {
        final step = _stepBlock(ci, 'Verify PostHog project key');
        expect(step, contains(r'if [ -z "${POSTHOG_API_KEY:-}" ]'));
        expect(step, contains('phc_*)'));
        expect(step, contains(r'if [ "${#POSTHOG_API_KEY}" -lt 40 ]'));
      });

      test('le contrôle passe AVANT la construction de l\'AAB', () {
        final check = ci.indexOf('- name: Verify PostHog project key');
        final build = ci.indexOf('- name: Build signed production AAB');
        expect(check, isNot(-1));
        expect(build, isNot(-1));
        expect(
          check < build,
          isTrue,
          reason:
              'contrôler après la construction ferait perdre le build entier, '
              'et surtout laisserait l\'artefact exister',
        );
      });

      test('iOS et Android refusent les mêmes choses', () {
        for (final rule in ['phc_', '40']) {
          expect(iosPreflight, contains(rule));
        }
        final step = _stepBlock(ci, 'Verify PostHog project key');
        for (final rule in ['phc_', '40']) {
          expect(
            step,
            contains(rule),
            reason: 'règle « $rule » présente côté iOS mais pas côté Android',
          );
        }
      });
    });

    // Un rapport de succès qui ment sur ce qu'il a contrôlé est pire qu'un
    // rapport absent : il annonçait « (49) » alors que le script exigeait 51.
    test(
        'le préflight Android n\'annonce pas une version qu\'il ne vérifie pas',
        () {
      final tail = androidPreflight.substring(androidPreflight.length - 400);
      expect(
        RegExp(r'Préflight Android OK.*\(\d+\)').hasMatch(tail),
        isFalse,
        reason: 'numéro de build en dur dans le message de succès',
      );
      expect(tail, contains(r'${EXPECTED_VERSION_CODE}'));
    });
  });
}
