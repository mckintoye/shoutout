import 'package:flutter/material.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppTokens.accent,
      onPrimary: Colors.white,
      surface: AppTokens.card,
      onSurface: AppTokens.ink,
      background: AppTokens.bg,
      onBackground: AppTokens.ink,
      outline: AppTokens.stroke,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppTokens.bg,

      textTheme: base.textTheme.copyWith(
        headlineMedium: AppTokens.h1.copyWith(color: AppTokens.ink),
        titleLarge: AppTokens.h2.copyWith(color: AppTokens.ink),
        bodyLarge: AppTokens.body.copyWith(color: AppTokens.ink),
        bodyMedium: AppTokens.body.copyWith(color: AppTokens.ink),
        bodySmall: AppTokens.small.copyWith(color: AppTokens.subInk),
      ),

      // CashLens feel: appbars look light/flat
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTokens.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTokens.h2.copyWith(color: AppTokens.ink),
      ),

      cardTheme: CardThemeData(
        color: AppTokens.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.r16),
          side: const BorderSide(color: AppTokens.stroke),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.r16),
          borderSide: const BorderSide(color: AppTokens.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.r16),
          borderSide: const BorderSide(color: AppTokens.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.r16),
          borderSide: BorderSide(
            color: AppTokens.accent.withOpacity(0.8),
            width: 1.4,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.r16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
