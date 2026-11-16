import 'package:flutter/material.dart';

import '../localization/l10n.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';
import 'status_pill.dart';

/// An inline message: info, warning, error or success.
///
/// The single replacement for the permission banners, dashboard notices and
/// "not enforced" disclaimers that each screen reimplemented. Always shows an
/// icon next to the text so meaning never depends on colour.
///
/// [AppTone.danger] banners are announced to screen readers when they appear
/// (override with [liveRegion]).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = AppTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.liveRegion,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be given together',
       );

  final String message;
  final String? title;
  final AppTone tone;

  /// Overrides the tone's default icon.
  final IconData? icon;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Announce the banner to screen readers when it appears. Defaults to true
  /// for [AppTone.danger] only.
  final bool? liveRegion;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final colors = c.tone(tone);
    final text = context.type;
    final glyph = icon ?? defaultToneIcon(tone) ?? Icons.info_rounded;

    return Semantics(
      container: true,
      liveRegion: liveRegion ?? tone == AppTone.danger,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: AppRadii.mediumAll,
          border: Border.all(color: colors.border, width: AppSizes.borderWidth),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(glyph, size: AppSizes.iconMd, color: colors.foreground),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: text.titleSmall?.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                    Text(message, style: text.bodyMedium),
                    if (actionLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.foreground,
                            padding: EdgeInsets.zero,
                            alignment: AlignmentDirectional.centerStart,
                          ),
                          child: Text(actionLabel!),
                        ),
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

/// Shown when the caller's effective permissions could not be loaded: the
/// management actions stay hidden (denied by default) until a retry works.
class PermissionNotice extends StatelessWidget {
  const PermissionNotice({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: NoticeBanner(
        tone: AppTone.warning,
        message: l.permLoadFailed,
        actionLabel: l.commonRetry,
        onAction: onRetry,
      ),
    );
  }
}
