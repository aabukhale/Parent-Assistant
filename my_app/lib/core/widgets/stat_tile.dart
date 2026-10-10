import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';
import 'app_card.dart';

/// A compact number-and-label tile (points, tasks due, screen time…).
///
/// The [value] is always a string the caller got from real data — the tile
/// never computes or invents anything. Set [onTap] to make it a link to the
/// detail screen.
///
/// Screen readers read the value and label together as one item; pass
/// [semanticLabel] when the visual pair is ambiguous.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = AppTone.neutral,
    this.caption,
    this.onTap,
    this.semanticLabel,
  });

  final String label;
  final String value;
  final IconData? icon;
  final AppTone tone;

  /// Small supporting line under the label.
  final String? caption;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final colors = c.tone(tone);
    final text = context.type;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(icon, size: AppSizes.icon, color: colors.foreground),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(value, style: text.headlineSmall),
        Text(label, style: text.bodyMedium?.copyWith(color: c.ink2)),
        if (caption != null)
          Text(caption!, style: text.bodySmall?.copyWith(color: c.ink3)),
      ],
    );

    return AppCard(
      onTap: onTap,
      semanticLabel: semanticLabel,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      // Value, label and caption read as one item.
      child: semanticLabel == null ? MergeSemantics(child: content) : content,
    );
  }
}
