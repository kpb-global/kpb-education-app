import 'dart:developer' as dev;

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Où la voix de l'étudiant est reconnue pendant une session de dictée.
///
/// La politique de confidentialité promet « converti en texte sur l'appareil ».
/// Ce mode est donc une information à rendre visible, pas un détail interne :
/// dès qu'il vaut [platformService], la voix quitte le téléphone.
enum SpeechProcessingMode {
  /// Reconnaissance locale demandée à la plateforme : l'audio ne part pas
  /// vers les serveurs d'Apple ou de Google.
  onDevice,

  /// Service de reconnaissance de la plateforme (Apple / Google) : la voix
  /// de l'étudiant est transmise et traitée hors de l'appareil.
  platformService,
}

/// Thin wrapper around [SpeechToText] for the case tunnel message step.
class SpeechInputService {
  SpeechInputService() : _speech = SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  SpeechProcessingMode? _lastProcessingMode;
  bool _onDeviceUnavailable = false;

  bool get isListening => _speech.isListening;

  /// Mode de la dernière session de dictée réellement lancée, `null` si aucune.
  SpeechProcessingMode? get lastProcessingMode => _lastProcessingMode;

  /// Vrai quand la plateforme a refusé la reconnaissance locale au dernier
  /// essai. L'appelant doit alors AVERTIR l'étudiant que sa voix serait
  /// traitée par le service d'Apple ou de Google, et n'appeler
  /// [startListening] avec `allowPlatformService: true` qu'après un accord
  /// explicite.
  bool get onDeviceUnavailable => _onDeviceUnavailable;

  Future<bool> initialize() async {
    if (_initialized) return _speech.isAvailable;
    _initialized = true;
    try {
      return await _speech.initialize(
        onError: (error) => dev.log('Speech error: $error'),
        onStatus: (status) => dev.log('Speech status: $status'),
      );
    } catch (e) {
      dev.log('Speech init failed: $e');
      return false;
    }
  }

  /// Démarre une dictée. Par défaut la reconnaissance est demandée SUR
  /// L'APPAREIL (`onDevice: true`).
  ///
  /// Le défaut du paquet, `onDevice: false`, ne veut pas dire « réseau si
  /// besoin » : il veut dire « appareil ET réseau », donc audio potentiellement
  /// envoyé au service de la plateforme à chaque session — ce que la politique
  /// de confidentialité de l'app contredit.
  ///
  /// Quand la reconnaissance locale n'est pas installée, iOS refuse la session
  /// (erreur `onDeviceError`) : on ne bascule PAS sur le réseau tout seul, on
  /// rend `false` en armant [onDeviceUnavailable] et en appelant
  /// [onOnDeviceUnavailable]. La bascule réseau existe, mais elle exige
  /// `allowPlatformService: true`, c'est-à-dire un accord de l'étudiant obtenu
  /// par l'appelant. Une dictée momentanément indisponible est réparable ;
  /// une voix partie en silence ne l'est pas.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'fr_FR',
    bool allowPlatformService = false,
    void Function()? onOnDeviceUnavailable,
  }) async {
    final ready = await initialize();
    if (!ready) return false;

    final requestOnDevice = !allowPlatformService;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.confirmation,
          partialResults: true,
          onDevice: requestOnDevice,
        ),
      );
    } on ListenFailedException catch (e) {
      // Toute session refusée alors qu'on demandait l'appareil est traitée
      // comme « reconnaissance locale indisponible ». Piste écartée : filtrer
      // sur le code `onDeviceError` d'iOS — `ListenFailedException` ne retient
      // que `message`/`details` et JETTE le code de la `PlatformException`, il
      // ne reste qu'une phrase anglaise de la plateforme à renifler. Se
      // tromper ici ne coûte qu'un avertissement affiché pour rien ; l'erreur
      // inverse enverrait la voix sans le dire.
      if (requestOnDevice) {
        _onDeviceUnavailable = true;
        onOnDeviceUnavailable?.call();
      }
      dev.log(
          'Speech listen refused (onDevice=$requestOnDevice): ${e.message}');
      return false;
    } catch (e) {
      // Micro occupé, plateforme non initialisée, canal absent : échec de
      // dictée ordinaire. On n'arme pas [onDeviceUnavailable] — le proposer
      // ici ferait offrir la bascule réseau pour une panne sans rapport.
      dev.log('Speech listen failed: $e');
      return false;
    }

    _onDeviceUnavailable = false;
    _lastProcessingMode = requestOnDevice
        ? SpeechProcessingMode.onDevice
        : SpeechProcessingMode.platformService;
    return _speech.isListening;
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
