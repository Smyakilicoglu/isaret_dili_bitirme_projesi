import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: const Color(0xFF1a1a1a),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2a2a2a),
      foregroundColor: Colors.white,
    ),
    cardColor: const Color(0xFF2a2a2a),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      surface: Color(0xFF2a2a2a),
    ),
  );
}