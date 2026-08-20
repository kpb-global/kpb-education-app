import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/services/speech_input_service.dart';

/// Le canal du plugin `speech_to_text`. C'est le dernier point Dart avant que
/// l'audio n'atteigne le moteur d'Apple ou de Google : on intercepte ICI, pas
/// une couche au-dessus.
///
/// Piste écartée : faux `SpeechToTextPlatform`. Il faudrait importer
/// `speech_to_text_platform_interface` (absent des dev_dependencies, fichier
/// hors périmètre de ce lot) et surtout il laisserait non vérifiée la
/// traduction options → arguments du canal, faite par
/// `MethodChannelSpeechToText.listen`. C'est exactement la marche où un
/// `onDevice` pourrait se perdre.
const MethodChannel _speechChannel = MethodChannel(
  'plugin.csdcorp.com/speech_to_text',
);

const MethodCodec _codec = StandardMethodCodec();

/// Journal des appels sortants vers la plateforme, arguments compris.
final List<MethodCall> _outgoing = <MethodCall>[];

/// Quand vrai, la plateforme refuse la reconnaissance locale comme le fait iOS
/// sur un appareil sans modèle installé : `FlutterError(code: 'onDeviceError')`
/// remonté en `PlatformException` par le canal.
bool _refuseOnDevice = false;

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

/// Rejoue un `notifyStatus` entrant, comme le plugin natif le fait quelques
/// millisecondes après `listen`. Sans lui `SpeechToText.isListening` reste
/// faux et `startListening` rendrait `false` alors que la session est partie.
Future<void> _pushStatus(String status) {
  return _messenger.handlePlatformMessage(
    _speechChannel.name,
    _codec.encodeMethodCall(MethodCall('notifyStatus', status)),
    (_) {},
  );
}

/// Arguments du dernier `listen` envoyé à la plateforme.
Map<Object?, Object?> _lastListenArgs() {
  final listens = _outgoing.where((c) => c.method == 'listen').toList();
  expect(
    listens,
    isNotEmpty,
    reason: 'aucun appel `listen` na atteint le canal du plugin',
  );
  return listens.last.arguments as Map<Object?, Object?>;
}

void main() {
  setUp(() {
    _outgoing.clear();
    _refuseOnDevice = false;
    _messenger.setMockMethodCallHandler(_speechChannel, (call) async {
      _outgoing.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'listen':
          final args = call.arguments as Map<Object?, Object?>;
          if (_refuseOnDevice && args['onDevice'] == true) {
            throw PlatformException(
              code: 'onDeviceError',
              message: 'on device recognition is not supported on this device',
            );
          }
          await _pushStatus('listening');
          return true;
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
    // `SpeechToText()` est un singleton du paquet : son `_listening` survit
    // d'un test à l'autre. On le remet à plat, sinon un test peut lire l'état
    // laissé par son voisin.
    await _pushStatus('notListening');
    _messenger.setMockMethodCallHandler(_speechChannel, null);
  });

  group('dictée — la voix reste sur l’appareil', () {
    test('la session demande explicitement la reconnaissance locale', () async {
      final service = SpeechInputService();

      final started = await service.startListening(
        onResult: (_, __) {},
        localeId: 'fr_FR',
      );

      expect(started, isTrue);

      final args = _lastListenArgs();
      expect(
        args['onDevice'],
        isTrue,
        reason:
            'la charge utile envoyée au moteur natif doit porter onDevice=true ; '
            'false signifie « appareil ET réseau », donc audio de l’étudiant '
            'transmis à Apple ou Google alors que la politique de '
            'confidentialité promet une conversion sur l’appareil',
      );
      // La locale voyage dans la même charge utile : si elle se perdait, la
      // dictée basculerait sur la langue système et le correctif serait
      // « vert » pour une session inutilisable.
      expect(args['localeId'], 'fr_FR');
      expect(service.lastProcessingMode, SpeechProcessingMode.onDevice);
      expect(service.onDeviceUnavailable, isFalse);
    });

    test(
      'refus local : aucune session réseau lancée en silence',
      () async {
        _refuseOnDevice = true;
        final service = SpeechInputService();
        var warned = false;

        final started = await service.startListening(
          onResult: (_, __) {},
          onOnDeviceUnavailable: () => warned = true,
        );

        // La charge utile d'abord : c'est elle qui dit où la voix est partie.
        // `started == false` n'est qu'un symptôme, et un repli muet le
        // remettrait à `true` en ayant déjà envoyé l'audio.
        final networkAttempts = _outgoing
            .where((c) => c.method == 'listen')
            .where(
              (c) => (c.arguments as Map<Object?, Object?>)['onDevice'] != true,
            );
        expect(
          networkAttempts,
          isEmpty,
          reason:
              'un repli automatique sur onDevice=false enverrait la voix au '
              'service de la plateforme sans que l’étudiant l’ait accepté',
        );

        expect(started, isFalse);
        expect(
          warned,
          isTrue,
          reason:
              'l’appelant doit être prévenu pour pouvoir avertir l’étudiant ; '
              'sans ce signal la dictée échouerait sans explication',
        );
        expect(service.onDeviceUnavailable, isTrue);
        expect(
          service.lastProcessingMode,
          isNull,
          reason: 'aucune session n’a démarré',
        );
      },
    );

    test(
      'après accord explicite, et seulement alors, la voix part au service '
      'de la plateforme',
      () async {
        final service = SpeechInputService();

        final started = await service.startListening(
          onResult: (_, __) {},
          allowPlatformService: true,
        );

        expect(started, isTrue);
        expect(_lastListenArgs()['onDevice'], isFalse);
        expect(
          service.lastProcessingMode,
          SpeechProcessingMode.platformService,
          reason:
              'le mode doit être lisible par l’UI : c’est ce qui permet de dire '
              'à l’étudiant où sa voix est traitée',
        );
      },
    );
  });
}
