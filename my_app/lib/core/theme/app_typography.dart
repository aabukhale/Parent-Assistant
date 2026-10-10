import 'package:flutter/material.dart';

import 'mamily_colors.dart';

/// Mamily's type scale, set in Rubik (one family for Latin, Arabic and
/// Hebrew, bundled as a variable font in `assets/fonts`).
///
/// Rules baked in:
/// * nothing below 12 sp (captions), body is 14–16 sp;
/// * `letterSpacing` is always 0 — non-zero tracking breaks Arabic letter
///   joining;
/// * line height is at least 1.25× (Rubik's own line box is 1.185×) and body
///   text sits at 1.33–1.5×, so Arabic/Hebrew marks never collide between lines;
/// * sizes are in logical pixels and scale with the user's text size, so
///   never put text in a fixed-height box.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Rubik';

  /// Fallback when a style is built outside the theme (tests, platform UI).
  ///
  /// Rubik is bundled as static Regular/Medium/SemiBold/Bold/ExtraBold
  /// instances, so a plain `FontWeight` always renders at its true weight and
  /// Rubik is the app-wide default.
  static const String legacyFontFamily = 'Arial';

  /// Smallest size any style may use.
  static const double minFontSize = 12;

  static TextStyle _style({
    required double size,
    required double lineHeight,
    required int weight,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: _weight(weight),
    letterSpacing: 0,
  );

  static FontWeight _weight(int w) => switch (w) {
    <= 400 => FontWeight.w400,
    <= 500 => FontWeight.w500,
    <= 600 => FontWeight.w600,
    <= 700 => FontWeight.w700,
    _ => FontWeight.w800,
  };

  /// The full Material 3 text theme, coloured with [ink].
  static TextTheme textTheme({required Color ink}) {
    TextStyle s(double size, double line, int weight) => _style(
      size: size,
      lineHeight: line,
      weight: weight,
    ).copyWith(color: ink);

    return TextTheme(
      // Display — rare, big numbers and hero moments.
      displayLarge: s(40, 52, 700),
      displayMedium: s(36, 48, 700),
      displaySmall: s(32, 40, 700),
      // Headline — screen titles inside content, stat values.
      headlineLarge: s(28, 36, 700),
      headlineMedium: s(24, 32, 600),
      headlineSmall: s(20, 28, 600),
      // Title — app bar, section headers, card titles.
      titleLarge: s(22, 28, 600),
      titleMedium: s(18, 24, 600),
      titleSmall: s(16, 24, 600),
      // Body.
      bodyLarge: s(16, 24, 400),
      bodyMedium: s(14, 20, 400),
      bodySmall: s(12, 16, 400),
      // Label — buttons, chips, pills, nav.
      labelLarge: s(14, 20, 600),
      labelMedium: s(12, 16, 600),
      labelSmall: s(12, 16, 500),
    );
  }
}

/// [AppTypography.textTheme] attached to the theme, so components read
/// `context.type` instead of `Theme.of(context).textTheme` (which still holds
/// the legacy font for existing screens).
@immutable
class MamilyTypography extends ThemeExtension<MamilyTypography> {
  const MamilyTypography(this.styles);

  final TextTheme styles;

  @override
  MamilyTypography copyWith({TextTheme? styles}) =>
      MamilyTypography(styles ?? this.styles);

  @override
  MamilyTypography lerp(ThemeExtension<MamilyTypography>? other, double t) {
    if (other is! MamilyTypography) return this;
    return MamilyTypography(TextTheme.lerp(styles, other.styles, t));
  }
}

/// `context.type` — Mamily's Rubik text styles for the current theme.
extension MamilyTypographyContext on BuildContext {
  TextTheme get type =>
      Theme.of(this).extension<MamilyTypography>()?.styles ??
      AppTypography.textTheme(ink: mamily.ink);
}
