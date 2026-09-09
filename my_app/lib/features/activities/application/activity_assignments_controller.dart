import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../children/application/selected_child_controller.dart';
import '../../tasks/application/points_controller.dart';
import '../../tasks/data/task_requests.dart';
import '../data/activities_repository.dart';
import '../data/activity_requests.dart';
import '../data/models/activity_assignment.dart';
import '../data/models/activity_completion.dart';

@immutable
class ActivityAssignmentsState {
  const ActivityAssignmentsState({
    required this.assignments,
    required this.meta,
    this.loadingMore = false,
  });

  final List<ActivityAssignment> assignments;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => assignments.isEmpty;
  bool get hasMore => meta.hasMore;

  ActivityAssignmentsState copyWith({
    List<ActivityAssignment>? assignments,
    PageMeta? meta,
    bool? loadingMore,
  }) => ActivityAssignmentsState(
    assignments: assignments ?? this.assignments,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// A child's activity assignments + their completion workflow. Child-scoped
/// through [childScopeProvider]; null scope → empty, no request. A family/child
/// switch tears the list down and reloads.
class ActivityAssignmentsController
    extends AsyncNotifier<ActivityAssignmentsState> {
  static const _perPage = 15;

  ({String familyId, String childId})? _scope() {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  @override
  Future<ActivityAssignmentsState> build() async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return ActivityAssignmentsState(
        assignments: const [],
        meta: PageMeta.single(0),
      );
    }
    final page = await ref
        .read(activitiesRepositoryProvider)
        .listAssignments(
          familyId: scope.familyId!,
          childId: scope.childId!,
          perPage: _perPage,
        );
    return ActivityAssignmentsState(assignments: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final scope = _scope();
    if (scope == null) return;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(activitiesRepositoryProvider)
          .listAssignments(
            familyId: scope.familyId,
            childId: scope.childId,
            perPage: _perPage,
          );
      return ActivityAssignmentsState(assignments: page.items, meta: page.meta);
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
          .read(activitiesRepositoryProvider)
          .listAssignments(
            familyId: scope.familyId,
            childId: scope.childId,
            page: current.meta.nextPage,
            perPage: _perPage,
          );
      state = AsyncData(
        current.copyWith(
          assignments: [...current.assignments, ...page.items],
          meta: page.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  Future<ActivityAssignment> assign(ActivityAssignInput input) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final assignment = await ref
        .read(activitiesRepositoryProvider)
        .createAssignment(scope.familyId, scope.childId, input);
    await refresh();
    bumpDashboardRefresh(ref);
    return assignment;
  }

  /// Parent-managed / on-behalf-of-child completion.
  Future<ActivityCompletion> complete(
    String assignmentId,
    ReviewInput input,
  ) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final completion = await ref
        .read(activitiesRepositoryProvider)
        .complete(scope.familyId, scope.childId, assignmentId, input);
    await refresh();
    // An auto-approved (0-point) completion already moved points server-side.
    _refreshLedger();
    return completion;
  }

  Future<ActivityCompletion> approve(
    String assignmentId,
    String completionId,
    ReviewInput input,
  ) => _act(assignmentId, completionId, 'approve', input, ledger: true);

  Future<ActivityCompletion> reject(
    String assignmentId,
    String completionId,
    ReviewInput input,
  ) => _act(assignmentId, completionId, 'reject', input, ledger: false);

  Future<ActivityCompletion> reverse(
    String assignmentId,
    String completionId,
    ReviewInput input,
  ) => _act(assignmentId, completionId, 'reverse', input, ledger: true);

  Future<ActivityCompletion> _act(
    String assignmentId,
    String completionId,
    String action,
    ReviewInput input, {
    required bool ledger,
  }) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final repo = ref.read(activitiesRepositoryProvider);
    final result = switch (action) {
      'approve' => await repo.approve(
        scope.familyId,
        scope.childId,
        assignmentId,
        completionId,
        input,
      ),
      'reject' => await repo.reject(
        scope.familyId,
        scope.childId,
        assignmentId,
        completionId,
        input,
      ),
      _ => await repo.reverse(
        scope.familyId,
        scope.childId,
        assignmentId,
        completionId,
        input,
      ),
    };
    await refresh();
    if (ledger) _refreshLedger();
    return result;
  }

  void _refreshLedger() {
    ref.invalidate(pointsBalanceProvider);
    ref.invalidate(pointsTxControllerProvider);
    bumpDashboardRefresh(ref);
  }
}

final activityAssignmentsControllerProvider =
    AsyncNotifierProvider<
      ActivityAssignmentsController,
      ActivityAssignmentsState
    >(ActivityAssignmentsController.new);
