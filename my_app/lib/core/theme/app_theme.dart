import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app theme, lifted verbatim from the original `main.dart` so the visual
/// design is unchanged.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Arial',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.navy),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.navy,
    ),
  );
}
