import 'package:flutter/material.dart';

import 'mamily_colors.dart';

/// Legacy palette names, now mapped onto the accessible design tokens
/// ([MamilyColors.light]) so any remaining screen that still reads them
/// meets WCAG AA. Prefer `context.mamily` in new code.
class AppColors {
  const AppColors._();

  static const navy = MamilyPalette.navy800;
  static const navyLight = Color(0xFF3E4C7A);

  /// Primary action coral (4.7:1 with white text).
  static const coral = Color(0xFFD43A26);
  static const teal = Color(0xFF0F766E);
  static const amber = Color(0xFF8A5300);
  static const background = Color(0xFFFAF7F3);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF24304F);
  static const textMuted = Color(0xFF5C6580);
  static const border = Color(0xFFECE4DA);
}
