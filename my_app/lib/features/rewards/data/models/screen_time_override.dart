import 'package:flutter/foundation.dart';

import 'reward_enums.dart';

/// The extra-screen-time grant an approved `screen_time` redemption creates
/// (`ScreenTimeOverrideResource`, embedded in the redemption's
/// `screen_time_override`).
///
/// This is **backend policy data only** — approving a reward changes what the
/// API reports, not any native device restriction.
@immutable
class ScreenTimeOverride {
  const ScreenTimeOverride({
    required this.id,
    required this.childId,
    required this.additionalMinutes,
    this.startsAt,
    this.expiresAt,
    required this.source,
    this.reason,
    this.rewardRedemptionId,
    required this.isActive,
    this.revokedAt,
    this.revokedBy,
    this.createdAt,
  });

  final String id;
  final String childId;
  final int additionalMinutes;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final ScreenTimeOverrideSource source;
  final String? reason;
  final String? rewardRedemptionId;

  /// Backend-computed at response time.
  final bool isActive;
  final DateTime? revokedAt;
  final String? revokedBy;
  final DateTime? createdAt;

  bool get isRevoked => revokedAt != null;

  factory ScreenTimeOverride.fromJson(Map<String, dynamic> json) =>
      ScreenTimeOverride(
        id: '${json['id']}',
        childId: '${json['child_id']}',
        additionalMinutes: (json['additional_minutes'] as num?)?.toInt() ?? 0,
        startsAt: DateTime.tryParse('${json['starts_at']}'),
        expiresAt: DateTime.tryParse('${json['expires_at']}'),
        source: ScreenTimeOverrideSource.fromWire(json['source'] as String?),
        reason: json['reason'] as String?,
        rewardRedemptionId: json['reward_redemption_id'] as String?,
        isActive: json['is_active'] as bool? ?? false,
        revokedAt: DateTime.tryParse('${json['revoked_at']}'),
        revokedBy: json['revoked_by'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}'),
      );
}
