import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';

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
    this.color = AppColors.teal,
    this.onTap,
  });

  final String label;
  final String? value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const Spacer(),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFF9AA3B5),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value ?? l.dashUnavailableShort,
              style: TextStyle(
                color: value == null ? AppColors.textMuted : AppColors.navy,
                fontSize: value == null ? 13 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
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
    this.color = AppColors.navy,
  });

  final String title;
  final IconData icon;
  final bool hasData;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasData)
            child
          else
            Text(
              l.dashSectionNoData,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.amber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
        ],
      ),
    );
  }
}
