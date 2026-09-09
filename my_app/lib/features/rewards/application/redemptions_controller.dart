import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../children/application/selected_child_controller.dart';
import '../../tasks/application/points_controller.dart';
import '../../tasks/data/task_requests.dart';
import '../data/models/reward_redemption.dart';
import '../data/reward_requests.dart';
import '../data/rewards_repository.dart';

@immutable
class RedemptionsListState {
  const RedemptionsListState({
    required this.redemptions,
    required this.meta,
    this.loadingMore = false,
  });

  final List<RewardRedemption> redemptions;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => redemptions.isEmpty;
  bool get hasMore => meta.hasMore;

  RedemptionsListState copyWith({
    List<RewardRedemption>? redemptions,
    PageMeta? meta,
    bool? loadingMore,
  }) => RedemptionsListState(
    redemptions: redemptions ?? this.redemptions,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Redemption history + review actions for the active family + selected child.
///
/// `build()` watches [childScopeProvider], so a family **or** selected-child
/// change tears the list down and reloads — no stale redemptions.
///
/// Points are **never** changed locally:
/// * request → no ledger effect.
/// * approve → the backend deducts; then the balance + ledger are re-fetched.
/// * reject → no ledger effect.
/// * cancel → the backend refunds and revokes any screen-time override; then
///   the balance + ledger are re-fetched. The override state comes from the
///   `screen_time_override` embedded in the approve/cancel response — never a
///   separate request.
class RedemptionsController extends AsyncNotifier<RedemptionsListState> {
  static const _perPage = 25;

  ({String familyId, String childId})? _scope() {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  @override
  Future<RedemptionsListState> build() async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return RedemptionsListState(
        redemptions: const [],
        meta: PageMeta.single(0),
      );
    }
    final page = await ref
        .read(rewardsRepositoryProvider)
        .listRedemptions(
          familyId: scope.familyId!,
          childId: scope.childId!,
          perPage: _perPage,
        );
    return RedemptionsListState(redemptions: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final scope = _scope();
    if (scope == null) return;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(rewardsRepositoryProvider)
          .listRedemptions(
            familyId: scope.familyId,
            childId: scope.childId,
            perPage: _perPage,
          );
      return RedemptionsListState(redemptions: page.items, meta: page.meta);
    });
  }

  Future<void> loadMore() async {
    final scope = _scope();
    final current = state.valueOrNull;
    if (scope == null ||
        current == null ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(rewardsRepositoryProvider)
          .listRedemptions(
            familyId: scope.familyId,
            childId: scope.childId,
            page: current.meta.nextPage,
            perPage: _perPage,
          );
      state = AsyncData(
        current.copyWith(
          redemptions: [...current.redemptions, ...page.items],
          meta: page.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  void _refreshLedger() {
    ref.invalidate(pointsBalanceProvider);
    ref.invalidate(pointsTxControllerProvider);
    bumpDashboardRefresh(ref);
  }

  /// Parent-managed / on-behalf-of-child (no secure Child Mode session yet).
  Future<RewardRedemption> requestRedemption(String rewardId) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final redemption = await ref
        .read(rewardsRepositoryProvider)
        .requestRedemption(
          scope.familyId,
          scope.childId,
          RedemptionRequestInput(rewardId: rewardId),
        );
    await refresh();
    return redemption;
  }

  Future<RewardRedemption> approve(
    String redemptionId,
    ReviewInput input,
  ) async {
    final result = await _act(redemptionId, 'approve', input);
    _refreshLedger();
    return result;
  }

  Future<RewardRedemption> reject(String redemptionId, ReviewInput input) =>
      _act(redemptionId, 'reject', input);

  Future<RewardRedemption> cancel(
    String redemptionId,
    ReviewInput input,
  ) async {
    final result = await _act(redemptionId, 'cancel', input);
    _refreshLedger();
    return result;
  }

  Future<RewardRedemption> _act(
    String redemptionId,
    String action,
    ReviewInput input,
  ) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final repo = ref.read(rewardsRepositoryProvider);
    final redemption = switch (action) {
      'approve' => await repo.approveRedemption(
        scope.familyId,
        scope.childId,
        redemptionId,
        input,
      ),
      'reject' => await repo.rejectRedemption(
        scope.familyId,
        scope.childId,
        redemptionId,
        input,
      ),
      _ => await repo.cancelRedemption(
        scope.familyId,
        scope.childId,
        redemptionId,
        input,
      ),
    };
    await refresh();
    return redemption;
  }
}

final redemptionsControllerProvider =
    AsyncNotifierProvider<RedemptionsController, RedemptionsListState>(
      RedemptionsController.new,
    );
