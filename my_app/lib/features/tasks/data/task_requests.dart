import 'package:flutter/foundation.dart';

import 'models/child_task.dart';
import 'models/task_enums.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `POST …/tasks` (`StoreChildTaskRequest`).
@immutable
class TaskCreateInput {
  const TaskCreateInput({
    required this.title,
    this.description,
    required this.points,
    required this.recurrenceType,
    this.recurrenceConfig,
    this.deadlineAt,
    this.category,
  });

  final String title;
  final String? description;
  final int points;
  final TaskRecurrence recurrenceType;
  final RecurrenceConfig? recurrenceConfig;
  final DateTime? deadlineAt;
  final String? category;

  Map<String, dynamic> toJson() {
    final config = recurrenceType.needsConfig
        ? recurrenceConfig?.toJson()
        : null;
    return {
      'title': title.trim(),
      if ((description ?? '').trim().isNotEmpty)
        'description': description!.trim(),
      'points': points,
      'recurrence_type': recurrenceType.wire,
      if (config != null && config.isNotEmpty) 'recurrence_config': config,
      if (deadlineAt != null)
        'deadline_at': deadlineAt!.toUtc().toIso8601String(),
      if ((category ?? '').trim().isNotEmpty) 'category': category!.trim(),
    };
  }
}

/// `PATCH …/tasks/{task}` (`UpdateChildTaskRequest`). `recurrence_type` and
/// `recurrence_config` are **not** updatable on the backend.
@immutable
class TaskUpdateInput {
  const TaskUpdateInput({
    this.title,
    this.description,
    this.clearDescription = false,
    this.points,
    this.deadlineAt,
    this.clearDeadline = false,
    this.category,
    this.clearCategory = false,
    this.status,
  });

  final String? title;
  final String? description;
  final bool clearDescription;
  final int? points;
  final DateTime? deadlineAt;
  final bool clearDeadline;
  final String? category;
  final bool clearCategory;
  final TaskStatus? status;

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title!.trim(),
    if (clearDescription)
      'description': null
    else if (description != null)
      'description': description!.trim(),
    if (points != null) 'points': points,
    if (clearDeadline)
      'deadline_at': null
    else if (deadlineAt != null)
      'deadline_at': deadlineAt!.toUtc().toIso8601String(),
    if (clearCategory)
      'category': null
    else if (category != null)
      'category': category!.trim(),
    if (status != null) 'status': status!.wire,
  };

  bool get isEmpty => toJson().isEmpty;
}

/// `POST …/tasks/{task}/completions` (`StoreTaskCompletionRequest`).
@immutable
class CompletionRequestInput {
  const CompletionRequestInput({this.occurrenceDate});

  /// `null` → backend defaults to today. Must be `<= today`.
  final DateTime? occurrenceDate;

  Map<String, dynamic> toJson() => {
    if (occurrenceDate != null) 'occurrence_date': _ymd(occurrenceDate!),
  };
}

/// `POST …/approve|reject|reverse` (`ReviewCompletionRequest`).
@immutable
class ReviewInput {
  const ReviewInput({this.note});
  final String? note;

  Map<String, dynamic> toJson() => {
    if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
  };
}
