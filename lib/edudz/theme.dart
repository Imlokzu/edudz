import 'package:flutter/material.dart';

const forest = Color(0xFF1B5245);
const mint = Color(0xFFDDEBC8);
const paper = Color(0xFFF6F5F0);
const ink = Color(0xFF24352F);
ThemeData edudzTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
      seedColor: forest,
      brightness: brightness,
      primary: dark ? const Color(0xFFA8D8BC) : forest,
      surface: dark ? const Color(0xFF17221D) : paper);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Manrope',
    textTheme: TextTheme(
      headlineLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          color: scheme.onSurface),
      headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: scheme.onSurface),
      titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
          color: scheme.onSurface),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurface),
      bodyMedium:
          TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurface),
      bodySmall:
          TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
    ),
    appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF23332B) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: scheme.primary, width: 2))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w700))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF1D2B23) : Colors.white,
        indicatorColor: dark ? const Color(0xFF37503E) : mint,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(
            fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w600))),
    dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .5), space: 30),
  );
}
