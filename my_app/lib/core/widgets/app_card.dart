import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';

/// The one card surface: flat, 1px hairline, 16px radius, 16px padding.
///
/// Pass [onTap] to make it tappable. A tappable card gets a real ink ripple, a
/// 48dp minimum height, button semantics and a focus highlight — which the
/// bare `GestureDetector` + `Container` cards it replaces did not.
///
/// Give [semanticLabel] when the visual text is not enough on its own (e.g.
/// "Points, 120"); it replaces the merged child text for screen readers.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = AppSpacing.cardInsets,
    this.margin,
    this.tone,
    this.color,
    this.borderRadius = AppRadii.mediumAll,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Tints the card with a tone's soft background and border.
  final AppTone? tone;

  /// Overrides the fill (defaults to the tone tint, else the surface colour).
  final Color? color;
  final BorderRadius borderRadius;
  final String? semanticLabel;

  bool get _interactive => onTap != null || onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final toneColors = tone == null ? null : c.tone(tone!);
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: BorderSide(
        color: toneColors?.border ?? c.border,
        width: AppSizes.borderWidth,
      ),
    );

    Widget content = Padding(padding: padding, child: child);
    if (_interactive) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: content,
      );
      content = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: shape,
        child: content,
      );
    }

    Widget card = Material(
      color: color ?? toneColors?.background ?? c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (semanticLabel != null) {
      card = Semantics(
        container: true,
        button: _interactive,
        label: semanticLabel,
        onTap: onTap,
        onLongPress: onLongPress,
        excludeSemantics: true,
        child: card,
      );
    } else if (_interactive) {
      // The card itself is the single button node: everything inside it is
      // merged into that node, so it always carries the combined text as its
      // label (a bare container would leave the button unlabeled whenever a
      // child forms its own semantics node).
      card = MergeSemantics(child: Semantics(button: true, child: card));
    }

    if (margin != null) card = Padding(padding: margin!, child: card);
    return card;
  }
}
