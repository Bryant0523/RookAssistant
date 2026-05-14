import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Estados posibles del servicio de wake word
enum WakeWordState { idle, listening, triggered, error }

/// Servicio que escucha continuamente el wake word "JARVIS"
/// Fallback con speech_to_text para detectar la palabra clave localmente.
class WakeWordService {
  static final WakeWordService instance = WakeWordService._();
  WakeWordService._();

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _isListening = false;
  WakeWordState _state = WakeWordState.idle;

  // Stream para notificar a la UI y otros servicios
  final _stateController = StreamController<WakeWordState>.broadcast();
  final _triggerController = StreamController<void>.broadcast();

  Stream<WakeWordState> get stateStream  => _stateController.stream;
  Stream<void>          get triggerStream => _triggerController.stream;
  WakeWordState         get state         => _state;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _initializeStt() async {
    if (_initialized) return;

    _initialized = await _stt.initialize(
      onError: (error) {
        debugPrint('[WakeWord] STT error: ${error.errorMsg}');
        _setState(WakeWordState.error);
      },
      onStatus: (status) {
        debugPrint('[WakeWord] STT status: $status');
        if (status == 'notListening') {
          _isListening = false;
          if (_state == WakeWordState.listening) {
            Future.delayed(const Duration(milliseconds: 300), _listenForWakeWord);
          }
        }
      },
    );

    if (!_initialized) {
      debugPrint('[WakeWord] STT no disponible');
      _setState(WakeWordState.error);
    }
  }

  Future<void> start() async {
    if (kIsWeb) {
      debugPrint('[WakeWord] Wake word deshabilitado en web');
      _setState(WakeWordState.idle);
      return;
    }

    if (_state == WakeWordState.listening) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      _setState(WakeWordState.error);
      debugPrint('[WakeWord] Sin permiso de micrófono');
      return;
    }

    await _initializeStt();
    if (!_initialized) return;

    await _listenForWakeWord();
  }

  Future<void> _listenForWakeWord() async {
    if (kIsWeb || !_initialized || _isListening) return;

    _setState(WakeWordState.listening);
    _isListening = true;

    await _stt.listen(
      onResult: _onResult,
      localeId: 'es_CO',
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 20),
      partialResults: true,
    );

    debugPrint('[WakeWord] Escuchando wake word con STT...');
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.toLowerCase();
    debugPrint('[WakeWord] STT texto: $text');

    if (text.contains('jarvis') || text.contains('oye jarvis') || text.contains('hola jarvis') || text.contains('hey jarvis')) {
      _onWakeWord();
    }

    if (result.finalResult) {
      _isListening = false;
      if (_state == WakeWordState.listening) {
        Future.delayed(const Duration(milliseconds: 300), _listenForWakeWord);
      }
    }
  }

  Future<void> _onWakeWord() async {
    if (_state != WakeWordState.listening) return;

    debugPrint('[WakeWord] ¡Wake word detectado!');
    _setState(WakeWordState.triggered);
    _triggerController.add(null);

    if (_stt.isListening) {
      await _stt.stop();
      _isListening = false;
    }

    // Vuelve a estado de escucha después de 200ms
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_state == WakeWordState.triggered) {
        _setState(WakeWordState.listening);
      }
    });
  }

  Future<void> pause() async {
    if (_stt.isListening) await _stt.stop();
    _isListening = false;
    _setState(WakeWordState.idle);
  }

  Future<void> resume() async {
    if (!_stt.isListening) {
      await _listenForWakeWord();
    }
  }

  Future<void> dispose() async {
    await _stt.cancel();
    await _stateController.close();
    await _triggerController.close();
    _setState(WakeWordState.idle);
  }

  void _setState(WakeWordState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }
}
