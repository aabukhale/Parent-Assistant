import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../auth/application/auth_controller.dart';
import '../data/models/reward.dart';
import '../data/reward_requests.dart';
import '../data/rewards_repository.dart';

@immutable
class RewardsListState {
  const RewardsListState({
    required this.rewards,
    required this.meta,
    this.loadingMore = false,
    this.includeInactive = false,
  });

  final List<Reward> rewards;
  final PageMeta meta;
  final bool loadingMore;
  final bool includeInactive;

  bool get isEmpty => rewards.isEmpty;
  bool get hasMore => meta.hasMore;

  List<Reward> get global =>
      rewards.where((r) => r.isGlobal).toList(growable: false);
  List<Reward> get family =>
      rewards.where((r) => !r.isGlobal).toList(growable: false);

  RewardsListState copyWith({
    List<Reward>? rewards,
    PageMeta? meta,
    bool? loadingMore,
    bool? includeInactive,
  }) => RewardsListState(
    rewards: rewards ?? this.rewards,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
    includeInactive: includeInactive ?? this.includeInactive,
  );
}

/// The reward catalog for the **active family** (global templates + this
/// family's own rewards). Family-scoped, not child-scoped — `build()` watches
/// [activeFamilyIdProvider], so a family switch throws the catalog away and
/// reloads.
class RewardsController extends AsyncNotifier<RewardsListState> {
  static const _perPage = 25;

  String? get _familyId => ref.read(activeFamilyIdProvider);

  @override
  Future<RewardsListState> build() async {
    final familyId = ref.watch(activeFamilyIdProvider);
    if (familyId == null) {
      return RewardsListState(rewards: const [], meta: PageMeta.single(0));
    }
    return _load(familyId, includeInactive: false);
  }

  Future<RewardsListState> _load(
    String familyId, {
    required bool includeInactive,
  }) async {
    final page = await ref
        .read(rewardsRepositoryProvider)
        .listRewards(
          familyId: familyId,
          page: 1,
          perPage: _perPage,
          includeInactive: includeInactive,
        );
    return RewardsListState(
      rewards: page.items,
      meta: page.meta,
      includeInactive: includeInactive,
    );
  }

  Future<void> refresh() async {
    final familyId = _familyId;
    if (familyId == null) return;
    final inc = state.valueOrNull?.includeInactive ?? false;
    state = await AsyncValue.guard(() => _load(familyId, includeInactive: inc));
  }

  Future<void> setIncludeInactive(bool value) async {
    final familyId = _familyId;
    if (familyId == null || value == state.valueOrNull?.includeInactive) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _load(familyId, includeInactive: value),
    );
  }

  Future<void> loadMore() async {
    final familyId = _familyId;
    final current = state.valueOrNull;
    if (familyId == null ||
        current == null ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(rewardsRepositoryProvider)
          .listRewards(
            familyId: familyId,
            page: current.meta.nextPage,
            perPage: _perPage,
            includeInactive: current.includeInactive,
          );
      state = AsyncData(
        current.copyWith(
          rewards: [...current.rewards, ...next.items],
          meta: next.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  Future<Reward> createReward(RewardCreateInput input) async {
    final familyId = _familyId;
    if (familyId == null) throw StateError('No active family');
    final reward = await ref
        .read(rewardsRepositoryProvider)
        .createReward(familyId, input);
    await refresh();
    return reward;
  }

  Future<Reward> updateReward(String rewardId, RewardUpdateInput input) async {
    final familyId = _familyId;
    if (familyId == null) throw StateError('No active family');
    final reward = await ref
        .read(rewardsRepositoryProvider)
        .updateReward(familyId, rewardId, input);
    await refresh();
    return reward;
  }

  Future<void> deleteReward(String rewardId) async {
    final familyId = _familyId;
    if (familyId == null) return;
    await ref.read(rewardsRepositoryProvider).deleteReward(familyId, rewardId);
    await refresh();
  }
}

final rewardsControllerProvider =
    AsyncNotifierProvider<RewardsController, RewardsListState>(
      RewardsController.new,
    );
