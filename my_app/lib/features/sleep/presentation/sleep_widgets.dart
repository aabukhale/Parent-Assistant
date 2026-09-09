import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../data/models/sleep_log.dart';

String _tag(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// Backend-derived minutes → "9h 30m" / "9س 30د" / "9ש׳ 30ד׳". Never recomputed
/// from timestamps — [minutes] comes straight from `duration_minutes`.
String formatSleepDuration(BuildContext context, int minutes) {
  final l = context.l10n;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return l.sleepDurationM(m);
  if (m == 0) return l.sleepDurationH(h);
  return l.sleepDurationHm(h, m);
}

/// Locale-aware time, e.g. "9:30 PM" / "٩:٣٠ م".
String formatSleepTime(BuildContext context, DateTime local) =>
    DateFormat.jm(_tag(context)).format(local);

/// Locale-aware weekday + date, e.g. "Wed, Sep 9".
String formatSleepDate(BuildContext context, DateTime local) =>
    DateFormat.MMMEd(_tag(context)).format(local);

/// Locale-aware month + day (no weekday), for summary night rows.
String formatSleepShortDate(BuildContext context, DateTime local) =>
    DateFormat.MMMd(_tag(context)).format(local);

String sleepSourceLabel(BuildContext context, SleepSource source) =>
    switch (source) {
      SleepSource.manual => context.l10n.sleepSourceManual,
      SleepSource.device => context.l10n.sleepSourceDevice,
    };
