// Device rules as the parent edits them, plus the honest per-device state
// reported back by each install (stored ≠ received ≠ applied ≠ observed).

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
    : const [];

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

class AppRef {
  const AppRef({required this.platform, required this.id, required this.name});

  /// android | ios
  final String platform;

  /// Android package name, or the opaque iOS Family Controls token data.
  final String id;
  final String name;

  String get key => '$platform:$id';

  factory AppRef.fromJson(Map<String, dynamic> j) => AppRef(
    platform: j['platform'] as String? ?? 'android',
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'id': id,
    'name': name,
  };

  @override
  bool operator ==(Object other) => other is AppRef && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class AppLimit {
  const AppLimit({required this.minutes, this.app, this.category});

  final AppRef? app;

  /// games | social | video | browsers | messaging | education | other
  final String? category;
  final int minutes;

  factory AppLimit.fromJson(Map<String, dynamic> j) => AppLimit(
    app: j['app'] is Map
        ? AppRef.fromJson((j['app'] as Map).cast<String, dynamic>())
        : null,
    category: j['category'] as String?,
    minutes: (j['minutes'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    if (app != null) 'app': app!.toJson(),
    'category': ?category,
    'minutes': minutes,
  };
}

class RuleSchedule {
  const RuleSchedule({
    required this.id,
    required this.preset,
    required this.name,
    required this.days,
    required this.start,
    required this.end,
    required this.restriction,
    required this.enabled,
  });

  final String id;

  /// school | homework | bedtime | custom
  final String preset;
  final String name;

  /// ISO weekdays, 1 = Monday … 7 = Sunday.
  final List<int> days;

  /// "HH:mm", family-local wall-clock time.
  final String start;
  final String end;

  /// allow_only | block_listed
  final String restriction;
  final bool enabled;

  bool get crossesMidnight => end.compareTo(start) <= 0;

  RuleSchedule copyWith({
    String? name,
    List<int>? days,
    String? start,
    String? end,
    String? restriction,
    bool? enabled,
  }) => RuleSchedule(
    id: id,
    preset: preset,
    name: name ?? this.name,
    days: days ?? this.days,
    start: start ?? this.start,
    end: end ?? this.end,
    restriction: restriction ?? this.restriction,
    enabled: enabled ?? this.enabled,
  );

  factory RuleSchedule.fromJson(Map<String, dynamic> j) => RuleSchedule(
    id: j['id'] as String,
    preset: j['preset'] as String? ?? 'custom',
    name: j['name'] as String? ?? '',
    days: ((j['days'] as List?) ?? const [])
        .map((d) => (d as num).toInt())
        .toList(),
    start: j['start'] as String? ?? '00:00',
    end: j['end'] as String? ?? '00:00',
    restriction: j['restriction'] as String? ?? 'allow_only',
    enabled: j['enabled'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'preset': preset,
    'name': name,
    'days': days,
    'start': start,
    'end': end,
    'restriction': restriction,
    'enabled': enabled,
  };
}

class WebRules {
  const WebRules({
    this.mode = 'off',
    this.blocked = const [],
    this.allowed = const [],
  });

  /// off | block_listed | approved_only
  final String mode;
  final List<String> blocked;
  final List<String> allowed;

  factory WebRules.fromJson(Map<String, dynamic>? j) => WebRules(
    mode: j?['mode'] as String? ?? 'off',
    blocked: (j?['blocked_domains'] as List?)?.cast<String>() ?? const [],
    allowed: (j?['allowed_domains'] as List?)?.cast<String>() ?? const [],
  );

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'blocked_domains': blocked,
    'allowed_domains': allowed,
  };
}

class DeviceRules {
  const DeviceRules({
    this.blockedApps = const [],
    this.allowedApps = const [],
    this.appLimits = const [],
    this.schedules = const [],
    this.web = const WebRules(),
    this.restrictNow,
  });

  final List<AppRef> blockedApps;
  final List<AppRef> allowedApps;
  final List<AppLimit> appLimits;
  final List<RuleSchedule> schedules;
  final WebRules web;
  final ({DateTime startedAt, DateTime? until})? restrictNow;

  DeviceRules copyWith({
    List<AppRef>? blockedApps,
    List<AppRef>? allowedApps,
    List<AppLimit>? appLimits,
    List<RuleSchedule>? schedules,
    WebRules? web,
  }) => DeviceRules(
    blockedApps: blockedApps ?? this.blockedApps,
    allowedApps: allowedApps ?? this.allowedApps,
    appLimits: appLimits ?? this.appLimits,
    schedules: schedules ?? this.schedules,
    web: web ?? this.web,
    restrictNow: restrictNow,
  );

  factory DeviceRules.fromJson(Map<String, dynamic> j) {
    final r = j['restrict_now'] as Map?;
    return DeviceRules(
      blockedApps: _list(j['blocked_apps']).map(AppRef.fromJson).toList(),
      allowedApps: _list(j['allowed_apps']).map(AppRef.fromJson).toList(),
      appLimits: _list(j['app_limits']).map(AppLimit.fromJson).toList(),
      schedules: _list(j['schedules']).map(RuleSchedule.fromJson).toList(),
      web: WebRules.fromJson((j['web'] as Map?)?.cast<String, dynamic>()),
      restrictNow: r == null
          ? null
          : (
              startedAt: _date(r['started_at']) ?? DateTime.now(),
              until: _date(r['until']),
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'blocked_apps': [for (final a in blockedApps) a.toJson()],
    'allowed_apps': [for (final a in allowedApps) a.toJson()],
    'app_limits': [for (final l in appLimits) l.toJson()],
    'schedules': [for (final s in schedules) s.toJson()],
    'web': web.toJson(),
  };
}

/// Per-install state the parent sees. Never "active" from a 200 alone.
class DeviceRuleDeviceState {
  const DeviceRuleDeviceState({
    required this.deviceId,
    required this.deviceName,
    required this.state,
    required this.capabilities,
    this.platform,
    this.deviceMode,
    this.lastContactAt,
    this.receivedVersion,
    this.appliedVersion,
    this.appliedAt,
    this.observedAt,
    this.results = const [],
  });

  final String deviceId;
  final String deviceName;
  final String? platform;
  final String? deviceMode;
  final DateTime? lastContactAt;

  /// active | partially_active | waiting_for_device | device_offline |
  /// permission_needed | unsupported | not_confirmed | no_rules
  final String state;
  final int? receivedVersion;
  final int? appliedVersion;
  final DateTime? appliedAt;
  final DateTime? observedAt;

  /// capability → available | permission_needed | setup_needed | unsupported
  final Map<String, String> capabilities;
  final List<({String rule, String state})> results;

  String capability(String key) => capabilities[key] ?? 'unknown';

  factory DeviceRuleDeviceState.fromJson(Map<String, dynamic> j) =>
      DeviceRuleDeviceState(
        deviceId: j['device_id'] as String,
        deviceName: j['device_name'] as String? ?? '',
        platform: j['platform'] as String?,
        deviceMode: j['device_mode'] as String?,
        lastContactAt: _date(j['last_contact_at']),
        state: j['state'] as String? ?? 'not_confirmed',
        receivedVersion: (j['received_version'] as num?)?.toInt(),
        appliedVersion: (j['applied_version'] as num?)?.toInt(),
        appliedAt: _date(j['applied_at']),
        observedAt: _date(j['observed_at']),
        capabilities: j['capabilities'] is Map
            ? (j['capabilities'] as Map).map(
                (k, v) => MapEntry(k as String, v as String),
              )
            : const {},
        results: _list(j['results'])
            .map(
              (r) => (
                rule: r['rule'] as String? ?? '',
                state: r['state'] as String? ?? '',
              ),
            )
            .toList(),
      );
}

class CurrentRestriction {
  const CurrentRestriction({
    required this.kind,
    this.name,
    this.until,
    this.preset,
  });

  /// restrict_now | schedule
  final String kind;
  final String? name;
  final DateTime? until;
  final String? preset;

  static CurrentRestriction? fromJson(Object? v) {
    if (v is! Map) return null;
    return CurrentRestriction(
      kind: v['kind'] as String? ?? 'schedule',
      name: v['name'] as String?,
      until: _date(v['until']),
      preset: v['preset'] as String?,
    );
  }
}

class DeviceRulesState {
  const DeviceRulesState({
    required this.childId,
    required this.version,
    required this.rules,
    required this.summary,
    required this.devices,
    required this.hasRules,
    required this.weekendDays,
    required this.timezone,
    this.current,
    this.restrictState,
  });

  final String childId;
  final int version;
  final DeviceRules rules;

  /// Worst device state, or no_rules / no_device.
  final String summary;
  final List<DeviceRuleDeviceState> devices;
  final bool hasRules;
  final List<int> weekendDays;
  final String timezone;
  final CurrentRestriction? current;

  /// on | expired | null
  final String? restrictState;

  factory DeviceRulesState.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DeviceRulesState(
      childId: j['child_id'] as String? ?? '',
      version: (j['version'] as num?)?.toInt() ?? 0,
      rules: DeviceRules.fromJson(
        (j['rules'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      summary: status['summary'] as String? ?? 'no_rules',
      devices: _list(
        status['devices'],
      ).map(DeviceRuleDeviceState.fromJson).toList(),
      hasRules: status['has_rules'] as bool? ?? false,
      current: CurrentRestriction.fromJson(status['current']),
      restrictState: (status['restrict_now'] as Map?)?['state'] as String?,
      weekendDays: ((j['weekend_days'] as List?) ?? const [6, 7])
          .map((d) => (d as num).toInt())
          .toList(),
      timezone: j['timezone'] as String? ?? 'UTC',
    );
  }
}

class RuleVersion {
  const RuleVersion({
    required this.version,
    required this.changeKind,
    required this.canUndoTo,
    this.summary,
    this.changedBy,
    this.createdAt,
  });

  final int version;
  final String changeKind;
  final String? summary;
  final String? changedBy;
  final DateTime? createdAt;
  final bool canUndoTo;

  factory RuleVersion.fromJson(Map<String, dynamic> j) => RuleVersion(
    version: (j['version'] as num).toInt(),
    changeKind: j['change_kind'] as String? ?? 'edit',
    summary: j['summary'] as String?,
    changedBy: j['changed_by'] as String?,
    createdAt: _date(j['created_at']),
    canUndoTo: j['can_undo_to'] as bool? ?? false,
  );
}

class RulePreview {
  const RulePreview({required this.changes, required this.deviceLimits});

  final List<Map<String, dynamic>> changes;

  /// device name → capabilities it can't enforce (capability, state).
  final List<
    ({String deviceName, List<({String capability, String state})> limits})
  >
  deviceLimits;

  factory RulePreview.fromJson(Map<String, dynamic> j) => RulePreview(
    changes: _list(j['changes']),
    deviceLimits: _list(j['devices'])
        .map(
          (d) => (
            deviceName: d['device_name'] as String? ?? '',
            limits: _list(d['limitations'])
                .map(
                  (l) => (
                    capability: l['capability'] as String? ?? '',
                    state: l['state'] as String? ?? 'unknown',
                  ),
                )
                .toList(),
          ),
        )
        .toList(),
  );
}
