/// Backend `App\Enums\TaskRecurrence`.
enum TaskRecurrence {
  oneTime('one_time'),
  daily('daily'),
  weekly('weekly'),
  custom('custom');

  const TaskRecurrence(this.wire);
  final String wire;

  static TaskRecurrence fromWire(String? v) {
    for (final r in TaskRecurrence.values) {
      if (r.wire == v) return r;
    }
    return TaskRecurrence.oneTime;
  }

  bool get needsConfig =>
      this == TaskRecurrence.weekly || this == TaskRecurrence.custom;
}

/// Backend `App\Enums\TaskStatus`.
enum TaskStatus {
  active,
  archived;

  static TaskStatus fromWire(String? v) =>
      v == 'archived' ? TaskStatus.archived : TaskStatus.active;

  String get wire => name;
}

/// Backend `App\Enums\CompletionStatus`. Note: there is **no** "reversed"
/// status — a reversed completion keeps `status: approved` and carries a
/// non-null `reversed_at` (see [TaskCompletion.isReversed]).
enum CompletionStatus {
  pending,
  approved,
  rejected;

  static CompletionStatus fromWire(String? v) => switch (v) {
    'approved' => CompletionStatus.approved,
    'rejected' => CompletionStatus.rejected,
    _ => CompletionStatus.pending,
  };

  String get wire => name;
}

/// Backend `App\Enums\PointTransactionType`.
enum PointTransactionType {
  taskAward('task_award'),
  taskReversal('task_reversal'),
  activityAward('activity_award'),
  activityReversal('activity_reversal'),
  redemption('redemption'),
  redemptionRefund('redemption_refund'),
  adjustment('adjustment');

  const PointTransactionType(this.wire);
  final String wire;

  static PointTransactionType fromWire(String? v) {
    for (final t in PointTransactionType.values) {
      if (t.wire == v) return t;
    }
    return PointTransactionType.adjustment;
  }
}

/// Backend `App\Enums\PointSourceType`.
enum PointSourceType {
  taskCompletion('task_completion'),
  activityCompletion('activity_completion'),
  rewardRedemption('reward_redemption'),
  manual('manual');

  const PointSourceType(this.wire);
  final String wire;

  static PointSourceType? fromWire(String? v) {
    for (final s in PointSourceType.values) {
      if (s.wire == v) return s;
    }
    return null;
  }
}
