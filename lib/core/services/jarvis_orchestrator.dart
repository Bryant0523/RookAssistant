import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/intent.dart';
import '../services/wake_word_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../../modules/reminders/reminders_module.dart';
import '../../modules/files/files_module.dart';
import '../../modules/system/system_module.dart';

/// Estado global del asistente
enum AssistantState {
  sleeping,     // Esperando wake word
  waking,       // Wake word detectado
  listening,    // Grabando voz del usuario
  processing,   // Procesando el comando
  responding,   // Hablando respuesta
  error,
}

/// Orquestador central de JARVIS
/// Conecta: WakeWord → STT → IntentEngine → Módulo → TTS
class JarvisOrchestrator {
  static final JarvisOrchestrator instance = JarvisOrchestrator._();
  JarvisOrchestrator._();

  AssistantState _state = AssistantState.sleeping;
  String _lastTranscript = '';
  String _lastResponse = '';
  final List<Map<String, String>> _history = [];

  final _stateController     = StreamController<AssistantState>.broadcast();
  final _transcriptController= StreamController<String>.broadcast();
  final _responseController  = StreamController<String>.broadcast();

  Stream<AssistantState> get stateStream      => _stateController.stream;
  Stream<String>         get transcriptStream => _transcriptController.stream;
  Stream<String>         get responseStream   => _responseController.stream;
  AssistantState         get state             => _state;
  String                 get lastTranscript    => _lastTranscript;
  String                 get lastResponse      => _lastResponse;
  List<Map<String, String>> get history        => List.unmodifiable(_history);

  StreamSubscription? _wakeWordSub;
  StreamSubscription? _speechSub;
  StreamSubscription? _partialSub;

  // ─── Inicialización ────────────────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('[JARVIS] Inicializando orquestador...');

    // Inicializar servicios en paralelo
    await Future.wait([
      SpeechService.instance.init(),
      TtsService.instance.init(),
      RemindersModule.instance.init(),
    ]);
    
    WakeWordService.instance.setSttInstance(SpeechService.instance.sttInstance);

    SpeechService.instance.onSttError = () {
      WakeWordService.instance.onSttError();
    };
    // Escuchar wake word → iniciar grabación
    _wakeWordSub = WakeWordService.instance.triggerStream.listen((_) {
      _onWakeWord();
    });

    // Escuchar resultado final de voz → procesar
    _speechSub = SpeechService.instance.resultStream.listen((text) {
      _onSpeechResult(text);
    });

    // Escuchar resultado parcial → actualizar UI en tiempo real
    _partialSub = SpeechService.instance.partialStream.listen((text) {
      _transcriptController.add(text);
    });

    debugPrint('[JARVIS] Listo');
  }

  Future<void> startWakeWord() async {
  await WakeWordService.instance.start();
  _setState(AssistantState.sleeping);
}

  // ─── Flujo principal ───────────────────────────────────────────────────────

  void _onWakeWord() {
  if (_state == AssistantState.sleeping) {
    debugPrint('[JARVIS] Wake word → iniciando escucha');
    _setState(AssistantState.waking);

    // NUEVO: pausa el wake word antes de escuchar el comando
    WakeWordService.instance.pause().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _startListening();
      });
    });
  }
}

  Future<void> _startListening() async {
    _setState(AssistantState.listening);
    await SpeechService.instance.startListening();

    // Timeout de seguridad: si en 20s no hay resultado, vuelve a dormir
    Future.delayed(const Duration(seconds: 20), () {
      if (_state == AssistantState.listening) {
        _setState(AssistantState.sleeping);
      }
    });
  }

  Future<void> _onSpeechResult(String text) async {
    if (text.isEmpty) {
      await WakeWordService.instance.resume(); // NUEVO
      _setState(AssistantState.sleeping);
      return;
    }

    _lastTranscript = text;
    _transcriptController.add(text);
    _setState(AssistantState.processing);

    debugPrint('[JARVIS] Procesando: "$text"');

    final intent = IntentEngine.parse(text);
    debugPrint('[JARVIS] Intent: $intent');

    // Comando de parada
    if (intent.name == 'stop') {
      await TtsService.instance.stop();
      await WakeWordService.instance.resume(); 
      _setState(AssistantState.sleeping);
      return;
    }

    final response = await _routeToModule(intent);

    if (response.isNotEmpty) {
      _lastResponse = response;
      _responseController.add(response);
      _addToHistory(text, response);

      _setState(AssistantState.responding);
      await TtsService.instance.speak(response);
    }

    await WakeWordService.instance.resume(); 
    _setState(AssistantState.sleeping);
  }
  Future<String> _routeToModule(JarvisIntent intent) async {
    try {
      if (RemindersModule.instance.canHandle(intent.name)) {
        return await RemindersModule.instance.execute(intent);
      }
      if (FilesModule.instance.canHandle(intent.name)) {
        return await FilesModule.instance.execute(intent);
      }
      if (SystemModule.instance.canHandle(intent.name)) {
        return await SystemModule.instance.execute(intent);
      }
      return 'No tengo un módulo para eso aún. Estoy en desarrollo.';
    } catch (e) {
      debugPrint('[JARVIS] Error en módulo: $e');
      return 'Hubo un error procesando tu solicitud.';
    }
  }

  // ─── Activación manual (botón en la UI) ────────────────────────────────────

  Future<void> activateManually() async {
    if (_state == AssistantState.sleeping || _state == AssistantState.error) {
      await _startListening();
    } else if (_state == AssistantState.listening) {
      await SpeechService.instance.stopListening();
      _setState(AssistantState.sleeping);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _addToHistory(String transcript, String response) {
    _history.insert(0, {'user': transcript, 'jarvis': response});
    if (_history.length > 50) _history.removeLast();
  }

  void _setState(AssistantState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  Future<void> dispose() async {
    await _wakeWordSub?.cancel();
    await _speechSub?.cancel();
    await _partialSub?.cancel();
    await WakeWordService.instance.dispose();
    await SpeechService.instance.dispose();
    await TtsService.instance.dispose();
  }
}
