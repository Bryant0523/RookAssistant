import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum WakeWordState { idle, listening, triggered, error }

class WakeWordService {
  static final WakeWordService instance = WakeWordService._();
  WakeWordService._();

  SpeechToText? _stt;
  bool _running = false;
  bool _paused  = false;
  WakeWordState _state = WakeWordState.idle;

  final _stateController   = StreamController<WakeWordState>.broadcast();
  final _triggerController = StreamController<void>.broadcast();

  Stream<WakeWordState> get stateStream   => _stateController.stream;
  Stream<void>          get triggerStream => _triggerController.stream;
  WakeWordState         get state          => _state;

  static const List<String> _keywords = [
    'jarvis', 'hey jarvis', 'oye jarvis', 'hola jarvis',
    'yarbis', 'oye yarbis',
    'rook', 'hey rook', 'oye rook',
  ];

  void setSttInstance(SpeechToText stt) {
    _stt = stt;
    debugPrint('[WakeWord] setSttInstance OK');
  }

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> start() async {
    debugPrint('[WakeWord] start() llamado, _stt=${_stt != null}');
    if (_running) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      _setState(WakeWordState.error);
      debugPrint('[WakeWord] Sin permiso de micrófono');
      return;
    }

    _running = true;
    _paused  = false;
    await _listenLoop();
  }
/// Llamado cuando el STT falla por timeout — reinicia el loop
void onSttError() {
  if (_running && !_paused) {
    debugPrint('[WakeWord] Timeout/error — reiniciando loop...');
    Future.delayed(const Duration(milliseconds: 500), _listenLoop);
  }
}
  Future<void> _listenLoop() async {
    if (!_running || _paused) return;

    if (_stt == null) {
      debugPrint('[WakeWord] ERROR: _stt no inicializado, esperando...');
      await Future.delayed(const Duration(seconds: 1));
      _listenLoop();
      return;
    }

    if (_stt!.isListening) return;

    _setState(WakeWordState.listening);
    debugPrint('[WakeWord] Iniciando ciclo de escucha...');

    try {
      await _stt!.listen(
        onResult: _onResult,
        localeId: 'es_CO',
        listenMode: ListenMode.confirmation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 10),
        partialResults: true,
        cancelOnError: false,
        onSoundLevelChange: null,
      );
    } catch (e) {
      debugPrint('[WakeWord] Error en listen: $e');
      if (_running && !_paused) {
        await Future.delayed(const Duration(seconds: 1));
        _listenLoop();
      }
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.toLowerCase().trim();
    if (text.isEmpty) return;

    debugPrint('[WakeWord] Escuché: "$text"');

    if (_keywords.any((kw) => text.contains(kw))) {
      debugPrint('[WakeWord] ¡Wake word detectado!');
      _setState(WakeWordState.triggered);
      _triggerController.add(null);
      return;
    }

    if (result.finalResult && _running && !_paused) {
      Future.delayed(const Duration(milliseconds: 300), _listenLoop);
    }
  }

  Future<void> pause() async {
    _paused = true;
    if (_stt?.isListening ?? false) await _stt!.stop();
    _setState(WakeWordState.idle);
    debugPrint('[WakeWord] Pausado');
  }

  Future<void> resume() async {
    if (!_running) return;
    _paused = false;
    await Future.delayed(const Duration(milliseconds: 500));
    await _listenLoop();
    debugPrint('[WakeWord] Reanudado');
  }

  Future<void> dispose() async {
    _running = false;
    _paused  = true;
    if (_stt?.isListening ?? false) await _stt!.cancel();
    await _stateController.close();
    await _triggerController.close();
  }

  void _setState(WakeWordState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }
}