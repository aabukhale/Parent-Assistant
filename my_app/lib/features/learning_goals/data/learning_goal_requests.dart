import 'package:flutter/foundation.dart';

import 'models/learning_goal.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `POST …/learning-goals` (`StoreLearningGoalRequest`).
@immutable
class LearningGoalCreateInput {
  const LearningGoalCreateInput({
    required this.title,
    this.description,
    required this.metric,
    this.targetValue,
    this.unit,
    this.startDate,
    this.targetDate,
  });

  final String title;
  final String? description;
  final LearningGoalMetric metric;
  final double? targetValue;
  final String? unit;
  final DateTime? startDate;
  final DateTime? targetDate;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    if (_notBlank(description)) 'description': description!.trim(),
    'metric': metric.wire,
    if (metric.requiresTarget && targetValue != null)
      'target_value': targetValue,
    if (metric == LearningGoalMetric.numeric && _notBlank(unit))
      'unit': unit!.trim(),
    if (startDate != null) 'start_date': _ymd(startDate!),
    if (targetDate != null) 'target_date': _ymd(targetDate!),
  };
}

/// `PATCH …/learning-goals/{goal}` (`UpdateLearningGoalRequest`).
/// `metric` and `start_date` are immutable — not sent here.
@immutable
class LearningGoalUpdateInput {
  const LearningGoalUpdateInput({
    this.title,
    this.description,
    this.clearDescription = false,
    this.targetValue,
    this.clearTargetValue = false,
    this.unit,
    this.clearUnit = false,
    this.targetDate,
    this.clearTargetDate = false,
    this.status,
  });

  final String? title;
  final String? description;
  final bool clearDescription;
  final double? targetValue;
  final bool clearTargetValue;
  final String? unit;
  final bool clearUnit;
  final DateTime? targetDate;
  final bool clearTargetDate;
  final LearningGoalStatus? status;

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title!.trim(),
    if (clearDescription)
      'description': null
    else if (description != null)
      'description': description!.trim(),
    if (clearTargetValue)
      'target_value': null
    else if (targetValue != null)
      'target_value': targetValue,
    if (clearUnit) 'unit': null else if (unit != null) 'unit': unit!.trim(),
    if (clearTargetDate)
      'target_date': null
    else if (targetDate != null)
      'target_date': _ymd(targetDate!),
    if (status != null) 'status': status!.wire,
  };

  bool get isEmpty => toJson().isEmpty;
}

/// `POST …/learning-goals/{goal}/progress` (`StoreLearningGoalProgressRequest`).
@immutable
class LearningGoalProgressInput {
  const LearningGoalProgressInput({
    required this.value,
    this.note,
    this.recordedAt,
  });

  final double value;
  final String? note;
  final DateTime? recordedAt;

  Map<String, dynamic> toJson() => {
    'value': value,
    if (_notBlank(note)) 'note': note!.trim(),
    if (recordedAt != null)
      'recorded_at': recordedAt!.toUtc().toIso8601String(),
  };
}

bool _notBlank(String? v) => v != null && v.trim().isNotEmpty;
