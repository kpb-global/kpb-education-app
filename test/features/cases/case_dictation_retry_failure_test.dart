// La dictée du tunnel de dossier : ce qui arrive APRÈS que l'étudiant a
// accepté d'envoyer sa voix au service de la plateforme.
//
// ## Le défaut
//
// `SpeechInputService` demande la reconnaissance LOCALE. Quand l'appareil ne
// sait pas le faire, la session est refusée et l'écran ouvre un dialogue :
// « votre voix serait envoyée à Apple/Google, on continue ? ». Si l'étudiant
// accepte, l'écran relance la dictée avec `allowPlatformService: true`.
//
// Cette SECONDE tentative peut échouer elle aussi — micro occupé par un autre
// appel, service de reconnaissance indisponible, session refusée. La branche se
// contentait alors de reposer `_listening = false` et de sortir, en sautant le
// message d'échec écrit juste en dessous. L'étudiant acceptait, le dialogue se
// fermait, et RIEN ne se passait. Un bouton qui n'a rien fait et pas un mot :
// exactement le silence que le dialogue venait d'éviter.
//
// ## Pourquoi ce fichier monte l'écran
//
// Le défaut n'est pas dans `SpeechInputService` — il rend bien `false` — mais
// dans ce que l'écran fait de ce `false`. Un test de service ne pouvait donc pas
// le voir. Et une assertion sur `_listening` ne prouverait rien non plus : l'état
// était déjà correct AVANT correctif. C'est la PRÉSENCE DU MESSAGE qui est la
// preuve, puisque c'est son absence qui était le bug.
//
// ## Le piège à ne pas retomber dedans
//
// `SpeechInputService.onDeviceUnavailable` n'est armé que sur un essai
// `onDevice`, et n'est désarmé qu'en cas de SUCCÈS. Après l'échec de la seconde
// tentative il vaut donc encore `true`, hérité du premier essai : s'en servir
// pour choisir le message reproposerait le dialogue en boucle. Le dernier test du
// groupe (1) verrouille ça en comptant les dialogues.

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

/// Le canal du plugin `speech_to_text` — le dernier point Dart avant le moteur
/// natif. On intercepte ICI, comme `test/core/services/speech_input_on_device_test.dart`,
/// pour que la traduction options → arguments du canal reste vérifiée : c'est la
/// marche où un `onDevice` peut se perdre.
const MethodChannel _speechChannel = MethodChannel(
  'plugin.csdcorp.com/speech_to_text',
);

const MethodCodec _codec = StandardMethodCodec();

/// Ce que la plateforme répond à la tentative RÉSEAU (`onDevice == false`),
/// c'est-à-dire à la seconde tentative, celle faite après l'accord de
/// l'étudiant. La tentative locale, elle, est toujours refusée dans ce
/// fichier — c'est le seul chemin qui ouvre le dialogue.
enum _PlatformServiceOutcome {
  /// Session refusée par la plateforme : micro occupé, service indisponible.
  /// Remonte en `PlatformException`, que `speech_to_text` retraduit en
  /// `ListenFailedException`.
  refused,

  /// La plateforme accepte l'appel mais ne démarre pas de session (`false`),
  /// sans lever. Chemin distinct du précédent dans `SpeechInputService` : il
  /// passe par la sortie normale, qui DÉSARME `onDeviceUnavailable`. Les deux
  /// doivent parler à l'étudiant.
  startedFalse,

  /// La dictée réseau démarre pour de bon.
  accepted,
}

late _PlatformServiceOutcome _platformService;
final List<MethodCall> _outgoing = <MethodCall>[];

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Rejoue un `notifyStatus` entrant, comme le plugin natif le fait quelques
/// millisecondes après `listen`. Sans lui `SpeechToText.isListening` reste faux
/// et une session réellement partie serait lue comme un échec.
Future<void> _pushStatus(String status) {
  return _messenger.handlePlatformMessage(
    _speechChannel.name,
    _codec.encodeMethodCall(MethodCall('notifyStatus', status)),
    (_) {},
  );
}

Iterable<MethodCall> get _listens =>
    _outgoing.where((c) => c.method == 'listen');

Iterable<MethodCall> get _networkListens => _listens.where(
      (c) => (c.arguments as Map<Object?, Object?>)['onDevice'] != true,
    );

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

/// Avance d'environ 1,2 s de trames : de quoi laisser le dialogue s'ouvrir ou
/// se fermer, la tentative de dictée rendre sa réponse et le bandeau
/// `Get.snackbar` entrer — mais PAS repartir.
///
/// Cette borne haute est la partie fragile du harnais, et elle a déjà menti une
/// fois pendant l'écriture de ce fichier. `pumpAndSettle` est hors jeu : le
/// bandeau GetX anime, attend, puis anime encore, donc « tout se stabilise »
/// n'arrive qu'après sa disparition. Mais avancer de 5 s ne marche pas non
/// plus : le bandeau s'auto-efface au bout de 3 s, l'assertion « le message est
/// là » tombait alors sur un écran redevenu vide et accusait le correctif. Et
/// symétriquement, une contre-épreuve « pas de message » attendant 5 s serait
/// verte même si un bandeau avait bel et bien clignoté. On observe donc pendant
/// la fenêtre où le bandeau est visible, et on vide les minuteurs après.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// À appeler en fin de test : épuise le minuteur d'auto-effacement du bandeau et
/// son animation de sortie. Sans lui, le test se termine sur un minuteur en
/// attente, ce que le framework signale comme un échec.
Future<void> _drainOverlays(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

/// Tape sur « Dicter mon message », puis accepte le dialogue de bascule réseau.
Future<void> _dictateAndAcceptPlatformService(WidgetTester tester) async {
  await tester.tap(find.text('case_message_dictate'.tr));
  await _settle(tester);

  expect(
    find.text('case_message_dictation_on_device_unavailable_title'.tr),
    findsOneWidget,
    reason: 'le refus de reconnaissance locale doit ouvrir le dialogue '
        'd\'accord ; sans lui le reste du scénario n\'existe pas',
  );

  await tester.tap(find.text('case_message_dictation_use_platform_service'.tr));
  await _settle(tester);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    _outgoing.clear();
    _platformService = _PlatformServiceOutcome.refused;
    _messenger.setMockMethodCallHandler(_speechChannel, (call) async {
      _outgoing.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'listen':
          final args = call.arguments as Map<Object?, Object?>;
          if (args['onDevice'] == true) {
            // iOS sur un appareil sans modèle local installé.
            throw PlatformException(
              code: 'onDeviceError',
              message: 'on device recognition is not supported on this device',
            );
          }
          switch (_platformService) {
            case _PlatformServiceOutcome.refused:
              throw PlatformException(
                code: 'error_busy',
                message: 'the recognizer is busy',
              );
            case _PlatformServiceOutcome.startedFalse:
              return false;
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
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  group('(1) accord donné, seconde tentative échouée : l\'étudiant est prévenu',
      () {
    testWidgets(
        'session refusée par la plateforme — un message, pas le silence',
        (tester) async {
      _platformService = _PlatformServiceOutcome.refused;
      await _openMessageStep(tester);
      await _dictateAndAcceptPlatformService(tester);

      // L'assertion qui attrape le défaut. Avant correctif, la branche sortait
      // après `setState` sans rien dire.
      expect(
        find.text('case_message_dictation_unavailable_title'.tr),
        findsOneWidget,
        reason:
            'l\'étudiant a accepté, le dialogue s\'est fermé, la dictée n\'a '
            'pas démarré : sans message il ne lui reste qu\'un bouton qui n\'a '
            'rien fait, et la conclusion que l\'app est cassée',
      );
      expect(
        find.text('case_message_dictation_unavailable_body'.tr),
        findsOneWidget,
      );

      // La tentative réseau a bien eu lieu — sinon le message serait juste
      // celui d'un dialogue annulé, et ce test passerait pour la mauvaise
      // raison.
      expect(_networkListens, hasLength(1));

      await _drainOverlays(tester);
    });

    testWidgets(
        'plateforme qui ne démarre rien sans lever — même retour à l\'étudiant',
        (tester) async {
      // Chemin distinct dans `SpeechInputService` : la sortie normale, qui
      // DÉSARME `onDeviceUnavailable`. Un correctif qui n'aurait traité que le
      // chemin « exception » laisserait celui-ci muet.
      _platformService = _PlatformServiceOutcome.startedFalse;
      await _openMessageStep(tester);
      await _dictateAndAcceptPlatformService(tester);

      expect(
        find.text('case_message_dictation_unavailable_title'.tr),
        findsOneWidget,
      );
      expect(_networkListens, hasLength(1));

      await _drainOverlays(tester);
    });

    testWidgets('le dialogue n\'est pas reproposé en boucle', (tester) async {
      _platformService = _PlatformServiceOutcome.refused;
      await _openMessageStep(tester);
      await _dictateAndAcceptPlatformService(tester);

      // `onDeviceUnavailable` vaut ENCORE `true` à ce point (armé au premier
      // essai, désarmé seulement en cas de succès). Un correctif qui le relirait
      // pour choisir le message rouvrirait le dialogue indéfiniment.
      expect(
        find.text('case_message_dictation_on_device_unavailable_title'.tr),
        findsNothing,
        reason: 'un second dialogue enfermerait l\'étudiant dans une boucle '
            'accord → échec → accord',
      );
      expect(
        _networkListens,
        hasLength(1),
        reason: 'une seule tentative réseau par accord donné',
      );

      await _drainOverlays(tester);
    });

    testWidgets('l\'écran ne prétend pas écouter', (tester) async {
      _platformService = _PlatformServiceOutcome.refused;
      await _openMessageStep(tester);
      await _dictateAndAcceptPlatformService(tester);

      // Assertion secondaire, et volontairement pas la principale : cet état
      // était DÉJÀ correct avant correctif. Elle ne prouve rien du silence, elle
      // interdit seulement d'échanger un défaut contre un autre.
      expect(find.text('case_message_stop_dictation'.tr), findsNothing);
      expect(find.text('listening_speak_clearly'.tr), findsNothing);
      expect(find.text('case_message_dictate'.tr), findsOneWidget);

      await _drainOverlays(tester);
    });
  });

  group('(2) contre-épreuves — le message n\'est pas affiché à tort', () {
    testWidgets('seconde tentative réussie : aucun message d\'échec',
        (tester) async {
      // Sans cette contre-épreuve, un écran qui crierait « dictée
      // indisponible » à chaque accord donnerait les mêmes verts que le
      // correctif.
      _platformService = _PlatformServiceOutcome.accepted;
      await _openMessageStep(tester);
      await _dictateAndAcceptPlatformService(tester);

      expect(
        find.text('case_message_dictation_unavailable_title'.tr),
        findsNothing,
        reason: 'la dictée a démarré : annoncer un échec serait un mensonge',
      );
      expect(find.text('case_message_stop_dictation'.tr), findsOneWidget);
      expect(find.text('listening_speak_clearly'.tr), findsOneWidget);

      // On coupe la session tant que le canal est encore simulé : sinon le
      // `dispose` du widget appellerait `stop` sur un canal démonté.
      await tester.tap(find.text('case_message_stop_dictation'.tr));
      await _drainOverlays(tester);
    });

    testWidgets('dialogue refusé : ni dictée réseau, ni message d\'échec',
        (tester) async {
      _platformService = _PlatformServiceOutcome.accepted;
      await _openMessageStep(tester);

      await tester.tap(find.text('case_message_dictate'.tr));
      await _settle(tester);
      await tester.tap(find.text('cancel'.tr));
      await _settle(tester);

      expect(
        _networkListens,
        isEmpty,
        reason: 'refuser le dialogue doit laisser la voix sur l\'appareil ; '
            'une session réseau ici serait une fuite',
      );
      expect(
        find.text('case_message_dictation_unavailable_title'.tr),
        findsNothing,
        reason: 'l\'étudiant vient de choisir d\'écrire au clavier : rien n\'a '
            'échoué, et un bandeau d\'échec le contredirait',
      );

      await _drainOverlays(tester);
    });
  });
}
