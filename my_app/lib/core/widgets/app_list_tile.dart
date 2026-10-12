import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// A tinted square holding an icon or an emoji — the leading visual of list
/// rows and summary cards.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    this.icon,
    this.emoji,
    this.tone = AppTone.neutral,
    this.size = 44,
  }) : assert(icon != null || emoji != null);

  final IconData? icon;
  final String? emoji;
  final AppTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.mamily.tone(tone);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: AppRadii.smallAll,
        ),
        child: emoji != null
            ? Text(
                emoji!,
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontSize: size * 0.5),
              )
            : Icon(icon, color: t.foreground, size: size * 0.5),
      ),
    );
  }
}

/// The standard list row: leading visual, title, optional subtitle and
/// trailing widget, in an [AppCard]. Tappable rows get a chevron.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleMaxLines = 2,
    this.subtitleMaxLines = 2,
    this.strikeTitle = false,
    this.tone,
    this.margin = const EdgeInsets.only(bottom: AppSpacing.sm),
  });

  final String title;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int titleMaxLines;
  final int subtitleMaxLines;

  /// Archived / reversed items.
  final bool strikeTitle;
  final AppTone? tone;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    return AppCard(
      onTap: onTap,
      tone: tone,
      margin: margin,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.titleSmall?.copyWith(
                    decoration: strikeTitle ? TextDecoration.lineThrough : null,
                    color: strikeTitle ? c.ink2 : null,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: subtitleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySmall?.copyWith(color: c.ink2),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ] else if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: c.ink3),
        ],
      ),
    );
  }
}

/// A tinted summary card with one big number (points balance, minutes left,
/// last night's sleep) and an optional action underneath.
class HeroMetricCard extends StatelessWidget {
  const HeroMetricCard({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.caption,
    this.icon,
    this.emoji,
    this.tone = AppTone.brand,
    this.onTap,
    this.actionLabel,
    this.footer,
  });

  final String label;
  final String? value;

  /// Replaces [value] (loading / error states).
  final Widget? valueWidget;
  final String? caption;
  final IconData? icon;
  final String? emoji;
  final AppTone tone;
  final VoidCallback? onTap;

  /// Shown as a link-styled row with a chevron when [onTap] is set.
  final String? actionLabel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final t = c.tone(tone);
    return AppCard(
      tone: tone,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null || emoji != null) ...[
            IconBadge(icon: icon, emoji: emoji, tone: tone, size: 52),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.type.labelLarge?.copyWith(color: t.foreground),
                ),
                const SizedBox(height: AppSpacing.xs),
                valueWidget ??
                    Text(value ?? '—', style: context.type.headlineMedium),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: context.type.bodyMedium?.copyWith(color: c.ink2),
                  ),
                ],
                if (actionLabel != null && onTap != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          actionLabel!,
                          style: context.type.labelLarge?.copyWith(
                            color: c.actionText,
                            decoration: TextDecoration.underline,
                            decorationColor: c.actionText,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: c.actionText,
                        size: AppSizes.icon,
                      ),
                    ],
                  ),
                ],
                ?footer,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of single-choice filter chips that wraps on narrow screens.
class ChoiceChipBar<T> extends StatelessWidget {
  const ChoiceChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: e.key == selected,
            onSelected: (_) => onSelected(e.key),
          ),
      ],
    );
  }
}
