import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../tasks/data/task_requests.dart';
import 'models/reward.dart';
import 'models/reward_redemption.dart';
import 'reward_requests.dart';

/// HTTP for the reward catalog (`/families/{family}/rewards`) and child
/// redemptions (`/families/{family}/children/{child}/reward-redemptions`).
///
/// Read = any active member. `manage_rewards` for family-reward CRUD;
/// `approve_redemptions` for approve / reject / **cancel**. Global templates are
/// read-only (edit/delete → 404). Inactive reward → 422; duplicate pending →
/// 409; insufficient balance on approval → **422**.
class RewardsRepository {
  RewardsRepository(this._client);

  final ApiClient _client;

  // --- Catalog (family-scoped) ---

  Future<Paginated<Reward>> listRewards({
    required String familyId,
    int page = 1,
    int perPage = 25,
    bool includeInactive = false,
  }) async {
    final envelope = await _client.get(
      '/families/$familyId/rewards',
      query: {
        'page': page,
        'per_page': perPage,
        if (includeInactive) 'include_inactive': true,
      },
    );
    return Paginated.from<Reward>(envelope, Reward.fromJson);
  }

  Future<Reward> createReward(String familyId, RewardCreateInput input) async {
    final envelope = await _client.post(
      '/families/$familyId/rewards',
      body: input.toJson(),
    );
    return Reward.fromJson(envelope.dataMap);
  }

  Future<Reward> updateReward(
    String familyId,
    String rewardId,
    RewardUpdateInput input,
  ) async {
    final envelope = await _client.patch(
      '/families/$familyId/rewards/$rewardId',
      body: input.toJson(),
    );
    return Reward.fromJson(envelope.dataMap);
  }

  Future<void> deleteReward(String familyId, String rewardId) async {
    await _client.delete('/families/$familyId/rewards/$rewardId');
  }

  // --- Redemptions (child-scoped) ---

  String _redemptionBase(String familyId, String childId) =>
      '/families/$familyId/children/$childId/reward-redemptions';

  Future<Paginated<RewardRedemption>> listRedemptions({
    required String familyId,
    required String childId,
    int page = 1,
    int perPage = 25,
  }) async {
    final envelope = await _client.get(
      _redemptionBase(familyId, childId),
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.from<RewardRedemption>(
      envelope,
      RewardRedemption.fromJson,
    );
  }

  Future<RewardRedemption> requestRedemption(
    String familyId,
    String childId,
    RedemptionRequestInput input,
  ) async {
    final envelope = await _client.post(
      _redemptionBase(familyId, childId),
      body: input.toJson(),
    );
    return RewardRedemption.fromJson(envelope.dataMap);
  }

  Future<RewardRedemption> _review(
    String familyId,
    String childId,
    String redemptionId,
    String action,
    ReviewInput input,
  ) async {
    final envelope = await _client.post(
      '${_redemptionBase(familyId, childId)}/$redemptionId/$action',
      body: input.toJson(),
    );
    return RewardRedemption.fromJson(envelope.dataMap);
  }

  Future<RewardRedemption> approveRedemption(
    String familyId,
    String childId,
    String redemptionId,
    ReviewInput input,
  ) => _review(familyId, childId, redemptionId, 'approve', input);

  Future<RewardRedemption> rejectRedemption(
    String familyId,
    String childId,
    String redemptionId,
    ReviewInput input,
  ) => _review(familyId, childId, redemptionId, 'reject', input);

  Future<RewardRedemption> cancelRedemption(
    String familyId,
    String childId,
    String redemptionId,
    ReviewInput input,
  ) => _review(familyId, childId, redemptionId, 'cancel', input);
}

final rewardsRepositoryProvider = Provider<RewardsRepository>(
  (ref) => RewardsRepository(ref.watch(apiClientProvider)),
);
