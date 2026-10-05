// La clé PostHog compilée dans l'archive iOS : le préflight la JOUE, il ne la
// lit pas seulement.
//
// Le 04/10/2026, deux constructions de la 55 ont été faites avec une clé fausse : la
// première avec une clé VIDE, la seconde avec une clé DOUBLÉE (la ligne de
// `read -rs` et celle de `flutter build` collées d'un coup). Le contrôle
// `strings … | grep -c '^phc_'` ne voit pas la clé doublée (un seul « phc_ » en
// début de ligne), et l'ancien préflight l'acceptait : préfixe `phc_` et au moins
// 40 caractères suffisaient.
//
// Ce test exécute VRAIMENT `scripts/preflight-ios-archive.sh` sur des
// `Generated.xcconfig` fabriqués. Les outils macOS (`codesign`, `security`,
// `plutil`) sont remplacés par des bouchons qui répondent « 0 » : la partie qui
// nous intéresse précède toute vérification de signature, et ainsi le test tourne
// aussi sur le CI Linux. Un Info.plist VIDE sert de preuve de passage : une clé
// acceptée fait échouer le script plus loin, sur « CFBundleIdentifier absent » ;
// une clé refusée l'arrête avant, sur un message qui nomme POSTHOG_API_KEY.
//
// Le script ne doit JAMAIS afficher la clé, même refusée : chaque cas le vérifie.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _script = 'scripts/preflight-ios-archive.sh';

/// Une ligne d'échec du préflight qui parle de la clé PostHog (le message de
/// SUCCÈS, lui, nomme aussi la clé : on ne cherche donc pas le seul mot).
final _posthogFailure = RegExp(r'ÉCHEC : [^\n]*POSTHOG_API_KEY', dotAll: false);

/// Une clé plausible : `phc_` suivi de [body] lettres et chiffres. La longueur
/// de la clé RÉELLE n'est lue nulle part dans le dépôt : la mémoire du projet
/// note 48 caractères au total pour la 55 (donc 44 après `phc_`), et les
/// contrôles n'en supposent aucune — ils exigent 30 à 60.
String _key(int body, {String seed = 'aB3dE5fG7hJ9kL1mN3pQ5rS7tV9wX1yZ3'}) {
  final buffer = StringBuffer();
  while (buffer.length < body) {
    buffer.write(seed);
  }
  return 'phc_${buffer.toString().substring(0, body)}';
}

String _expected(String name) {
  final match = RegExp('^$name="([^"]+)"', multiLine: true)
      .firstMatch(File(_script).readAsStringSync());
  expect(match, isNotNull, reason: '$name introuvable dans $_script');
  return match!.group(1)!;
}

class _Run {
  _Run(this.exitCode, this.output);
  final int exitCode;
  final String output;
}

void main() {
  final tools = ['bash', 'python3'];
  final missing = tools.where((tool) {
    try {
      return Process.runSync('which', [tool]).exitCode != 0;
    } on ProcessException {
      return true;
    }
  }).toList();

  late Directory sandbox;
  late String fakeBin;
  late String appPath;

  setUpAll(() {
    sandbox = Directory.systemTemp.createTempSync('kpb-preflight-posthog-');
    // Bouchons des outils macOS que le script exige AVANT de lire quoi que ce
    // soit : ils ne servent qu'à passer la vérification de présence.
    final bin = Directory('${sandbox.path}/bin')..createSync();
    for (final tool in ['codesign', 'security', 'plutil']) {
      final stub = File('${bin.path}/$tool')
        ..writeAsStringSync('#!/bin/sh\nexit 0\n');
      Process.runSync('chmod', ['+x', stub.path]);
    }
    fakeBin = bin.path;
    final app = Directory('${sandbox.path}/Runner.app')..createSync();
    File('${app.path}/Info.plist').writeAsStringSync('');
    appPath = app.path;
  });

  tearDownAll(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  /// Fabrique un `Generated.xcconfig` dont `DART_DEFINES` porte la clé donnée
  /// (`null` = aucune définition POSTHOG_API_KEY du tout).
  File xcconfig(String name, {String? posthog, List<String> extra = const []}) {
    final defines = <String>[
      'KPB_APP_ENV=prod',
      'KPB_WHATSAPP_NUMBER=+33768674292',
      if (posthog != null) 'POSTHOG_API_KEY=$posthog',
      ...extra,
    ];
    final encoded = defines.map((d) => base64Encode(utf8.encode(d))).join(',');
    return File('${sandbox.path}/$name.xcconfig')
      ..writeAsStringSync(
        'FLUTTER_BUILD_NAME=${_expected('EXPECTED_VERSION')}\n'
        'FLUTTER_BUILD_NUMBER=${_expected('EXPECTED_BUILD')}\n'
        'DART_DEFINES=$encoded\n',
      );
  }

  _Run run(File config, {bool postHogOnly = false}) {
    final result = Process.runSync(
      'bash',
      [
        _script,
        '--xcconfig',
        config.path,
        if (postHogOnly) '--posthog-only' else ...['--app', appPath],
      ],
      environment: {
        'PATH': '$fakeBin:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
      },
      includeParentEnvironment: true,
    );
    return _Run(result.exitCode, '${result.stdout}${result.stderr}');
  }

  /// Le script est allé PLUS LOIN que la clé : il échoue sur l'Info.plist vide.
  void expectKeyAccepted(_Run result, String key) {
    expect(result.output, isNot(contains(key)),
        reason: 'le script a affiché la clé');
    expect(result.output, isNot(matches(_posthogFailure)),
        reason: 'une clé valide ne doit pas être refusée :\n${result.output}');
    expect(result.output, contains('CFBundleIdentifier'),
        reason: 'le script aurait dû passer la clé puis échouer sur '
            'l\'Info.plist vide :\n${result.output}');
    expect(result.exitCode, isNot(0));
  }

  void expectKeyRefused(_Run result, String key, {String? because}) {
    expect(result.exitCode, isNot(0),
        reason: 'une clé refusée doit arrêter le préflight');
    if (key.isNotEmpty) {
      expect(result.output, isNot(contains(key)),
          reason: 'le script a affiché la clé :\n${result.output}');
    }
    expect(result.output, matches(_posthogFailure),
        reason: 'le refus doit nommer la clé :\n${result.output}');
    expect(result.output, isNot(contains('CFBundleIdentifier')),
        reason: 'le script est passé outre la clé :\n${result.output}');
    if (because != null) {
      expect(result.output, contains(because),
          reason: 'mauvaise raison de refus :\n${result.output}');
    }
  }

  final skipTools =
      missing.isEmpty ? null : 'outil absent : ${missing.join(', ')}';

  group('Préflight iOS : la clé PostHog compilée', skip: skipTools, () {
    test('une clé de projet plausible (phc_ + 43) passe', () {
      final key = _key(43);
      expectKeyAccepted(run(xcconfig('valid', posthog: key)), key);
    });

    test('une clé VIDE est refusée (la première build du 04/10)', () {
      expectKeyRefused(
        run(xcconfig('empty', posthog: '')),
        '',
        because: 'VIDE',
      );
    });

    test('une clé ABSENTE est refusée', () {
      expectKeyRefused(
        run(xcconfig('absent')),
        '',
        because: 'sans choix explicite',
      );
    });

    test('une clé DOUBLÉE est refusée (la seconde build du 04/10)', () {
      final one = _key(43);
      final doubled = '$one$one';
      // Elle commence bien par `phc_` et dépasse 40 caractères : c'est ce qui la
      // faisait passer. Le grep `^phc_` de la checklist n'y voit non plus qu'une
      // clé.
      expect(doubled.startsWith('phc_'), isTrue);
      expect(doubled.length, greaterThanOrEqualTo(40));
      final result = run(xcconfig('doubled', posthog: doubled));
      expectKeyRefused(result, doubled);
      // Le diagnostic donne la longueur et le verdict, jamais la valeur.
      expect(result.output, contains('${doubled.length}'));
    });

    test('une clé collée deux fois AVEC un séparateur est refusée aussi', () {
      final one = _key(43);
      for (final glue in ['-', ' ', 'é']) {
        final key = '$one$glue$one';
        expectKeyRefused(run(xcconfig('glue', posthog: key)), key);
      }
    });

    test('un SAUT DE LIGNE dans la valeur est refusé (clé en deux lignes)', () {
      // `POSTHOG_API_KEY=$(pbpaste)` avec la clé sur deux lignes dans le
      // presse-papiers : le define compilé porte un saut de ligne. L'ancien
      // décodage imprimait un define par LIGNE et ne regardait que la première :
      // « une seule clé phc_ … OK » pour une valeur de 95 caractères.
      final one = _key(43);
      final cases = <String, String>{
        'lf-doubled': '$one\n$one',
        'crlf-doubled': '$one\r\n$one',
        'trailing-lf': '$one\n',
        'trailing-crlf': '$one\r\n',
        'trailing-cr': '$one\r',
        'leading-lf': '\n$one',
        'lf-inside': '${one.substring(0, 20)}\n${one.substring(20)}',
      };
      for (final entry in cases.entries) {
        for (final onlyKey in [false, true]) {
          final result = run(
            xcconfig(entry.key, posthog: entry.value),
            postHogOnly: onlyKey,
          );
          expectKeyRefused(result, entry.value);
          // Le verdict ne doit jamais dire « une seule clé … OK ».
          expect(result.output.contains('— OK'), isFalse,
              reason: '${entry.key} : verdict « OK » pour une clé multiligne');
          if (!onlyKey) continue;
          expect(result.exitCode, 1, reason: entry.key);
        }
      }
    });

    test('un saut de ligne ne FABRIQUE pas une seconde définition', () {
      // « PHC…\nPOSTHOG_API_KEY=phc_… » : ce n'est ni une clé valide, ni deux
      // définitions dont l'une serait la bonne.
      final one = _key(43);
      final key = '$one\nPOSTHOG_API_KEY=$one';
      expectKeyRefused(run(xcconfig('forged', posthog: key)), key);
    });

    test('la forme réelle (phc_ + 44 = 48 caractères) passe aussi', () {
      final key = _key(44);
      expect(key.length, 48);
      expectKeyAccepted(run(xcconfig('real48', posthog: key)), key);
      final result =
          run(xcconfig('real48-only', posthog: key), postHogOnly: true);
      expect(result.exitCode, 0, reason: result.output);
      expect(result.output, contains('48 caractères'));
    });

    test('des caractères interdits sont refusés, où qu\'ils soient', () {
      final base = _key(43);
      final forbidden = <String>[
        '${base.substring(0, 20)}-${base.substring(21)}', // tiret
        '${base.substring(0, 20)}_${base.substring(21)}', // souligné interne
        '${base.substring(0, 20)} ${base.substring(21)}', // espace
        '$base ', // espace final
        '${base.substring(0, 20)}"${base.substring(21)}', // guillemet
        '${base.substring(0, 20)}é${base.substring(21)}', // accent
        '${base.substring(0, 20)}\$${base.substring(21)}', // dollar
        '${base.substring(0, 20)}=${base.substring(21)}', // égal
      ];
      for (final key in forbidden) {
        expectKeyRefused(run(xcconfig('forbidden', posthog: key)), key);
      }
    });

    test('mauvais préfixe : refusé', () {
      final key = 'phx_${_key(43).substring(4)}';
      expectKeyRefused(run(xcconfig('prefix', posthog: key)), key);
    });

    test(
        'les bornes : 36 caractères après phc_ passent, 35 non ; 60 passent, '
        '61 non', () {
      final ok36 = _key(36);
      final ok60 = _key(60);
      expectKeyAccepted(run(xcconfig('b36', posthog: ok36)), ok36);
      expectKeyAccepted(run(xcconfig('b60', posthog: ok60)), ok60);
      expectKeyRefused(run(xcconfig('b35', posthog: _key(35))), _key(35));
      expectKeyRefused(run(xcconfig('b61', posthog: _key(61))), _key(61));
    });

    test('une clé définie DEUX fois dans DART_DEFINES est refusée', () {
      final key = _key(43);
      final result = run(xcconfig(
        'twice',
        posthog: key,
        extra: [
          'POSTHOG_API_KEY=${_key(43, seed: 'zY8xW6vU4tS2rQ0pO8nM6lK4jI2hG0')}'
        ],
      ));
      expectKeyRefused(result, key);
    });

    test('ni la clé ni aucune de ses variantes ne sont jamais imprimées', () {
      final keys = <String>[
        _key(43),
        '${_key(43)}${_key(43)}',
        '${_key(20)}-${_key(20)}',
      ];
      for (final key in keys) {
        final out = run(xcconfig('leak', posthog: key)).output;
        expect(out, isNot(contains(key.substring(4, 24))),
            reason: 'un fragment de la clé est dans la sortie :\n$out');
      }
    });
  });

  group('Préflight iOS : --posthog-only (contrôle juste après le build)',
      skip: skipTools, () {
    // La checklist le lance dès la fin de `flutter build ios`, avant d'ouvrir
    // Xcode : une clé fausse se découvre en une minute et non après l'archive.
    test('clé valide : sortie 0, longueur et verdict, jamais la clé', () {
      final key = _key(43);
      final result = run(xcconfig('only-ok', posthog: key), postHogOnly: true);
      expect(result.exitCode, 0, reason: result.output);
      expect(result.output, isNot(contains(key)));
      expect(result.output, contains('${key.length}'));
      expect(result.output, contains('OK'));
    });

    test('clé doublée, vide ou absente : sortie non nulle', () {
      final one = _key(43);
      for (final entry in <String, String?>{
        'only-doubled': '$one$one',
        'only-empty': '',
        'only-absent': null,
      }.entries) {
        final result = run(
          xcconfig(entry.key, posthog: entry.value),
          postHogOnly: true,
        );
        expect(result.exitCode, isNot(0), reason: entry.key);
        expect(result.output, matches(_posthogFailure), reason: entry.key);
        expect(result.output, isNot(contains(one)), reason: entry.key);
      }
    });

    test('ne demande ni bundle ni outil de signature', () {
      // Aucun --app : le mode ne doit pas tomber sur l'usage.
      final result = Process.runSync(
        'bash',
        [
          _script,
          '--xcconfig',
          xcconfig('only-noapp', posthog: _key(43)).path,
          '--posthog-only',
        ],
        environment: {'PATH': '/usr/bin:/bin'},
        includeParentEnvironment: false,
      );
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });
  });

  group('La checklist montre le même contrôle', () {
    test('elle ne le décrit pas à la main : elle lance le préflight', () {
      final checklist =
          File('docs/mise-a-jour-55-checklist.md').readAsStringSync();
      expect(checklist, contains('--posthog-only'));
      expect(checklist, contains(r'${#POSTHOG_API_KEY}'));
    });

    test('elle ne fige pas une longueur que le dépôt ne connaît pas', () {
      // La longueur de la vraie clé n'est lue nulle part ici ; la mémoire du
      // projet la donne à 48 pour la 55. « 47 » / « 94 » étaient supposés.
      final checklist =
          File('docs/mise-a-jour-55-checklist.md').readAsStringSync();
      for (final banned in ['**47**', '**94**', '47 caractères', '= 47']) {
        expect(checklist.contains(banned), isFalse,
            reason: 'la checklist fige « $banned » comme longueur attendue');
      }
      expect(checklist, contains('Project settings'),
          reason: 'elle doit dire où comparer la longueur à la vraie clé');
    });

    test('la preuve des sondes échoue quand elle est vide ou insuffisante', () {
      // `gh run list` a rendu `[]` alors que 4 à 5 sondes existaient : le jq de
      // la checklist rendait {"hors_succes":0,"sondes":0}, qui SATISFAIT
      // « hors_succes = 0 ». Une preuve vide n'est pas une preuve : le filtre
      // doit faire échouer la commande.
      final checklist =
          File('docs/mise-a-jour-55-checklist.md').readAsStringSync();
      final match = RegExp(r"--jq '([^']+)'", dotAll: true)
          .firstMatch(checklist.substring(checklist.indexOf('gh run list')));
      expect(match, isNotNull, reason: 'le filtre --jq a disparu');
      final filter = match!.group(1)!;
      if (Process.runSync('which', ['jq']).exitCode != 0) {
        markTestSkipped('jq absent');
        return;
      }

      String stamp(Duration ago) => DateTime.now()
          .toUtc()
          .subtract(ago)
          .toIso8601String()
          .replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
      Map<String, Object?> probe(Duration ago, String conclusion) => {
            'createdAt': stamp(ago),
            'conclusion': conclusion,
            'status': 'completed',
          };
      ProcessResult jq(List<Map<String, Object?>> runs) {
        // `gh --jq` est un jq : on joue le même programme sur la même forme.
        final dir = Directory.systemTemp.createTempSync('kpb-jq-');
        try {
          final input = File('${dir.path}/runs.json')
            ..writeAsStringSync(jsonEncode(runs));
          return Process.runSync('jq', ['-e', filter, input.path]);
        } finally {
          dir.deleteSync(recursive: true);
        }
      }

      final good = [
        for (final h in [1, 6, 11, 17, 22])
          probe(Duration(hours: h), 'success'),
      ];
      final ok = jq(good);
      expect(ok.exitCode, 0, reason: '${ok.stdout}${ok.stderr}');
      expect(ok.stdout, contains('"sondes": 5'));

      final empty = jq(const []);
      expect(empty.exitCode, isNot(0),
          reason: 'zéro sonde ne doit PAS passer pour une preuve :\n'
              '${empty.stdout}');
      final tooFew = jq([probe(const Duration(hours: 2), 'success')]);
      expect(tooFew.exitCode, isNot(0), reason: 'une sonde ne prouve rien');
      final oneFailure = jq([
        ...good,
        probe(const Duration(hours: 9), 'failure'),
      ]);
      expect(oneFailure.exitCode, isNot(0),
          reason: 'un échec réel dans les 24 h doit faire échouer la commande');
      // Une sonde ancienne (hors fenêtre) ne compte pas.
      final stale = jq([
        for (final h in [30, 40, 50]) probe(Duration(hours: h), 'success'),
      ]);
      expect(stale.exitCode, isNot(0), reason: 'hors fenêtre de 24 h');

      expect(checklist, contains("n'est PAS une preuve"),
          reason:
              'la checklist doit dire que sondes = 0 n\'est pas une preuve');
    });

    test('la saisie de la clé est SÉPARÉE de la construction', () {
      // Le 04/10, deux lignes collées d'un coup : `read -rs` a avalé la suivante.
      // Une commande qui lit un secret vit seule dans son bloc, jamais collée à
      // `flutter build`.
      final checklist =
          File('docs/mise-a-jour-55-checklist.md').readAsStringSync();
      final blocks = RegExp(r'```[a-z]*\n(.*?)```', dotAll: true)
          .allMatches(checklist)
          .map((m) => m.group(1)!)
          .toList();
      final readers =
          blocks.where((b) => b.contains('read -rs POSTHOG_API_KEY')).toList();
      expect(readers, isNotEmpty,
          reason: 'la checklist ne montre plus la saisie de la clé');
      for (final block in readers) {
        expect(block, isNot(contains('flutter build')),
            reason:
                '`read -rs` et `flutter build` dans le même bloc :\n$block');
      }
    });
  });
}
