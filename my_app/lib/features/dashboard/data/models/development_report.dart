import 'package:flutter/foundation.dart';

/// One section of a development report. Every section carries [hasData] so the
/// UI can show "no data this period" instead of a fabricated zero.
///
/// The backend returns only **period aggregates** — there is no per-day series
/// and no composite "development score". Charts that need a daily breakdown are
/// therefore shown as unavailable (see docs/flutter-integration.md).
@immutable
class ReportSection {
  const ReportSection({required this.hasData, required this.metrics});

  final bool hasData;

  /// Ordered metric key → raw integer value, straight from the backend. Keys are
  /// section-specific (`total_minutes`, `nights_logged`, `sessions`, …).
  final Map<String, int> metrics;

  int metric(String key) => metrics[key] ?? 0;

  factory ReportSection.fromJson(Map<String, dynamic> json, List<String> keys) {
    return ReportSection(
      hasData: json['has_data'] as bool? ?? false,
      metrics: {for (final k in keys) k: (json[k] as num?)?.round() ?? 0},
    );
  }

  static const _empty = ReportSection(hasData: false, metrics: {});
}

@immutable
class DevelopmentReportSections {
  const DevelopmentReportSections({
    required this.screenTime,
    required this.sleep,
    required this.activities,
    required this.games,
    required this.tasks,
    required this.points,
  });

  final ReportSection screenTime;
  final ReportSection sleep;
  final ReportSection activities;
  final ReportSection games;
  final ReportSection tasks;
  final ReportSection points;

  static ReportSection _section(Object? raw, List<String> keys) =>
      raw is Map<String, dynamic>
      ? ReportSection.fromJson(raw, keys)
      : ReportSection._empty;

  factory DevelopmentReportSections.fromJson(
    Map<String, dynamic> json,
  ) => DevelopmentReportSections(
    screenTime: _section(json['screen_time'], const [
      'total_minutes',
      'days_with_usage',
      'daily_average_minutes',
    ]),
    sleep: _section(json['sleep'], const [
      'nights_logged',
      'total_minutes',
      'average_minutes',
    ]),
    activities: _section(json['activities'], const ['completed', 'approved']),
    games: _section(json['games'], const [
      'sessions',
      'distinct_games',
      'total_play_minutes',
    ]),
    tasks: _section(json['tasks'], const [
      'approved_completions',
      'points_from_tasks',
    ]),
    points: _section(json['points'], const ['net_change', 'transaction_count']),
  );
}

/// `GET /families/{family}/children/{child}/reports/{weekly|monthly}` — a
/// weekly or monthly development report computed from source tables. Nothing is
/// stored server-side and nothing is computed on the client.
@immutable
class DevelopmentReport {
  const DevelopmentReport({
    required this.schemaVersion,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.timezone,
    required this.generatedAt,
    required this.hasSufficientData,
    required this.sections,
  });

  /// `weekly` | `monthly` — kept as the raw string; an unexpected value is
  /// displayed as-is rather than crashing.
  final String period;
  final int schemaVersion;

  /// Family-local calendar dates (date-only).
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String timezone;
  final DateTime? generatedAt;

  /// `true` when at least one section has data.
  final bool hasSufficientData;
  final DevelopmentReportSections sections;

  factory DevelopmentReport.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    return DevelopmentReport(
      schemaVersion: (json['schema_version'] as num?)?.round() ?? 1,
      period: json['period'] as String? ?? 'weekly',
      periodStart: DateTime.tryParse('${json['period_start']}'),
      periodEnd: DateTime.tryParse('${json['period_end']}'),
      timezone: json['timezone'] as String? ?? 'UTC',
      generatedAt: DateTime.tryParse('${json['generated_at']}')?.toLocal(),
      hasSufficientData: json['has_sufficient_data'] as bool? ?? false,
      sections: rawSections is Map<String, dynamic>
          ? DevelopmentReportSections.fromJson(rawSections)
          : DevelopmentReportSections.fromJson(const {}),
    );
  }
}
