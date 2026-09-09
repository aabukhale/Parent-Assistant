/// Backend `App\Enums\RewardType`.
enum RewardType {
  screenTime('screen_time'),
  physical('physical'),
  familyActivity('family_activity'),
  privilege('privilege');

  const RewardType(this.wire);
  final String wire;

  static RewardType fromWire(String? v) {
    for (final t in RewardType.values) {
      if (t.wire == v) return t;
    }
    return RewardType.privilege;
  }

  /// Only `screen_time` rewards carry a documented `metadata.minutes` value.
  bool get needsMinutes => this == RewardType.screenTime;
}

/// Backend `App\Enums\RedemptionStatus`.
enum RedemptionStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static RedemptionStatus fromWire(String? v) => switch (v) {
    'approved' => RedemptionStatus.approved,
    'rejected' => RedemptionStatus.rejected,
    'cancelled' => RedemptionStatus.cancelled,
    _ => RedemptionStatus.pending,
  };

  String get wire => name;

  bool get isTerminal => this != RedemptionStatus.pending;
}

/// Backend `App\Enums\ScreenTimeOverrideSource`.
enum ScreenTimeOverrideSource {
  manual,
  rewardRedemption;

  static ScreenTimeOverrideSource fromWire(String? v) =>
      v == 'reward_redemption'
      ? ScreenTimeOverrideSource.rewardRedemption
      : ScreenTimeOverrideSource.manual;
}
