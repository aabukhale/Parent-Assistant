import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/models/child_task.dart';
import '../data/task_requests.dart';
import '../data/tasks_repository.dart';
import 'task_detail_controller.dart';

@immutable
class TasksListState {
  const TasksListState({
    required this.tasks,
    required this.meta,
    this.loadingMore = false,
    this.statusFilter = 'active',
  });

  final List<ChildTask> tasks;
  final PageMeta meta;
  final bool loadingMore;
  final String statusFilter;

  bool get isEmpty => tasks.isEmpty;
  bool get hasMore => meta.hasMore;

  TasksListState copyWith({
    List<ChildTask>? tasks,
    PageMeta? meta,
    bool? loadingMore,
    String? statusFilter,
  }) => TasksListState(
    tasks: tasks ?? this.tasks,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
    statusFilter: statusFilter ?? this.statusFilter,
  );
}

/// Paginated task list for the active family + selected child.
///
/// `build()` watches [childScopeProvider], so a family **or** selected-child
/// change tears the list down and reloads — no stale tasks across children.
class TasksController extends AsyncNotifier<TasksListState> {
  static const _perPage = 20;

  ({String familyId, String childId})? _scope() {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  @override
  Future<TasksListState> build() async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return TasksListState(tasks: const [], meta: PageMeta.single(0));
    }
    return _load(scope.familyId!, scope.childId!, status: 'active');
  }

  Future<TasksListState> _load(
    String familyId,
    String childId, {
    required String status,
  }) async {
    final page = await ref
        .read(tasksRepositoryProvider)
        .listTasks(
          familyId: familyId,
          childId: childId,
          page: 1,
          perPage: _perPage,
          status: status,
        );
    return TasksListState(
      tasks: page.items,
      meta: page.meta,
      statusFilter: status,
    );
  }

  Future<void> refresh() async {
    final scope = _scope();
    if (scope == null) return;
    final status = state.valueOrNull?.statusFilter ?? 'active';
    state = await AsyncValue.guard(
      () => _load(scope.familyId, scope.childId, status: status),
    );
  }

  Future<void> setStatusFilter(String status) async {
    final scope = _scope();
    if (scope == null || status == state.valueOrNull?.statusFilter) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _load(scope.familyId, scope.childId, status: status),
    );
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
      final next = await ref
          .read(tasksRepositoryProvider)
          .listTasks(
            familyId: scope.familyId,
            childId: scope.childId,
            page: current.meta.nextPage,
            perPage: _perPage,
            status: current.statusFilter,
          );
      state = AsyncData(
        current.copyWith(
          tasks: [...current.tasks, ...next.items],
          meta: next.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  Future<ChildTask> createTask(TaskCreateInput input) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final task = await ref
        .read(tasksRepositoryProvider)
        .createTask(scope.familyId, scope.childId, input);
    await refresh();
    bumpDashboardRefresh(ref);
    return task;
  }

  Future<ChildTask> updateTask(String taskId, TaskUpdateInput input) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final task = await ref
        .read(tasksRepositoryProvider)
        .updateTask(scope.familyId, scope.childId, taskId, input);
    ref.invalidate(taskDetailProvider(taskId));
    await refresh();
    bumpDashboardRefresh(ref);
    return task;
  }

  Future<ChildTask> archiveTask(String taskId) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final task = await ref
        .read(tasksRepositoryProvider)
        .archiveTask(scope.familyId, scope.childId, taskId);
    ref.invalidate(taskDetailProvider(taskId));
    await refresh();
    bumpDashboardRefresh(ref);
    return task;
  }

  /// Called by the completions controller so the list stays consistent after a
  /// completion action (currently a no-op beyond a refresh, kept for symmetry).
  Future<void> reconcile() => refresh();
}

final tasksControllerProvider =
    AsyncNotifierProvider<TasksController, TasksListState>(TasksController.new);
