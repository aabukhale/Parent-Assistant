import 'package:flutter/material.dart';

import '../localization/l10n.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';
import 'app_card.dart';

/// Heading above a group of form fields.
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key, this.helper});

  final String text;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(text, style: context.type.titleSmall),
          ),
          if (helper != null)
            Text(
              helper!,
              style: context.type.bodySmall?.copyWith(
                color: context.mamily.ink2,
              ),
            ),
        ],
      ),
    );
  }
}

/// A field that opens a picker (date, time, list) and looks like a text
/// input. Optional clear button with a full-size touch target.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.onClear,
    this.enabled = true,
  });

  final IconData icon;

  /// Shown as the placeholder when [value] is null, and read to screen
  /// readers either way.
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadii.smallAll,
      side: BorderSide(color: c.border, width: AppSizes.borderWidth),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: value == null ? label : '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: enabled ? c.surface : c.surfaceMuted,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.lg,
                end: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(icon, color: c.ink3, size: AppSizes.icon),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      value ?? label,
                      style: context.type.bodyLarge?.copyWith(
                        color: value == null ? c.ink3 : c.ink,
                      ),
                    ),
                  ),
                  if (onClear != null && enabled)
                    IconButton(
                      tooltip: context.l10n.commonClear,
                      onPressed: onClear,
                      icon: Icon(Icons.close_rounded, color: c.ink2),
                    )
                  else
                    const SizedBox(width: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One option of a single-choice group, as a card with a title and help
/// text. The selected card gets an accent tint, a thicker border and a
/// filled radio icon (state is never colour alone).
class RadioOptionCard<T> extends StatelessWidget {
  const RadioOptionCard({
    super.key,
    required this.value,
    required this.groupValue,
    required this.title,
    required this.onChanged,
    this.subtitle,
    this.leading,
    this.enabled = true,
  });

  final T value;
  final T groupValue;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final ValueChanged<T> onChanged;

  /// Locked choices (e.g. fields that can't change after creation) stay
  /// visible but dimmed and inert.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final selected = value == groupValue;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
          tone: selected ? AppTone.accent : null,
          color: enabled || selected ? null : c.surfaceMuted,
          onTap: enabled ? () => onChanged(value) : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? c.accent.foreground : c.ink3,
              ),
              const SizedBox(width: AppSpacing.md),
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
                      style: context.type.titleSmall?.copyWith(
                        color: enabled || selected ? null : c.ink2,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.type.bodySmall?.copyWith(color: c.ink2),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A value that can't be edited here, with a lock icon saying so.
class ReadOnlyField extends StatelessWidget {
  const ReadOnlyField({
    super.key,
    required this.text,
    this.icon = Icons.lock_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    return AppCard(
      color: c.surfaceMuted,
      child: Row(
        children: [
          Icon(icon, size: AppSizes.icon, color: c.ink2),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.type.bodyLarge)),
        ],
      ),
    );
  }
}
