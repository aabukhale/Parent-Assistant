import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';

/// A heading for a group of content, with an optional subtitle and one
/// trailing action ("See all"). Marked as a heading for screen readers so
/// users can jump between sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be given together',
       ),
       assert(
         trailing == null || actionLabel == null,
         'Use either trailing or actionLabel/onAction, not both',
       );

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Any custom trailing widget (e.g. a [StatusPill]). Mutually exclusive with
  /// [actionLabel].
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = context.type;
    final c = context.mamily;

    Widget? end = trailing;
    if (actionLabel != null) {
      end = TextButton(onPressed: onAction, child: Text(actionLabel!));
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: text.titleMedium),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: text.bodyMedium?.copyWith(color: c.ink2),
                  ),
              ],
            ),
          ),
          if (end != null) ...[const SizedBox(width: AppSpacing.sm), end],
        ],
      ),
    );
  }
}
