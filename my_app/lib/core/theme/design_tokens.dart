import 'package:flutter/material.dart';

/// Spacing scale on a 4-pt grid. Use these instead of raw numbers.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal page gutter.
  static const double pageGutter = xl;

  /// Default inner padding of a card.
  static const double cardPadding = lg;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: pageGutter,
  );
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);
}

/// Corner radii: three steps plus a pill. Nothing else should be needed.
class AppRadii {
  const AppRadii._();

  /// Inputs, chips, small tiles.
  static const double small = 12;

  /// Cards.
  static const double medium = 16;

  /// Hero cards, sheets, dialogs.
  static const double large = 24;

  /// Buttons and pills.
  static const double pill = 999;

  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumAll = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Fixed sizes shared across components.
class AppSizes {
  const AppSizes._();

  /// Minimum interactive target (Material / WCAG 2.5.5 guidance).
  static const double minTouchTarget = 48;

  /// Minimum interactive target for the parent-launched Kid View.
  static const double minTouchTargetKid = 56;

  /// Reading-column cap on tablets and landscape; phones are unaffected.
  static const double maxContentWidth = 640;

  static const double borderWidth = 1;

  /// Borders that must be perceivable on their own (inputs, outlined buttons).
  static const double borderWidthStrong = 1.5;

  static const double focusWidth = 2;

  static const double iconSm = 16;
  static const double icon = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;
}

/// Motion. Short and calm: no looping or attention-grabbing animation.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOut;

  /// [duration], or [Duration.zero] when the user asked to reduce motion.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
