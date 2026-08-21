// Les deux réserves déclarées en ouvrant la PR #220, sur le bouton de dictée de
// l'étape « Message » du tunnel de dossier.
//
// ## Réserve A — le message disait une cause fausse
//
// `case_message_dictation_unavailable_body` annonce « La reconnaissance vocale
// n'est pas disponible sur cet appareil. » C'est vrai quand le greffon manque ou
// que la plateforme n'initialise rien. C'était FAUX sur le chemin ajouté par
// #220 : l'étudiant a accepté l'envoi de sa voix au service de la plateforme, la
// seconde tentative a échoué parce que le micro était occupé ou la session
// refusée à cet instant — la reconnaissance EST disponible, et un nouvel essai
// peut suffire. Le message accusait le téléphone et ne proposait rien.
//
// Ce fichier exerce les DEUX messages, chacun sur SON chemin. C'est l'objet du
// groupe (A), et c'est délibérément la seule forme de garde qui prouve quelque
// chose ici : le défaut n'était pas « aucun message », c'était « le mauvais
// message ». Une assertion « un bandeau apparaît » aurait été verte avant comme
// après le correctif.
//
// ## Réserve B — une branche qu'aucun test n'exerçait
//
// Sur Android, `_toggleDictation` demande la permission micro et affiche
// `case_message_mic_required_*` si elle est refusée. Sous `flutter test` sur
// macOS, `Platform.isAndroid` vaut faux : cette branche n'était jouée par aucun
// test du dépôt. Elle pouvait cesser de fonctionner sans qu'une assertion bouge.
//
// `CaseDictationPlatform` pose la couture (patron `AppConfig` /
// `IntakeCalendar.clock`), le groupe (B) la traverse — et son dernier test
// vérifie que, couture NON armée, la production d'aujourd'hui est inchangée :
// la permission n'est même pas demandée sur un hôte qui n'est pas Android.
//
// ## Le harnais, et ses pièges déjà payés sur ce fichier
//
// * Le bandeau `Get.snackbar` s'auto-efface au bout de 3 s. On observe donc
//   vers 1,2 s (`_settle`) puis on vide les minuteurs (`_drainOverlays`).
//   `pumpAndSettle` ne convient pas : le bandeau anime, attend, anime encore,
//   donc « tout est stable » n'arrive qu'après sa disparition.
// * `SpeechToText()` est un singleton du paquet et son `_initWorked` ne
//   redevient jamais faux une fois vrai. Le test « l'appareil ne sait pas » doit
//   donc être joué AVANT toute initialisation réussie du fichier, et il le
//   vérifie lui-même en comptant les appels `initialize` : si un voisin avait
//   déjà armé le drapeau, l'assertion tombe au lieu de passer pour rien.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/cases/case_tunnel_flow.dart';

import '../../widget_test_helpers.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Le canal du greffon `speech_to_text` — dernier point Dart avant le moteur
/// natif, comme dans `case_dictation_retry_failure_test.dart`.
const MethodChannel _speechChannel = MethodChannel(
  'plugin.csdcorp.com/speech_to_text',
);

const MethodCodec _codec = StandardMethodCodec();

/// Ce que la plateforme répond à la tentative LOCALE (`onDevice: true`), la
/// première que l'écran tente toujours.
enum _OnDeviceOutcome {
  /// iOS sans modèle local : la session est refusée avec `onDeviceError`.
  /// `SpeechInputService` arme alors `onDeviceUnavailable` et l'écran ouvre le
  /// dialogue d'accord.
  refused,

  /// La plateforme accepte l'appel mais n'ouvre aucune session, sans lever.
  /// `onDeviceUnavailable` n'est PAS armé : pas de dialogue, c'est l'échec de
  /// dictée du premier essai.
  startedFalse,

  /// La dictée locale démarre.
  accepted,
}

/// Ce que la plateforme répond à la tentative RÉSEAU (`onDevice: false`), celle
/// faite après l'accord de l'étudiant.
enum _PlatformServiceOutcome { refused, accepted }

late bool _initializeResult;
late _OnDeviceOutcome _onDevice;
late _PlatformServiceOutcome _platformService;
final List<MethodCall> _outgoing = <MethodCall>[];

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Rejoue le `notifyStatus` entrant que le greffon natif émet peu après
/// `listen`. Sans lui, `SpeechToText.isListening` reste faux et une session
/// réellement partie serait lue comme un échec.
Future<void> _pushStatus(String status) {
  return _messenger.handlePlatformMessage(
    _speechChannel.name,
    _codec.encodeMethodCall(MethodCall('notifyStatus', status)),
    (_) {},
  );
}

Iterable<MethodCall> _calls(String method) =>
    _outgoing.where((c) => c.method == method);

Iterable<MethodCall> get _listens => _calls('listen');

Iterable<MethodCall> get _networkListens => _listens.where(
      (c) => (c.arguments as Map<Object?, Object?>)['onDevice'] != true,
    );

Map<String, String> _fr() => AppTranslations().keys['fr']!;
Map<String, String> _en() => AppTranslations().keys['en']!;

Future<void> _seedSignedInAccount() async {
  AppConfig.enableRemoteSyncOverride = false;
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        isGuestMode: false,
        profile: createTestProfile(),
      ),
    ),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);

  final auth = _MockAuthService();
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  when(() => auth.isLoggedIn).thenReturn(false);
  Get.put<AuthService>(auth, permanent: true);
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// ~1,2 s de trames : le dialogue s'ouvre ou se ferme, la tentative rend sa
/// réponse, le bandeau entre — et n'est pas encore reparti.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Épuise le minuteur d'auto-effacement du bandeau et son animation de sortie.
/// Sans lui le test finirait sur un minuteur en attente, ce que le framework
/// compte comme un échec.
Future<void> _drainOverlays(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Vide la file de bandeaux de GetX à la fin du test, quoi qu'il arrive.
///
/// `Get.snackbar` passe par `SnackbarController._snackBarQueue`, une file
/// STATIQUE que `Get.reset()` ne touche pas. Un bandeau laissé ouvert — ce qui
/// arrive dès qu'une assertion échoue avant `_drainOverlays` — met celui du test
/// SUIVANT en file d'attente, où il n'apparaîtra jamais. Deux dégâts, et le
/// second est le grave : des voisins rouges pour rien, mais surtout une
/// assertion « aucun message affiché » qui passerait au vert pour la mauvaise
/// raison. Cette file est exactement le genre d'outil de vérification qui a déjà
/// caché des défauts dans ce dépôt.
void _clearSnackbarQueueAfterTest(WidgetTester tester) {
  addTearDown(() async {
    Get.closeAllSnackbars();
    await _drainOverlays(tester);
  });
}

const _prefill = CaseTunnelPrefill(
  title: 'Master en France',
  contextLabel: 'France • master',
);

/// Monte le tunnel et s'arrête à l'étape « Message », celle qui porte le bouton
/// de dictée.
Future<void> _openMessageStep(WidgetTester tester) async {
  await _seedSignedInAccount();
  _tallPhone(tester);
  _clearSnackbarQueueAfterTest(tester);

  await tester.pumpWidget(_wrap(
    const Scaffold(body: CaseTunnelFlow(prefill: _prefill)),
  ));
  await tester.pumpAndSettle();

  // Type → Contexte → Documents → Message : trois « Suivant ».
  for (var step = 0; step < 3; step++) {
    await tester.tap(find.text('common_next'.tr));
    await tester.pumpAndSettle();
  }

  expect(
    find.text('case_message_dictate'.tr),
    findsOneWidget,
    reason: 'sans le bouton de dictée, la suite du test ne mesure plus rien',
  );
}

Future<void> _tapDictate(WidgetTester tester) async {
  await tester.tap(find.text('case_message_dictate'.tr));
  await _settle(tester);
}

/// Tape sur « Dicter mon message » puis accepte le dialogue de bascule réseau.
Future<void> _dictateAndAcceptPlatformService(WidgetTester tester) async {
  await _tapDictate(tester);
  expect(
    find.text('case_message_dictation_on_device_unavailable_title'.tr),
    findsOneWidget,
    reason: 'sans le dialogue d\'accord, le chemin mesuré ici n\'existe pas',
  );
  await tester.tap(find.text('case_message_dictation_use_platform_service'.tr));
  await _settle(tester);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    _outgoing.clear();
    _initializeResult = true;
    _onDevice = _OnDeviceOutcome.refused;
    _platformService = _PlatformServiceOutcome.refused;
    _messenger.setMockMethodCallHandler(_speechChannel, (call) async {
      _outgoing.add(call);
      switch (call.method) {
        case 'initialize':
          return _initializeResult;
        case 'listen':
          final args = call.arguments as Map<Object?, Object?>;
          if (args['onDevice'] == true) {
            switch (_onDevice) {
              case _OnDeviceOutcome.refused:
                throw PlatformException(
                  code: 'onDeviceError',
                  message:
                      'on device recognition is not supported on this device',
                );
              case _OnDeviceOutcome.startedFalse:
                return false;
              case _OnDeviceOutcome.accepted:
                await _pushStatus('listening');
                return true;
            }
          }
          switch (_platformService) {
            case _PlatformServiceOutcome.refused:
              throw PlatformException(
                code: 'error_busy',
                message: 'the recognizer is busy',
              );
            case _PlatformServiceOutcome.accepted:
              await _pushStatus('listening');
              return true;
          }
        case 'stop':
        case 'cancel':
          await _pushStatus('notListening');
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    // `SpeechToText()` est un singleton du paquet : son état d'écoute survit
    // d'un test à l'autre. On le remet à plat, sinon un test lit ce que son
    // voisin a laissé.
    await _pushStatus('notListening');
    _messenger.setMockMethodCallHandler(_speechChannel, null);
    CaseDictationPlatform.resetOverrides();
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  group('(A) chaque échec dit SA cause, pas celle du voisin', () {
    // Ce test doit rester le PREMIER du fichier : voir le piège du singleton
    // `_initWorked` en tête de fichier. Il se protège lui-même en comptant les
    // appels `initialize`, mais mieux vaut ne pas dépendre de ce filet.
    testWidgets(
        'la plateforme n\'initialise rien — « pas disponible sur cet appareil »',
        (tester) async {
      _initializeResult = false;
      await _openMessageStep(tester);
      await _tapDictate(tester);

      expect(
        _calls('initialize'),
        hasLength(1),
        reason: 'si `initialize` n\'a pas été appelé, c\'est que le singleton '
            'du paquet avait déjà mémorisé un succès : ce test ne mesure plus '
            'l\'indisponibilité qu\'il annonce',
      );
      expect(
        _listens,
        isEmpty,
        reason: 'la plateforme n\'est pas prête : ouvrir une session serait '
            'allumer un micro sans moteur pour l\'écouter',
      );

      expect(
        find.text('case_message_dictation_unavailable_title'.tr),
        findsOneWidget,
        reason: 'ici la cause EST l\'appareil : ce message-là est le bon',
      );
      expect(
        find.text('case_message_dictation_unavailable_body'.tr),
        findsOneWidget,
      );
      expect(
        find.text('case_message_dictation_not_started_title'.tr),
        findsNothing,
        reason: 'inviter à réessayer une reconnaissance vocale absente '
            'enverrait l\'étudiant taper le bouton indéfiniment',
      );
      expect(
        find.text('case_message_dictation_on_device_unavailable_title'.tr),
        findsNothing,
        reason: 'aucune reconnaissance disponible : proposer la bascule réseau '
            'n\'aurait rien à basculer',
      );

      await _drainOverlays(tester);
    });

    testWidgets(
        'accord donné puis session refusée — « la session n\'a pas démarré »',
        (tester) async {
      _onDevice = _OnDeviceOutcome.refused;
      _platformService = _PlatformServiceOutcome.refused;
      await _openMessageStep(tester);
      await _dictateAndAcceptPlatformService(tester);

      // L'assertion de la réserve A. Avant correctif, c'est
      // `case_message_dictation_unavailable_*` qui s'affichait ici : « la
      // reconnaissance vocale n'est pas disponible sur cet appareil », alors
      // que l'étudiant venait d'autoriser le service qui, lui, l'est.
      expect(
        find.text('case_message_dictation_not_started_title'.tr),
        findsOneWidget,
        reason: 'la reconnaissance est disponible, c\'est la session qui a '
            'échoué : le message doit parler de la session',
      );
      expect(
        find.text('case_message_dictation_not_started_body'.tr),
        findsOneWidget,
      );
      expect(
        find.text('case_message_dictation_unavailable_title'.tr),
        findsNothing,
        reason: 'cause fausse : l\'appareil n\'est pas en défaut, et le dire '
            'dissuade du nouvel essai qui peut suffire',
      );
      expect(
        _networkListens,
        hasLength(1),
        reason: 'sans tentative réseau, le message viendrait d\'un autre '
            'chemin et ce test passerait pour la mauvaise raison',
      );

      await _drainOverlays(tester);
    });

    testWidgets(
        'premier essai sans session et sans refus local — message inchangé',
        (tester) async {
      // Le chemin `!started && !onDeviceUnavailable` du premier essai. Il garde
      // `case_message_dictation_unavailable_*`, comme avant #220 : c'est la
      // moitié « on ne casse pas l'existant » de la réserve A.
      //
      // Piste écartée : lui donner aussi le message « réessaie ». La plateforme
      // a bien accepté l'appel, donc un micro occupé est plausible — mais
      // « aucun moteur installé » l'est tout autant, et rien dans la réponse du
      // greffon ne permet de trancher. Changer ce message serait une décision
      // produit que la mission ne tranche pas ; on applique le plus prudent, le
      // statu quo.
      _onDevice = _OnDeviceOutcome.startedFalse;
      await _openMessageStep(tester);
      await _tapDictate(tester);

      expect(
        find.text('case_message_dictation_unavailable_title'.tr),
        findsOneWidget,
      );
      expect(
        find.text('case_message_dictation_not_started_title'.tr),
        findsNothing,
      );
      expect(
        find.text('case_message_dictation_on_device_unavailable_title'.tr),
        findsNothing,
        reason: '`onDeviceUnavailable` n\'est pas armé sur ce chemin : un '
            'dialogue ici proposerait la bascule réseau pour une panne sans '
            'rapport avec la reconnaissance locale',
      );
      expect(_networkListens, isEmpty);

      await _drainOverlays(tester);
    });

    testWidgets('dictée qui démarre — aucun des deux messages', (tester) async {
      // Contre-épreuve : sans elle, un écran qui afficherait les DEUX bandeaux
      // à chaque tentative rendrait les tests ci-dessus verts.
      _onDevice = _OnDeviceOutcome.accepted;
      await _openMessageStep(tester);
      await _tapDictate(tester);

      expect(find.text('case_message_stop_dictation'.tr), findsOneWidget);
      expect(
        find.text('case_message_dictation_unavailable_title'.tr),
        findsNothing,
      );
      expect(
        find.text('case_message_dictation_not_started_title'.tr),
        findsNothing,
      );

      // On coupe la session tant que le canal est encore simulé : sinon le
      // `dispose` du widget appellerait `stop` sur un canal démonté.
      await tester.tap(find.text('case_message_stop_dictation'.tr));
      await _drainOverlays(tester);
    });

    test('les deux textes existent, diffèrent, et ne conseillent pas pareil',
        () {
      const keys = <String>[
        'case_message_dictation_not_started_title',
        'case_message_dictation_not_started_body',
      ];
      for (final key in keys) {
        expect(_fr()[key], isNotNull, reason: '$key absente du bloc FR');
        expect(_en()[key], isNotNull, reason: '$key absente du bloc EN');
        expect(_fr()[key]!.trim(), isNotEmpty);
        expect(_en()[key], isNot(equals(_fr()[key])),
            reason: '$key : la valeur EN est la copie du FR');
      }

      // Deux clés qui porteraient le même texte laisseraient les tests de
      // rendu ci-dessus verts tout en ne distinguant plus rien à l'écran.
      expect(
        _fr()['case_message_dictation_not_started_body'],
        isNot(equals(_fr()['case_message_dictation_unavailable_body'])),
      );
      expect(
        _en()['case_message_dictation_not_started_body'],
        isNot(equals(_en()['case_message_dictation_unavailable_body'])),
      );

      // Le nouveau message INVITE à réessayer — c'est sa raison d'être.
      expect(_fr()['case_message_dictation_not_started_body'],
          contains('réessaie'));
      expect(_en()['case_message_dictation_not_started_body'],
          contains('try again'));

      // Et il n'accuse pas l'appareil : c'était exactement la cause fausse.
      expect(_fr()['case_message_dictation_not_started_body'],
          isNot(contains('appareil')));
      expect(_en()['case_message_dictation_not_started_body'],
          isNot(contains('device')));

      // Symétriquement, le message d'indisponibilité réelle ne doit pas se
      // mettre à conseiller un nouvel essai : il n'y a rien à réessayer.
      expect(_fr()['case_message_dictation_unavailable_body'],
          isNot(contains('réessai')));
      expect(_en()['case_message_dictation_unavailable_body'],
          isNot(contains('try again')));
    });
  });

  group('(B) le chemin permission micro, enfin joué', () {
    testWidgets('permission refusée — un message, et pas de micro ouvert',
        (tester) async {
      CaseDictationPlatform.requiresMicrophonePermissionOverride = () => true;
      CaseDictationPlatform.requestMicrophonePermissionOverride =
          () async => false;

      _onDevice = _OnDeviceOutcome.accepted;
      await _openMessageStep(tester);
      await _tapDictate(tester);

      expect(
        find.text('case_message_mic_required_title'.tr),
        findsOneWidget,
        reason: 'sans couture, cette branche n\'était atteinte par aucun test '
            'du dépôt : `Platform.isAndroid` est faux sous `flutter test`',
      );
      expect(find.text('case_message_mic_required_body'.tr), findsOneWidget);

      expect(
        _listens,
        isEmpty,
        reason: 'permission refusée : ouvrir une session serait tenter '
            'd\'écouter sans droit, et la plateforme la refuserait de toute '
            'façon — avec un second message par-dessus le premier',
      );
      expect(
        find.text('case_message_dictation_unavailable_title'.tr),
        findsNothing,
      );
      expect(
        find.text('case_message_dictation_not_started_title'.tr),
        findsNothing,
        reason: 'la cause est la permission, et le message le dit déjà',
      );
      expect(find.text('case_message_dictate'.tr), findsOneWidget,
          reason: 'l\'écran ne doit pas prétendre écouter');

      await _drainOverlays(tester);
    });

    testWidgets('permission accordée — la dictée suit son cours',
        (tester) async {
      // Sans cette moitié, une couture qui refuserait TOUJOURS la permission
      // rendrait le test précédent vert en bloquant la dictée pour tout le
      // monde.
      var requests = 0;
      CaseDictationPlatform.requiresMicrophonePermissionOverride = () => true;
      CaseDictationPlatform.requestMicrophonePermissionOverride = () async {
        requests++;
        return true;
      };

      _onDevice = _OnDeviceOutcome.accepted;
      await _openMessageStep(tester);
      await _tapDictate(tester);

      expect(
        requests,
        1,
        reason: 'la permission doit être demandée UNE fois avant la dictée ; '
            'zéro voudrait dire que l\'écran ne passe plus par la couture et '
            'que le test précédent ne mesure plus rien de l\'écran',
      );
      expect(find.text('case_message_mic_required_title'.tr), findsNothing);
      expect(_listens, hasLength(1));
      expect(find.text('case_message_stop_dictation'.tr), findsOneWidget);

      await tester.tap(find.text('case_message_stop_dictation'.tr));
      await _drainOverlays(tester);
    });

    testWidgets('couture non armée — la production d\'aujourd\'hui, intacte',
        (tester) async {
      // La garde du « ne change rien en production ». On n'arme QUE le compteur
      // de demandes, en laissant la condition sur sa valeur par défaut,
      // `Platform.isAndroid`. L'hôte de test n'est pas Android : la permission
      // ne doit donc même pas être demandée, exactement comme avant la couture.
      var requests = 0;
      CaseDictationPlatform.requestMicrophonePermissionOverride = () async {
        requests++;
        return false;
      };

      expect(
        CaseDictationPlatform.requiresMicrophonePermission,
        isFalse,
        reason: 'sur cet hôte de test `Platform.isAndroid` est faux ; si la '
            'valeur par défaut de la couture ne le suivait plus, la '
            'production changerait de comportement à notre insu',
      );

      _onDevice = _OnDeviceOutcome.accepted;
      await _openMessageStep(tester);
      await _tapDictate(tester);

      expect(requests, 0);
      expect(find.text('case_message_mic_required_title'.tr), findsNothing);
      expect(find.text('case_message_stop_dictation'.tr), findsOneWidget);

      await tester.tap(find.text('case_message_stop_dictation'.tr));
      await _drainOverlays(tester);
    });
  });
}
