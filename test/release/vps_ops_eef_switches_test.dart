// Les interrupteurs de la 56 dans « VPS ops » : bulle et écoles privées.
//
// Quatre actions : `eef-bubble-on` / `-off` et `eef-private-schools-on` /
// `-off`, sur le modèle d'`eef-space-on` / `-off`. Ce fichier ne se contente pas
// de LIRE le script et le workflow : il les JOUE.
//
//   • le script `vps-ops.sh` est exécuté pour de bon, avec un faux `docker` qui
//     consigne ses appels, dans un répertoire jetable. On voit donc ce qui est
//     écrit dans le `.env`, ce qui est recréé, et surtout ce qui ne l'est PAS
//     (la simulation) ;
//   • les programmes Python des étapes de preuve du workflow sont extraits du
//     YAML et exécutés sur des réponses `/config/app` fabriquées. Une assertion
//     qu'on n'a jamais vue échouer ne prouve rien — et le workflow, lui, ne
//     tourne que sur GitHub, avec l'écriture en production pour seul essai.
//
// Pourquoi tant de soin : plusieurs fois sur ce projet, l'étape de preuve d'une
// opération n'a jamais pu s'exécuter (apostrophe dans le programme Python,
// étape lue avant que l'API réponde). Une preuve qui ne tourne pas est pire
// qu'une preuve absente : on croit avoir vérifié.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _scriptPath = '.github/scripts/vps-ops.sh';
const _workflowPath = '.github/workflows/vps-ops.yml';

/// Une action de drapeau : sa variable d'environnement, sa clé `/config/app`, et
/// ce qu'elle fait.
class _Switch {
  const _Switch(this.action, this.envKey, this.jsonKey, this.opens);
  final String action;
  final String envKey;
  final String jsonKey;
  final bool opens;
}

const _switches = <_Switch>[
  _Switch(
      'eef-bubble-on', 'KPB_EEF_HELP_BUBBLE_ENABLED', 'eefHelpBubble', true),
  _Switch(
      'eef-bubble-off', 'KPB_EEF_HELP_BUBBLE_ENABLED', 'eefHelpBubble', false),
  _Switch('eef-private-schools-on', 'KPB_EEF_PRIVATE_SCHOOLS_ENABLED',
      'eefPrivateSchools', true),
  _Switch('eef-private-schools-off', 'KPB_EEF_PRIVATE_SCHOOLS_ENABLED',
      'eefPrivateSchools', false),
];

/// Toutes les clés que `.env` peut porter pour cet espace : aucune action de
/// drapeau ne doit toucher une autre que la sienne.
const _eefEnvKeys = <String>[
  'KPB_EEF_TEASER_ENABLED',
  'KPB_EEF_SPACE_ENABLED',
  'KPB_EEF_ENABLED',
  'KPB_EEF_HELP_BUBBLE_ENABLED',
  'KPB_EEF_PRIVATE_SCHOOLS_ENABLED',
  'KPB_EEF_CAMPAIGN_OPENS_AT',
  'KPB_EEF_SUSPENDED_COUNTRIES',
  'KPB_RECOMMENDED_APP_VERSION',
  'KPB_MIN_APP_VERSION',
];

// ── Un faux `docker`, qui répond juste assez pour que le script s'exécute ────
//
// Il consigne chaque appel dans $FAKE_DOCKER_LOG et refuse (code 99) tout appel
// qu'il ne connaît pas : un script qui se mettrait à appeler autre chose que ce
// que ce test a prévu fait rougir le test, il ne passe pas en silence.
//
// `compose exec -T api grep …` n'est PAS une réponse figée : le faux conteneur est
// un vrai répertoire ($FAKE_CONTAINER_ROOT) et le vrai `grep` y est exécuté. Le
// garde « le backend déployé SERT la clé » est donc vu rouge si la clé cherchée ou
// le fichier visé change : avec une réponse figée, on pouvait le vider de son sens
// (`grep -q eefSpace` sur un autre chemin) sans qu'aucun test ne bouge.
const _fakeDocker = r'''#!/usr/bin/env bash
echo "$*" >> "$FAKE_DOCKER_LOG"
case "$*" in
  "inspect -f {{.Config.Image}} kpb_api") echo "kpb-backend:abc123" ;;
  "inspect -f {{.Image}} kpb_api") echo "sha256:img1" ;;
  "inspect -f {{range .Config.Env}}{{println .}}{{end}} kpb_api") echo "KPB_BUILD_SHA=deadbeef" ;;
  "compose exec -T api grep "*)
    shift 4
    (cd "$FAKE_CONTAINER_ROOT" && "$@") ;;
  "compose up -d --no-deps --no-build api") : ;;
  *) echo "faux docker : appel inconnu : $*" >&2; exit 99 ;;
esac
''';

/// Les clés `features.*` que sert le contrôleur compilé d'un backend « 56 ».
const _keys56 = <String>{'eefHelpBubble', 'eefPrivateSchools'};

/// Le contenu du contrôleur compilé d'un faux conteneur : `eefSpace` y est
/// toujours (un backend de la 55 le sert), [serves] ajoute les clés de la 56.
String _compiledController(Set<String> serves) => [
      'features: {',
      '  eefTeaser, eef, eefSpace,',
      for (final key in serves) '  $key,',
      '}',
    ].join('\n');

const _controllerInContainer = 'dist/modules/config/app-config.controller.js';

class _Run {
  _Run(this.exitCode, this.output, this.env, this.dockerCalls, this.backups);
  final int exitCode;
  final String output;

  /// Le `.env` APRÈS l'exécution.
  final String env;
  final List<String> dockerCalls;

  /// Les sauvegardes `.env.bak.*` laissées dans le répertoire.
  final List<String> backups;

  bool get recreated => dockerCalls
      .any((c) => c.startsWith('compose up -d --no-deps --no-build'));

  /// Valeur d'une clé dans le `.env` final (la DERNIÈRE occurrence, comme Node).
  String? value(String key) {
    String? found;
    for (final line in const LineSplitter().convert(env)) {
      if (line.startsWith('$key=')) found = line.substring(key.length + 1);
    }
    return found;
  }
}

/// Exécute `vps-ops.sh` pour de bon dans un répertoire jetable.
///
/// [composeText] est, par défaut, le VRAI `docker-compose.yml` du dépôt : le
/// garde-fou `require_relay` lit donc le relais réel, pas une copie de test.
_Run _runOps(
  String action, {
  String? dryRun,
  String initialEnv = 'KPB_EEF_TEASER_ENABLED=true\n'
      'KPB_EEF_SPACE_ENABLED=true\n'
      'KPB_EEF_ENABLED=false\n'
      'KPB_MIN_APP_VERSION=0.0.0\n',
  String? composeText,
  Set<String> backendServes = _keys56,
}) {
  final root = Directory.systemTemp.createTempSync('vps_ops_switch_');
  addTearDown(() => root.deleteSync(recursive: true));

  final vps = Directory('${root.path}/vps')..createSync();
  final bin = Directory('${root.path}/bin')..createSync();
  File('${vps.path}/.env').writeAsStringSync(initialEnv);
  File('${vps.path}/docker-compose.yml').writeAsStringSync(
      composeText ?? File('docker-compose.yml').readAsStringSync());
  final container = Directory('${root.path}/container')..createSync();
  File('${container.path}/$_controllerInContainer')
    ..createSync(recursive: true)
    ..writeAsStringSync(_compiledController(backendServes));
  final docker = File('${bin.path}/docker')..writeAsStringSync(_fakeDocker);
  Process.runSync('chmod', ['+x', docker.path]);
  final log = File('${root.path}/docker.log')..writeAsStringSync('');

  final result = Process.runSync(
    'bash',
    [File(_scriptPath).absolute.path],
    environment: {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'VPS_PATH': vps.path,
      'ACTION': action,
      if (dryRun != null) 'DRY_RUN': dryRun,
      'FAKE_DOCKER_LOG': log.path,
      'FAKE_CONTAINER_ROOT': container.path,
    },
    includeParentEnvironment: false,
  );

  return _Run(
    result.exitCode,
    '${result.stdout}\n${result.stderr}',
    File('${vps.path}/.env').readAsStringSync(),
    log.readAsLinesSync().where((l) => l.isNotEmpty).toList(),
    vps
        .listSync()
        .map((e) => e.path.split('/').last)
        .where((n) => n.startsWith('.env.bak.'))
        .toList(),
  );
}

/// Le texte d'une étape du workflow, de son `- name:` au suivant.
String _step(String workflow, String namePrefix) {
  final starts = RegExp(r'^      - name: (.*)$', multiLine: true)
      .allMatches(workflow)
      .toList();
  for (var i = 0; i < starts.length; i++) {
    if (starts[i].group(1)!.startsWith(namePrefix)) {
      final end = i + 1 < starts.length ? starts[i + 1].start : workflow.length;
      return workflow.substring(starts[i].start, end);
    }
  }
  fail('Étape « $namePrefix… » introuvable dans $_workflowPath');
}

/// Le programme Python d'une étape : entre `python3 -c '` et `' < "$config"`.
///
/// Tel que YAML le livre à bash, c'est-à-dire déjà dédenté de l'indentation du
/// bloc `run: |` : c'est exactement ce que Python recevra sur le runner.
String _pythonProgram(String step) {
  final match =
      RegExp(r'''python3 -c '\n(.*?)\n[ ]*' < "\$config"''', dotAll: true)
          .firstMatch(step);
  expect(match, isNotNull,
      reason: 'programme `python3 -c \'…\' < "\$config"` introuvable');
  return match!.group(1)!;
}

/// Le bloc `run: |` d'une étape, dédenté comme le runner le fait : les 10
/// espaces d'indentation YAML retirés, et rien d'autre.
String _runScript(String step) {
  final lines = step.split('\n');
  final at = lines.indexWhere((l) => l == '        run: |');
  expect(at, greaterThan(-1), reason: 'pas de `run: |` dans l\'étape');
  final body = <String>[];
  for (final line in lines.skip(at + 1)) {
    if (line.trim().isNotEmpty && !line.startsWith(' ' * 10)) break;
    body.add(line.length >= 10 ? line.substring(10) : '');
  }
  return body.join('\n');
}

/// Le bloc `env:` d'une étape : variable -> expression telle qu'écrite.
Map<String, String> _envBlock(String step) {
  final lines = step.split('\n');
  final at = lines.indexWhere((l) => l == '        env:');
  if (at < 0) return const {};
  final env = <String, String>{};
  for (final line in lines.skip(at + 1)) {
    final m = RegExp(r'^          (\w+): (.*)$').firstMatch(line);
    if (m == null) break;
    env[m.group(1)!] = m.group(2)!;
  }
  return env;
}

const _healthUrl = 'http://kpb.test';

/// Un faux `curl` : consigne ses arguments, copie la réponse prévue vers
/// l'argument de `-o`, ou échoue comme `curl -f` sur une 404 (code 22).
const _fakeCurl = r'''#!/usr/bin/env bash
echo "$*" >> "$FAKE_CURL_LOG"
[ "${FAKE_CURL_FAIL:-0}" = "1" ] && exit 22
out=""; prev=""
for arg in "$@"; do
  [ "$prev" = "-o" ] && out="$arg"
  prev="$arg"
done
cp "$FAKE_CONFIG" "$out"
''';

class _StepRun {
  _StepRun(this.code, this.output, this.githubEnv, this.curlCalls);
  final int code;
  final String output;

  /// Ce que l'étape a écrit dans `$GITHUB_ENV` (lu par les étapes suivantes).
  final String githubEnv;
  final List<String> curlCalls;

  /// La valeur d'une variable posée dans `$GITHUB_ENV`.
  String? exported(String key) {
    String? found;
    for (final line in const LineSplitter().convert(githubEnv)) {
      if (line.startsWith('$key=')) found = line.substring(key.length + 1);
    }
    return found;
  }
}

/// Joue UNE étape du workflow comme le runner : son `run:` dédenté, sous
/// `bash -e`, avec EXACTEMENT les variables de son bloc `env:` (une expression
/// inconnue fait échouer le test) et celles que les étapes précédentes ont posées
/// dans `$GITHUB_ENV` ([priorGithubEnv]).
///
/// [config] est la réponse de `/api/config/app` ; `null` = l'API ne répond pas.
_StepRun _playStep(
  String step, {
  required String action,
  required Map<String, Object?>? config,
  String priorGithubEnv = '',
}) {
  final root = Directory.systemTemp.createTempSync('vps_ops_step_');
  addTearDown(() => root.deleteSync(recursive: true));
  final bin = Directory('${root.path}/bin')..createSync();
  final curl = File('${bin.path}/curl')..writeAsStringSync(_fakeCurl);
  Process.runSync('chmod', ['+x', curl.path]);
  final curlLog = File('${root.path}/curl.log')..writeAsStringSync('');
  final configFile = File('${root.path}/served.json')
    ..writeAsStringSync(jsonEncode(config ?? const {}));
  final githubEnv = File('${root.path}/github_env')
    ..writeAsStringSync(priorGithubEnv);
  final script = File('${root.path}/step.sh')
    ..writeAsStringSync(_runScript(step));

  final env = <String, String>{};
  for (final entry in _envBlock(step).entries) {
    switch (entry.value) {
      case r'${{ secrets.VPS_HEALTH_URL }}':
        env[entry.key] = _healthUrl;
      case r'${{ inputs.action }}':
        env[entry.key] = action;
      default:
        fail('${entry.key}: expression « ${entry.value} » non gérée par le '
            'test : elle n\'est donc pas jouée');
    }
  }
  for (final line in const LineSplitter().convert(priorGithubEnv)) {
    final i = line.indexOf('=');
    if (i > 0) env[line.substring(0, i)] = line.substring(i + 1);
  }

  final result = Process.runSync(
    'bash',
    ['-e', script.path],
    environment: {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'TMPDIR': root.path,
      'GITHUB_ENV': githubEnv.path,
      'FAKE_CURL_LOG': curlLog.path,
      'FAKE_CONFIG': configFile.path,
      if (config == null) 'FAKE_CURL_FAIL': '1',
      ...env,
    },
    includeParentEnvironment: false,
  );
  return _StepRun(
    result.exitCode,
    '${result.stdout}\n${result.stderr}',
    githubEnv.readAsStringSync(),
    curlLog.readAsLinesSync().where((l) => l.isNotEmpty).toList(),
  );
}

/// Ce que `/config/app` sert, pour les cas de preuve. Une clé à `null` est
/// ABSENTE de la réponse (ancien backend), pas « fausse ».
Map<String, Object?> _served({
  Object? bubble,
  Object? schools,
  Object? space = true,
  Object? eef = false,
}) =>
    {
      'features': {
        'eefTeaser': true,
        if (eef != null) 'eef': eef,
        if (space != null) 'eefSpace': space,
        if (bubble != null) 'eefHelpBubble': bubble,
        if (schools != null) 'eefPrivateSchools': schools,
      },
    };

/// La même réponse, avec la clé de [s] à [value] et l'autre interrupteur à
/// [other].
Map<String, Object?> _servedFor(
  _Switch s,
  Object? value, {
  Object? other,
  Object? space = true,
  Object? eef = false,
}) {
  final bubble = s.jsonKey == 'eefHelpBubble';
  return _served(
    bubble: bubble ? value : other,
    schools: bubble ? other : value,
    space: space,
    eef: eef,
  );
}

/// Les `inputs.action` du menu du workflow.
List<String> _menuActions(String workflow) =>
    RegExp(r'options:\s*\n((?:\s*- \S+\n)+)')
        .firstMatch(workflow)!
        .group(1)!
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('- '))
        .map((l) => l.substring(2))
        .toList();

/// Évalue la condition `if:` d'une étape pour chaque (action, dry_run) : la
/// grammaire est celle de GitHub réduite à ce que ces conditions emploient
/// (`==`, `!`, `&&`, `||`, `success()`). Une fonction inconnue fait échouer Python,
/// donc le test, plutôt que de passer en silence.
Map<String, bool> _evalIf(String step, List<String> actions) {
  final raw = RegExp(r'^        if: \$\{\{ (.*) \}\}$', multiLine: true)
      .firstMatch(step)
      ?.group(1);
  expect(raw, isNotNull,
      reason: "pas de `if:` en expression GitHub dans l'étape");
  final python = raw!
      .replaceAllMapped(RegExp(r"inputs\.action == '([^']+)'"),
          (m) => "(A == '${m.group(1)}')")
      .replaceAll('inputs.dry_run', 'D')
      .replaceAll('success()', 'True')
      .replaceAll('&&', ' and ')
      .replaceAll('||', ' or ')
      .replaceAll('!', ' not ');
  final program = '''
import json, sys
out = {}
for a in json.loads(sys.argv[1]):
    for d in (True, False):
        out["%s|%s" % (a, str(d).lower())] = bool(eval(sys.argv[2], {}, {"A": a, "D": d}))
print(json.dumps(out))
''';
  final result =
      Process.runSync('python3', ['-c', program, jsonEncode(actions), python]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return (jsonDecode(result.stdout as String) as Map<String, dynamic>)
      .cast<String, bool>();
}

void main() {
  final script = File(_scriptPath).readAsStringSync();
  final workflow = File(_workflowPath).readAsStringSync();

  test('le script est de la syntaxe bash valide', () {
    // `bash -n` lit sans exécuter : une apostrophe ou un `fi` oublié dans une
    // des quatre branches neuves est attrapé ici, pas sur le VPS.
    final result = Process.runSync('bash', ['-n', _scriptPath]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  group('le menu', () {
    final options = RegExp(r'options:\s*\n((?:\s*- \S+\n)+)')
        .firstMatch(workflow)!
        .group(1)!;

    for (final s in _switches) {
      test('${s.action} est proposée', () {
        expect(options, contains('- ${s.action}\n'));
      });

      test('${s.action} a sa branche dans le script', () {
        expect(script, contains('\n  ${s.action})\n'));
      });
    }

    test('la simulation est annoncée pour les deux actions d\'ouverture', () {
      final description = RegExp(r"description: 'Simuler seulement \(([^)]*)\)")
          .firstMatch(workflow)!
          .group(1)!;
      expect(description, contains('eef-bubble-on'));
      expect(description, contains('eef-private-schools-on'));
      // Les retours arrière n'ont PAS de simulation : ils ne doivent pas
      // laisser croire qu'un « dry_run » coché les retiendrait.
      expect(description, isNot(contains('eef-bubble-off')));
      expect(description, isNot(contains('eef-private-schools-off')));
    });
  });

  // ── Le script, joué ───────────────────────────────────────────────────────
  for (final s in _switches.where((s) => s.opens)) {
    group('${s.action} — ouvre ${s.jsonKey}', () {
      test('SIMULATION par défaut : DRY_RUN absent, rien n\'est écrit', () {
        final run = _runOps(s.action);

        expect(run.exitCode, 0, reason: run.output);
        expect(run.output, contains('SIMULATION'));
        expect(run.value(s.envKey), isNull,
            reason: 'la simulation a écrit dans le .env');
        expect(run.recreated, isFalse,
            reason: 'la simulation a recréé kpb_api');
        expect(run.backups, isEmpty);
      });

      test('SIMULATION aussi quand dry_run vaut « true »', () {
        final run = _runOps(s.action, dryRun: 'true');

        expect(run.exitCode, 0, reason: run.output);
        expect(run.value(s.envKey), isNull);
        expect(run.recreated, isFalse);
      });

      test('une valeur de dry_run inattendue SIMULE aussi (échec fermé)', () {
        // On n'écrit que sur un « false » explicite : ce qui ouvre une surface
        // aux étudiants ne se déclenche pas sur une faute de frappe.
        for (final odd in ['', 'oui', 'True', '0', 'no']) {
          final run = _runOps(s.action, dryRun: odd);
          expect(run.exitCode, 0, reason: '$odd : ${run.output}');
          expect(run.value(s.envKey), isNull, reason: 'dry_run=« $odd »');
          expect(run.recreated, isFalse, reason: 'dry_run=« $odd »');
        }
      });

      test('la simulation CONTRÔLE quand même (backend sans la clé = refus)',
          () {
        final run = _runOps(s.action, backendServes: const {});

        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.output, contains('::error::'));
        expect(run.output, contains(s.jsonKey));
        expect(run.recreated, isFalse);
      });

      test('application : pose SA clé à true, recrée api, sauvegarde le .env',
          () {
        final run = _runOps(s.action, dryRun: 'false');

        expect(run.exitCode, 0, reason: run.output);
        expect(run.value(s.envKey), 'true');
        expect(run.recreated, isTrue);
        expect(run.backups, hasLength(1), reason: 'pas de sauvegarde du .env');
        // Recréation À L'IDENTIQUE : jamais de reconstruction.
        expect(run.dockerCalls,
            contains('compose up -d --no-deps --no-build api'));
        expect(run.dockerCalls.where((c) => c.contains('build api')),
            hasLength(1));
      });

      test('application : AUCUNE autre clé du .env ne bouge', () {
        const before = 'KPB_EEF_TEASER_ENABLED=true\n'
            'KPB_EEF_SPACE_ENABLED=false\n'
            'KPB_EEF_ENABLED=false\n'
            'KPB_EEF_HELP_BUBBLE_ENABLED=false\n'
            'KPB_EEF_PRIVATE_SCHOOLS_ENABLED=false\n'
            'KPB_MIN_APP_VERSION=2.0.0\n';
        final run = _runOps(s.action, dryRun: 'false', initialEnv: before);

        expect(run.exitCode, 0, reason: run.output);
        for (final key in _eefEnvKeys.where((k) => k != s.envKey)) {
          final expected = RegExp('^$key=(.*)\$', multiLine: true)
              .firstMatch(before)
              ?.group(1);
          expect(run.value(key), expected, reason: '$key a bougé');
        }
        expect(run.value(s.envKey), 'true');
        // Et la clé est REMPLACÉE, pas dupliquée.
        expect(RegExp('^${s.envKey}=', multiLine: true).allMatches(run.env),
            hasLength(1));
      });

      test('application : pose la clé même absente du .env', () {
        final run = _runOps(s.action,
            dryRun: 'false', initialEnv: 'KPB_EEF_SPACE_ENABLED=true\n');

        expect(run.exitCode, 0, reason: run.output);
        expect(run.value(s.envKey), 'true');
        expect(run.value('KPB_EEF_SPACE_ENABLED'), 'true');
      });

      test(
          'application : un .env SANS saut de ligne final ne voit pas sa '
          'dernière ligne altérée', () {
        // La clé de l'interrupteur n'existe pas encore dans le .env du VPS : le
        // premier passage AJOUTE une ligne. Sans saut de ligne final, elle se
        // collait au bout de la dernière (ici un secret) et api repartait avec
        // un mot de passe altéré.
        final run = _runOps(s.action,
            dryRun: 'false',
            initialEnv: 'KPB_EEF_SPACE_ENABLED=true\nPOSTGRES_PASSWORD=s3cret');

        expect(run.exitCode, 0, reason: run.output);
        expect(run.value('POSTGRES_PASSWORD'), 's3cret');
        expect(run.value('KPB_EEF_SPACE_ENABLED'), 'true');
        expect(run.value(s.envKey), 'true');
      });

      test('application : un .env VIDE reçoit la clé sur sa première ligne',
          () {
        final run = _runOps(s.action, dryRun: 'false', initialEnv: '');

        expect(run.exitCode, 0, reason: run.output);
        expect(run.env, '${s.envKey}=true\n');
      });

      test(
          'refuse si la clé n\'est pas relayée par compose (poser le .env '
          'n\'aurait aucun effet)', () {
        final compose = File('docker-compose.yml')
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.contains('- ${s.envKey}='))
            .join('\n');
        final run = _runOps(s.action, dryRun: 'false', composeText: compose);

        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.output, contains(s.envKey));
        expect(run.value(s.envKey), isNull);
        expect(run.recreated, isFalse);
      });

      test('refuse un backend qui ne porte pas le code qui sert la clé', () {
        final run = _runOps(s.action, dryRun: 'false', backendServes: const {});

        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.output, contains('Déployer d\'abord le backend'));
        expect(run.value(s.envKey), isNull);
        expect(run.recreated, isFalse);
        expect(run.backups, isEmpty);
      });

      test(
          'le garde cherche SA clé, dans le contrôleur COMPILÉ du conteneur '
          '(la ligne exacte est consignée)', () {
        final run = _runOps(s.action, dryRun: 'false');

        expect(run.exitCode, 0, reason: run.output);
        expect(
            run.dockerCalls,
            contains('compose exec -T api grep -q ${s.jsonKey} '
                '$_controllerInContainer'));
        // Et une seule clé est cherchée : jamais celle de l'autre interrupteur.
        final greps =
            run.dockerCalls.where((c) => c.startsWith('compose exec')).toList();
        expect(greps, hasLength(1));
      });

      test('un backend qui ne sert QUE sa clé suffit', () {
        final run =
            _runOps(s.action, dryRun: 'false', backendServes: {s.jsonKey});

        expect(run.exitCode, 0, reason: run.output);
        expect(run.value(s.envKey), 'true');
      });

      test(
          'un backend qui ne sert que l\'AUTRE clé est refusé (le garde '
          'dépend de la clé de l\'action)', () {
        final other = _keys56.firstWhere((k) => k != s.jsonKey);
        final run = _runOps(s.action, dryRun: 'false', backendServes: {other});

        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.output, contains('features.${s.jsonKey}'));
        expect(run.value(s.envKey), isNull);
        expect(run.recreated, isFalse);
        expect(run.backups, isEmpty);
      });

      test(
          'un backend de la 55 (sert eefSpace, pas les clés de la 56) est '
          'refusé : c\'est le piège que le garde existe pour fermer', () {
        // `_compiledController` porte toujours eefSpace : un garde qui
        // chercherait cette clé-là laisserait passer cette image.
        final run =
            _runOps(s.action, dryRun: 'false', backendServes: const <String>{});

        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.output, contains('Déployer d\'abord le backend'));
        expect(run.value(s.envKey), isNull);
        expect(run.recreated, isFalse);
      });

      test('espace fermé dans le .env : prévient, ne bloque pas', () {
        // Ordre d'ouverture : espace d'abord. Mais la recette allume et éteint
        // dans le désordre ; un avertissement, pas un refus.
        final run = _runOps(s.action,
            dryRun: 'true', initialEnv: 'KPB_EEF_SPACE_ENABLED=false\n');

        expect(run.exitCode, 0, reason: run.output);
        expect(run.output, contains('eef-space-on'));
      });
    });
  }

  for (final s in _switches.where((s) => !s.opens)) {
    group('${s.action} — ferme ${s.jsonKey}', () {
      test('AGIT tout de suite, même avec dry_run coché (retour arrière)', () {
        // Comme `eef-space-off` : un retour arrière qu'une case cochée par
        // défaut transformerait en simulation serait un retour arrière qui ne
        // revient pas.
        for (final dryRun in [null, 'true', 'false']) {
          final run = _runOps(s.action,
              dryRun: dryRun,
              initialEnv: 'KPB_EEF_SPACE_ENABLED=true\n'
                  '${s.envKey}=true\n');

          expect(run.exitCode, 0, reason: 'dry_run=$dryRun : ${run.output}');
          expect(run.value(s.envKey), 'false', reason: 'dry_run=$dryRun');
          expect(run.recreated, isTrue, reason: 'dry_run=$dryRun');
          expect(run.backups, hasLength(1));
        }
      });

      test('ne touche à aucune autre clé', () {
        const before = 'KPB_EEF_TEASER_ENABLED=true\n'
            'KPB_EEF_SPACE_ENABLED=true\n'
            'KPB_EEF_HELP_BUBBLE_ENABLED=true\n'
            'KPB_EEF_PRIVATE_SCHOOLS_ENABLED=true\n';
        final run = _runOps(s.action, initialEnv: before);

        expect(run.exitCode, 0, reason: run.output);
        for (final key in _eefEnvKeys.where((k) => k != s.envKey)) {
          final expected = RegExp('^$key=(.*)\$', multiLine: true)
              .firstMatch(before)
              ?.group(1);
          expect(run.value(key), expected, reason: '$key a bougé');
        }
        expect(run.value(s.envKey), 'false');
      });

      test('ne dépend PAS du code déployé : on doit pouvoir TOUJOURS fermer',
          () {
        // Un retour arrière refusé parce que le backend est ancien ne
        // servirait à rien : la clé est alors déjà ignorée.
        final run = _runOps(s.action,
            initialEnv: '${s.envKey}=true\n', backendServes: const {});

        expect(run.exitCode, 0, reason: run.output);
        expect(run.value(s.envKey), 'false');
      });

      test(
          'un .env SANS saut de ligne final ne voit pas sa dernière ligne altérée',
          () {
        final run = _runOps(s.action,
            initialEnv: 'KPB_EEF_SPACE_ENABLED=true\nPOSTGRES_PASSWORD=s3cret');

        expect(run.exitCode, 0, reason: run.output);
        expect(run.value('POSTGRES_PASSWORD'), 's3cret');
        expect(run.value(s.envKey), 'false');
      });

      test('ferme même quand la clé n\'était pas dans le .env', () {
        final run =
            _runOps(s.action, initialEnv: 'KPB_EEF_SPACE_ENABLED=true\n');

        expect(run.exitCode, 0, reason: run.output);
        expect(run.value(s.envKey), 'false');
      });

      test(
          'refuse si la clé n\'est pas relayée (rien d\'écrit, rien de recréé)',
          () {
        final compose = File('docker-compose.yml')
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.contains('- ${s.envKey}='))
            .join('\n');
        final run = _runOps(s.action,
            composeText: compose, initialEnv: '${s.envKey}=true\n');

        expect(run.exitCode, isNot(0), reason: run.output);
        expect(run.value(s.envKey), 'true');
        expect(run.recreated, isFalse);
      });
    });
  }

  test('les deux interrupteurs sont indépendants l\'un de l\'autre', () {
    // Ouvrir la bulle ne pose pas les écoles privées, et inversement.
    final bubble = _runOps('eef-bubble-on', dryRun: 'false');
    expect(bubble.value('KPB_EEF_HELP_BUBBLE_ENABLED'), 'true');
    expect(bubble.value('KPB_EEF_PRIVATE_SCHOOLS_ENABLED'), isNull);

    final schools = _runOps('eef-private-schools-on', dryRun: 'false');
    expect(schools.value('KPB_EEF_PRIVATE_SCHOOLS_ENABLED'), 'true');
    expect(schools.value('KPB_EEF_HELP_BUBBLE_ENABLED'), isNull);
  });

  test('l\'ancien commutateur eef-space-on / -off n\'a pas changé de portée',
      () {
    // Garde de non-régression : les branches voisines n'ont pas été touchées
    // par l'ajout. `eef-space-off` ne pose QUE sa propre clé.
    final run = _runOps('eef-space-off',
        initialEnv: 'KPB_EEF_SPACE_ENABLED=true\n'
            'KPB_EEF_HELP_BUBBLE_ENABLED=true\n');

    expect(run.exitCode, 0, reason: run.output);
    expect(run.value('KPB_EEF_SPACE_ENABLED'), 'false');
    expect(run.value('KPB_EEF_HELP_BUBBLE_ENABLED'), 'true');
  });

  // ── Le workflow : les deux étapes, JOUÉES en entier ───────────────────────
  //
  // Pas seulement leur programme Python : le bash qui les entoure (le `case`,
  // le `exit 1`, l'écriture dans $GITHUB_ENV, l'URL lue, la clé et la valeur
  // dérivées de l'action) est exécuté par `bash -e`, avec le seul environnement
  // que leur bloc `env:` déclare. Retirer une variable de ce bloc, inverser la
  // dérivation de la clé ou renommer SPACE_BEFORE fait donc rougir un test.
  group('le workflow prouve l\'état depuis /config/app', () {
    // Paresseux : une étape absente fait rougir CHAQUE test qui en dépend, au
    // lieu d'empêcher tout le fichier de se charger.
    late String proof, before;
    setUp(() {
      proof = _step(workflow, "Prouver l'état de l'interrupteur");
      before = _step(workflow, "Relever l'espace avant");
    });

    test('la lecture « avant » précède l\'exécution de l\'opération', () {
      expect(workflow.indexOf(before),
          lessThan(workflow.indexOf("- name: Exécuter l'opération")),
          reason:
              'sans relevé avant, « eefSpace n\'a pas bougé » ne se prouve pas');
    });

    test('la preuve vient APRÈS l\'attente de disponibilité de l\'API', () {
      expect(
          workflow.indexOf(
              "- name: Vérifier depuis l'extérieur ce que le serveur annonce vraiment"),
          lessThan(workflow.indexOf(proof)));
    });

    test(
        'les conditions `if:` : relevé et preuve tournent pour les quatre '
        'actions et pour elles seules (table de vérité)', () {
      final actions = _menuActions(workflow);
      expect(actions, containsAll(_switches.map((s) => s.action)));
      final flagActions = _switches.map((s) => s.action).toSet();

      for (final entry in {'relevé': before, 'preuve': proof}.entries) {
        final truth = _evalIf(entry.value, actions);
        for (final action in actions) {
          for (final dry in [true, false]) {
            // Un `-on` simulé n'écrit rien : rien à relever ni à prouver. Un
            // `-off` agit toujours, dry_run ou non : il se relève et se prouve
            // toujours.
            final expected = flagActions.contains(action) &&
                (action.endsWith('-off') || !dry);
            expect(truth['$action|$dry'], expected,
                reason: '${entry.key} : action=$action dry_run=$dry');
          }
        }
      }
    });

    test('la preuve ne tourne que si l\'opération a réussi', () {
      expect(proof, contains(r'if: ${{ success() && ('));
    });

    test('AUCUNE apostrophe dans les programmes Python (bash les coupe)', () {
      // Un programme reçu par bash entre apostrophes est tronqué à la première
      // qu'on y écrit : c'est ce qui a rendu une étape de preuve inexécutable
      // jusqu'au 02/10/2026, sans que rien ne le montre.
      expect(_pythonProgram(proof), isNot(contains("'")));
      expect(_pythonProgram(before), isNot(contains("'")));
    });

    test('les deux étapes lisent /config/app sur l\'URL publique', () {
      final r = _playStep(before,
          action: 'eef-bubble-off', config: _served(space: true));
      expect(r.curlCalls, hasLength(1));
      expect(r.curlCalls.single, contains('$_healthUrl/api/config/app'));
      expect(r.curlCalls.single, contains('--retry-all-errors'));

      final p = _playStep(proof,
          action: 'eef-bubble-off',
          config: _served(bubble: false),
          priorGithubEnv: 'SPACE_BEFORE=true\n');
      expect(p.curlCalls.single, contains('$_healthUrl/api/config/app'));
      expect(p.curlCalls.single, contains('--retry-all-errors'));
    });

    // ── « Relever l'espace avant » ─────────────────────────────────────────
    group('relevé « avant »', () {
      for (final s in _switches) {
        test('${s.action} : eefSpace lisible est posé dans \$GITHUB_ENV', () {
          for (final space in [true, false]) {
            final r = _playStep(before,
                action: s.action, config: _served(space: space));

            expect(r.code, 0, reason: r.output);
            expect(r.exported('SPACE_BEFORE'), '$space', reason: r.output);
            expect(r.output, contains('eefSpace avant : $space'));
            expect(r.output, isNot(contains('Traceback')));
          }
        });

        test(
            '${s.action} : eefSpace illisible '
            '${s.opens ? "REFUSE l'ouverture (jamais à l'aveugle)" : "ne bloque PAS le retour arrière"}',
            () {
          final unreadable = <String, Map<String, Object?>?>{
            'absent': _served(space: null),
            'texte': _served(space: 'true'),
            'l\'API ne répond pas': null,
          };
          for (final entry in unreadable.entries) {
            final r = _playStep(before, action: s.action, config: entry.value);
            if (s.opens) {
              expect(r.code, isNot(0), reason: entry.key);
              expect(r.output, contains('::error::'), reason: entry.key);
              expect(r.exported('SPACE_BEFORE'), isNull,
                  reason: '${entry.key} : un -on refusé n\'exporte rien');
            } else {
              expect(r.code, 0, reason: '${entry.key} : ${r.output}');
              expect(r.exported('SPACE_BEFORE'), 'unknown', reason: entry.key);
            }
          }
        });
      }
    });

    // ── « Prouver l'état de l'interrupteur » ───────────────────────────────
    group('preuve', () {
      for (final s in _switches) {
        final good = s.opens;
        final other = _keys56.firstWhere((k) => k != s.jsonKey);
        final label = s.action;

        _StepRun prove(
          Map<String, Object?>? config, {
          String priorGithubEnv = 'SPACE_BEFORE=true\n',
          String? action,
        }) =>
            _playStep(proof,
                action: action ?? s.action,
                config: config,
                priorGithubEnv: priorGithubEnv);

        test('$label : la valeur voulue est servie, la preuve passe', () {
          final r = prove(_servedFor(s, good));

          expect(r.code, 0, reason: r.output);
          expect(
              r.output, contains('${s.jsonKey} = ${good ? "True" : "False"}'));
          expect(r.output, isNot(contains('Traceback')));
        });

        test(
            '$label : ne demande NI eefCatalog NI eefCampaign (propres à '
            'l\'ouverture de l\'espace)', () {
          // `_served` ne les porte pas, et la preuve passe : une preuve qui les
          // exigerait refuserait d'ouvrir la bulle pour une raison qui ne la
          // regarde pas.
          final cfg = _servedFor(s, good);
          expect((cfg['features']! as Map).containsKey('eefCatalog'), isFalse);
          expect(cfg.containsKey('eefCatalog'), isFalse);
          expect(prove(cfg).code, 0);
        });

        test('$label : clé ABSENTE (ancienne image en production) : rouge', () {
          final r = prove(_servedFor(s, null, other: !good));
          expect(r.code, isNot(0));
          expect(r.output, contains('features.${s.jsonKey} absent'));
        });

        test('$label : mauvaise valeur : rouge', () {
          final r = prove(_servedFor(s, !good));
          expect(r.code, isNot(0));
          expect(r.output, contains('features.${s.jsonKey}='));
        });

        test('$label : valeur non booléenne (texte) : rouge', () {
          expect(prove(_servedFor(s, good ? 'true' : 'false')).code, isNot(0));
        });

        test(
            '$label : la clé vérifiée est CELLE DE L\'ACTION, pas '
            '${other == 'eefHelpBubble' ? 'la bulle' : 'les écoles privées'}',
            () {
          // Seule l'autre clé a la valeur voulue : une preuve qui vérifierait
          // l'autre clé « réussirait » ici.
          final r = prove(_servedFor(s, !good, other: good));
          expect(r.code, isNot(0), reason: r.output);

          // Et l'autre clé, absente ou dans l'état contraire, ne gêne pas :
          // chaque interrupteur se prouve seul.
          for (final o in [null, !good, good]) {
            final ok = prove(_servedFor(s, good, other: o));
            expect(ok.code, 0, reason: 'autre clé = $o : ${ok.output}');
          }
        });

        test('$label : `eef` vrai ou absent : rouge (la vitrine a disparu)',
            () {
          final bad = prove(_servedFor(s, good, eef: true));
          expect(bad.code, isNot(0));
          expect(bad.output, contains('features.eef'));
          expect(prove(_servedFor(s, good, eef: null)).code, isNot(0));
        });

        test('$label : eefSpace a BOUGÉ pendant l\'opération : rouge', () {
          expect(
              prove(_servedFor(s, good, space: false),
                      priorGithubEnv: 'SPACE_BEFORE=true\n')
                  .code,
              isNot(0));
          expect(
              prove(_servedFor(s, good, space: true),
                      priorGithubEnv: 'SPACE_BEFORE=false\n')
                  .code,
              isNot(0));
        });

        test('$label : eefSpace fermé avant ET après : rien n\'a bougé', () {
          final r = prove(_servedFor(s, good, space: false),
              priorGithubEnv: 'SPACE_BEFORE=false\n');
          expect(r.code, 0, reason: r.output);
        });

        test(
            '$label : relevé « avant » absent ou illisible : la preuve le '
            'DIT sans bloquer, mais vérifie toujours la clé', () {
          for (final prior in ['', 'SPACE_BEFORE=unknown\n']) {
            final ok = prove(_servedFor(s, good), priorGithubEnv: prior);
            expect(ok.code, 0, reason: ok.output);
            expect(ok.output, contains('ATTENTION'));

            final bad = prove(_servedFor(s, !good), priorGithubEnv: prior);
            expect(bad.code, isNot(0));
          }
        });

        test('$label : l\'API ne répond pas pendant la preuve : rouge', () {
          expect(prove(null).code, isNot(0));
        });
      }

      test('une action inconnue est REFUSÉE, jamais devinée', () {
        final r = _playStep(proof,
            action: 'eef-space-on',
            config: _served(bubble: true),
            priorGithubEnv: 'SPACE_BEFORE=true\n');
        expect(r.code, isNot(0), reason: r.output);
        expect(r.output, contains('::error::'));
        // Refusée par SON message, pas par un effet de bord (variable vide,
        // KeyError Python) : le journal du job doit dire pourquoi.
        expect(r.output, contains('Action inconnue'));
        expect(r.output, isNot(contains('Traceback')));
      });
    });

    // ── La chaîne entière : relevé -> opération -> preuve ──────────────────
    group('relevé puis preuve, enchaînés par \$GITHUB_ENV', () {
      for (final s in _switches) {
        test('${s.action} : eefSpace identique avant et après : vert', () {
          for (final space in [true, false]) {
            final b = _playStep(before,
                action: s.action, config: _served(space: space));
            expect(b.code, 0, reason: b.output);

            final p = _playStep(proof,
                action: s.action,
                config: _servedFor(s, s.opens, space: space),
                priorGithubEnv: b.githubEnv);
            expect(p.code, 0, reason: p.output);
            expect(p.output, isNot(contains('ATTENTION')),
                reason: 'le relevé « avant » doit arriver jusqu\'à la preuve');
            expect(p.output, contains('(avant : $space)'));
          }
        });

        test('${s.action} : eefSpace change entre les deux : rouge', () {
          final b =
              _playStep(before, action: s.action, config: _served(space: true));
          final p = _playStep(proof,
              action: s.action,
              config: _servedFor(s, s.opens, space: false),
              priorGithubEnv: b.githubEnv);
          expect(p.code, isNot(0), reason: p.output);
        });
      }
    });
  });

  // ── Une seule orthographe des clés, de bout en bout ──────────────────────
  //
  // `eefHelpBubble` et `eefPrivateSchools` sont écrites à cinq endroits : le
  // contrôleur qui les sert, les getters Flutter qui les lisent, l'argument du
  // script, la dérivation du workflow, et les tests. Renommer l'une d'elles
  // dans un seul endroit ferait « réussir » l'ouverture sans qu'aucun effet ne
  // se voie : le `.env` est écrit, la preuve rougit APRÈS la recréation, et
  // l'app ne lit rien.
  group('les clés sont écrites de la même façon partout', () {
    final controller =
        File('backend/src/modules/config/app-config.controller.ts')
            .readAsStringSync();
    final flags = File('lib/app/core/services/remote_feature_flags.dart')
        .readAsStringSync();
    final features = RegExp(r'features:\s*\{(.*?)\}', dotAll: true)
        .firstMatch(controller)!
        .group(1)!;

    for (final key in _keys56) {
      final s = _switches.firstWhere((s) => s.jsonKey == key && s.opens);

      test('$key : servie par le contrôleur, lue par le client', () {
        expect(RegExp('^\\s*$key,\\s*\$', multiLine: true).hasMatch(features),
            isTrue,
            reason: 'features.$key n\'est pas servie par le contrôleur');
        expect(flags, contains("_flag('$key'"));
        expect(controller, contains('process.env.${s.envKey}'));
      });

      test(
          '$key : l\'argument du script et la dérivation du workflow la '
          'reprennent', () {
        expect(script, contains('eef_flag_on ${s.envKey} $key ${s.action}'));
        final proof =
            _runScript(_step(workflow, "Prouver l'état de l'interrupteur"));
        expect(proof, contains('=$key'));
      });
    }

    test('le chemin visé par le garde est celui que `tsc` produit', () {
      // `outDir: ./dist`, sources sous `src/` : le contrôleur compilé est
      // dist/modules/config/app-config.controller.js, et le Dockerfile lance
      // `node dist/main.js` depuis /app.
      expect(
          File('backend/src/${_controllerInContainer.replaceFirst('dist/', '').replaceFirst('.js', '.ts')}')
              .existsSync(),
          isTrue);
      expect(File('backend/tsconfig.json').readAsStringSync(),
          contains('"outDir": "./dist"'));
      expect(File('backend/Dockerfile').readAsStringSync(),
          contains('"dist/main.js"'));
      expect(script, contains(_controllerInContainer));
    });
  });
}
