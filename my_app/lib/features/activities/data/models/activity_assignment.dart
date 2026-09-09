import 'package:flutter/foundation.dart';

import 'activity.dart';
import 'activity_completion.dart';

/// Backend `App\Enums\AssignmentStatus`. Unknown → [assigned].
enum AssignmentStatus {
  assigned,
  completed,
  cancelled;

  static AssignmentStatus fromWire(String? v) => switch (v) {
    'completed' => AssignmentStatus.completed,
    'cancelled' => AssignmentStatus.cancelled,
    _ => AssignmentStatus.assigned,
  };

  String get wire => name;
}

/// An activity assigned to a child (`ActivityAssignmentResource`).
///
/// `requiresApproval` is backend-derived (`points_reward > 0`). When it is
/// false, completing the assignment is auto-approved server-side; when true the
/// completion lands `pending` and a parent must approve it before points move.
@immutable
class ActivityAssignment {
  const ActivityAssignment({
    required this.id,
    required this.activityId,
    required this.childId,
    required this.assignedBy,
    required this.pointsReward,
    required this.requiresApproval,
    required this.status,
    required this.dueDate,
    required this.activity,
    required this.completions,
    this.createdAt,
  });

  final String id;
  final String activityId;
  final String childId;
  final String? assignedBy;
  final int pointsReward;
  final bool requiresApproval;
  final AssignmentStatus status;

  /// Date-only.
  final DateTime? dueDate;
  final Activity? activity;
  final List<ActivityCompletion> completions;
  final DateTime? createdAt;

  bool get isCancelled => status == AssignmentStatus.cancelled;

  /// The most recent completion, if any (the list is newest-first from the API
  /// via the assignment's `latest()` ordering on the parent).
  ActivityCompletion? get latestCompletion =>
      completions.isEmpty ? null : completions.first;

  /// A completion can be requested while the assignment isn't cancelled and
  /// there is no pending/approved completion already standing.
  bool get canComplete {
    if (isCancelled) return false;
    final last = latestCompletion;
    return last == null || last.isRejected;
  }

  factory ActivityAssignment.fromJson(Map<String, dynamic> json) {
    final rawActivity = json['activity'];
    final rawCompletions = (json['completions'] as List?) ?? const [];
    return ActivityAssignment(
      id: '${json['id']}',
      activityId: '${json['activity_id']}',
      childId: '${json['child_id']}',
      assignedBy: json['assigned_by'] as String?,
      pointsReward: (json['points_reward'] as num?)?.round() ?? 0,
      requiresApproval: json['requires_approval'] as bool? ?? false,
      status: AssignmentStatus.fromWire(json['status'] as String?),
      dueDate: DateTime.tryParse('${json['due_date']}'),
      activity: rawActivity is Map<String, dynamic>
          ? Activity.fromJson(rawActivity)
          : null,
      completions: rawCompletions
          .whereType<Map>()
          .map((m) => ActivityCompletion.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
      createdAt: DateTime.tryParse('${json['created_at']}'),
    );
  }
}
