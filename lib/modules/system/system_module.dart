import 'package:intl/intl.dart';
import '../../core/models/intent.dart';

class SystemModule {
  static final SystemModule instance = SystemModule._();
  SystemModule._();

  List<String> get supportedIntents => [
    'get_time', 'get_date', 'get_battery',
    'greeting', 'status', 'help', 'stop', 'unknown',
  ];

  bool canHandle(String intent) => supportedIntents.contains(intent);

  Future<String> execute(JarvisIntent intent) async {
    switch (intent.name) {
      case 'get_time':  return _getTime();
      case 'get_date':  return _getDate();
      case 'greeting':  return _greeting();
      case 'status':    return _status();
      case 'help':      return _help();
      case 'stop':      return '';   // Silencio — la UI lo maneja
      case 'unknown':   return _unknown(intent.rawText);
      default:          return 'No tengo respuesta para eso aún.';
    }
  }

  String _getTime() {
    final now = DateTime.now();
    final fmt = DateFormat('HH:mm', 'es');
    return 'Son las ${fmt.format(now)}.';
  }

  String _getDate() {
    final now = DateTime.now();
    final fmt = DateFormat("EEEE d 'de' MMMM 'de' y", 'es');
    return 'Hoy es ${fmt.format(now)}.';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12)  return 'Buenos días. Sistemas activos y a tu disposición.';
    if (hour >= 12 && hour < 18) return 'Buenas tardes. Todo en orden.';
    return 'Buenas noches. ¿En qué puedo ayudarte?';
  }

  String _status() {
    return 'Todos los sistemas operativos. Wake word activo. Listo para tus órdenes.';
  }

  String _help() {
    return 'Puedo ayudarte con recordatorios — di "recuérdame tomar agua a las 3". '
           'Con archivos — di "organiza mis archivos" o "busca el archivo contrato". '
           'Con información — di "qué hora es" o "qué día es hoy". '
           '¿Qué necesitas?';
  }

  String _unknown(String text) {
    if (text.isEmpty) return 'No escuché nada. Inténtalo de nuevo.';
    return 'No reconocí ese comando: "$text". Di "ayuda" para ver qué puedo hacer.';
  }
}
