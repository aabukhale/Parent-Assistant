import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/learning_goal_requests.dart';
import '../data/learning_goals_repository.dart';
import '../data/models/learning_goal.dart';
import 'learning_goal_detail_controller.dart';
import 'learning_goals_controller.dart';

@immutable
class GoalProgressState {
  const GoalProgressState({
    required this.entries,
    required this.meta,
    this.loadingMore = false,
  });

  final List<LearningGoalProgressEntry> entries;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => entries.isEmpty;
  bool get hasMore => meta.hasMore;

  GoalProgressState copyWith({
    List<LearningGoalProgressEntry>? entries,
    PageMeta? meta,
    bool? loadingMore,
  }) => GoalProgressState(
    entries: entries ?? this.entries,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Paginated progress history for one goal (`GET …/{goal}/progress`), keyed by
/// goal id and scoped to the active family + selected child.
class GoalProgressController
    extends AutoDisposeFamilyAsyncNotifier<GoalProgressState, String> {
  static const _perPage = 25;

  ({String familyId, String childId})? _scope() {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  @override
  Future<GoalProgressState> build(String goalId) async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return GoalProgressState(entries: const [], meta: PageMeta.single(0));
    }
    final page = await ref
        .read(learningGoalsRepositoryProvider)
        .progressHistory(
          familyId: scope.familyId!,
          childId: scope.childId!,
          goalId: goalId,
          perPage: _perPage,
        );
    return GoalProgressState(entries: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final scope = _scope();
    if (scope == null) return;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(learningGoalsRepositoryProvider)
          .progressHistory(
            familyId: scope.familyId,
            childId: scope.childId,
            goalId: arg,
            perPage: _perPage,
          );
      return GoalProgressState(entries: page.items, meta: page.meta);
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
          .read(learningGoalsRepositoryProvider)
          .progressHistory(
            familyId: scope.familyId,
            childId: scope.childId,
            goalId: arg,
            page: current.meta.nextPage,
            perPage: _perPage,
          );
      state = AsyncData(
        current.copyWith(
          entries: [...current.entries, ...page.items],
          meta: page.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// Record a progress entry. The backend response carries the (possibly
  /// auto-achieved) goal, so we refresh the detail and the goals list too.
  Future<RecordedProgress> record(LearningGoalProgressInput input) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final result = await ref
        .read(learningGoalsRepositoryProvider)
        .recordProgress(scope.familyId, scope.childId, arg, input);
    await refresh();
    ref.invalidate(learningGoalDetailProvider(arg));
    await ref
        .read(learningGoalsControllerProvider.notifier)
        .reconcileAfterProgress();
    return result;
  }
}

final goalProgressControllerProvider = AsyncNotifierProvider.autoDispose
    .family<GoalProgressController, GoalProgressState, String>(
      GoalProgressController.new,
    );
