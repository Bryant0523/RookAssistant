import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService instance = TtsService._();
  TtsService._();

  final _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<void> init() async {
    await _tts.setLanguage('es-CO');
    await _tts.setSpeechRate(0.48);    // Velocidad natural
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.95);         // Tono ligeramente grave — más JARVIS

    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setErrorHandler((msg) {
      _speaking = false;
      debugPrint('[TTS] Error: $msg');
    });

    _initialized = true;
    debugPrint('[TTS] Inicializado');
  }

  Future<void> speak(String text) async {
    if (!_initialized) await init();
    await stop();           // Corta cualquier cosa que esté diciendo
    await _tts.speak(text);
  }

  Future<void> stop() async {
    if (_speaking) await _tts.stop();
  }

  Future<void> dispose() async => await _tts.stop();
}
