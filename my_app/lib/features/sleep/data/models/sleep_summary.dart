import 'package:flutter/foundation.dart';

/// One night in the summary — `sleep_minutes` is the total for the calendar date
/// (keyed by `ended_at` in the family timezone, server-side).
@immutable
class SleepNight {
  const SleepNight({required this.date, required this.sleepMinutes});

  /// Family-local calendar date (date-only; no timezone conversion needed).
  final DateTime date;
  final int sleepMinutes;

  factory SleepNight.fromJson(Map<String, dynamic> json) => SleepNight(
    date: DateTime.tryParse('${json['date']}') ?? DateTime(1970),
    sleepMinutes: (json['sleep_minutes'] as num?)?.round() ?? 0,
  );
}

/// Derived sleep summary (`SleepSummaryService`). Everything here is computed by
/// the backend in the **family timezone** — the app displays the numbers and
/// dates verbatim, it does not recompute averages or durations.
@immutable
class SleepSummary {
  const SleepSummary({
    required this.period,
    required this.timezone,
    required this.periodStart,
    required this.periodEnd,
    required this.nightsLogged,
    required this.totalSleepMinutes,
    required this.averageSleepMinutes,
    required this.hasSufficientData,
    required this.nights,
  });

  /// `weekly` | `monthly`
  final String period;

  /// The family timezone the backend used (informational).
  final String timezone;

  final DateTime periodStart;
  final DateTime periodEnd;
  final int nightsLogged;
  final int totalSleepMinutes;
  final int averageSleepMinutes;
  final bool hasSufficientData;
  final List<SleepNight> nights;

  factory SleepSummary.fromJson(Map<String, dynamic> json) {
    final rawNights = (json['nights'] as List?) ?? const [];
    return SleepSummary(
      period: json['period'] as String? ?? 'weekly',
      timezone: json['timezone'] as String? ?? 'UTC',
      periodStart:
          DateTime.tryParse('${json['period_start']}') ?? DateTime(1970),
      periodEnd: DateTime.tryParse('${json['period_end']}') ?? DateTime(1970),
      nightsLogged: (json['nights_logged'] as num?)?.round() ?? 0,
      totalSleepMinutes: (json['total_sleep_minutes'] as num?)?.round() ?? 0,
      averageSleepMinutes:
          (json['average_sleep_minutes'] as num?)?.round() ?? 0,
      hasSufficientData: json['has_sufficient_data'] as bool? ?? false,
      nights: rawNights
          .whereType<Map>()
          .map((m) => SleepNight.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}
