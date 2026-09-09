import 'package:flutter/foundation.dart';

/// One screen-time rule row (`ScreenTimeRuleResource`). `scope == 'default'`
/// applies every day (`dayOfWeek == null`); `weekday_override` targets an ISO
/// weekday (1=Mon … 7=Sun). `dailyLimitMinutes == 0` means "no screen time
/// allowed"; there is no "unlimited" — a disabled rule (`isEnabled == false`)
/// is what removes the limit.
@immutable
class ScreenTimeRule {
  const ScreenTimeRule({
    required this.id,
    required this.childId,
    required this.scope,
    required this.dayOfWeek,
    required this.dailyLimitMinutes,
    required this.sessionLimitMinutes,
    required this.allowedStartTime,
    required this.allowedEndTime,
    required this.isEnabled,
  });

  final String id;
  final String childId;
  final String scope;
  final int? dayOfWeek;
  final int dailyLimitMinutes;
  final int? sessionLimitMinutes;

  /// `HH:mm` strings as returned by the API, or null.
  final String? allowedStartTime;
  final String? allowedEndTime;
  final bool isEnabled;

  bool get isDefault => scope == 'default' || dayOfWeek == null;

  factory ScreenTimeRule.fromJson(Map<String, dynamic> json) => ScreenTimeRule(
    id: '${json['id']}',
    childId: '${json['child_id']}',
    scope: json['scope'] as String? ?? 'default',
    dayOfWeek: (json['day_of_week'] as num?)?.round(),
    dailyLimitMinutes: (json['daily_limit_minutes'] as num?)?.round() ?? 0,
    sessionLimitMinutes: (json['session_limit_minutes'] as num?)?.round(),
    allowedStartTime: json['allowed_start_time'] as String?,
    allowedEndTime: json['allowed_end_time'] as String?,
    isEnabled: json['is_enabled'] as bool? ?? false,
  );
}

@immutable
class ScreenTimeAppUsage {
  const ScreenTimeAppUsage({
    required this.appIdentifier,
    required this.appName,
    required this.category,
    required this.usedMinutes,
  });

  final String? appIdentifier;
  final String? appName;
  final String? category;
  final int usedMinutes;

  factory ScreenTimeAppUsage.fromJson(Map<String, dynamic> json) =>
      ScreenTimeAppUsage(
        appIdentifier: json['app_identifier'] as String?,
        appName: json['app_name'] as String?,
        category: json['category'] as String?,
        usedMinutes: (json['used_minutes'] as num?)?.round() ?? 0,
      );
}

/// `GET …/screen-time/summary` (`ScreenTimePolicyService::dailySummary`),
/// computed server-side in the family timezone. `effectiveLimitMinutes` /
/// `remainingMinutes` / `baseLimitMinutes` are **null when no rule is
/// configured** — that is "no limit set", not zero.
@immutable
class ScreenTimeSummary {
  const ScreenTimeSummary({
    required this.date,
    required this.timezone,
    required this.usedMinutes,
    required this.baseLimitMinutes,
    required this.bonusMinutes,
    required this.effectiveLimitMinutes,
    required this.remainingMinutes,
    required this.ruleSource,
    required this.hasSufficientData,
    required this.perApp,
  });

  final String date;
  final String timezone;
  final int usedMinutes;
  final int? baseLimitMinutes;
  final int bonusMinutes;
  final int? effectiveLimitMinutes;
  final int? remainingMinutes;

  /// `none` | `default` | `weekday_override`.
  final String ruleSource;
  final bool hasSufficientData;
  final List<ScreenTimeAppUsage> perApp;

  bool get hasLimit => effectiveLimitMinutes != null;

  factory ScreenTimeSummary.fromJson(Map<String, dynamic> json) {
    final rawApps = (json['per_app'] as List?) ?? const [];
    return ScreenTimeSummary(
      date: '${json['date']}',
      timezone: json['timezone'] as String? ?? 'UTC',
      usedMinutes: (json['used_minutes'] as num?)?.round() ?? 0,
      baseLimitMinutes: (json['base_limit_minutes'] as num?)?.round(),
      bonusMinutes: (json['bonus_minutes'] as num?)?.round() ?? 0,
      effectiveLimitMinutes: (json['effective_limit_minutes'] as num?)?.round(),
      remainingMinutes: (json['remaining_minutes'] as num?)?.round(),
      ruleSource: json['rule_source'] as String? ?? 'none',
      hasSufficientData: json['has_sufficient_data'] as bool? ?? false,
      perApp: rawApps
          .whereType<Map>()
          .map((m) => ScreenTimeAppUsage.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

/// A manual/reward screen-time override (`ScreenTimeOverrideResource`). Same
/// shape the reward-redemption response embeds. `source` is `manual` or
/// `reward_redemption`.
@immutable
class ScreenTimeOverride {
  const ScreenTimeOverride({
    required this.id,
    required this.childId,
    required this.additionalMinutes,
    required this.startsAt,
    required this.expiresAt,
    required this.source,
    required this.reason,
    required this.rewardRedemptionId,
    required this.isActive,
    required this.revokedAt,
  });

  final String id;
  final String childId;
  final int additionalMinutes;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final String source;
  final String? reason;
  final String? rewardRedemptionId;
  final bool isActive;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
  bool get isFromReward => source == 'reward_redemption';

  factory ScreenTimeOverride.fromJson(Map<String, dynamic> json) =>
      ScreenTimeOverride(
        id: '${json['id']}',
        childId: '${json['child_id']}',
        additionalMinutes: (json['additional_minutes'] as num?)?.round() ?? 0,
        startsAt: DateTime.tryParse('${json['starts_at']}')?.toLocal(),
        expiresAt: DateTime.tryParse('${json['expires_at']}')?.toLocal(),
        source: json['source'] as String? ?? 'manual',
        reason: json['reason'] as String?,
        rewardRedemptionId: json['reward_redemption_id'] as String?,
        isActive: json['is_active'] as bool? ?? false,
        revokedAt: DateTime.tryParse('${json['revoked_at']}')?.toLocal(),
      );
}

/// `GET …/screen-time/policy` (`ScreenTimePolicyService::lockPolicy`). This is
/// a **policy evaluation**, not enforcement. `shouldLock` says what native code
/// *should* do; the app cannot lock anything itself.
@immutable
class ScreenTimePolicy {
  const ScreenTimePolicy({
    required this.childId,
    required this.shouldLock,
    required this.lockReason,
    required this.enforcementScope,
    required this.remainingMinutes,
    required this.effectiveLimitMinutes,
    required this.note,
  });

  final String childId;
  final bool shouldLock;
  final String? lockReason;
  final String enforcementScope;
  final int? remainingMinutes;
  final int? effectiveLimitMinutes;
  final String? note;

  factory ScreenTimePolicy.fromJson(
    Map<String, dynamic> json,
  ) => ScreenTimePolicy(
    childId: '${json['child_id']}',
    shouldLock: json['should_lock'] as bool? ?? false,
    lockReason: json['lock_reason'] as String?,
    enforcementScope: json['enforcement_scope'] as String? ?? 'child_mode_only',
    remainingMinutes: (json['remaining_minutes'] as num?)?.round(),
    effectiveLimitMinutes: (json['effective_limit_minutes'] as num?)?.round(),
    note: json['note'] as String?,
  );
}
