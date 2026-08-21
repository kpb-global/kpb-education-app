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
// ── OÙ EN EST L'INVENTAIRE (21/08/2026, lot 2) ──────────────────────────────
// Les 19 dépendances mortes inventoriées le 20/08 ont été tranchées : 17
// retirées de pubspec.yaml, 2 gardées avec leur motif (voir
// kDeadPendingArbitration). Le verrou passe de 266 à 220 paquets, et
// `webview_flutter` — l'incident fondateur de ce fichier — en disparaît
// complètement, son dernier porteur transitif (flutter_widget_from_html) étant
// parti avec le lot.
//
// La règle de décision appliquée était ASYMÉTRIQUE, et elle le reste : retirer
// un paquet encore utile casse l'app, garder un paquet inutile ne coûte que des
// octets. On ne retire donc que ce qu'on peut PROUVER inutile.
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
// Ce dépôt a déjà vu cinq fois le défaut caché par l'outil censé le détecter.
// Un parseur qui ne trouve RIEN rendrait ces trois tests verts et muets. Le
// premier groupe mesure donc le parseur lui-même avant de mesurer le dépôt.
//
// Le lot 2 a failli en produire une sixième variante, dans ce fichier même. Le
// seuil du groupe (0) était calé sur « au moins 40 dépendances » quand le
// pubspec en comptait 58. Après le retrait de 17 paquets il en reste 41 : le
// test passait encore — vérifié, seuil 40 sur 41 dépendances est VERT — mais à
// UNE dépendance près il aurait annoncé « le parseur est cassé » alors que
// c'était le nettoyage qui avait réussi. Un plancher qui mesure l'outil ne doit
// pas se transformer en cliquet anti-réduction : seuil ramené à 30.
//
// Et la baisse ne désarme rien, c'est mesuré : parseur saboté (motif d'extraction
// remplacé), le groupe (0) lit 0 dépendance et rougit bien contre le seuil 30.

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
/// Ce n'est pas une absolution : c'est un inventaire daté. La valeur dit ce
/// qu'on sait, pas ce qu'on espère.
///
/// HISTORIQUE, parce qu'il explique la forme actuelle de la table.
///   · MESURÉ le 20/08/2026 : 23 dépendances directes sans import dans lib/ —
///     4 légitimes (table ci-dessus) et 19 ici. Le correctif 5 n'avait mandat
///     que sur `webview_flutter` ; solder les 19 autres dans le même lot aurait
///     mélangé un signal store faux avec 19 arbitrages non demandés.
///   · LOT 2, le 21/08/2026 : ces 19 arbitrages ont été rendus. 17 paquets
///     retirés de pubspec.yaml (verrou 266 → 220 paquets). Il reste les DEUX
///     ci-dessous, et ils restent pour une raison, pas par fatigue.
///
/// Ce qui a servi de preuve pour les 17, dans l'ordre où ça a été vérifié :
/// aucun `package:x/` dans lib/ NI dans test/ ; aucun symbole du paquet employé
/// via un réexport (`SvgPicture`, `HtmlWidget`, `LineChart`, `VideoPlayer`… —
/// les seules occurrences trouvées étaient la prose de CE fichier, et la classe
/// applicative `ScholarshipVideoPlayerScreen`, qui passe par
/// youtube_player_flutter) ; aucune référence dans le natif écrit à la main
/// (android/, ios/, web/) ; puis `flutter build apk --debug` vert, seul contrôle
/// qui valide l'enregistrement des greffons.
///
/// `http` et `logging` sont sortis de `dependencies:` sans sortir du verrou :
/// dio, supabase_flutter, printing, syncfusion et socket_io_client en dépendent,
/// pub les garde en `transitive`. C'était bien la DÉCLARATION DIRECTE qui
/// mentait, pas leur présence — et c'est le cas le plus instructif de la série.
const kDeadPendingArbitration = <String, String>{
  // Ces deux-là enregistrent du code natif iOS/Android : ils figurent nommément
  // dans l'avertissement Swift Package Manager de `flutter pub get` et dans
  // .flutter-plugins-dependencies. Leur retrait modifie le jeu de greffons
  // compilés, et un `flutter build apk --debug` vert ne prouve RIEN pour iOS.
  //
  // Piste écartée, explicitement : les retirer parce que les 17 autres sont
  // partis sans dégât. La règle de décision est asymétrique — retirer un paquet
  // encore utile casse l'app, garder un paquet inutile ne coûte que des octets.
  // Sans build device iOS derrière, la preuve manque ; on garde et on l'écrit.
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
      // POURQUOI 30 ET PAS 40. Ce seuil mesure LE PARSEUR, pas la longueur de la
      // liste : il doit rougir quand le format du bloc change et que le parseur
      // ne lit plus rien, cas où il renvoie 0 ou une poignée d'entrées.
      //
      // Il était à 40 quand le pubspec en comptait 58. Le lot 2 en a retiré 17,
      // il en reste 41 : le seuil passait à UNE dépendance de rougir pour une
      // raison fausse — « le nettoyage a marché » aurait été rapporté comme
      // « le parseur est cassé ». C'est le piège que ce dépôt a déjà vu cinq
      // fois : l'outil de détection qui accuse le correctif.
      //
      // Un seuil de plancher ne doit donc PAS servir de cliquet anti-réduction.
      // Le cliquet anti-réduction, c'est le groupe (2) : il refuse qu'une
      // exception survive au retrait de son paquet. Ici on veut seulement la
      // preuve que la lecture a eu lieu.
      expect(
        _directDependencies.length,
        greaterThanOrEqualTo(30),
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

    test('pubspec.lock ne le contient plus du tout, même en transitif', () {
      // CE TEST A CHANGÉ DE FORME AU LOT 2, et c'est le cliquet qui l'exige.
      // Il affirmait seulement « s'il est là, il n'est pas là en direct », parce
      // que le paquet restait tiré en transitif par fwfh_webview ←
      // flutter_widget_from_html : affirmer son absence aurait été FAUX. Le lot 2
      // a retiré flutter_widget_from_html, son dernier porteur. L'absence est
      // devenue vraie, donc elle devient l'assertion — un progrès non verrouillé
      // se perd (même règle que screen_overflow_budget).
      //
      // Pourquoi refuser même un retour TRANSITIF : ce qui compte pour la revue
      // store n'est pas la forme de la déclaration mais le fait qu'une WebView
      // soit embarquée dans le binaire. Un retour par transitivité l'embarque
      // tout autant. Si un besoin réel apparaît, ce test se met à jour DANS LE
      // MÊME LOT que la fiche store et docs/store-* — c'est le couplage voulu.
      final lock = File('pubspec.lock').readAsLinesSync();
      final index = lock.indexWhere((line) => line == '  webview_flutter:');
      final kind = index == -1 ? null : lock[index + 1].trim();
      expect(
        index,
        -1,
        reason: 'webview_flutter est revenu dans pubspec.lock en « $kind ». '
            'Le seul lecteur embarqué de l\'app est youtube_player_flutter, qui '
            'passe par flutter_inappwebview. Trouvez qui le tire avec '
            '`flutter pub deps` : si c\'est un besoin réel, la fiche store et '
            'docs/store-* doivent le dire dans le même lot — c\'est exactement '
            'la confusion que ce test empêche.',
      );
    });
  });
}
