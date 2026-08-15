// Ce qui va à l'écran d'un étudiant, et ce qui n'y va pas.
//
// Trois gardes, nées de trois défauts mesurés dans ce dépôt.
//
//   1. `canLaunchUrl` ne doit plus servir de PRÉCONDITION. Il ment sur Android
//      11+ (visibilité des paquets, `targetSdkVersion` 36), et quand il ment le
//      code ne faisait rien du tout — pas de message, pas de journal. Neuf
//      sites écrivaient ce motif, dont le renvoi WhatsApp, unique chemin de
//      monétisation de l'app.
//
//   2. `e.toString()` ne doit plus être PEINT à l'écran. Sur le chemin PDF de
//      l'écran de dossier, une DioException complète — URL, en-têtes, code de
//      statut — pouvait s'afficher en bandeau à un étudiant.
//
//   3. Le corps « fichier trop volumineux » doit être traduit. Il était en
//      anglais brut sous un titre français, sur une app dont tout le public est
//      francophone.
//
// Les deux premières sont statiques, et c'est délibéré : un test de rendu ne
// couvre qu'un écran, alors que ces deux défauts sont des MOTIFS. Une garde qui
// lit le dépôt attrape le prochain endroit où le motif réapparaît, y compris
// dans un fichier que personne n'a pensé à tester.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/services/document_upload_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/external_link.dart';

List<String> _trackedLibFiles() {
  try {
    final result = Process.runSync('git', ['ls-files', '--', 'lib']);
    if (result.exitCode == 0) {
      return (result.stdout as String)
          .split('\n')
          .where((path) => path.endsWith('.dart'))
          .toList();
    }
  } catch (_) {
    // git absent : repli sur le scan filesystem.
  }
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path.replaceAll('\\', '/'))
      .toList();
}

/// Les lignes de code (hors commentaires) qui correspondent à [pattern].
List<String> _hits(Pattern pattern, {Set<String> allowed = const <String>{}}) {
  final found = <String>[];
  for (final relativePath in _trackedLibFiles()) {
    if (allowed.contains(relativePath)) continue;
    final file = File(relativePath);
    if (!file.existsSync()) continue;
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.trimLeft().startsWith('//')) continue;
      if (line.contains(pattern)) {
        found.add('  $relativePath:${index + 1} — ${line.trim()}');
      }
    }
  }
  return found;
}

/// Une exception convertie en chaîne et passée en ARGUMENT.
///
/// La borne gauche `(?<![A-Za-z0-9_.])` compte : sans elle, le motif attrapait
/// `error.runtimeType.toString()` — parce que « Typ**e**.toString() » se termine
/// par « e.toString() ». Ce site-là est légitime (il journalise un nom de type,
/// pas un message), et un garde-fou qui accuse du code correct se fait désarmer
/// dans la semaine.
final _rawExceptionArgument =
    RegExp(r'(?<![A-Za-z0-9_.])(e|err|error|exception)\.toString\(\)\s*,');

/// La seule exemption, et elle est délibérée.
///
/// `BootstrapErrorApp` (lib/main.dart) est l'écran de dernier recours : il ne
/// s'affiche que si l'app n'a PAS pu démarrer. À ce moment-là aucune traduction
/// n'est chargée — `GetMaterialApp` n'a jamais été monté — et la journalisation
/// distante peut être morte elle aussi, puisque c'est souvent son initialisation
/// qui a échoué. Le texte brut y est la seule information qui existe, et son
/// public pendant la 49 est un testeur, pas un étudiant.
///
/// Cette garde a TROUVÉ ce site toute seule : il est exempté en connaissance de
/// cause, pas par omission.
const _rawExceptionAllowed = <String>{'lib/main.dart'};

void main() {
  group('1. on TENTE d\'ouvrir un lien, on ne DEMANDE pas la permission', () {
    test('`canLaunchUrl` n\'apparaît plus dans lib/', () {
      // Une seule exception possible, et elle n'existe pas encore : si un jour
      // un appel légitime devait revenir, il faudrait l'ajouter ici ET écrire
      // pourquoi. Une allowlist qu'on remplit sans justification redevient un
      // garde-fou désarmé.
      final violations = _hits('canLaunchUrl');

      expect(
        violations,
        isEmpty,
        reason: 'Sur Android 11+, `canLaunchUrl` est filtré par la visibilité '
            'des paquets et rend FAUX même quand un navigateur est installé. '
            'Utilisé comme précondition, il rend le bouton muet ; et un bouton '
            'muet est indiscernable d\'une app plantée. Utilisez '
            '`kpbOpenExternalUrl` (lib/app/core/utils/external_link.dart), qui '
            'tente le lancement et rend `false` sur échec — vous DEVEZ alors '
            'traiter ce `false`.\n${violations.join('\n')}',
      );
    });

    test('le manifeste Android déclare les intentions nécessaires', () {
      // Les COMMENTAIRES XML sont retirés avant l'analyse : le bloc `<queries>`
      // explique justement pourquoi `QUERY_ALL_PACKAGES` est interdit, et sans
      // ce nettoyage la garde s'accusait elle-même. (Elle l'a fait, la première
      // fois qu'elle a tourné.)
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync()
          .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

      expect(
        manifest.contains('android.intent.action.VIEW'),
        isTrue,
        reason: 'Sans intention VIEW déclarée dans `<queries>`, la résolution '
            'de tout lien externe est filtrée sur Android 11+.',
      );
      expect(manifest.contains('android:scheme="https"'), isTrue);
      expect(
        manifest.contains('com.whatsapp'),
        isTrue,
        reason: 'Le renvoi conseiller est l\'unique chemin de monétisation de '
            'l\'app : il n\'y a délibérément aucun paiement in-app.',
      );
      expect(
        manifest.contains('QUERY_ALL_PACKAGES'),
        isFalse,
        reason: 'Motif de refus de politique Play — et sur une app DÉJÀ '
            'publiée, le refus porterait sur la mise à jour elle-même.',
      );
    });

    test('un lien sans schéma n\'est jamais présenté comme ouvrable', () {
      // La donnée du catalogue n'est pas propre : `Uri.parse` accepte
      // volontiers un chemin relatif, puis le lancement échoue.
      expect(isOpenableWebUrl('exemple.org/apply'), isFalse);
      expect(isOpenableWebUrl('ftp://example.org/file'), isFalse);
      expect(isOpenableWebUrl('https:///no-host'), isFalse);
      expect(isOpenableWebUrl(''), isFalse);
      expect(isOpenableWebUrl(null), isFalse);
      expect(isOpenableWebUrl('https://example.org/apply'), isTrue);
      expect(isOpenableWebUrl('  http://example.org  '), isTrue);
    });
  });

  group('2. aucune exception brute n\'est peinte à l\'écran', () {
    test('`e.toString()` ne part pas dans un Get.snackbar', () {
      // On cherche le motif exact qui a causé le défaut : une variable
      // d'exception convertie en chaîne au moment de l'affichage. La garde est
      // volontairement littérale — elle attrape ce que les développeurs
      // écrivent réellement, pas une abstraction du problème.
      final violations = _hits(
        _rawExceptionArgument,
        allowed: _rawExceptionAllowed,
      )..sort();

      expect(
        violations,
        isEmpty,
        reason: 'Une exception rendue telle quelle peut afficher une URL '
            'd\'API, des en-têtes et un code de statut à un étudiant. Donnez '
            'un message actionnable à l\'écran et envoyez la trace aux '
            'journaux (`safeRecordError`).\n${violations.join('\n')}',
      );
    });
  });

  group('3. « fichier trop volumineux » parle la langue de l\'utilisateur', () {
    setUp(() {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
      Get.fallbackLocale = const Locale('fr');
    });
    tearDown(Get.reset);

    test('le corps du bandeau est traduit et porte les deux nombres', () {
      const error = FileTooLargeException(
        sizeInBytes: 12 * 1024 * 1024,
        maxSizeInBytes: 10 * 1024 * 1024,
      );

      final body = error.localizedBody();

      expect(
        body,
        isNot(contains('File is too large')),
        reason: 'C\'est la moitié de l\'assertion qui casse si le correctif '
            'est annulé : l\'ancien texte anglais revenait par `toString()`.',
      );
      expect(body, contains('12.0'));
      expect(body, contains('10'));
      expect(body, contains('Mo'));
    });

    test('et la clé existe dans les DEUX langues', () {
      final keys = AppTranslations().keys;
      expect(keys['fr']!['file_too_large_body'], isNotNull);
      expect(keys['en']!['file_too_large_body'], isNotNull);
      // Les deux paramètres doivent survivre à la traduction, sinon le message
      // perd les chiffres qui le rendent utile.
      for (final locale in const ['fr', 'en']) {
        expect(keys[locale]!['file_too_large_body'], contains('@size'));
        expect(keys[locale]!['file_too_large_body'], contains('@max'));
      }
    });

    test('le toString() anglais survit — il va aux JOURNAUX, pas à l\'écran',
        () {
      const error = FileTooLargeException(
        sizeInBytes: 12 * 1024 * 1024,
        maxSizeInBytes: 10 * 1024 * 1024,
      );
      expect(error.toString(), contains('File is too large'));
    });
  });
}
