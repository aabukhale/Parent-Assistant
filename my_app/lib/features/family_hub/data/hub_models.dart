// Parent-side models for the family overview endpoints (pulse, inbox,
// recap, planner, pairing, meals, notification preferences).

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? v) => v is List
    ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
    : const [];
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

class PulseChild {
  const PulseChild({
    required this.childId,
    required this.name,
    required this.tasksTotal,
    required this.tasksDone,
    required this.tasksPending,
    required this.tasksTodo,
    required this.pendingApprovals,
    required this.pointsBalance,
    required this.deviceState,
    required this.pairedDevices,
    required this.screenTime,
    this.avatarKey,
    this.avatarColor,
    this.lastCheckin,
    this.routine,
    this.lastContactAt,
  });

  final String childId;
  final String name;
  final String? avatarKey;
  final String? avatarColor;
  final int tasksTotal;
  final int tasksDone;
  final int tasksPending;
  final int tasksTodo;
  final int pendingApprovals;
  final int pointsBalance;
  final Map<String, dynamic>? lastCheckin;
  final Map<String, dynamic>? routine;

  /// fresh | stale | offline | unknown
  final String deviceState;
  final int pairedDevices;
  final DateTime? lastContactAt;

  /// {state: measured|not_reported|hidden, limit_minutes, used_minutes, last_report_at, enforcement}
  final Map<String, dynamic> screenTime;

  factory PulseChild.fromJson(Map<String, dynamic> j) {
    final child = _map(j['child']);
    final tasks = _map(j['tasks_today']);
    final device = _map(j['device']);
    return PulseChild(
      childId: child['id'] as String,
      name: child['name'] as String? ?? '',
      avatarKey: child['avatar_key'] as String?,
      avatarColor: child['avatar_color'] as String?,
      tasksTotal: _int(tasks['total']),
      tasksDone: _int(tasks['approved']),
      tasksPending: _int(tasks['pending']),
      tasksTodo: _int(tasks['todo']) + _int(tasks['rejected']),
      pendingApprovals: _int(j['pending_approvals']),
      pointsBalance: _int(j['points_balance']),
      lastCheckin: j['last_checkin'] is Map ? _map(j['last_checkin']) : null,
      routine: j['routine'] is Map ? _map(j['routine']) : null,
      deviceState: device['state'] as String? ?? 'unknown',
      pairedDevices: _int(device['paired_devices']),
      lastContactAt: _date(device['last_contact_at']),
      screenTime: _map(j['screen_time']),
    );
  }
}

class FamilyPulse {
  const FamilyPulse({
    required this.generatedAt,
    required this.localDate,
    required this.pendingTotal,
    required this.children,
    required this.timezone,
  });

  final DateTime? generatedAt;
  final String localDate;
  final String timezone;
  final int pendingTotal;
  final List<PulseChild> children;

  factory FamilyPulse.fromJson(Map<String, dynamic> j) => FamilyPulse(
    generatedAt: _date(j['generated_at']),
    localDate: j['local_date'] as String? ?? '',
    timezone: j['timezone'] as String? ?? 'UTC',
    pendingTotal: _int(j['pending_total']),
    children: _list(
      j['children'],
    ).map(PulseChild.fromJson).toList(growable: false),
  );
}

class InboxItem {
  const InboxItem({
    required this.kind,
    required this.id,
    required this.childId,
    required this.title,
    required this.detail,
    required this.canAct,
    this.childName,
    this.createdAt,
  });

  /// task_completion | activity_completion | reward_redemption | reward_wish |
  /// screen_time_request | routine_run | checkin
  final String kind;
  final String id;
  final String childId;
  final String? childName;
  final String title;
  final Map<String, dynamic> detail;
  final bool canAct;
  final DateTime? createdAt;

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
    kind: j['kind'] as String? ?? '',
    id: j['id'] as String,
    childId: j['child_id'] as String? ?? '',
    childName: j['child_name'] as String?,
    title: j['title'] as String? ?? '',
    detail: _map(j['detail']),
    canAct: j['can_act'] as bool? ?? false,
    createdAt: _date(j['created_at']),
  );
}

class FamilyInbox {
  const FamilyInbox({required this.items, required this.actionable});

  final List<InboxItem> items;
  final int actionable;

  factory FamilyInbox.fromJson(Map<String, dynamic> j) => FamilyInbox(
    items: _list(j['items']).map(InboxItem.fromJson).toList(growable: false),
    actionable: _int(j['actionable']),
  );
}

class PlannerItem {
  const PlannerItem({
    required this.type,
    required this.id,
    required this.sourceId,
    required this.title,
    required this.date,
    required this.allDay,
    required this.childIds,
    this.time,
    this.description,
    this.location,
  });

  /// event | task_deadline | routine
  final String type;
  final String id;
  final String sourceId;
  final String title;
  final String date;
  final String? time;
  final bool allDay;
  final String? description;
  final String? location;
  final List<String> childIds;

  factory PlannerItem.fromJson(Map<String, dynamic> j) => PlannerItem(
    type: j['type'] as String? ?? 'event',
    id: j['id'] as String,
    sourceId: j['source_id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    date: j['date'] as String? ?? '',
    time: j['time'] as String?,
    allDay: j['all_day'] as bool? ?? false,
    description: j['description'] as String?,
    location: j['location'] as String?,
    childIds: ((j['child_ids'] as List?) ?? const [])
        .whereType<String>()
        .toList(growable: false),
  );
}

class WeeklyRecap {
  const WeeklyRecap({
    required this.weekStart,
    required this.weekEnd,
    required this.hasData,
    required this.familyTotals,
    required this.children,
    required this.highlights,
    required this.challengesCompleted,
  });

  final String weekStart;
  final String weekEnd;
  final bool hasData;
  final Map<String, int> familyTotals;
  final List<Map<String, dynamic>> children;
  final List<String> highlights;
  final List<Map<String, dynamic>> challengesCompleted;

  factory WeeklyRecap.fromJson(Map<String, dynamic> j) => WeeklyRecap(
    weekStart: j['week_start'] as String? ?? '',
    weekEnd: j['week_end'] as String? ?? '',
    hasData: j['has_data'] as bool? ?? false,
    familyTotals: _map(j['family_totals']).map((k, v) => MapEntry(k, _int(v))),
    children: _list(j['children']),
    highlights: ((j['highlights'] as List?) ?? const [])
        .whereType<String>()
        .toList(growable: false),
    challengesCompleted: _list(j['challenges_completed']),
  );
}

class PairingCode {
  const PairingCode({
    required this.id,
    required this.state,
    required this.deviceMode,
    required this.expiresAt,
    this.code,
    this.qrPayload,
    this.usedAt,
  });

  final String id;

  /// Only present right after creation; never re-fetched.
  final String? code;
  final String? qrPayload;

  /// active | used | revoked | expired
  final String state;
  final String deviceMode;
  final DateTime? expiresAt;
  final DateTime? usedAt;

  factory PairingCode.fromJson(Map<String, dynamic> j) => PairingCode(
    id: j['id'] as String,
    code: j['code'] as String?,
    qrPayload: j['qr_payload'] as String?,
    state: j['state'] as String? ?? 'active',
    deviceMode: j['device_mode'] as String? ?? 'child_dedicated',
    expiresAt: _date(j['expires_at']),
    usedAt: _date(j['used_at']),
  );
}

class ChildDevice {
  const ChildDevice({
    required this.id,
    required this.name,
    required this.isActive,
    required this.hasChildSession,
    required this.hasPushToken,
    this.platform,
    this.deviceMode,
    this.lastSeenAt,
    this.pairedAt,
  });

  final String id;
  final String name;
  final String? platform;
  final String? deviceMode;
  final bool isActive;
  final bool hasChildSession;
  final bool hasPushToken;
  final DateTime? lastSeenAt;
  final DateTime? pairedAt;

  factory ChildDevice.fromJson(Map<String, dynamic> j) => ChildDevice(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    platform: j['platform'] as String?,
    deviceMode: j['device_mode'] as String?,
    isActive: j['is_active'] as bool? ?? false,
    hasChildSession: j['has_child_session'] as bool? ?? false,
    hasPushToken: j['has_push_token'] as bool? ?? false,
    lastSeenAt: _date(j['last_seen_at']),
    pairedAt: _date(j['paired_at']),
  );
}

class MealLog {
  const MealLog({
    required this.id,
    required this.eatenAt,
    required this.mealType,
    this.description,
    this.appetite,
    this.note,
  });

  final String id;
  final DateTime eatenAt;

  /// breakfast | lunch | dinner | snack
  final String mealType;
  final String? description;

  /// all | most | some | little | none
  final String? appetite;
  final String? note;

  factory MealLog.fromJson(Map<String, dynamic> j) => MealLog(
    id: j['id'] as String,
    eatenAt: _date(j['eaten_at']) ?? DateTime.now(),
    mealType: j['meal_type'] as String? ?? 'snack',
    description: j['description'] as String?,
    appetite: j['appetite'] as String?,
    note: j['note'] as String?,
  );
}

class NotificationPrefs {
  const NotificationPrefs({
    required this.categories,
    required this.showDetailsOnLockScreen,
    required this.surfaceOptions,
    this.quietStart,
    this.quietEnd,
    this.childQuietStart,
    this.childQuietEnd,
    this.timezone,
  });

  /// category → {push_enabled: bool, muted_child_ids: [..]}
  final Map<String, Map<String, dynamic>> categories;
  final String? quietStart;
  final String? quietEnd;
  final bool showDetailsOnLockScreen;
  final Map<String, bool> surfaceOptions;
  final String? childQuietStart;
  final String? childQuietEnd;
  final String? timezone;

  bool pushEnabled(String category) =>
      categories[category]?['push_enabled'] as bool? ?? true;

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) =>
      NotificationPrefs(
        categories: {
          for (final c in _list(j['categories'])) c['category'] as String: c,
        },
        quietStart: j['quiet_hours_start'] as String?,
        quietEnd: j['quiet_hours_end'] as String?,
        showDetailsOnLockScreen:
            j['show_details_on_lock_screen'] as bool? ?? false,
        surfaceOptions: _map(
          j['surface_options'],
        ).map((k, v) => MapEntry(k, v == true)),
        childQuietStart: j['child_quiet_hours_start'] as String?,
        childQuietEnd: j['child_quiet_hours_end'] as String?,
        timezone: j['timezone'] as String?,
      );
}
