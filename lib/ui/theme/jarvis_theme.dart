import 'package:flutter/material.dart';

class JarvisTheme {
  // Paleta JARVIS — azul frío + negro profundo + acento cian
  static const Color background   = Color(0xFF070B14);
  static const Color surface      = Color(0xFF0D1526);
  static const Color surfaceAlt   = Color(0xFF111D33);
  static const Color primary      = Color(0xFF00C8FF);   // cian JARVIS
  static const Color primaryDim   = Color(0xFF0A3D52);
  static const Color accent       = Color(0xFF0066FF);
  static const Color success      = Color(0xFF00E5A0);
  static const Color warning      = Color(0xFFFFB020);
  static const Color error        = Color(0xFFFF3B5C);
  static const Color textPrimary  = Color(0xFFE8F4FF);
  static const Color textSecondary= Color(0xFF6B8FAF);
  static const Color textHint     = Color(0xFF2E4A65);
  static const Color border       = Color(0xFF1A2E47);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        background: background,
        surface: surface,
        primary: primary,
        secondary: accent,
        error: error,
        onBackground: textPrimary,
        onSurface: textPrimary,
        onPrimary: background,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 0.5),
        ),
      ),
      dividerColor: border,
      textTheme: const TextTheme(
        displayLarge : TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 2),
        titleLarge   : TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w500),
        titleMedium  : TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1),
        bodyLarge    : TextStyle(color: textPrimary, fontSize: 15, height: 1.6),
        bodyMedium   : TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
        labelSmall   : TextStyle(color: textHint, fontSize: 11, letterSpacing: 1.5),
      ),
    );
  }
}
