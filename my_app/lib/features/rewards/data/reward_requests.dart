import 'package:flutter/foundation.dart';

import 'models/reward.dart';
import 'models/reward_enums.dart';

/// `POST /families/{family}/rewards` (`StoreRewardRequest`).
@immutable
class RewardCreateInput {
  const RewardCreateInput({
    required this.title,
    this.description,
    required this.type,
    required this.pointsCost,
    this.screenTimeMinutes,
    this.isActive = true,
  });

  final String title;
  final String? description;
  final RewardType type;
  final int pointsCost;
  final int? screenTimeMinutes;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    if ((description ?? '').trim().isNotEmpty)
      'description': description!.trim(),
    'type': type.wire,
    'points_cost': pointsCost,
    if (type == RewardType.screenTime && screenTimeMinutes != null)
      'metadata': {'minutes': screenTimeMinutes},
    'is_active': isActive,
  };
}

/// `PATCH /families/{family}/rewards/{reward}` (`UpdateRewardRequest`).
/// `type` is **not** updatable on the backend.
@immutable
class RewardUpdateInput {
  const RewardUpdateInput({
    this.title,
    this.description,
    this.clearDescription = false,
    this.pointsCost,
    this.screenTimeMinutes,
    this.updateMinutes = false,
    this.isActive,
  });

  final String? title;
  final String? description;
  final bool clearDescription;
  final int? pointsCost;
  final int? screenTimeMinutes;

  /// Send the `metadata` block (only meaningful for screen-time rewards).
  final bool updateMinutes;
  final bool? isActive;

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title!.trim(),
    if (clearDescription)
      'description': null
    else if (description != null)
      'description': description!.trim(),
    if (pointsCost != null) 'points_cost': pointsCost,
    if (updateMinutes && screenTimeMinutes != null)
      'metadata': {'minutes': screenTimeMinutes},
    if (isActive != null) 'is_active': isActive,
  };

  bool get isEmpty => toJson().isEmpty;

  factory RewardUpdateInput.fromReward(
    Reward reward, {
    required String title,
    required String? description,
    required int pointsCost,
    required bool isActive,
    int? screenTimeMinutes,
  }) {
    final desc = (description ?? '').trim();
    return RewardUpdateInput(
      title: title,
      description: desc.isEmpty ? null : desc,
      clearDescription: desc.isEmpty,
      pointsCost: pointsCost,
      isActive: isActive,
      screenTimeMinutes: screenTimeMinutes,
      updateMinutes: reward.type == RewardType.screenTime,
    );
  }
}

/// `POST …/reward-redemptions` (`StoreRedemptionRequest`).
@immutable
class RedemptionRequestInput {
  const RedemptionRequestInput({required this.rewardId});
  final String rewardId;

  Map<String, dynamic> toJson() => {'reward_id': rewardId};
}
