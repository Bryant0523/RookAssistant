import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'ui/screens/jarvis_home_screen.dart';
import 'ui/theme/jarvis_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Español para fechas
  await initializeDateFormatting('es', null);

  // Pantalla siempre activa mientras JARVIS escucha
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JARVIS',
      debugShowCheckedModeBanner: false,
      theme: JarvisTheme.dark,
      home: const JarvisHomeScreen(),
    );
  }
}
