import 'package:flutter/foundation.dart';

/// The most recent completed sleep for a child, as embedded in the child
/// summary. `null` when the child has no sleep logs.
@immutable
class LastSleep {
  const LastSleep({
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
  });

  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Backend-derived duration (`SleepLog::durationMinutes()`), never recomputed.
  final int durationMinutes;

  factory LastSleep.fromJson(Map<String, dynamic> json) => LastSleep(
    startedAt: DateTime.tryParse('${json['started_at']}')?.toLocal(),
    endedAt: DateTime.tryParse('${json['ended_at']}')?.toLocal(),
    durationMinutes: (json['duration_minutes'] as num?)?.round() ?? 0,
  );
}

/// Today's screen-time position for a child (family timezone, server-side).
/// `effectiveLimitMinutes` / `remainingMinutes` are **null** when no screen-time
/// rule is configured — that is "no limit set", not zero.
@immutable
class ScreenTimeToday {
  const ScreenTimeToday({
    required this.usedMinutes,
    required this.effectiveLimitMinutes,
    required this.remainingMinutes,
  });

  final int usedMinutes;
  final int? effectiveLimitMinutes;
  final int? remainingMinutes;

  bool get hasLimit => effectiveLimitMinutes != null;

  factory ScreenTimeToday.fromJson(Map<String, dynamic> json) =>
      ScreenTimeToday(
        usedMinutes: (json['used_minutes'] as num?)?.round() ?? 0,
        effectiveLimitMinutes: (json['effective_limit_minutes'] as num?)
            ?.round(),
        remainingMinutes: (json['remaining_minutes'] as num?)?.round(),
      );
}

@immutable
class TaskCounts {
  const TaskCounts({required this.active, required this.pendingApproval});

  final int active;
  final int pendingApproval;

  factory TaskCounts.fromJson(Map<String, dynamic> json) => TaskCounts(
    active: (json['active'] as num?)?.round() ?? 0,
    pendingApproval: (json['pending_approval'] as num?)?.round() ?? 0,
  );
}

@immutable
class LearningGoalCounts {
  const LearningGoalCounts({required this.active, required this.achieved});

  final int active;
  final int achieved;

  factory LearningGoalCounts.fromJson(Map<String, dynamic> json) =>
      LearningGoalCounts(
        active: (json['active'] as num?)?.round() ?? 0,
        achieved: (json['achieved'] as num?)?.round() ?? 0,
      );
}

/// A per-child developmental digest — `GET /families/{family}/children/{child}/summary`
/// and each entry of the parent dashboard's `children[]`.
///
/// Every number is a backend aggregate. Nothing here is computed on the client;
/// nullable fields (`age`, screen-time limit, `lastSleep`) stay nullable so the
/// UI can distinguish "zero" from "not available".
@immutable
class ChildSummary {
  const ChildSummary({
    required this.childId,
    required this.name,
    required this.age,
    required this.pointsBalance,
    required this.screenTimeToday,
    required this.lastSleep,
    required this.tasks,
    required this.learningGoals,
  });

  final String childId;
  final String name;
  final int? age;
  final int pointsBalance;
  final ScreenTimeToday screenTimeToday;
  final LastSleep? lastSleep;
  final TaskCounts tasks;
  final LearningGoalCounts learningGoals;

  factory ChildSummary.fromJson(Map<String, dynamic> json) {
    final screenTime = json['screen_time_today'];
    final lastSleep = json['last_sleep'];
    final tasks = json['tasks'];
    final goals = json['learning_goals'];
    return ChildSummary(
      childId: '${json['child_id']}',
      name: json['name'] as String? ?? '',
      age: (json['age'] as num?)?.round(),
      pointsBalance: (json['points_balance'] as num?)?.round() ?? 0,
      screenTimeToday: screenTime is Map<String, dynamic>
          ? ScreenTimeToday.fromJson(screenTime)
          : const ScreenTimeToday(
              usedMinutes: 0,
              effectiveLimitMinutes: null,
              remainingMinutes: null,
            ),
      lastSleep: lastSleep is Map<String, dynamic>
          ? LastSleep.fromJson(lastSleep)
          : null,
      tasks: tasks is Map<String, dynamic>
          ? TaskCounts.fromJson(tasks)
          : const TaskCounts(active: 0, pendingApproval: 0),
      learningGoals: goals is Map<String, dynamic>
          ? LearningGoalCounts.fromJson(goals)
          : const LearningGoalCounts(active: 0, achieved: 0),
    );
  }
}
