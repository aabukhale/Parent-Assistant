import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';

/// The icon a status [tone] carries by default, so colour is never the only
/// signal. Returns null for tones that carry no status meaning of their own
/// (neutral, brand, accent) — pass an explicit icon there if one helps.
IconData? defaultToneIcon(AppTone tone) => switch (tone) {
  AppTone.success => Icons.check_circle_rounded,
  AppTone.warning => Icons.warning_amber_rounded,
  AppTone.danger => Icons.error_rounded,
  AppTone.info => Icons.info_rounded,
  AppTone.sleep => Icons.bedtime_rounded,
  AppTone.neutral || AppTone.brand || AppTone.accent => null,
};

/// A small read-only status label: tinted background, dark text, and — for the
/// status tones (success/warning/danger/info) — always an icon plus a word.
///
/// The single replacement for the several private pills that each screen grew.
/// It is not interactive, so it is exempt from the 48dp target rule; do not
/// wrap it in a tap handler (use a button next to it instead).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = AppTone.neutral,
    this.icon,
  });

  final String label;
  final AppTone tone;

  /// Overrides [defaultToneIcon].
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.mamily.tone(tone);
    final glyph = icon ?? defaultToneIcon(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: colors.border, width: AppSizes.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              Icon(glyph, size: AppSizes.iconSm, color: colors.foreground),
              const SizedBox(width: AppSpacing.xs + 2),
            ],
            // Flexible so a long label wraps instead of overflowing when the
            // user has a large text size.
            Flexible(
              child: Text(
                label,
                style: context.type.labelMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
