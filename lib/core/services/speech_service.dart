import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum SpeechState { idle, listening, processing, error }

class SpeechService {
  static final SpeechService instance = SpeechService._();
  SpeechService._();

  final _stt    = SpeechToText();
  bool _available = false;
  bool _isStarting = false;
  SpeechState _state = SpeechState.idle;

  final _stateController  = StreamController<SpeechState>.broadcast();
  final _resultController = StreamController<String>.broadcast();
  final _partialController= StreamController<String>.broadcast();

  Stream<SpeechState> get stateStream   => _stateController.stream;
  Stream<String>      get resultStream  => _resultController.stream;
  Stream<String>      get partialStream => _partialController.stream;
  SpeechState         get state          => _state;

  Future<void> init() async {
    _available = await _stt.initialize(
      onError: (e) {
        debugPrint('[Speech] Error: ${e.errorMsg}');
        _setState(SpeechState.error);
      },
      onStatus: (status) {
        debugPrint('[Speech] Status: $status');
        if (status == 'done' || status == 'notListening') {
          _setState(SpeechState.idle);
        }
      },
    );
    debugPrint('[Speech] Disponible: $_available');
  }

  Future<void> startListening() async {
    if (!_available || _state == SpeechState.listening || _stt.isListening || _isStarting) return;

    _isStarting = true;
    try {
      if (kIsWeb) {
        await _stt.cancel();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      _setState(SpeechState.listening);

      await _stt.listen(
        onResult: _onResult,
        localeId: 'es_CO',          // Español Colombia — cambia a es_ES, es_MX, etc.
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 15),
        partialResults: true,
      );
    } catch (e) {
      debugPrint('[Speech] Error al iniciar escucha: $e');
      _setState(SpeechState.error);
    } finally {
      _isStarting = false;
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      final text = result.recognizedWords.trim();
      debugPrint('[Speech] Resultado final: $text');
      if (text.isNotEmpty) {
        _resultController.add(text);
      }
      _setState(SpeechState.idle);
    } else {
      // Resultado parcial — útil para mostrar en la UI en tiempo real
      _partialController.add(result.recognizedWords);
    }
  }

  Future<void> stopListening() async {
    if (_stt.isListening) {
      await _stt.stop();
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }
    _setState(SpeechState.idle);
  }

  Future<void> cancelListening() async {
    await _stt.cancel();
    _setState(SpeechState.idle);
  }

  bool get isListening => _state == SpeechState.listening;

  void _setState(SpeechState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  Future<void> dispose() async {
    await _stt.cancel();
    await _stateController.close();
    await _resultController.close();
    await _partialController.close();
  }
}
