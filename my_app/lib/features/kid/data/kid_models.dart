// Typed models for the child-session API (`/api/v1/child/*`).
//
// Every field mirrors the backend payload; nothing is invented client-side.

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? v) => v is List
    ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
    : const [];
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double? _double(Object? v) => (v as num?)?.toDouble();
DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

/// A value plus how fresh it is (live vs shown from the offline cache).
class Fresh<T> {
  const Fresh(this.value, {required this.fetchedAt, this.fromCache = false});

  final T value;
  final DateTime fetchedAt;
  final bool fromCache;
}

class KidTaskSummary {
  const KidTaskSummary({
    required this.id,
    required this.title,
    required this.points,
    required this.state,
    this.description,
    this.iconKey,
    this.category,
    this.reviewNote,
    this.completionId,
    this.recurrenceType,
    this.deadlineAt,
  });

  final String id;
  final String title;
  final String? description;
  final int points;

  /// todo | pending | approved | rejected
  final String state;
  final String? iconKey;
  final String? category;
  final String? reviewNote;
  final String? completionId;
  final String? recurrenceType;
  final DateTime? deadlineAt;

  bool get canSubmit => state == 'todo' || state == 'rejected';

  factory KidTaskSummary.fromJson(Map<String, dynamic> j) {
    final completion = j['completion'] is Map ? _map(j['completion']) : null;
    return KidTaskSummary(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      description: j['description'] as String?,
      points: _int(j['points']),
      state: j['state'] as String? ?? 'todo',
      iconKey: j['icon_key'] as String?,
      category: j['category'] as String?,
      reviewNote: (completion?['review_note'] ?? j['review_note']) as String?,
      completionId: completion?['id'] as String?,
      recurrenceType: j['recurrence_type'] as String?,
      deadlineAt: _date(j['deadline_at']),
    );
  }
}

class RoutineStep {
  const RoutineStep({
    required this.id,
    required this.title,
    required this.position,
    required this.checked,
    this.iconKey,
    this.durationMinutes,
  });

  final String id;
  final String title;
  final int position;
  final bool checked;
  final String? iconKey;
  final int? durationMinutes;

  factory RoutineStep.fromJson(Map<String, dynamic> j) => RoutineStep(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    position: _int(j['position']),
    checked: j['checked'] as bool? ?? false,
    iconKey: j['icon_key'] as String?,
    durationMinutes: (j['duration_minutes'] as num?)?.toInt(),
  );
}

class RoutineRunInfo {
  const RoutineRunInfo({
    required this.id,
    required this.status,
    required this.stepsTotal,
    required this.stepsDone,
    required this.progress,
    this.runDate,
    this.startedAt,
    this.completedAt,
    this.pointsAwarded,
    this.reviewNote,
  });

  final String id;

  /// in_progress | completed | pending_review | approved | rejected
  final String status;
  final int stepsTotal;
  final int stepsDone;
  final double progress;
  final String? runDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? pointsAwarded;
  final String? reviewNote;

  bool get isFinished => status != 'in_progress';

  factory RoutineRunInfo.fromJson(Map<String, dynamic> j) => RoutineRunInfo(
    id: j['id'] as String,
    status: j['status'] as String? ?? 'in_progress',
    stepsTotal: _int(j['steps_total']),
    stepsDone: _int(j['steps_done']),
    progress: _double(j['progress']) ?? 0,
    runDate: j['run_date'] as String?,
    startedAt: _date(j['started_at']),
    completedAt: _date(j['completed_at']),
    pointsAwarded: (j['points_awarded'] as num?)?.toInt(),
    reviewNote: j['review_note'] as String?,
  );
}

class Routine {
  const Routine({
    required this.id,
    required this.childId,
    required this.title,
    required this.kind,
    required this.daysOfWeek,
    required this.bonusPoints,
    required this.isActive,
    required this.reminderEnabled,
    required this.steps,
    this.startTime,
    this.endTime,
    this.todayRun,
    this.scheduledToday,
  });

  final String id;
  final String childId;
  final String title;

  /// morning | after_school | bedtime | custom
  final String kind;
  final String? startTime;
  final String? endTime;
  final List<int> daysOfWeek;
  final int bonusPoints;
  final bool isActive;
  final bool reminderEnabled;
  final List<RoutineStep> steps;
  final RoutineRunInfo? todayRun;
  final bool? scheduledToday;

  int get doneCount => steps.where((s) => s.checked).length;
  double get progress => steps.isEmpty ? 0 : doneCount / steps.length;

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
    id: j['id'] as String,
    childId: j['child_id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    kind: j['kind'] as String? ?? 'custom',
    startTime: j['start_time'] as String?,
    endTime: j['end_time'] as String?,
    daysOfWeek: ((j['days_of_week'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList(growable: false),
    bonusPoints: _int(j['bonus_points']),
    isActive: j['is_active'] as bool? ?? true,
    reminderEnabled: j['reminder_enabled'] as bool? ?? true,
    steps: _list(j['steps']).map(RoutineStep.fromJson).toList(growable: false),
    todayRun: j['today_run'] is Map
        ? RoutineRunInfo.fromJson(_map(j['today_run']))
        : null,
    scheduledToday: j['scheduled_today'] as bool?,
  );
}

class TimelineItem {
  const TimelineItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.state,
    this.time,
    this.task,
    this.routine,
    this.event,
  });

  /// routine | task | event
  final String kind;
  final String id;
  final String title;
  final String state;
  final String? time;
  final KidTaskSummary? task;
  final Routine? routine;
  final Map<String, dynamic>? event;

  factory TimelineItem.fromJson(Map<String, dynamic> j) => TimelineItem(
    kind: j['kind'] as String? ?? 'task',
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    state: j['state'] as String? ?? 'todo',
    time: j['time'] as String?,
    task: j['task'] is Map
        ? KidTaskSummary.fromJson({..._map(j['task']), 'state': j['state']})
        : null,
    routine: j['routine'] is Map ? Routine.fromJson(_map(j['routine'])) : null,
    event: j['event'] is Map ? _map(j['event']) : null,
  );
}

class RewardGoal {
  const RewardGoal({
    required this.rewardId,
    required this.title,
    required this.pointsCost,
    required this.pointsNeeded,
    required this.progress,
    required this.chosenByChild,
  });

  final String rewardId;
  final String title;
  final int pointsCost;
  final int pointsNeeded;
  final double progress;
  final bool chosenByChild;

  factory RewardGoal.fromJson(Map<String, dynamic> j) => RewardGoal(
    rewardId: j['reward_id'] as String,
    title: j['title'] as String? ?? '',
    pointsCost: _int(j['points_cost']),
    pointsNeeded: _int(j['points_needed']),
    progress: _double(j['progress']) ?? 0,
    chosenByChild: j['chosen_by_child'] as bool? ?? false,
  );
}

class Encouragement {
  const Encouragement({
    required this.id,
    required this.message,
    this.badgeKey,
    this.senderName,
    this.subjectType,
    this.seenAt,
    this.createdAt,
  });

  final String id;
  final String message;
  final String? badgeKey;
  final String? senderName;
  final String? subjectType;
  final DateTime? seenAt;
  final DateTime? createdAt;

  factory Encouragement.fromJson(Map<String, dynamic> j) => Encouragement(
    id: j['id'] as String,
    message: j['message'] as String? ?? '',
    badgeKey: j['badge_key'] as String?,
    senderName: j['sender_name'] as String?,
    subjectType: j['subject_type'] as String?,
    seenAt: _date(j['seen_at']),
    createdAt: _date(j['created_at']),
  );
}

class MyDay {
  const MyDay({
    required this.date,
    required this.now,
    required this.greeting,
    required this.timeline,
    required this.pointsBalance,
    required this.tasksTotal,
    required this.tasksDone,
    required this.tasksWaiting,
    required this.routinesTotal,
    required this.routinesDone,
    required this.checkedInToday,
    required this.newEncouragements,
    required this.goals,
    this.nextAction,
    this.rewardGoal,
  });

  final String date;
  final String now;

  /// morning | afternoon | evening
  final String greeting;
  final List<TimelineItem> timeline;
  final Map<String, dynamic>? nextAction;
  final int pointsBalance;
  final int tasksTotal;
  final int tasksDone;
  final int tasksWaiting;
  final int routinesTotal;
  final int routinesDone;
  final RewardGoal? rewardGoal;
  final bool checkedInToday;
  final List<Encouragement> newEncouragements;
  final List<Map<String, dynamic>> goals;

  bool get isEmpty => timeline.isEmpty;
  bool get allDone =>
      timeline.isNotEmpty &&
      timeline.every(
        (t) => t.state == 'approved' || t.state == 'done' || t.state == 'past',
      );

  TimelineItem? get nextItem {
    final id = nextAction?['id'];
    if (id == null) return null;
    for (final t in timeline) {
      if (t.id == id) return t;
    }
    return null;
  }

  factory MyDay.fromJson(Map<String, dynamic> j) {
    final summary = _map(j['summary']);
    return MyDay(
      date: j['date'] as String? ?? '',
      now: j['now'] as String? ?? '',
      greeting: j['greeting'] as String? ?? 'morning',
      timeline: _list(
        j['timeline'],
      ).map(TimelineItem.fromJson).toList(growable: false),
      nextAction: j['next_action'] is Map ? _map(j['next_action']) : null,
      pointsBalance: _int(_map(j['points'])['balance']),
      tasksTotal: _int(summary['tasks_total']),
      tasksDone: _int(summary['tasks_done']),
      tasksWaiting: _int(summary['tasks_waiting']),
      routinesTotal: _int(summary['routines_total']),
      routinesDone: _int(summary['routines_done']),
      rewardGoal: j['reward_goal'] is Map
          ? RewardGoal.fromJson(_map(j['reward_goal']))
          : null,
      checkedInToday: j['checked_in_today'] as bool? ?? false,
      newEncouragements: _list(
        j['new_encouragements'],
      ).map(Encouragement.fromJson).toList(growable: false),
      goals: _list(j['goals']),
    );
  }
}

class KidReward {
  const KidReward({
    required this.id,
    required this.title,
    required this.type,
    required this.pointsCost,
    required this.affordable,
    required this.pointsNeeded,
    required this.progress,
    required this.hasPendingRequest,
    required this.isSavingFor,
    this.description,
    this.minutes,
  });

  final String id;
  final String title;
  final String? description;
  final String type;
  final int pointsCost;
  final bool affordable;
  final int pointsNeeded;
  final double progress;
  final bool hasPendingRequest;
  final bool isSavingFor;
  final int? minutes;

  factory KidReward.fromJson(Map<String, dynamic> j) => KidReward(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    description: j['description'] as String?,
    type: j['type'] as String? ?? 'privilege',
    pointsCost: _int(j['points_cost']),
    affordable: j['affordable'] as bool? ?? false,
    pointsNeeded: _int(j['points_needed']),
    progress: _double(j['progress']) ?? 0,
    hasPendingRequest: j['has_pending_request'] as bool? ?? false,
    isSavingFor: j['is_saving_for'] as bool? ?? false,
    minutes: (_map(j['metadata'])['minutes'] as num?)?.toInt(),
  );
}

class KidRewardsCatalog {
  const KidRewardsCatalog({
    required this.balance,
    required this.rewards,
    this.savingForRewardId,
  });

  final int balance;
  final String? savingForRewardId;
  final List<KidReward> rewards;

  factory KidRewardsCatalog.fromJson(Map<String, dynamic> j) =>
      KidRewardsCatalog(
        balance: _int(j['balance']),
        savingForRewardId: j['saving_for_reward_id'] as String?,
        rewards: _list(
          j['rewards'],
        ).map(KidReward.fromJson).toList(growable: false),
      );
}

class RewardWish {
  const RewardWish({
    required this.id,
    required this.title,
    required this.status,
    this.note,
    this.decisionNote,
    this.rewardId,
    this.childId,
    this.createdAt,
  });

  final String id;
  final String title;

  /// pending | approved | declined | withdrawn
  final String status;
  final String? note;
  final String? decisionNote;
  final String? rewardId;
  final String? childId;
  final DateTime? createdAt;

  factory RewardWish.fromJson(Map<String, dynamic> j) => RewardWish(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    status: j['status'] as String? ?? 'pending',
    note: j['note'] as String?,
    decisionNote: j['decision_note'] as String?,
    rewardId: j['reward_id'] as String?,
    childId: j['child_id'] as String?,
    createdAt: _date(j['created_at']),
  );
}

class MoodCheckin {
  const MoodCheckin({
    required this.id,
    required this.mood,
    required this.childId,
    this.note,
    this.reply,
    this.replySticker,
    this.repliedByName,
    this.repliedAt,
    this.createdAt,
  });

  final String id;
  final String childId;

  /// great | happy | okay | tired | sad | worried | angry
  final String mood;
  final String? note;
  final String? reply;
  final String? replySticker;
  final String? repliedByName;
  final DateTime? repliedAt;
  final DateTime? createdAt;

  bool get hasReply => repliedAt != null;

  factory MoodCheckin.fromJson(Map<String, dynamic> j) => MoodCheckin(
    id: j['id'] as String,
    childId: j['child_id'] as String? ?? '',
    mood: j['mood'] as String? ?? 'okay',
    note: j['note'] as String?,
    reply: j['reply'] as String?,
    replySticker: j['reply_sticker'] as String?,
    repliedByName: j['replied_by_name'] as String?,
    repliedAt: _date(j['replied_at']),
    createdAt: _date(j['created_at']),
  );
}

class ChallengeParticipant {
  const ChallengeParticipant({
    required this.id,
    required this.name,
    this.avatarKey,
    this.avatarColor,
  });

  final String id;
  final String name;
  final String? avatarKey;
  final String? avatarColor;

  factory ChallengeParticipant.fromJson(Map<String, dynamic> j) =>
      ChallengeParticipant(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        avatarKey: j['avatar_key'] as String?,
        avatarColor: j['avatar_color'] as String?,
      );
}

class FamilyChallenge {
  const FamilyChallenge({
    required this.id,
    required this.title,
    required this.metric,
    required this.targetValue,
    required this.progressValue,
    required this.progress,
    required this.status,
    required this.startsOn,
    required this.endsOn,
    required this.rewardPoints,
    required this.participants,
    this.description,
    this.iconKey,
    this.unitLabel,
    this.myContribution,
    this.contributionsByChild = const {},
  });

  final String id;
  final String title;
  final String? description;
  final String? iconKey;

  /// tasks | routines | manual
  final String metric;
  final int targetValue;
  final int progressValue;
  final double progress;
  final String? unitLabel;

  /// active | achieved | rewarded | ended | cancelled
  final String status;
  final String startsOn;
  final String endsOn;
  final int rewardPoints;
  final List<ChallengeParticipant> participants;
  final int? myContribution;
  final Map<String, int> contributionsByChild;

  bool get isManual => metric == 'manual';
  bool get isActive => status == 'active';

  factory FamilyChallenge.fromJson(Map<String, dynamic> j) => FamilyChallenge(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    description: j['description'] as String?,
    iconKey: j['icon_key'] as String?,
    metric: j['metric'] as String? ?? 'manual',
    targetValue: _int(j['target_value']),
    progressValue: _int(j['progress_value']),
    progress: _double(j['progress']) ?? 0,
    unitLabel: j['unit_label'] as String?,
    status: j['status'] as String? ?? 'active',
    startsOn: j['starts_on'] as String? ?? '',
    endsOn: j['ends_on'] as String? ?? '',
    rewardPoints: _int(j['reward_points']),
    participants: _list(
      j['participants'],
    ).map(ChallengeParticipant.fromJson).toList(growable: false),
    myContribution: (j['my_contribution'] as num?)?.toInt(),
    contributionsByChild: _map(
      j['contributions_by_child'],
    ).map((k, v) => MapEntry(k, _int(v))),
  );
}

class ScreenTimeRequest {
  const ScreenTimeRequest({
    required this.id,
    required this.minutes,
    required this.status,
    this.reason,
    this.grantedMinutes,
    this.decisionNote,
    this.childId,
    this.createdAt,
  });

  final String id;
  final int minutes;
  final String status;
  final String? reason;
  final int? grantedMinutes;
  final String? decisionNote;
  final String? childId;
  final DateTime? createdAt;

  factory ScreenTimeRequest.fromJson(Map<String, dynamic> j) =>
      ScreenTimeRequest(
        id: j['id'] as String,
        minutes: _int(j['minutes']),
        status: j['status'] as String? ?? 'pending',
        reason: j['reason'] as String?,
        grantedMinutes: (j['granted_minutes'] as num?)?.toInt(),
        decisionNote: j['decision_note'] as String?,
        childId: j['child_id'] as String?,
        createdAt: _date(j['created_at']),
      );
}

class KidScreenTime {
  const KidScreenTime({
    required this.usageSource,
    required this.enforcement,
    required this.requests,
    this.limitMinutes,
    this.bonusMinutes,
    this.usedMinutes,
    this.remainingMinutes,
    this.restrictionKind,
    this.restrictionName,
    this.restrictionUntil,
  });

  final int? limitMinutes;

  /// What is limiting the child right now (restrict_now | schedule), its
  /// name and when it ends — for calm copy like "paused until 17:00".
  final String? restrictionKind;
  final String? restrictionName;
  final DateTime? restrictionUntil;

  /// Whether this phone confirmed it enforces the current rules.
  bool get enforcedOnDevice => enforcement == 'enforced_on_device';
  final int? bonusMinutes;
  final int? usedMinutes;
  final int? remainingMinutes;

  /// measured | not_reported
  final String usageSource;
  final String enforcement;
  final List<ScreenTimeRequest> requests;

  ScreenTimeRequest? get pending {
    for (final r in requests) {
      if (r.status == 'pending') return r;
    }
    return null;
  }

  factory KidScreenTime.fromJson(Map<String, dynamic> j) => KidScreenTime(
    limitMinutes: (j['limit_minutes'] as num?)?.toInt(),
    bonusMinutes: (j['bonus_minutes'] as num?)?.toInt(),
    usedMinutes: (j['used_minutes'] as num?)?.toInt(),
    remainingMinutes: (j['remaining_minutes'] as num?)?.toInt(),
    usageSource: j['usage_source'] as String? ?? 'not_reported',
    enforcement: j['enforcement'] as String? ?? 'not_enforced_by_app',
    restrictionKind: (j['current_restriction'] as Map?)?['kind'] as String?,
    restrictionName: (j['current_restriction'] as Map?)?['name'] as String?,
    restrictionUntil: DateTime.tryParse(
      ((j['current_restriction'] as Map?)?['until'] as String?) ?? '',
    )?.toLocal(),
    requests: _list(
      j['requests'],
    ).map(ScreenTimeRequest.fromJson).toList(growable: false),
  );
}

class KidRequest {
  const KidRequest({
    required this.kind,
    required this.id,
    required this.title,
    required this.status,
    required this.explanation,
    this.note,
    this.points,
    this.minutes,
    this.updatedAt,
  });

  /// task | reward | wish | screen_time | routine
  final String kind;
  final String id;
  final String title;
  final String status;
  final String explanation;
  final String? note;
  final int? points;
  final int? minutes;
  final DateTime? updatedAt;

  factory KidRequest.fromJson(Map<String, dynamic> j) => KidRequest(
    kind: j['kind'] as String? ?? 'task',
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    status: j['status'] as String? ?? 'pending',
    explanation: j['explanation'] as String? ?? '',
    note: j['note'] as String?,
    points: (j['points'] as num?)?.toInt(),
    minutes: (j['minutes'] as num?)?.toInt(),
    updatedAt: _date(j['updated_at']),
  );
}

class KidRequests {
  const KidRequests({required this.pending, required this.decided});

  final List<KidRequest> pending;
  final List<KidRequest> decided;

  factory KidRequests.fromJson(Map<String, dynamic> j) => KidRequests(
    pending: _list(
      j['pending'],
    ).map(KidRequest.fromJson).toList(growable: false),
    decided: _list(
      j['decided'],
    ).map(KidRequest.fromJson).toList(growable: false),
  );
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.amount,
    required this.type,
    this.reference,
    this.createdAt,
  });

  final String id;
  final int amount;
  final String type;
  final String? reference;
  final DateTime? createdAt;

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
    id: j['id'] as String,
    amount: _int(j['amount']),
    type: j['type'] as String? ?? '',
    reference: j['reference'] as String?,
    createdAt: _date(j['created_at']),
  );
}

class KidPoints {
  const KidPoints({required this.balance, required this.entries});

  final int balance;
  final List<LedgerEntry> entries;
}
