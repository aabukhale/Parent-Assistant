import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/models/point_transaction.dart';
import '../data/tasks_repository.dart';

/// `GET …/points-balance` — the **single source of truth** for the balance.
/// Never computed or mutated locally; re-fetched after every approval /
/// reversal. Child-scoped.
final pointsBalanceProvider = FutureProvider.autoDispose<PointsBalance>((ref) {
  final scope = ref.watch(childScopeProvider);
  if (scope.familyId == null || scope.childId == null) {
    throw StateError('No active family / selected child');
  }
  return ref
      .watch(tasksRepositoryProvider)
      .pointsBalance(scope.familyId!, scope.childId!);
});

@immutable
class PointsTxState {
  const PointsTxState({
    required this.transactions,
    required this.meta,
    this.loadingMore = false,
  });

  final List<PointTransaction> transactions;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => transactions.isEmpty;
  bool get hasMore => meta.hasMore;

  PointsTxState copyWith({
    List<PointTransaction>? transactions,
    PageMeta? meta,
    bool? loadingMore,
  }) => PointsTxState(
    transactions: transactions ?? this.transactions,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Paginated `GET …/point-transactions` (immutable ledger, newest first).
/// Child-scoped; `build()` watches [childScopeProvider].
class PointsTxController extends AsyncNotifier<PointsTxState> {
  static const _perPage = 25;

  ({String familyId, String childId})? _scope() {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  @override
  Future<PointsTxState> build() async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return PointsTxState(transactions: const [], meta: PageMeta.single(0));
    }
    final page = await ref
        .read(tasksRepositoryProvider)
        .pointTransactions(
          familyId: scope.familyId!,
          childId: scope.childId!,
          perPage: _perPage,
        );
    return PointsTxState(transactions: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final scope = _scope();
    if (scope == null) return;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(tasksRepositoryProvider)
          .pointTransactions(
            familyId: scope.familyId,
            childId: scope.childId,
            perPage: _perPage,
          );
      return PointsTxState(transactions: page.items, meta: page.meta);
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
          .read(tasksRepositoryProvider)
          .pointTransactions(
            familyId: scope.familyId,
            childId: scope.childId,
            page: current.meta.nextPage,
            perPage: _perPage,
          );
      state = AsyncData(
        current.copyWith(
          transactions: [...current.transactions, ...page.items],
          meta: page.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }
}

final pointsTxControllerProvider =
    AsyncNotifierProvider<PointsTxController, PointsTxState>(
      PointsTxController.new,
    );
