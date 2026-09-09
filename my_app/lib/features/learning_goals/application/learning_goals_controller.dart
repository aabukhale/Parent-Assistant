import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/learning_goal_requests.dart';
import '../data/learning_goals_repository.dart';
import '../data/models/learning_goal.dart';
import 'learning_goal_detail_controller.dart';

@immutable
class LearningGoalsListState {
  const LearningGoalsListState({
    required this.goals,
    required this.meta,
    this.loadingMore = false,
    this.statusFilter = 'active',
  });

  final List<LearningGoal> goals;
  final PageMeta meta;
  final bool loadingMore;
  final String statusFilter;

  bool get isEmpty => goals.isEmpty;
  bool get hasMore => meta.hasMore;

  LearningGoalsListState copyWith({
    List<LearningGoal>? goals,
    PageMeta? meta,
    bool? loadingMore,
    String? statusFilter,
  }) => LearningGoalsListState(
    goals: goals ?? this.goals,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
    statusFilter: statusFilter ?? this.statusFilter,
  );
}

/// Learning goals for the active family + selected child.
///
/// `build()` watches [childScopeProvider], so a family **or** selected-child
/// change tears the list down and reloads (no stale goals across children).
class LearningGoalsController extends AsyncNotifier<LearningGoalsListState> {
  static const _perPage = 20;

  ChildScope get _scope => ref.read(childScopeProvider);

  @override
  Future<LearningGoalsListState> build() async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return LearningGoalsListState(goals: const [], meta: PageMeta.single(0));
    }
    return _load(scope.familyId!, scope.childId!, status: 'active');
  }

  Future<LearningGoalsListState> _load(
    String familyId,
    String childId, {
    required String status,
  }) async {
    final page = await ref
        .read(learningGoalsRepositoryProvider)
        .list(
          familyId: familyId,
          childId: childId,
          page: 1,
          perPage: _perPage,
          status: status,
        );
    return LearningGoalsListState(
      goals: page.items,
      meta: page.meta,
      statusFilter: status,
    );
  }

  ({String familyId, String childId})? _requireScope() {
    final scope = _scope;
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  Future<void> refresh() async {
    final scope = _requireScope();
    if (scope == null) return;
    final status = state.valueOrNull?.statusFilter ?? 'active';
    state = await AsyncValue.guard(
      () => _load(scope.familyId, scope.childId, status: status),
    );
  }

  Future<void> setStatusFilter(String status) async {
    final scope = _requireScope();
    if (scope == null || status == state.valueOrNull?.statusFilter) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _load(scope.familyId, scope.childId, status: status),
    );
  }

  Future<void> loadMore() async {
    final scope = _requireScope();
    final current = state.valueOrNull;
    if (scope == null ||
        current == null ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(learningGoalsRepositoryProvider)
          .list(
            familyId: scope.familyId,
            childId: scope.childId,
            page: current.meta.nextPage,
            perPage: _perPage,
            status: current.statusFilter,
          );
      state = AsyncData(
        current.copyWith(
          goals: [...current.goals, ...next.items],
          meta: next.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  Future<LearningGoal> createGoal(LearningGoalCreateInput input) async {
    final scope = _requireScope();
    if (scope == null) throw StateError('No active family / selected child');
    final goal = await ref
        .read(learningGoalsRepositoryProvider)
        .create(scope.familyId, scope.childId, input);
    await refresh();
    bumpDashboardRefresh(ref);
    return goal;
  }

  Future<LearningGoal> updateGoal(
    String goalId,
    LearningGoalUpdateInput input,
  ) async {
    final scope = _requireScope();
    if (scope == null) throw StateError('No active family / selected child');
    final goal = await ref
        .read(learningGoalsRepositoryProvider)
        .update(scope.familyId, scope.childId, goalId, input);
    ref.invalidate(learningGoalDetailProvider(goalId));
    await refresh();
    bumpDashboardRefresh(ref);
    return goal;
  }

  Future<LearningGoal> archiveGoal(String goalId) async {
    final scope = _requireScope();
    if (scope == null) throw StateError('No active family / selected child');
    final goal = await ref
        .read(learningGoalsRepositoryProvider)
        .archive(scope.familyId, scope.childId, goalId);
    ref.invalidate(learningGoalDetailProvider(goalId));
    await refresh();
    bumpDashboardRefresh(ref);
    return goal;
  }

  /// Called by the progress controller after a progress entry is recorded, so a
  /// goal that just auto-achieved reflects its new status in the list.
  Future<void> reconcileAfterProgress() async {
    await refresh();
    bumpDashboardRefresh(ref);
  }
}

final learningGoalsControllerProvider =
    AsyncNotifierProvider<LearningGoalsController, LearningGoalsListState>(
      LearningGoalsController.new,
    );
