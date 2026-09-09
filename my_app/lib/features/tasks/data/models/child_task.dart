import 'package:flutter/foundation.dart';

import 'task_completion.dart';
import 'task_enums.dart';

/// The recurrence definition (`recurrence_config` JSON). Only the keys the
/// backend documents are used — nothing invented.
///
/// * `weekly` → [daysOfWeek] (ISO weekday, 1 = Mon … 7 = Sun), at least one.
/// * `custom` → **either** [dates] (`YYYY-MM-DD` strings) **or**
///   [intervalDays] (1–365) + [anchorDate] (`YYYY-MM-DD`).
/// * `one_time` / `daily` → the backend forces this to `null`.
@immutable
class RecurrenceConfig {
  const RecurrenceConfig({
    this.daysOfWeek = const [],
    this.dates = const [],
    this.intervalDays,
    this.anchorDate,
  });

  final List<int> daysOfWeek;
  final List<String> dates;
  final int? intervalDays;
  final String? anchorDate;

  bool get isEmpty =>
      daysOfWeek.isEmpty &&
      dates.isEmpty &&
      intervalDays == null &&
      anchorDate == null;

  bool get isIntervalForm =>
      intervalDays != null && (anchorDate ?? '').isNotEmpty;

  factory RecurrenceConfig.fromJson(Map<String, dynamic> json) =>
      RecurrenceConfig(
        daysOfWeek: ((json['days_of_week'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(growable: false),
        dates: ((json['dates'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(growable: false),
        intervalDays: (json['interval_days'] as num?)?.toInt(),
        anchorDate: json['anchor_date'] as String?,
      );

  Map<String, dynamic> toJson() => {
    if (daysOfWeek.isNotEmpty) 'days_of_week': daysOfWeek,
    if (dates.isNotEmpty) 'dates': dates,
    if (intervalDays != null) 'interval_days': intervalDays,
    if ((anchorDate ?? '').isNotEmpty) 'anchor_date': anchorDate,
  };
}

/// A child task (`ChildTaskResource`).
@immutable
class ChildTask {
  const ChildTask({
    required this.id,
    required this.childId,
    required this.title,
    this.description,
    required this.points,
    required this.recurrenceType,
    this.recurrenceConfig,
    this.deadlineAt,
    this.category,
    this.iconKey,
    this.reminderConfig,
    required this.status,
    this.createdBy,
    this.completions = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String childId;
  final String title;
  final String? description;
  final int points;
  final TaskRecurrence recurrenceType;
  final RecurrenceConfig? recurrenceConfig;
  final DateTime? deadlineAt;
  final String? category;
  final String? iconKey;

  /// Pass-through only — not edited in this phase (no reminders/notifications).
  final Map<String, dynamic>? reminderConfig;

  final TaskStatus status;
  final String? createdBy;

  /// Only present on `GET tasks/{task}` (the `show` endpoint), newest first.
  final List<TaskCompletion> completions;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isArchived => status == TaskStatus.archived;

  factory ChildTask.fromJson(Map<String, dynamic> json) {
    final rawCompletions = (json['completions'] as List?) ?? const [];
    final rc = json['recurrence_config'];
    return ChildTask(
      id: '${json['id']}',
      childId: '${json['child_id']}',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      points: (json['points'] as num?)?.toInt() ?? 0,
      recurrenceType: TaskRecurrence.fromWire(
        json['recurrence_type'] as String?,
      ),
      recurrenceConfig: rc is Map<String, dynamic>
          ? RecurrenceConfig.fromJson(rc)
          : null,
      deadlineAt: DateTime.tryParse('${json['deadline_at']}'),
      category: json['category'] as String?,
      iconKey: json['icon_key'] as String?,
      reminderConfig: json['reminder_config'] is Map<String, dynamic>
          ? (json['reminder_config'] as Map<String, dynamic>)
          : null,
      status: TaskStatus.fromWire(json['status'] as String?),
      createdBy: json['created_by'] as String?,
      completions: rawCompletions
          .whereType<Map>()
          .map((m) => TaskCompletion.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
      createdAt: DateTime.tryParse('${json['created_at']}'),
      updatedAt: DateTime.tryParse('${json['updated_at']}'),
    );
  }
}
