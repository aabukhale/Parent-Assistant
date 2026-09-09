import 'package:intl/intl.dart';

/// `POST …/activity-assignments` body. `points_reward` and `due_date` are
/// optional; a `points_reward > 0` makes the completion require approval.
class ActivityAssignInput {
  const ActivityAssignInput({
    required this.activityId,
    this.pointsReward,
    this.dueDate,
  });

  final String activityId;
  final int? pointsReward;
  final DateTime? dueDate;

  Map<String, dynamic> toJson() => {
    'activity_id': activityId,
    if (pointsReward != null) 'points_reward': pointsReward,
    if (dueDate != null) 'due_date': DateFormat('yyyy-MM-dd').format(dueDate!),
  };
}

/// `POST …/activities/generate` body — all fields optional. The backend returns
/// **503** until an AI provider is configured; this never fabricates anything.
class GenerateActivityInput {
  const GenerateActivityInput({this.theme, this.durationMinutes, this.count});

  final String? theme;
  final int? durationMinutes;
  final int? count;

  Map<String, dynamic> toJson() => {
    if ((theme ?? '').trim().isNotEmpty) 'theme': theme!.trim(),
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    if (count != null) 'count': count,
  };
}
