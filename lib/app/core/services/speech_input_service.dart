import 'dart:developer' as dev;

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around [SpeechToText] for the case tunnel message step.
class SpeechInputService {
  SpeechInputService() : _speech = SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;

  bool get isListening => _speech.isListening;

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

  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'fr_FR',
  }) async {
    final ready = await initialize();
    if (!ready) return false;

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.confirmation,
        partialResults: true,
      ),
    );
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
