// Garde : AUCUN des trois collecteurs ne doit collecter au démarrage tant que
// le choix persisté de l'utilisateur n'est pas connu.
//
// LE DÉFAUT CORRIGÉ. `Firebase.initializeApp` et `Posthog().setup` tournent en
// haut de `main()` ; le choix persisté n'est lu qu'à `controller.hydrate()`, une
// centaine de lignes plus bas, derrière Supabase, Hive, le cache catalogue,
// l'outbox et le dépôt local. Tout ce qui était collecté dans cette fenêtre
// l'était sans consentement — y compris pour quelqu'un qui avait refusé. Et
// pour Crashlytics, la file de rapports non envoyés survit aux lancements : le
// SDK natif peut la téléverser au démarrage du processus, avant la première
// ligne de Dart. Un `setCrashlyticsCollectionEnabled` côté Dart est donc
// structurellement trop tard.
//
// CE FICHIER PROUVE DEUX CHOSES DISTINCTES :
//   (1) les valeurs par défaut NATIVES sont bien à « désactivé » — lecture du
//       manifeste Android et de l'Info.plist ;
//   (2) le code Dart n'allume un collecteur qu'APRÈS la lecture du choix
//       persisté — test structurel sur les positions dans lib/main.dart, sur le
//       patron de backend/src/main.imports.spec.ts (lire le fichier de
//       démarrage plutôt que ses propres importations).
//
// POURQUOI TOUT PASSE PAR `_withoutComments`. Le manifeste, l'Info.plist et
// main.dart expliquent en prose ce qu'ils désactivent : ils citent les noms de
// clés et la variante `…_DEACTIVATED` interdite dans leurs commentaires. Une
// assertion sur le texte brut serait satisfaite par ces phrases seules — on
// pourrait supprimer la configuration protégée et garder le test vert. Sur ce
// dépôt, quatre fois, le défaut a été caché par l'outil censé le détecter.
//
// POURQUOI PAS UN TEST DE COMPORTEMENT. Sans app Firebase par défaut les appels
// SDK lèvent, et le catch par collecteur d'`AnalyticsService` les avale : un
// test d'exécution resterait vert pendant que la collecte continue. Et la
// valeur par défaut native n'est, par construction, lisible que dans les
// fichiers de configuration — elle est consommée par le SDK natif au démarrage
// du processus, pas par du Dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _plistPath = 'ios/Runner/Info.plist';
const _mainPath = 'lib/main.dart';

// Les orthographes EXACTES lues par les SDK installés. Une variante est ignorée
// sans erreur ni avertissement : c'est l'orthographe elle-même qu'on garde.
//
// · `firebase_analytics_collection_enabled` :
//   play-services-measurement-impl-23.2.0, com.google.android.gms.measurement
//   .internal.zzic (metaData.getBoolean).
// · `firebase_crashlytics_collection_enabled` : firebase-crashlytics-20.0.5,
//   com.google.firebase.crashlytics.internal.common.DataCollectionArbiter
//   (readCrashlyticsDataCollectionEnabledFromManifest).
const _androidAnalyticsKey = 'firebase_analytics_collection_enabled';
const _androidCrashlyticsKey = 'firebase_crashlytics_collection_enabled';

// · FIREBASE_ANALYTICS_COLLECTION_ENABLED : chaîne présente dans
//   GoogleAppMeasurement.xcframework (ios-arm64).
// · FirebaseCrashlyticsCollectionEnabled : constante
//   FIRCLSCrashlyticsCollectionKey dans FIRCLSDataCollectionArbiter.m.
const _iosAnalyticsKey = 'FIREBASE_ANALYTICS_COLLECTION_ENABLED';
const _iosCrashlyticsKey = 'FirebaseCrashlyticsCollectionEnabled';

/// Les variantes IRRÉVERSIBLES. Elles désactivent aussi la collecte, mais
/// `setAnalyticsCollectionEnabled(true)` ne les rouvre pas : les employer
/// casserait la collecte pour qui a ACCEPTÉ. Gardées absentes, pas présentes.
const _forbiddenAndroid = 'firebase_analytics_collection_deactivated';
const _forbiddenIos = 'FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED';

String _withoutXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// main.dart privé de ses commentaires. Le fichier DÉCRIT `optOut = true` et
/// l'ordre attendu en prose ; sans ce filtrage, les commentaires satisferaient
/// seuls les assertions ci-dessous.
String _dartWithoutComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n')
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

/// Les balises `<meta-data …>` du bloc `<application>`, ses `<activity>`
/// retirées : une méta-donnée de configuration du SDK posée dans une activité
/// serait ignorée. On affirme le NIVEAU de la déclaration, pas sa présence.
List<String> _applicationMetaData(String manifestBody) {
  final application = RegExp(r'<application\b.*?</application>', dotAll: true)
      .firstMatch(manifestBody);
  expect(application, isNotNull, reason: '<application> introuvable');
  final body = application!
      .group(0)!
      .replaceAll(RegExp(r'<activity\b.*?</activity>', dotAll: true), '');
  return RegExp(r'<meta-data\b[^>]*>')
      .allMatches(body)
      .map((m) => m.group(0)!)
      .toList();
}

/// La valeur booléenne associée à [key] dans un plist, ou null si la clé est
/// absente ou n'est pas un booléen (`<string>false</string>` par exemple, que
/// les SDK acceptent mais qui rend la garde moins nette).
bool? _plistBool(String plistBody, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<(true|false)\\s*/>',
  ).firstMatch(plistBody);
  if (match == null) return null;
  return match.group(1) == 'true';
}

/// La position de [needle] dans [haystack]. Échoue si absent ou ambigu : deux
/// occurrences d'un même jalon rendraient la comparaison d'ordre arbitraire.
int _soleIndex(String haystack, String needle, {required String reason}) {
  final first = haystack.indexOf(needle);
  expect(first, isNot(-1), reason: 'Jalon introuvable : « $needle ». $reason');
  expect(
    haystack.indexOf(needle, first + 1),
    -1,
    reason:
        'Jalon « $needle » présent plusieurs fois : la comparaison d\'ordre '
        'ne dirait plus rien de sûr.',
  );
  return first;
}

void main() {
  final manifest = _withoutXmlComments(File(_manifestPath).readAsStringSync());
  final plist = _withoutXmlComments(File(_plistPath).readAsStringSync());
  final main = _dartWithoutComments(File(_mainPath).readAsStringSync());

  group('valeurs par défaut natives : les trois collecteurs démarrent coupés',
      () {
    test('Android : les deux méta-données Firebase sont à false', () {
      final metaData = _applicationMetaData(manifest);

      for (final key in [_androidAnalyticsKey, _androidCrashlyticsKey]) {
        final declarations = metaData
            .where((tag) => tag.contains('android:name="$key"'))
            .toList();
        expect(
          declarations,
          hasLength(1),
          reason: 'Attendue une fois au niveau <application>, orthographiée '
              'exactement « $key » — le SDK ignore silencieusement toute autre '
              'clé, et sans elle la collecte démarre avant que le choix '
              'persisté soit lu.',
        );
        expect(
          declarations.single,
          contains('android:value="false"'),
          reason: 'Le SDK lit un booléen : `false` littéral. Toute autre '
              'valeur laisse le collecteur démarrer allumé.',
        );
      }
    });

    test('iOS : les deux clés Firebase de l\'Info.plist sont à false', () {
      expect(
        _plistBool(plist, _iosAnalyticsKey),
        isFalse,
        reason: 'Sans « $_iosAnalyticsKey » à <false/>, Firebase Analytics '
            'démarre avec Firebase, avant `controller.hydrate()`.',
      );
      expect(
        _plistBool(plist, _iosCrashlyticsKey),
        isFalse,
        reason: 'Sans « $_iosCrashlyticsKey » à <false/>, le SDK natif peut '
            'téléverser la file de rapports non envoyés au démarrage du '
            'processus, avant la première ligne de Dart.',
      );
    });

    test('PostHog démarre opté dehors', () {
      // Le `setup` reste en haut de main() (l'état persisté du SDK prime sur
      // cette valeur, donc qui a accepté ne perd pas « Application Opened ») ;
      // c'est ce champ, et lui seul, qui ferme la fenêtre.
      final optOut = RegExp(r'\.\.\s*optOut\s*=\s*(\w+)').firstMatch(main);
      expect(
        optOut,
        isNotNull,
        reason: 'PostHogConfig.optOut absent de main.dart : le SDK démarre en '
            'collectant (cycle de vie, rejeu de session, capture automatique) '
            'avant que le choix persisté soit lu.',
      );
      expect(
        optOut!.group(1),
        'true',
        reason: 'optOut à false = le SDK branche ses intégrations dès le '
            '`setup`, donc avant hydrate().',
      );
      expect(
        _soleIndex(main, '..optOut = true',
            reason: 'la garde compare des positions'),
        lessThan(
          _soleIndex(main, 'Posthog().setup(',
              reason: 'point de démarrage du SDK PostHog'),
        ),
        reason: 'Le champ doit être posé sur la config AVANT `setup` : après, '
            'il n\'est plus lu.',
      );
    });

    test('aucune variante irréversible : qui accepte doit encore être collecté',
        () {
      // Piège symétrique du défaut : couper « pour de bon » satisferait une
      // garde naïve tout en cassant la collecte pour qui a accepté.
      expect(
        manifest.toLowerCase().contains(_forbiddenAndroid),
        isFalse,
        reason: '« $_forbiddenAndroid » est irréversible : '
            '`setAnalyticsCollectionEnabled(true)` ne le rouvre pas. C\'est la '
            'variante « …_enabled » qu\'il faut.',
      );
      expect(
        plist.contains(_forbiddenIos),
        isFalse,
        reason: '« $_forbiddenIos » est irréversible : la collecte ne '
            'repartirait jamais, même pour qui a accepté.',
      );
    });
  });

  group('côté Dart : rien n\'est allumé avant la lecture du choix persisté',
      () {
    // Patron de backend/src/main.imports.spec.ts : on lit le fichier de
    // démarrage, pas ses propres importations.
    test('applyAnalyticsConsent() vient APRÈS hydrate()', () {
      final hydrate = _soleIndex(
        main,
        'await controller.hydrate()',
        reason: 'c\'est là que le choix persisté devient connu',
      );
      final consent = _soleIndex(
        main,
        'controller.applyAnalyticsConsent()',
        reason: 'sans cet appel, un refus est oublié au prochain lancement et '
            'les trois collecteurs repartent',
      );
      expect(
        hydrate,
        lessThan(consent),
        reason: 'Appliquer le consentement avant `hydrate()` reviendrait à '
            'appliquer la valeur par défaut en mémoire, pas le choix de '
            'l\'utilisateur.',
      );
    });

    test('aucun collecteur n\'est allumé avant hydrate()', () {
      final hydrate = _soleIndex(
        main,
        'await controller.hydrate()',
        reason: 'borne de la fenêtre sans consentement',
      );
      final beforeHydrate = main.substring(0, hydrate);

      // Toute manière d'allumer un collecteur, quel que soit le SDK. Une seule
      // suffirait à rouvrir la fenêtre que ce lot ferme.
      const enablers = <String>[
        'setCollectionEnabled(',
        'setAnalyticsCollectionEnabled(',
        'setCrashlyticsCollectionEnabled(',
        'applyCrashlyticsConsent(',
        'Posthog().enable(',
        'applyAnalyticsConsent(',
      ];
      for (final enabler in enablers) {
        expect(
          beforeHydrate.contains(enabler),
          isFalse,
          reason: '« $enabler » apparaît avant `controller.hydrate()` : le '
              'choix persisté n\'est pas encore lu, donc la collecte '
              'redémarrerait même après un refus.',
        );
      }
    });
  });
}
