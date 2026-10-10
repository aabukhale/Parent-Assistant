import 'dart:math' as math;
import 'dart:ui' show Color;

/// WCAG 2.x contrast helpers. Used by the design-system tests to keep every
/// token pair honest, and available to pick a readable foreground at runtime.
class Contrast {
  const Contrast._();

  /// Minimum ratio for body text (WCAG 2.x AA, 1.4.3).
  static const double aaText = 4.5;

  /// Minimum ratio for large text and UI component boundaries (AA, 1.4.11).
  static const double aaLargeOrUi = 3.0;

  /// WCAG relative luminance of an sRGB [color] (alpha is ignored).
  static double luminance(Color color) {
    double channel(double c) => c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// Contrast ratio between two opaque colors, from 1 (identical) to 21.
  static double ratio(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Whichever of [candidates] reads best on [background].
  static Color bestOn(Color background, List<Color> candidates) {
    assert(candidates.isNotEmpty);
    return candidates.reduce(
      (best, next) =>
          ratio(next, background) > ratio(best, background) ? next : best,
    );
  }
}
