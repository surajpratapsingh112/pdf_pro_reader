import 'package:flutter/material.dart';

class AppColors {
  static const bg      = Color(0xFF1a1a2e);
  static const bar     = Color(0xFF16213e);
  static const accent  = Color(0xFFe94560);
  static const accent2 = Color(0xFF0f3460);
  static const cyan    = Color(0xFF00e5ff);
  static const text    = Color(0xFFEAEAEA);
  static const sub     = Color(0xFFA0A0B0);
  static const card    = Color(0xFF1e2a45);
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    primaryColor: AppColors.accent,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.cyan,
      surface: AppColors.card,
      error: Color(0xFFff5252),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bar,
      foregroundColor: AppColors.text,
      elevation: 4,
      titleTextStyle: TextStyle(
        color: AppColors.accent,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.text),
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.sub),
    ),
  );
}
