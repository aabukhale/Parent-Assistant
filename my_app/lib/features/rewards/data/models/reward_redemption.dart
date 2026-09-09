import 'package:flutter/foundation.dart';

import 'reward_enums.dart';
import 'screen_time_override.dart';

/// A redemption request (`RewardRedemptionResource`).
///
/// Historical title / type / cost come from **snapshots** taken at request time
/// (`reward_title`, `reward_type`, `points_cost`) — the live reward may have
/// changed or been deleted since. `reward_type` is a raw snapshot string.
@immutable
class RewardRedemption {
  const RewardRedemption({
    required this.id,
    required this.rewardId,
    required this.childId,
    required this.status,
    required this.rewardTitle,
    required this.rewardType,
    required this.pointsCost,
    this.requestedBy,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    this.deductionTransactionId,
    this.refundTransactionId,
    this.screenTimeOverride,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String rewardId;
  final String childId;
  final RedemptionStatus status;

  /// Snapshot.
  final String rewardTitle;

  /// Snapshot (`screen_time` | `physical` | `family_activity` | `privilege`,
  /// but parsed leniently since it is a plain string column).
  final RewardType rewardType;

  /// Snapshot.
  final int pointsCost;

  final String? requestedBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;

  final String? deductionTransactionId;
  final String? refundTransactionId;

  /// Present (embedded) on the list, approve and cancel responses when the
  /// redemption is a screen-time reward. Never fetched separately.
  final ScreenTimeOverride? screenTimeOverride;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == RedemptionStatus.pending;
  bool get isApproved => status == RedemptionStatus.approved;
  bool get isRejected => status == RedemptionStatus.rejected;
  bool get isCancelled => status == RedemptionStatus.cancelled;

  bool get canApproveOrReject => isPending;
  bool get canCancel => isApproved;

  factory RewardRedemption.fromJson(Map<String, dynamic> json) {
    final rawOverride = json['screen_time_override'];
    return RewardRedemption(
      id: '${json['id']}',
      rewardId: '${json['reward_id']}',
      childId: '${json['child_id']}',
      status: RedemptionStatus.fromWire(json['status'] as String?),
      rewardTitle: json['reward_title'] as String? ?? '',
      rewardType: RewardType.fromWire(json['reward_type'] as String?),
      pointsCost: (json['points_cost'] as num?)?.toInt() ?? 0,
      requestedBy: json['requested_by'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: DateTime.tryParse('${json['reviewed_at']}'),
      reviewNote: json['review_note'] as String?,
      deductionTransactionId: json['deduction_transaction_id'] as String?,
      refundTransactionId: json['refund_transaction_id'] as String?,
      screenTimeOverride: rawOverride is Map<String, dynamic>
          ? ScreenTimeOverride.fromJson(rawOverride)
          : null,
      createdAt: DateTime.tryParse('${json['created_at']}'),
      updatedAt: DateTime.tryParse('${json['updated_at']}'),
    );
  }
}
