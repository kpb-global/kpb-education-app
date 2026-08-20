// Garde PRIV-OS1 — rien de ce qui part vers OneSignal n'emporte l'adresse
// e-mail de l'étudiant.
//
// La garde n'inspecte PAS le source de `onesignal_service.dart` : elle branche
// un faux destinataire sur les MethodChannel du SDK OneSignal et lit ce qui y
// passe réellement. Un test qui aurait cherché `addEmail` dans le fichier
// serait resté vert le jour où la fuite repasse par une autre porte du SDK
// (`addSms`, un alias, une étiquette) — et c'est exactement le mode de panne
// déjà rencontré sur ce dépôt : un harnais qui rassure sans rien observer.
//
// Deux pièges de harnais sont donc pinés explicitement avant toute assertion
// de non-fuite :
//   1. sans App ID configuré, `login()` sort au premier `if` et la garde
//      « aucun e-mail » serait vraie parce que RIEN ne part ;
//   2. `initialize()` avale ses erreurs ; si un canal du SDK n'est pas simulé,
//      le service reste non initialisé et toutes les méthodes deviennent des
//      no-op — même symptôme, garde creuse.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/services/onesignal_service.dart';

/// Tous les canaux ouverts par `OneSignal.initialize()` : le SDK enchaîne les
/// `lifecycleInit()` dans un `Future.wait`, un seul canal non simulé fait
/// échouer l'init entière.
const _oneSignalChannels = <String>[
  'OneSignal',
  'OneSignal#debug',
  'OneSignal#user',
  'OneSignal#pushsubscription',
  'OneSignal#notifications',
  'OneSignal#inappmessages',
];

/// Adresse volontairement reconnaissable : on la cherche ensuite dans tout ce
/// qui a traversé les canaux.
const _studentEmail = 'aminata.diallo@student.example';

/// Les quatre étiquettes de ciblage assumées et déclarées côté boutiques.
const _declaredTags = <String, String>{
  'account_type': 'student',
  'level': 'licence3',
  'target_country': 'ca',
  'locale': 'fr',
};

class _ChannelCall {
  const _ChannelCall(this.channel, this.method, this.arguments);

  final String channel;
  final String method;
  final Object? arguments;

  @override
  String toString() => '$channel → $method($arguments)';
}

/// Aplatit récursivement une charge utile de MethodChannel en chaînes, clés
/// comprises : une fuite peut aussi bien voyager en valeur d'étiquette qu'en
/// argument nommé.
Iterable<String> _payloadStrings(Object? value) {
  if (value == null) return const <String>[];
  if (value is String) return <String>[value];
  if (value is Map) {
    return value.entries.expand(
      (entry) => <String>[
        ..._payloadStrings(entry.key),
        ..._payloadStrings(entry.value),
      ],
    );
  }
  if (value is Iterable) return value.expand(_payloadStrings);
  return <String>[value.toString()];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <_ChannelCall>[];

  TestDefaultBinaryMessenger messengerOf() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    for (final name in _oneSignalChannels) {
      messengerOf().setMockMethodCallHandler(MethodChannel(name), (
        call,
      ) async {
        calls.add(_ChannelCall(name, call.method, call.arguments));
        // Ces deux méthodes sont typées `bool` NON nullable côté SDK :
        // renvoyer null ferait échouer `lifecycleInit()` (donc `initialize()`,
        // qui avale ses erreurs) et la garde n'observerait plus rien.
        if (call.method == 'OneSignal#permission' ||
            call.method == 'OneSignal#requestPermission') {
          return false;
        }
        return null;
      });
    }
    await OneSignalService.instance.initialize();
  });

  tearDownAll(() {
    for (final name in _oneSignalChannels) {
      messengerOf().setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  setUp(calls.clear);

  test('le harnais observe réellement les appels OneSignal', () async {
    expect(
      AppConfig.oneSignalEnabled,
      isTrue,
      reason:
          'sans App ID, login() sort au premier if : la garde ne prouverait rien',
    );
    expect(
      OneSignalService.instance.isInitialized,
      isTrue,
      reason:
          'initialize() a échoué (canal non simulé ?) : tout appel suivant est '
          'un no-op et la garde serait creuse',
    );

    await OneSignalService.instance.login(
      userId: 'usr-42',
      email: _studentEmail,
      tags: _declaredTags,
    );

    final methods = calls.map((call) => call.method).toList();
    expect(
      methods,
      contains('OneSignal#login'),
      reason: 'l\'identifiant externe doit bien partir : $calls',
    );
    expect(
      methods,
      contains('OneSignal#addTags'),
      reason: 'les étiquettes de ciblage doivent bien partir : $calls',
    );
  });

  test(
    'login() n\'emporte jamais l\'e-mail, même quand l\'appelant le passe',
    () async {
      await OneSignalService.instance.login(
        userId: 'usr-42',
        email: _studentEmail,
        tags: _declaredTags,
      );

      expect(calls, isNotEmpty, reason: 'rien intercepté : harnais muet');

      for (final call in calls) {
        expect(
          call.method.toLowerCase(),
          isNot(contains('email')),
          reason: 'appel e-mail interdit vers OneSignal : $call',
        );
        for (final text in _payloadStrings(call.arguments)) {
          expect(
            text,
            isNot(contains('@')),
            reason: 'adresse e-mail dans la charge utile OneSignal : $call',
          );
          expect(
            text.toLowerCase(),
            isNot(contains('student.example')),
            reason: 'domaine de l\'e-mail étudiant repéré dans : $call',
          );
        }
      }
    },
  );

  test(
    'aucune porte e-mail ni SMS sur toute la surface publique du service',
    () async {
      final service = OneSignalService.instance;
      await service.login(
        userId: 'usr-42',
        email: _studentEmail,
        tags: _declaredTags,
      );
      await service.setTags(_declaredTags);
      await service.requestPermission();
      await service.logout();

      expect(calls, isNotEmpty, reason: 'rien intercepté : harnais muet');
      for (final call in calls) {
        final method = call.method.toLowerCase();
        expect(
          method,
          isNot(contains('email')),
          reason: 'canal e-mail OneSignal touché : $call',
        );
        expect(
          method,
          isNot(contains('sms')),
          reason: 'canal SMS OneSignal touché : $call',
        );
      }
    },
  );

  test('les étiquettes envoyées sont exactement celles qu\'on déclare',
      () async {
    await OneSignalService.instance.login(
      userId: 'usr-42',
      email: _studentEmail,
      tags: _declaredTags,
    );

    final tagCalls =
        calls.where((call) => call.method == 'OneSignal#addTags').toList();
    expect(tagCalls, hasLength(1));

    final sent = (tagCalls.single.arguments as Map)
        .keys
        .map((key) => key.toString())
        .toSet();
    // Le formulaire de confidentialité des boutiques déclare ces quatre
    // étiquettes et rien d'autre : toute clé ajoutée en douce au service
    // rendrait cette déclaration fausse.
    expect(sent, _declaredTags.keys.toSet());
  });
}
