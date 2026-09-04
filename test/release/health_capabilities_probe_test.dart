import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = '.github/scripts/check-health-capabilities.py';

/// Exécute VRAIMENT le script, avec un corps JSON sur stdin.
///
/// On ne relit pas ses chaînes : une garde qui vérifie qu'un fichier « contient
/// le mot erreur » passe encore après que la règle a été inversée. Ici le
/// verdict testé est celui que la CI obtiendra.
Future<({int code, String out})> _run(String body) async {
  final process = await Process.start('python3', [_script]);
  process.stdin.write(body);
  await process.stdin.close();
  final out = await process.stdout.transform(utf8.decoder).join();
  final err = await process.stderr.transform(utf8.decoder).join();
  final code = await process.exitCode;
  return (code: code, out: '$out$err');
}

void main() {
  group('La sonde de capacités voit ce que live/ready ne voient pas', () {
    // Le 15/08/2026, clamd est mort. `live` et `ready` ont répondu 200 pendant
    // vingt jours pendant qu'AUCUN envoi de fichier ne passait : le processus
    // vivait, PostgreSQL répondait, et `AntivirusService` — fail-closed —
    // rendait 503 sur chaque document, chaque avatar, chaque pièce.
    test('configuré mais n\'analyse pas ⇒ ÉCHEC bruyant', () async {
      final r = await _run(jsonEncode({
        'status': 'ok',
        'antivirus': {'configured': true, 'scanning': false},
      }));
      expect(r.code, 1);
      expect(r.out, contains("N'ANALYSE PAS"));
      expect(r.out, contains('restart-clamav'),
          reason:
              'une alerte doit dire quoi faire, pas seulement ce qui casse');
    });

    test('analyse réellement ⇒ succès', () async {
      final r = await _run(jsonEncode({
        'antivirus': {'configured': true, 'scanning': true},
      }));
      expect(r.code, 0);
    });

    // Asymétrie voulue : ne pas configurer d'antivirus est un choix de
    // déploiement, pas une panne. En faire une alerte rendrait la sonde
    // inutilisable partout ailleurs qu'en production.
    test('non configuré ⇒ pas d\'alerte', () async {
      final r = await _run(jsonEncode({
        'antivirus': {'configured': false, 'scanning': false},
      }));
      expect(r.code, 0);
      expect(r.out, contains('non configuré'));
    });

    // Le piège le plus vicieux : un backend antérieur à cette sonde ne rapporte
    // rien. Traiter l'absence comme « rien à signaler » ferait passer un
    // déploiement en retard pour un service sain — exactement la confusion
    // qu'on cherche à supprimer.
    test('champ absent ⇒ ÉCHEC, jamais un silence rassurant', () async {
      final r = await _run(jsonEncode({
        'status': 'ok',
        'ai': {'configured': true},
      }));
      expect(r.code, 1);
      expect(r.out, contains('ne rapporte pas'));
    });

    test('réponse illisible ⇒ ÉCHEC', () async {
      expect((await _run('<html>502</html>')).code, 1);
      expect((await _run('')).code, 1);
      expect((await _run('[]')).code, 1);
    });
  });

  group('La sonde est branchée', () {
    test('uptime.yml appelle le script', () {
      final yaml = File('.github/workflows/uptime.yml').readAsStringSync();
      expect(yaml, contains('check-health-capabilities.py'),
          reason: 'la sonde existe mais rien ne l\'exécute');
      expect(yaml, contains('/api/health"'),
          reason: 'la sonde doit lire /api/health, pas live ni ready — '
              'ce sont eux qui étaient aveugles');
    });

    test('le script existe et est exécutable par python3', () {
      expect(File(_script).existsSync(), isTrue);
    });
  });

  // ── Une garde qui ne peut pas s'exécuter n'est pas une garde ─────────────
  //
  // Le job `probe` de `uptime.yml` démarre sur un workspace VIDE : il ne
  // faisait que des `curl`, et n'avait donc jamais eu besoin d'`actions/
  // checkout`. Y ajouter un appel à un script du dépôt sans checkout donne
  // `python3: can't open file` À CHAQUE exécution — une surveillance rouge en
  // permanence pour une raison étrangère à la production, ce qui est pire que
  // pas de surveillance du tout : on apprend à ignorer le rouge.
  //
  // L'invariant est général, pas propre à ce script : tout job qui exécute un
  // fichier de `.github/scripts/` doit avoir sorti le dépôt.
  group('Tout job qui exécute un script du dépôt le sort d\'abord', () {
    /// Retire les commentaires de ligne avant toute assertion.
    ///
    /// Sans ça, la garde se satisfait de sa PROPRE prose : le commentaire qui
    /// explique pourquoi le checkout est nécessaire contient les mots
    /// « actions/checkout », et un `contains` brut le trouve même après que
    /// l'étape a été supprimée. C'est ce qui s'est produit à la première
    /// écriture de ce test — la mutation est passée au vert.
    String withoutComments(String yaml) =>
        yaml.split('\n').where((l) => !RegExp(r'^\s*#').hasMatch(l)).join('\n');

    /// Découpe un workflow en blocs de job (clé indentée de 2 espaces sous `jobs:`).
    Map<String, String> jobBlocks(String yaml) {
      final jobsAt = yaml.indexOf(RegExp(r'^jobs:', multiLine: true));
      if (jobsAt < 0) return {};
      final body = yaml.substring(jobsAt);
      final starts = RegExp(r'^  ([a-zA-Z0-9_-]+):', multiLine: true)
          .allMatches(body)
          .toList();
      final out = <String, String>{};
      for (var i = 0; i < starts.length; i++) {
        final from = starts[i].start;
        final to = i + 1 < starts.length ? starts[i + 1].start : body.length;
        out[starts[i].group(1)!] = body.substring(from, to);
      }
      return out;
    }

    for (final path in [
      '.github/workflows/uptime.yml',
      '.github/workflows/vps-ops.yml',
      '.github/workflows/deploy.yml',
    ]) {
      test(path, () {
        final file = File(path);
        if (!file.existsSync()) return;
        jobBlocks(withoutComments(file.readAsStringSync()))
            .forEach((name, block) {
          if (!block.contains('.github/scripts/')) return;
          // Une ÉTAPE `- uses: actions/checkout`, pas la chaîne quelque part.
          expect(block, matches(RegExp(r'-\s*uses:\s*actions/checkout')),
              reason: 'le job `$name` de $path exécute un script du dépôt '
                  'sans avoir sorti le dépôt : il échouera sur '
                  '« can\'t open file » à chaque exécution');
        });
      });
    }
  });
}
