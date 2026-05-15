import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/jarvis_orchestrator.dart';
import '../../core/services/wake_word_service.dart';
import '../theme/jarvis_theme.dart';
import 'reminders_screen.dart';

class JarvisHomeScreen extends StatefulWidget {
  const JarvisHomeScreen({super.key});
  @override
  State<JarvisHomeScreen> createState() => _JarvisHomeScreenState();
}

class _JarvisHomeScreenState extends State<JarvisHomeScreen>
    with TickerProviderStateMixin {

  late AnimationController _orbController;
  late AnimationController _pulseController;
  late AnimationController _wakeController;

  AssistantState _assistantState = AssistantState.sleeping;
  String _transcript  = '';
  String _response    = '';
  bool   _wakeActive  = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupListeners();
    _startJarvis();
  }

  void _setupAnimations() {
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _wakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void _setupListeners() {
    JarvisOrchestrator.instance.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _assistantState = state);

      switch (state) {
        case AssistantState.waking:
          _wakeController.forward(from: 0);
          _pulseController.repeat(reverse: true);
          break;
        case AssistantState.listening:
          _pulseController.repeat(reverse: true);
          break;
        case AssistantState.processing:
          _pulseController.stop();
          break;
        case AssistantState.responding:
          _pulseController.repeat(reverse: true);
          break;
        case AssistantState.sleeping:
          _pulseController.stop();
          setState(() => _transcript = '');
          break;
        default:
          break;
      }
    });

    JarvisOrchestrator.instance.transcriptStream.listen((text) {
      if (mounted) setState(() => _transcript = text);
    });

    JarvisOrchestrator.instance.responseStream.listen((text) {
      if (mounted) setState(() => _response = text);
    });

    WakeWordService.instance.stateStream.listen((state) {
      if (mounted) setState(() => _wakeActive = state == WakeWordState.listening);
    });
  }

  Future<void> _startJarvis() async {
  await JarvisOrchestrator.instance.init();
  await JarvisOrchestrator.instance.startWakeWord();
}

  @override
  void dispose() {
    _orbController.dispose();
    _pulseController.dispose();
    _wakeController.dispose();
    super.dispose();
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildCenter()),
            _buildBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Logo / nombre
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('J.A.R.V.I.S',
                style: TextStyle(
                  color: JarvisTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4,
                )),
              Text('Asistente Personal',
                style: TextStyle(
                  color: JarvisTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 2,
                )),
            ],
          ),
          const Spacer(),
          // Indicador wake word
          _WakeIndicator(active: _wakeActive),
          const SizedBox(width: 12),
          // Menú
          PopupMenuButton<String>(
            color: JarvisTheme.surface,
            icon: const Icon(Icons.more_vert, color: JarvisTheme.textSecondary, size: 20),
            onSelected: _onMenuSelected,
            itemBuilder: (_) => [
              _menuItem('reminders', Icons.notifications_outlined, 'Recordatorios'),
              _menuItem('history',   Icons.history,                 'Historial'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String val, IconData icon, String label) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, color: JarvisTheme.textSecondary, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: JarvisTheme.textPrimary, fontSize: 14)),
      ]),
    );
  }

  void _onMenuSelected(String val) {
    if (val == 'reminders') {
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RemindersScreen()));
    }
  }

  Widget _buildCenter() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Orbe animado central
        GestureDetector(
          onTap: () => JarvisOrchestrator.instance.activateManually(),
          child: _JarvisOrb(
            state: _assistantState,
            orbController: _orbController,
            pulseController: _pulseController,
          ),
        ),
        const SizedBox(height: 40),
        // Texto de estado
        _StatusText(state: _assistantState),
        const SizedBox(height: 24),
        // Transcripción en vivo
        if (_transcript.isNotEmpty)
          _TranscriptBubble(text: _transcript, isUser: true),
        if (_response.isNotEmpty && _assistantState != AssistantState.sleeping)
          _TranscriptBubble(text: _response, isUser: false),
      ],
    );
  }

  Widget _buildBottom() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        children: [
          // Botón manual
          GestureDetector(
            onTap: () => JarvisOrchestrator.instance.activateManually(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: JarvisTheme.border),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _assistantState == AssistantState.listening
                      ? Icons.mic : Icons.mic_none,
                    color: _assistantState == AssistantState.listening
                      ? JarvisTheme.primary : JarvisTheme.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _assistantState == AssistantState.listening
                      ? 'Escuchando...' : 'Pulsar para hablar',
                    style: TextStyle(
                      color: _assistantState == AssistantState.listening
                        ? JarvisTheme.primary : JarvisTheme.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _wakeActive ? 'Di "Jarvis" para activar' : 'Wake word inactivo',
            style: const TextStyle(
              color: JarvisTheme.textHint,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _JarvisOrb extends StatelessWidget {
  final AssistantState state;
  final AnimationController orbController;
  final AnimationController pulseController;

  const _JarvisOrb({required this.state, required this.orbController, required this.pulseController});

  Color get _color {
    switch (state) {
      case AssistantState.listening:  return JarvisTheme.primary;
      case AssistantState.processing: return JarvisTheme.warning;
      case AssistantState.responding: return JarvisTheme.success;
      case AssistantState.waking:     return JarvisTheme.primary;
      case AssistantState.error:      return JarvisTheme.error;
      default:                        return JarvisTheme.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([orbController, pulseController]),
      builder: (_, __) {
        final pulse = state == AssistantState.listening ||
                      state == AssistantState.responding
            ? 1.0 + (pulseController.value * 0.15)
            : 1.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Anillo exterior
            Transform.scale(
              scale: 1.3 * pulse,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _color.withOpacity(0.15), width: 1),
                ),
              ),
            ),
            // Anillo medio
            Transform.scale(
              scale: 1.1 * pulse,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _color.withOpacity(0.25), width: 1),
                ),
              ),
            ),
            // Orbe central
            Transform.scale(
              scale: pulse,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _color.withOpacity(0.08),
                  border: Border.all(color: _color.withOpacity(0.6), width: 1.5),
                ),
                child: CustomPaint(
                  painter: _OrbPainter(orbController.value, _color),
                ),
              ),
            ),
            // Ícono central
            Icon(
              _stateIcon,
              color: _color,
              size: 32,
            ),
          ],
        );
      },
    );
  }

  IconData get _stateIcon {
    switch (state) {
      case AssistantState.listening:  return Icons.graphic_eq;
      case AssistantState.processing: return Icons.memory;
      case AssistantState.responding: return Icons.volume_up;
      case AssistantState.error:      return Icons.error_outline;
      default:                        return Icons.blur_on;
    }
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _OrbPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2 - 8;
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 3; i++) {
      final angle = (progress * 2 * math.pi) + (i * math.pi * 2 / 3);
      final x = cx + r * 0.6 * math.cos(angle);
      final y = cy + r * 0.6 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 3, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.progress != progress;
}

class _StatusText extends StatelessWidget {
  final AssistantState state;
  const _StatusText({required this.state});

  String get _label {
    switch (state) {
      case AssistantState.sleeping:   return 'EN ESPERA';
      case AssistantState.waking:     return 'ACTIVANDO';
      case AssistantState.listening:  return 'ESCUCHANDO';
      case AssistantState.processing: return 'PROCESANDO';
      case AssistantState.responding: return 'RESPONDIENDO';
      case AssistantState.error:      return 'ERROR';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label,
      style: const TextStyle(
        color: JarvisTheme.textSecondary,
        fontSize: 11,
        letterSpacing: 3,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _TranscriptBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? JarvisTheme.primaryDim : JarvisTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUser ? JarvisTheme.primary.withOpacity(0.3)
                          : JarvisTheme.border,
            width: 0.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? JarvisTheme.primary : JarvisTheme.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _WakeIndicator extends StatelessWidget {
  final bool active;
  const _WakeIndicator({required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? JarvisTheme.success : JarvisTheme.textHint,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          active ? 'ACTIVO' : 'INACTIVO',
          style: TextStyle(
            color: active ? JarvisTheme.success : JarvisTheme.textHint,
            fontSize: 9,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
