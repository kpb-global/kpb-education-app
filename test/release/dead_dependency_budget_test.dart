// Cliquet sur les dépendances DIRECTES de pubspec.yaml que lib/ n'importe
// jamais — même patron que test/core/ui/screen_overflow_budget.dart (budget
// nommé, cliquet dans les deux sens) et que le budget par fichier de
// text_faint_contrast_test.dart.
//
// POURQUOI CE CLIQUET EXISTE. `webview_flutter` était déclaré en `direct main`
// et n'était importé nulle part. Le dégât n'a pas été un plantage : la revue des
// déclarations store a lu la liste des dépendances et en a conclu que l'app
// embarquait une WebView de comparaison de prix. Elle a tenu cette croyance un
// moment. Le seul lecteur réellement embarqué est `youtube_player_flutter`, qui
// passe par `flutter_inappwebview` — pas par `webview_flutter`.
//
// Une dépendance déclarée est donc une DÉCLARATION, lue par des humains qui
// remplissent des formulaires de conformité. Une déclaration fausse coûte plus
// cher qu'un octet de binaire.
//
// ── LA LIMITE, DITE FRANCHEMENT ─────────────────────────────────────────────
// « Jamais importé dans lib/ » ne veut PAS dire « inutile ». Quatre familles de
// paquets légitimes n'ont aucun `import 'package:x/...'` :
//
//   1. les RÉEXPORTS — `hive` est utilisé partout (`Hive.`, `Box<`, `openBox`)
//      mais à travers `hive_flutter`, qui fait `export 'package:hive/hive.dart'`
//      (hive_flutter.dart:13). Zéro import direct, paquet bien vivant ;
//   2. les GREFFONS DE PLATEFORME — enregistrés côté natif via
//      GeneratedPluginRegistrant, sans une ligne de Dart chez nous ;
//   3. les POLICES et ACTIFS — livrés par le bloc `flutter:` du pubspec ;
//   4. les OUTILS — lancés en ligne de commande (`dart run …`), et qui lisent
//      leur configuration dans ce même pubspec.
//
// C'est POUR CETTE RAISON qu'il y a une liste d'exceptions et pas une
// interdiction sèche : une interdiction sèche serait fausse, donc désarmée dans
// la semaine. Chaque exception porte sa raison, une par une, et le cliquet
// refuse qu'elle survive à son motif.
//
// ── LE CLIQUET, DANS LES DEUX SENS ──────────────────────────────────────────
//   · une dépendance directe morte ABSENTE des deux tables fait échouer :
//     ajoutez-la avec sa raison, ou retirez-la du pubspec ;
//   · une exception dont le motif a disparu fait AUSSI échouer, avec la cause
//     exacte — soit le paquet est désormais importé (l'exception mentait), soit
//     il n'est plus déclaré (l'exception est un fossile). Sans ce second sens,
//     la table deviendrait la décharge où l'on range ce qu'on ne veut pas
//     trancher, et resterait verte pour toujours.
//
// ── ANTI-VERT-SILENCIEUX ────────────────────────────────────────────────────
// Ce dépôt a déjà vu trois fois le défaut caché par l'outil censé le détecter.
// Un parseur qui ne trouve RIEN rendrait ces trois tests verts et muets. Le
// premier groupe mesure donc le parseur lui-même avant de mesurer le dépôt.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Paquets sans import Dart PAR CONSTRUCTION — leur absence d'import n'est pas
/// un symptôme. Retirer l'un d'eux casserait quelque chose de réel.
const kNoDartImportByDesign = <String, String>{
  // Réexport : `hive_flutter` fait `export 'package:hive/hive.dart'` et lib/
  // utilise `Hive.`, `Box<`, `openBox` dans catalog_cache_service,
  // success_lab_cache_service, coach_service, success_lab_outbox, main.dart.
  // Un test l'importe même directement. Vivant, sans import direct dans lib/ :
  // c'est l'exemple qui justifie l'existence de cette table.
  'hive': 'utilisé via le réexport de hive_flutter (Hive., Box<, openBox)',

  // Outil de release. `dart run flutter_launcher_icons` lit le bloc
  // `flutter_launcher_icons:` de CE pubspec — dont `remove_alpha_ios: true`,
  // sans quoi Apple rejette l'upload (erreur 90717).
  'flutter_launcher_icons':
      'outil de release, configuré par le bloc flutter_launcher_icons: du pubspec',

  // Outil ponctuel : `dart run change_app_package_name:main`. Sert quand
  // l'identifiant de paquet bouge — opération sensible ici, les ids des fiches
  // déjà publiées sont figés (com.karatou.android / Karatou.karatou).
  'change_app_package_name': 'outil en ligne de commande, jamais importé',

  // Paquet de POLICE : il livre les glyphes Cupertino, il n'a pas de code Dart
  // à importer. Piste écartée : « donc on peut le retirer ». Non — un actif de
  // police se retire après avoir vérifié qu'aucun glyphe n'est référencé, et
  // cette vérification n'est pas du ressort de ce cliquet. C'est aussi la
  // dépendance par défaut du gabarit Flutter, la retirer sans raison ferait du
  // bruit dans la revue.
  'cupertino_icons': 'paquet de police (glyphes Cupertino), aucun code Dart',
};

/// Paquets réellement morts, dont le RETRAIT n'a pas encore été tranché.
///
/// Ce n'est pas une absolution : c'est un inventaire daté. Le correctif 5 avait
/// mandat sur `webview_flutter` seul — retirer 19 paquets de plus dans le même
/// lot aurait mélangé un signal store faux avec 19 arbitrages non demandés,
/// dont deux qui touchent l'enregistrement de greffons natifs iOS.
///
/// MESURÉ le 20/08/2026 sur Flutter 3.44.x : 23 dépendances directes sans
/// import dans lib/, dont 4 légitimes (table ci-dessus) et ces 19.
///
/// La valeur dit ce qu'on sait, pas ce qu'on espère.
const kDeadPendingArbitration = <String, String>{
  // Pur Dart, retrait sans effet natif — les plus simples à solder.
  'readmore': 'mort — ReadMoreText absent de lib/ ; pur Dart',
  'logger': 'mort — la journalisation passe par app_logger + Crashlytics',
  'logging': 'mort en direct — reste tiré en transitif par fwfh_webview',
  'http': 'mort — tous les appels réseau passent par dio',
  'flutter_expandable_fab': 'mort — aucun ExpandableFab dans lib/',
  'pin_code_fields': 'mort — aucun PinCodeTextField dans lib/',
  'get_storage': 'mort — le stockage local est hive + shared_preferences',
  'flutter_screenutil': 'mort — aucun ScreenUtilInit ni extension .sp/.w',
  'flutter_svg': 'mort en direct — aucun SvgPicture dans lib/',
  'country_picker': 'mort — aucun showCountryPicker dans lib/',
  'percent_indicator': 'mort — aucun Circular/LinearPercentIndicator',
  'timeago': 'mort — aucun appel timeago dans lib/',
  'flutter_speed_dial': 'mort — aucun SpeedDial dans lib/',
  'flutter_staggered_grid_view': 'mort — aucune grille décalée dans lib/',
  'fl_chart': 'mort — aucun LineChart/BarChart/PieChart dans lib/',
  // Celui-ci porte encore webview_flutter en transitif : c'est lui, et pas la
  // déclaration directe supprimée par le correctif 5, qui laisse le paquet
  // WebView dans pubspec.lock. Le binaire ne maigrira qu'avec son retrait.
  'flutter_widget_from_html':
      'mort — aucun HtmlWidget dans lib/ ; tire fwfh_webview → webview_flutter',
  'video_player': 'mort — le seul lecteur est youtube_player_flutter',
  // Les deux suivants enregistrent du code natif iOS (ils figurent dans
  // .flutter-plugins-dependencies et dans l'avertissement Swift Package
  // Manager de `flutter pub get`). Leur retrait modifie le jeu de greffons
  // compilés : à faire seule, avec un build device derrière, pas en passant.
  'fluttertoast': 'mort en Dart mais greffon natif iOS/Android enregistré',
  'nb_utils': 'mort en Dart mais greffon natif iOS/Android enregistré',
};

/// Les paquets fournis par le SDK Flutter : ils s'écrivent `sdk: flutter` et
/// n'ont pas de version. `flutter_localizations` n'est jamais importé sous ce
/// nom-là dans la plupart des fichiers, et surtout il n'a pas de sens dans un
/// inventaire de dépendances pub. On les sort du périmètre plutôt que de les
/// noyer dans les exceptions.
const _sdkDependencies = <String>{'flutter', 'flutter_localizations'};

/// Une dépendance qu'on sait importée : sert à prouver que le parseur voit
/// vraiment le dépôt (cf. ANTI-VERT-SILENCIEUX en tête de fichier).
const _knownImported = <String>['get', 'supabase_flutter', 'hive_flutter'];

final _directDependencies = _parseDirectDependencies();
final _libSources = _readTrackedLibSources();

/// Extrait les clés du SEUL bloc `dependencies:` de pubspec.yaml.
///
/// `dev_dependencies:` et `dependency_overrides:` sont hors sujet : ils ne
/// partent pas dans le binaire et ne sont pas ce que lit une revue de fiche
/// store. Le bloc s'arrête à la première ligne en colonne 0.
Set<String> _parseDirectDependencies() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final found = <String>{};
  var inBlock = false;
  for (final line in lines) {
    if (!inBlock) {
      if (line.trimRight() == 'dependencies:') inBlock = true;
      continue;
    }
    if (line.trim().isEmpty) continue;
    // Toute ligne non indentée termine le bloc (dev_dependencies:, flutter:, …).
    if (!line.startsWith(' ') && !line.startsWith('#')) break;
    final match = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (match != null) found.add(match.group(1)!);
  }
  return found;
}

/// Le code de lib/ SUIVI PAR GIT, concaténé. Patron repris de
/// test/core/no_remote_animation_test.dart : on mesure le dépôt, pas les
/// brouillons locaux d'une autre session.
String _readTrackedLibSources() {
  Iterable<String> paths;
  final result = Process.runSync('git', ['ls-files', '--', 'lib']);
  if (result.exitCode == 0) {
    paths = (result.stdout as String)
        .split('\n')
        .where((path) => path.endsWith('.dart'));
  } else {
    paths = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path.replaceAll('\\', '/'))
        .where((path) => path.endsWith('.dart'));
  }
  final buffer = StringBuffer();
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) buffer.writeln(file.readAsStringSync());
  }
  return buffer.toString();
}

bool _isImportedInLib(String package) =>
    _libSources.contains('package:$package/');

void main() {
  final exceptions = <String, String>{
    ...kNoDartImportByDesign,
    ...kDeadPendingArbitration,
  };

  group('(0) le harnais se mesure avant de mesurer le dépôt', () {
    test('le parseur voit bien le bloc dependencies:', () {
      expect(
        _directDependencies.length,
        greaterThanOrEqualTo(40),
        reason: 'Seulement ${_directDependencies.length} dépendances directes '
            'lues dans pubspec.yaml. Le format du bloc a changé et le parseur '
            'ne le suit plus : les trois tests suivants seraient verts sans '
            'rien mesurer.',
      );
      expect(_directDependencies, containsAll(_sdkDependencies));
    });

    test('la lecture de lib/ trouve bien les imports', () {
      expect(
        _libSources.length,
        greaterThan(100000),
        reason: 'lib/ lu en ${_libSources.length} caractères : la lecture a '
            'échoué (git ls-files muet, mauvais répertoire courant ?). Toute '
            'dépendance passerait alors pour morte.',
      );
      for (final package in _knownImported) {
        expect(
          _isImportedInLib(package),
          isTrue,
          reason: '`$package` est importé dans lib/ mais le détecteur ne le '
              'voit pas. Le motif « package:$package/ » ne correspond plus.',
        );
      }
    });

    test('une exception ne peut pas figurer dans les deux tables', () {
      final both = kNoDartImportByDesign.keys
          .where(kDeadPendingArbitration.containsKey)
          .toList();
      expect(both, isEmpty,
          reason: 'Un paquet est à la fois « légitime » et « mort » : '
              'tranchez. ${both.join(', ')}');
    });
  });

  group('(1) aucune dépendance directe morte non déclarée', () {
    test('tout paquet jamais importé dans lib/ porte sa raison', () {
      final undeclared = <String>[];
      for (final package in _directDependencies) {
        if (_sdkDependencies.contains(package)) continue;
        if (_isImportedInLib(package)) continue;
        if (exceptions.containsKey(package)) continue;
        undeclared.add('  $package');
      }
      expect(
        undeclared,
        isEmpty,
        reason:
            'Dépendance(s) directe(s) déclarée(s) dans pubspec.yaml et jamais '
            'importée(s) dans lib/ :\n${undeclared.join('\n')}\n\n'
            'Une liste de dépendances est lue par des humains qui remplissent '
            'des formulaires de conformité store : `webview_flutter` déclaré à '
            'vide a fait croire à une WebView de comparaison de prix. Deux '
            'issues, pas trois :\n'
            '  · retirez le paquet du pubspec et relancez `flutter pub get` ;\n'
            '  · ou, s\'il sert sans import Dart (réexport, greffon natif, '
            'police, outil), ajoutez-le à kNoDartImportByDesign avec CE '
            'motif-là.',
      );
    });
  });

  // DEUX TESTS, PAS UN SEUL AVEC DEUX `expect`. Écrit d'abord en un test, la
  // mutation a montré le défaut : le premier `expect` qui rougit interrompt le
  // corps du test, donc la seconde direction du cliquet n'était jamais
  // exécutée — et n'a jamais pu être vue rouge. Un cliquet dont une moitié n'a
  // pas de preuve rouge ne vaut pas mieux qu'un commentaire.
  group('(2) aucune exception ne survit à son motif', () {
    test('aucune exception ne couvre un paquet désormais importé', () {
      final nowImported = <String>[];
      exceptions.forEach((package, reason) {
        if (!_directDependencies.contains(package)) return;
        if (_isImportedInLib(package)) nowImported.add('  $package — $reason');
      });
      expect(
        nowImported,
        isEmpty,
        reason: 'Ce paquet est maintenant importé dans lib/ : son exception ne '
            'décrit plus la réalité et masquerait le jour où l\'import '
            'disparaît. Retirez la ligne.\n${nowImported.join('\n')}',
      );
    });

    // Cliquet descendant, même règle que screen_overflow_budget : un progrès
    // non verrouillé se perd. Une exception dont le paquet a été retiré du
    // pubspec est un fossile qui rendrait acceptable son retour.
    test('aucune exception ne survit au retrait de son paquet', () {
      final noLongerDeclared = <String>[];
      exceptions.forEach((package, reason) {
        if (!_directDependencies.contains(package)) {
          noLongerDeclared.add('  $package — $reason');
        }
      });
      expect(
        noLongerDeclared,
        isEmpty,
        reason: 'Ce paquet n\'est plus déclaré dans pubspec.yaml : verrouillez '
            'le progrès en retirant son exception.\n'
            '${noLongerDeclared.join('\n')}',
      );
    });
  });

  group('(3) webview_flutter ne revient pas par la porte de devant', () {
    test('pas de déclaration directe dans pubspec.yaml', () {
      expect(
        _directDependencies.contains('webview_flutter'),
        isFalse,
        reason: 'webview_flutter est de retour en dépendance DIRECTE. Le seul '
            'lecteur embarqué de l\'app est youtube_player_flutter, qui passe '
            'par flutter_inappwebview. Si un besoin réel apparaît, la fiche '
            'store et docs/store-* doivent le dire dans le même lot — c\'est '
            'exactement la confusion que ce test empêche.',
      );
    });

    test('pubspec.lock ne le marque pas « direct main »', () {
      // Le paquet RESTE dans le verrou, en transitif, tiré par fwfh_webview ←
      // flutter_widget_from_html. Affirmer son absence serait donc faux
      // aujourd'hui — et deviendrait vrai le jour où flutter_widget_from_html
      // part. On affirme la seule chose stable dans les deux futurs : s'il est
      // là, il n'est pas là comme dépendance directe.
      final lock = File('pubspec.lock').readAsLinesSync();
      final index = lock.indexWhere((line) => line == '  webview_flutter:');
      if (index == -1) return; // retiré pour de bon : rien à garder.
      final kind = lock[index + 1].trim();
      expect(
        kind,
        isNot(contains('direct')),
        reason: 'pubspec.lock déclare webview_flutter en « $kind ». Le verrou '
            'et le pubspec doivent raconter la même histoire : relancez '
            '`flutter pub get` après avoir édité pubspec.yaml.',
      );
    });
  });
}
