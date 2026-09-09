import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/models/task_completion.dart';
import '../data/task_requests.dart';
import '../data/tasks_repository.dart';
import 'points_controller.dart';
import 'task_detail_controller.dart';

@immutable
class CompletionsState {
  const CompletionsState({
    required this.completions,
    required this.meta,
    this.loadingMore = false,
  });

  final List<TaskCompletion> completions;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => completions.isEmpty;
  bool get hasMore => meta.hasMore;

  CompletionsState copyWith({
    List<TaskCompletion>? completions,
    PageMeta? meta,
    bool? loadingMore,
  }) => CompletionsState(
    completions: completions ?? this.completions,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Paginated completion history for one task, keyed by task id and scoped to
/// the active family + selected child.
///
/// The request/approve/reject/reverse methods delegate entirely to the backend
/// (no local points math) and then refresh the authoritative state:
/// this history, the task detail, and — for approve/reverse — the points
/// balance and the transaction ledger.
class CompletionsController
    extends AutoDisposeFamilyAsyncNotifier<CompletionsState, String> {
  static const _perPage = 25;

  ({String familyId, String childId})? _scope() {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  @override
  Future<CompletionsState> build(String taskId) async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return CompletionsState(completions: const [], meta: PageMeta.single(0));
    }
    final page = await ref
        .read(tasksRepositoryProvider)
        .listCompletions(
          familyId: scope.familyId!,
          childId: scope.childId!,
          taskId: taskId,
          perPage: _perPage,
        );
    return CompletionsState(completions: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final scope = _scope();
    if (scope == null) return;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(tasksRepositoryProvider)
          .listCompletions(
            familyId: scope.familyId,
            childId: scope.childId,
            taskId: arg,
            perPage: _perPage,
          );
      return CompletionsState(completions: page.items, meta: page.meta);
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
          .listCompletions(
            familyId: scope.familyId,
            childId: scope.childId,
            taskId: arg,
            page: current.meta.nextPage,
            perPage: _perPage,
          );
      state = AsyncData(
        current.copyWith(
          completions: [...current.completions, ...page.items],
          meta: page.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  void _afterAny() {
    ref.invalidate(taskDetailProvider(arg));
    bumpDashboardRefresh(ref);
  }

  void _afterLedgerChange() {
    ref.invalidate(pointsBalanceProvider);
    ref.invalidate(pointsTxControllerProvider);
  }

  /// Parent-managed / on-behalf-of-child (no secure Child Mode session yet —
  /// see docs/child-mode-security.md).
  Future<TaskCompletion> requestCompletion(CompletionRequestInput input) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final completion = await ref
        .read(tasksRepositoryProvider)
        .requestCompletion(scope.familyId, scope.childId, arg, input);
    await refresh();
    _afterAny();
    return completion;
  }

  Future<TaskCompletion> approve(String completionId, ReviewInput input) async {
    final result = await _act(completionId, input, _Verb.approve);
    _afterLedgerChange();
    return result;
  }

  Future<TaskCompletion> reject(String completionId, ReviewInput input) =>
      _act(completionId, input, _Verb.reject);

  Future<TaskCompletion> reverse(String completionId, ReviewInput input) async {
    final result = await _act(completionId, input, _Verb.reverse);
    _afterLedgerChange();
    return result;
  }

  Future<TaskCompletion> _act(
    String completionId,
    ReviewInput input,
    _Verb verb,
  ) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final repo = ref.read(tasksRepositoryProvider);
    final completion = switch (verb) {
      _Verb.approve => await repo.approveCompletion(
        scope.familyId,
        scope.childId,
        arg,
        completionId,
        input,
      ),
      _Verb.reject => await repo.rejectCompletion(
        scope.familyId,
        scope.childId,
        arg,
        completionId,
        input,
      ),
      _Verb.reverse => await repo.reverseCompletion(
        scope.familyId,
        scope.childId,
        arg,
        completionId,
        input,
      ),
    };
    await refresh();
    _afterAny();
    return completion;
  }
}

enum _Verb { approve, reject, reverse }

final completionsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CompletionsController, CompletionsState, String>(
      CompletionsController.new,
    );
