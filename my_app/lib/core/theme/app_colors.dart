import 'package:flutter/material.dart';

/// Mamily's current palette, extracted from the original screens. Colors are UI
/// constants (permitted static data) — no business meaning.
///
/// Legacy: existing screens still read these. Several fail WCAG AA as text
/// (e.g. [textMuted] 3.0:1, [coral] 2.95:1). New and redesigned screens use the
/// accessible tokens on `MamilyColors` (`context.mamily`) instead, and screens
/// migrate off this class one step at a time.
class AppColors {
  const AppColors._();

  static const navy = Color(0xFF2E3B63);
  static const navyLight = Color(0xFF3E4C7A);
  static const coral = Color(0xFFFF624E);
  static const teal = Color(0xFF62D9D4);
  static const amber = Color(0xFFFFB84D);
  static const background = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF20283F);
  static const textMuted = Color(0xFF8A94AA);
  static const border = Color(0xFFE0E3EB);
}
