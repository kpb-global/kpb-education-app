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
    test('configuré mais injoignable ⇒ ÉCHEC bruyant', () async {
      final r = await _run(jsonEncode({
        'status': 'ok',
        'antivirus': {'configured': true, 'reachable': false},
      }));
      expect(r.code, 1);
      expect(r.out, contains('INJOIGNABLE'));
      expect(r.out, contains('restart-clamav'),
          reason:
              'une alerte doit dire quoi faire, pas seulement ce qui casse');
    });

    test('joignable ⇒ succès', () async {
      final r = await _run(jsonEncode({
        'antivirus': {'configured': true, 'reachable': true},
      }));
      expect(r.code, 0);
    });

    // Asymétrie voulue : ne pas configurer d'antivirus est un choix de
    // déploiement, pas une panne. En faire une alerte rendrait la sonde
    // inutilisable partout ailleurs qu'en production.
    test('non configuré ⇒ pas d\'alerte', () async {
      final r = await _run(jsonEncode({
        'antivirus': {'configured': false, 'reachable': false},
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
}
