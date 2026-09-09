import 'package:flutter/foundation.dart';

/// How a learning goal is measured (backend `LearningGoalMetric`).
enum LearningGoalMetric {
  /// done / not done — progress value 0 or 1, no target.
  boolean,

  /// a count toward [LearningGoal.targetValue] in [LearningGoal.unit].
  numeric,

  /// 0–100 completion.
  percent;

  static LearningGoalMetric fromString(String? v) => switch (v) {
    'numeric' => LearningGoalMetric.numeric,
    'percent' => LearningGoalMetric.percent,
    _ => LearningGoalMetric.boolean,
  };

  String get wire => name;

  bool get requiresTarget =>
      this == LearningGoalMetric.numeric || this == LearningGoalMetric.percent;
}

/// Backend `LearningGoalStatus`. `archived` is set only via the archive endpoint;
/// `achieved` is set by the backend when progress reaches the target.
enum LearningGoalStatus {
  active,
  achieved,
  paused,
  archived;

  static LearningGoalStatus fromString(String? v) => switch (v) {
    'achieved' => LearningGoalStatus.achieved,
    'paused' => LearningGoalStatus.paused,
    'archived' => LearningGoalStatus.archived,
    _ => LearningGoalStatus.active,
  };

  String get wire => name;

  /// The statuses a user may set via `PATCH` (not `archived`).
  static const editable = [active, paused, achieved];
}

@immutable
class LearningGoalProgressEntry {
  const LearningGoalProgressEntry({
    required this.id,
    required this.value,
    this.note,
    this.recordedBy,
    this.recordedAt,
    this.createdAt,
  });

  final String id;
  final double value;
  final String? note;
  final String? recordedBy;
  final DateTime? recordedAt;
  final DateTime? createdAt;

  factory LearningGoalProgressEntry.fromJson(Map<String, dynamic> json) =>
      LearningGoalProgressEntry(
        id: '${json['id']}',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        note: json['note'] as String?,
        recordedBy: json['recorded_by'] as String?,
        recordedAt: DateTime.tryParse('${json['recorded_at']}'),
        createdAt: DateTime.tryParse('${json['created_at']}'),
      );
}

/// A structured learning goal (`LearningGoalResource`).
///
/// `currentValue` and `progressPercentage` are **computed by the backend** —
/// never recompute them client-side.
@immutable
class LearningGoal {
  const LearningGoal({
    required this.id,
    required this.childId,
    required this.title,
    this.description,
    required this.metric,
    this.targetValue,
    this.unit,
    required this.currentValue,
    this.progressPercentage,
    this.startDate,
    this.targetDate,
    required this.status,
    this.achievedAt,
    this.createdBy,
    this.progress = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String childId;
  final String title;
  final String? description;
  final LearningGoalMetric metric;
  final double? targetValue;
  final String? unit;

  /// Latest recorded progress value (backend `current_value`).
  final double currentValue;

  /// Backend `progress_percentage` — `round(min(100, current/target*100), 1)`,
  /// or null when there is no positive target.
  final double? progressPercentage;

  final DateTime? startDate;
  final DateTime? targetDate;
  final LearningGoalStatus status;
  final DateTime? achievedAt;
  final String? createdBy;

  /// Progress entries embedded on index/show/store responses (newest first).
  final List<LearningGoalProgressEntry> progress;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isBooleanDone =>
      metric == LearningGoalMetric.boolean && currentValue >= 1;

  bool get isArchived => status == LearningGoalStatus.archived;

  /// A 0–1 fraction for progress bars, derived only from backend values.
  double get progressFraction {
    if (metric == LearningGoalMetric.boolean) return isBooleanDone ? 1 : 0;
    final pct = progressPercentage;
    if (pct != null) return (pct / 100).clamp(0, 1).toDouble();
    return 0;
  }

  factory LearningGoal.fromJson(Map<String, dynamic> json) {
    final rawProgress = (json['progress'] as List?) ?? const [];
    return LearningGoal(
      id: '${json['id']}',
      childId: '${json['child_id']}',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      metric: LearningGoalMetric.fromString(json['metric'] as String?),
      targetValue: (json['target_value'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
      progressPercentage: (json['progress_percentage'] as num?)?.toDouble(),
      startDate: _date(json['start_date']),
      targetDate: _date(json['target_date']),
      status: LearningGoalStatus.fromString(json['status'] as String?),
      achievedAt: DateTime.tryParse('${json['achieved_at']}'),
      createdBy: json['created_by'] as String?,
      progress: rawProgress
          .whereType<Map>()
          .map(
            (m) =>
                LearningGoalProgressEntry.fromJson(m.cast<String, dynamic>()),
          )
          .toList(growable: false),
      createdAt: DateTime.tryParse('${json['created_at']}'),
      updatedAt: DateTime.tryParse('${json['updated_at']}'),
    );
  }

  static DateTime? _date(Object? v) {
    if (v == null) return null;
    return DateTime.tryParse('$v');
  }
}
