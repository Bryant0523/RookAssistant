// ─── Modelo de Intent ────────────────────────────────────────────────────────

class JarvisIntent {
  final String name;
  final Map<String, dynamic> params;
  final String rawText;
  final double confidence;

  const JarvisIntent({
    required this.name,
    required this.params,
    required this.rawText,
    this.confidence = 1.0,
  });

  bool get isUnknown => name == 'unknown';

  @override
  String toString() => 'Intent($name, params: $params)';
}

// ─── Motor de Intents (NLU local, sin APIs externas) ─────────────────────────

class IntentEngine {
  static JarvisIntent parse(String text) {
    final t = text.toLowerCase().trim();

    // --- RECORDATORIOS ---
    if (_matches(t, ['recuérdame', 'recordatorio', 'recuerda que', 'pon una alarma', 'avísame'])) {
      return JarvisIntent(
        name: 'set_reminder',
        params: {
          'text': text,
          'datetime': _extractDatetime(t),
          'label': _extractReminderLabel(t),
        },
        rawText: text,
      );
    }
    if (_matches(t, ['mis recordatorios', 'qué recordatorios', 'lista de recordatorios', 'ver recordatorios'])) {
      return JarvisIntent(name: 'list_reminders', params: {}, rawText: text);
    }
    if (_matches(t, ['elimina el recordatorio', 'borra el recordatorio', 'cancela el recordatorio'])) {
      return JarvisIntent(name: 'delete_reminder', params: {'text': text}, rawText: text);
    }

    // --- ARCHIVOS ---
    if (_matches(t, ['organiza', 'ordena los archivos', 'organizar archivos'])) {
      return JarvisIntent(name: 'organize_files', params: {'text': text}, rawText: text);
    }
    if (_matches(t, ['busca el archivo', 'buscar archivo', 'encuentra el archivo', 'dónde está el archivo'])) {
      return JarvisIntent(
        name: 'search_file',
        params: {'query': _extractFileQuery(t)},
        rawText: text,
      );
    }
    if (_matches(t, ['mueve el archivo', 'mover archivo', 'copia el archivo'])) {
      return JarvisIntent(name: 'move_file', params: {'text': text}, rawText: text);
    }
    if (_matches(t, ['lista de archivos', 'mis archivos', 'qué archivos', 'ver archivos'])) {
      return JarvisIntent(name: 'list_files', params: {}, rawText: text);
    }

    // --- SISTEMA / INFORMACIÓN ---
    if (_matches(t, ['qué hora', 'dime la hora', 'hora es'])) {
      return JarvisIntent(name: 'get_time', params: {}, rawText: text);
    }
    if (_matches(t, ['qué día', 'qué fecha', 'fecha de hoy', 'día es hoy'])) {
      return JarvisIntent(name: 'get_date', params: {}, rawText: text);
    }
    if (_matches(t, ['batería', 'carga del teléfono', 'cuánta batería'])) {
      return JarvisIntent(name: 'get_battery', params: {}, rawText: text);
    }
    if (_matches(t, ['hola', 'buenos días', 'buenas tardes', 'buenas noches', 'hey jarvis'])) {
      return JarvisIntent(name: 'greeting', params: {}, rawText: text);
    }
    if (_matches(t, ['cómo estás', 'cómo te encuentras', 'todo bien'])) {
      return JarvisIntent(name: 'status', params: {}, rawText: text);
    }
    if (_matches(t, ['apaga', 'para', 'detente', 'silencio', 'cancela'])) {
      return JarvisIntent(name: 'stop', params: {}, rawText: text);
    }
    if (_matches(t, ['ayuda', 'qué puedes hacer', 'qué sabes hacer', 'comandos'])) {
      return JarvisIntent(name: 'help', params: {}, rawText: text);
    }

    return JarvisIntent(
      name: 'unknown',
      params: {'text': text},
      rawText: text,
      confidence: 0.0,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static bool _matches(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  static DateTime? _extractDatetime(String text) {
    final now = DateTime.now();

    if (text.contains('mañana')) {
      final timeMatch = RegExp(r'a las (\d{1,2})(?::(\d{2}))?').firstMatch(text);
      if (timeMatch != null) {
        final h = int.parse(timeMatch.group(1)!);
        final m = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        return DateTime(now.year, now.month, now.day + 1, h, m);
      }
      return DateTime(now.year, now.month, now.day + 1, 9, 0);
    }

    if (text.contains('en ') && text.contains('minuto')) {
      final match = RegExp(r'en (\d+) minutos?').firstMatch(text);
      if (match != null) {
        return now.add(Duration(minutes: int.parse(match.group(1)!)));
      }
    }

    if (text.contains('en ') && text.contains('hora')) {
      final match = RegExp(r'en (\d+) horas?').firstMatch(text);
      if (match != null) {
        return now.add(Duration(hours: int.parse(match.group(1)!)));
      }
    }

    final timeMatch = RegExp(r'a las (\d{1,2})(?::(\d{2}))?').firstMatch(text);
    if (timeMatch != null) {
      final h = int.parse(timeMatch.group(1)!);
      final m = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      var dt = DateTime(now.year, now.month, now.day, h, m);
      if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
      return dt;
    }

    return null;
  }

  static String _extractReminderLabel(String text) {
    // Elimina las frases de activación para quedarse con el contenido
    var label = text
      .replaceAll(RegExp(r'recuérdame (que |de |)|pon una alarma para|avísame'), '')
      .replaceAll(RegExp(r'\s+(mañana|hoy|a las \d+|en \d+ minutos?|en \d+ horas?).*'), '')
      .trim();
    return label.isEmpty ? text : label;
  }

  static String _extractFileQuery(String text) {
    return text
      .replaceAll(RegExp(r'busca el archivo|buscar archivo|encuentra el archivo|dónde está el archivo'), '')
      .trim();
  }
}
