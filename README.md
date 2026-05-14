# J.A.R.V.I.S — Asistente Personal de Voz
### Fase 1: Móvil (iOS + Android)

---

## Estructura del proyecto

```
jarvis_app/
├── lib/
│   ├── main.dart                          ← Entrada principal
│   ├── core/
│   │   ├── models/
│   │   │   └── intent.dart                ← Modelo JarvisIntent + IntentEngine (NLU)
│   │   └── services/
│   │       ├── wake_word_service.dart      ← Porcupine wake word "Jarvis"
│   │       ├── speech_service.dart         ← Reconocimiento de voz (STT)
│   │       ├── tts_service.dart            ← Síntesis de voz (TTS)
│   │       └── jarvis_orchestrator.dart    ← Cerebro central — conecta todo
│   ├── modules/
│   │   ├── reminders/
│   │   │   └── reminders_module.dart       ← Recordatorios + notificaciones + DB
│   │   ├── files/
│   │   │   └── files_module.dart           ← Gestión de archivos
│   │   └── system/
│   │       └── system_module.dart          ← Hora, fecha, saludo, ayuda
│   └── ui/
│       ├── theme/
│       │   └── jarvis_theme.dart           ← Paleta y tema JARVIS (azul/negro/cian)
│       └── screens/
│           ├── jarvis_home_screen.dart     ← Pantalla principal con orbe animado
│           └── reminders_screen.dart       ← Lista de recordatorios
├── android/
│   └── app/src/main/AndroidManifest.xml   ← Permisos Android + soporte TV
├── ios/
│   └── Runner/Info.plist                  ← Permisos iOS + background modes
└── pubspec.yaml                           ← Dependencias
```

---

## Pasos para ejecutar

### 1. Instalar Flutter
```bash
# Descarga Flutter SDK de https://flutter.dev
flutter --version   # Verifica instalación
flutter doctor      # Verifica dependencias
```

### 2. Clonar/copiar este proyecto
```bash
cd jarvis_app
flutter pub get     # Instala dependencias
```

### 3. Obtener AccessKey de Porcupine (OBLIGATORIO)
1. Ve a https://console.picovoice.ai/
2. Crea una cuenta gratuita (uso personal)
3. Copia tu AccessKey
4. Abre `lib/core/services/wake_word_service.dart`
5. Reemplaza `'TU_ACCESS_KEY_AQUI'` con tu clave

### 4. Ejecutar en móvil
```bash
flutter devices                    # Ver dispositivos disponibles
flutter run -d <device_id>         # Ejecutar en el dispositivo
flutter run --release              # Versión optimizada
```

### 5. Compilar APK (Android)
```bash
flutter build apk --release
# El APK queda en: build/app/outputs/flutter-apk/app-release.apk
```

### 6. Compilar para iOS
```bash
flutter build ipa
# Abre Xcode para firmar y distribuir
```

---

## Comandos de voz disponibles

| Comando de ejemplo                              | Acción                    |
|-------------------------------------------------|---------------------------|
| "Jarvis" (wake word)                            | Activa el asistente        |
| "Recuérdame tomar agua a las 3"                 | Crea recordatorio          |
| "Recuérdame llamar a mamá mañana a las 10"      | Recordatorio para mañana   |
| "Mis recordatorios"                             | Lista recordatorios         |
| "Organiza mis archivos"                         | Organiza por tipo           |
| "Busca el archivo contrato"                     | Busca archivo               |
| "Qué hora es"                                   | Hora actual                 |
| "Qué día es hoy"                                | Fecha actual                |
| "Ayuda"                                         | Lista de comandos           |
| "Para" / "Silencio" / "Cancela"                 | Detiene la respuesta        |

---

## Agregar nuevo módulo (extensibilidad)

Para agregar una nueva funcionalidad, crea un archivo en `lib/modules/`:

```dart
// lib/modules/weather/weather_module.dart
import '../../core/models/intent.dart';

class WeatherModule {
  static final WeatherModule instance = WeatherModule._();
  WeatherModule._();

  List<String> get supportedIntents => ['get_weather', 'forecast'];
  bool canHandle(String intent) => supportedIntents.contains(intent);

  Future<String> execute(JarvisIntent intent) async {
    // Tu lógica aquí
    return 'El clima es soleado, 25 grados.';
  }
}
```

Luego regístralo en `jarvis_orchestrator.dart` en el método `_routeToModule`:
```dart
if (WeatherModule.instance.canHandle(intent.name)) {
  return await WeatherModule.instance.execute(intent);
}
```

Y agrega los intents al `IntentEngine` en `intent.dart`.

---

## Próximas fases

- **Fase 2**: Desktop (Windows / macOS / Linux) — mismos módulos, UI adaptada
- **Fase 3**: Android TV — interfaz en landscape para control por voz
- **Fase 4**: Equipos de sonido — integración AirPlay/Bluetooth/Cast
- **Fase 5**: IoT (luces, AC) — Raspberry Pi + MQTT + Home Assistant

---

## Notas de privacidad

- El wake word corre 100% on-device (Porcupine)
- El STT usa el motor nativo del dispositivo (sin cloud obligatorio)
- Los datos se almacenan localmente en SQLite
- Sin telemetría, sin servidores externos requeridos
- Uso personal, no comercial
