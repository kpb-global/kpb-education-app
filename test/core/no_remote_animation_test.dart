// Aucune animation, aucune image, aucune police ne doit venir d'un CDN tiers à
// l'exécution.
//
// Ce test naît d'un défaut précis. `app_lock_screen.dart` chargeait son cadenas
// animé par `Lottie.network` depuis une URL lottiefiles qui répond **403**. Deux
// dégâts, chacun suffisant pour justifier cette garde :
//
//   · en release, lottie ne rend son message d'erreur que sous `kDebugMode`, donc
//     l'écran de verrouillage affichait un TROU de 180×180 — invisible en
//     développement, permanent chez l'utilisateur ;
//   · et chaque déverrouillage envoyait l'adresse IP de l'utilisateur à un tiers
//     absent de la déclaration de confidentialité des stores. Sur un écran de
//     sécurité.
//
// La règle générale qui en découle : un actif visuel embarqué ne peut pas tomber
// en panne, un actif distant peut. Sur un public qui utilise beaucoup de forfaits
// prépayés et de réseaux instables, ce n'est pas un détail esthétique.
//
// Patron repris de test/core/no_hardcoded_french_test.dart : on mesure le dépôt
// SUIVI PAR GIT, pas les brouillons locaux d'une autre session.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les constructeurs qui vont chercher un actif de CHROME sur le réseau.
const _remoteChromeConstructors = <String, String>{
  'Lottie.network(': 'animation Lottie tirée d\'un CDN',
  'SvgPicture.network(': 'SVG tiré du réseau',
};

/// ## Pourquoi `NetworkImage` et `Image.network` ne sont PAS dans cette liste
///
/// Première version de ce test : je les avais inclus. Résultat mesuré, onze
/// occurrences légitimes — vignettes de cours, photos de pays, images de récits
/// Parcours, logos de partenaires, illustrations de bourses. Ce sont des
/// **données**, servies par notre propre API ou par les URL de contenu du
/// catalogue, avec un composant dédié qui porte déjà leur repli
/// (`kpb_network_image.dart`).
///
/// Les faire passer par une allowlist de onze entrées aurait produit exactement
/// ce que ce dépôt sait reconnaître : un garde-fou qu'on désarme dans la semaine
/// et qui reste vert pour toujours.
///
/// La distinction qui tient : une image de contenu peut manquer sans casser
/// l'interface, et son absence se voit. La CHROME de l'app — ses icônes, ses
/// animations, ses illustrations — n'a aucune raison de dépendre d'un hôte qu'on
/// ne contrôle pas, et son absence laisse un trou muet. C'est ce trou-là,
/// 180×180, que ce test interdit.

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

void main() {
  test('aucune animation ni illustration d\'interface ne vient d\'un CDN', () {
    final violations = <String>[];

    for (final relativePath in _trackedLibFiles()) {
      final file = File(relativePath);
      if (!file.existsSync()) continue;
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (line.trimLeft().startsWith('//')) continue;
        for (final entry in _remoteChromeConstructors.entries) {
          if (line.contains(entry.key)) {
            violations.add('  $relativePath:${index + 1} — ${entry.value} '
                '(${entry.key.replaceAll('(', '')})');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Un actif de CHROME dépend d\'un hôte tiers : en release son échec '
          'est muet, et chaque affichage envoie l\'adresse IP de l\'utilisateur à '
          'ce tiers — qui devrait alors figurer dans la déclaration de '
          'confidentialité des stores. Embarquez l\'actif.\n'
          '${violations.join('\n')}',
    );
  });

  test('le paquet lottie ne revient pas sans raison', () {
    // Il n'avait qu'un seul appelant dans toute l'app, et c'était l'URL en 403.
    // Le retirer de pubspec.yaml supprime aussi son arbre de dépendances.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'^\s{2}lottie:', multiLine: true);
    expect(
      declared.hasMatch(pubspec),
      isFalse,
      reason:
          'Le paquet `lottie` est de retour dans pubspec.yaml. Si un besoin '
          'réel le justifie, utilisez `Lottie.asset` avec un fichier embarqué — '
          'jamais `Lottie.network`, et mettez ce test à jour en le disant.',
    );
  });
}
