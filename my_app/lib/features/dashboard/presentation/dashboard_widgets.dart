import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';

String _tag(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// Backend-derived minutes → "1h 30m" / "45m" / "2h", locale-aware. The value
/// always comes straight from an API aggregate — never recomputed here.
String formatDurationMinutes(BuildContext context, int minutes) {
  final l = context.l10n;
  final safe = minutes < 0 ? 0 : minutes;
  final h = safe ~/ 60;
  final m = safe % 60;
  if (h == 0) return l.commonDurationM(m);
  if (m == 0) return l.commonDurationH(h);
  return l.commonDurationHm(h, m);
}

/// "Sep 1 – Sep 7" style range from two date-only values, locale-aware.
String formatDateRange(BuildContext context, DateTime? start, DateTime? end) {
  if (start == null || end == null) return '';
  final fmt = DateFormat.MMMd(_tag(context));
  return '${fmt.format(start)} – ${fmt.format(end)}';
}

/// Locale-aware short date, e.g. "Wed, Sep 9".
String formatShortDate(BuildContext context, DateTime local) =>
    DateFormat.MMMEd(_tag(context)).format(local);

/// A single metric tile. [value] is `null` when the backend did not provide the
/// figure — the tile then reads "unavailable", never "0".
class DashboardStatTile extends StatelessWidget {
  const DashboardStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = AppTone.accent,
    this.onTap,
  });

  final String label;
  final String? value;
  final IconData icon;
  final AppTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, tone: tone, size: 36),
              const Spacer(),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: context.mamily.ink3),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value ?? l.dashUnavailableShort,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: value == null
                ? context.type.bodyMedium?.copyWith(color: context.mamily.ink2)
                : context.type.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          ),
        ],
      ),
    );
  }
}

/// Two-column tiles whose rows grow to fit their tallest tile.
class DashboardTileGrid extends StatelessWidget {
  const DashboardTileGrid({
    super.key,
    required this.tiles,
    this.gap = AppSpacing.sm,
  });

  final List<Widget> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              SizedBox(width: gap),
              Expanded(
                child: i + 1 < tiles.length
                    ? tiles[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// A titled card wrapping a report section. Shows [child] when the section has
/// data, otherwise an honest "no data for this period" line.
class DashboardSectionCard extends StatelessWidget {
  const DashboardSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.hasData,
    required this.child,
    this.tone = AppTone.neutral,
  });

  final String title;
  final IconData icon;
  final bool hasData;
  final Widget child;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, tone: tone, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: context.type.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (hasData)
            child
          else
            Text(
              l.dashSectionNoData,
              style: context.type.bodyMedium?.copyWith(
                color: context.mamily.ink2,
              ),
            ),
        ],
      ),
    );
  }
}

/// One "label: value" row inside a section card.
class DashboardMetricRow extends StatelessWidget {
  const DashboardMetricRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.type.bodyMedium?.copyWith(
                color: context.mamily.ink2,
              ),
            ),
          ),
          Text(value, style: context.type.labelLarge),
        ],
      ),
    );
  }
}

/// The amber "reports aren't available to you" / permission-retry banner,
/// matching the shared style used on the sleep and rewards screens.
class DashboardNoticeBanner extends StatelessWidget {
  const DashboardNoticeBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: NoticeBanner(
        tone: AppTone.warning,
        message: message,
        actionLabel: onRetry == null ? null : l.commonRetry,
        onAction: onRetry,
      ),
    );
  }
}
