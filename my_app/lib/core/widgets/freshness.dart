import 'package:flutter/material.dart';

import '../localization/l10n.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';

/// "just now" / "5 min ago" / "2 hours ago" / "yesterday", localized.
String relativeTime(BuildContext context, DateTime when, {DateTime? now}) {
  final l = context.l10n;
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.hoursAgo(diff.inHours);
  return l.daysAgo(diff.inDays);
}

/// Small "Updated 3 min ago" line, or an offline notice when the data comes
/// from the device cache. Never claims live data it doesn't have.
class FreshnessLine extends StatelessWidget {
  const FreshnessLine({
    super.key,
    required this.fetchedAt,
    this.fromCache = false,
  });

  final DateTime fetchedAt;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    final l = context.l10n;
    final when = relativeTime(context, fetchedAt);
    final tone = fromCache ? c.warning : c.neutral;
    return Semantics(
      liveRegion: fromCache,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fromCache ? Icons.cloud_off_rounded : Icons.schedule_rounded,
            size: AppSizes.iconSm,
            color: tone.foreground,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              fromCache ? l.offlineShowingSaved(when) : l.lastUpdated(when),
              style: context.type.bodySmall?.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
