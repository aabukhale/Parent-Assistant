import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/models/sleep_log.dart';
import '../data/sleep_repository.dart';
import '../data/sleep_requests.dart';
import 'sleep_log_detail_controller.dart';
import 'sleep_summary_controller.dart';

@immutable
class SleepLogsListState {
  const SleepLogsListState({
    required this.logs,
    required this.meta,
    this.loadingMore = false,
  });

  final List<SleepLog> logs;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => logs.isEmpty;
  bool get hasMore => meta.hasMore;

  SleepLogsListState copyWith({
    List<SleepLog>? logs,
    PageMeta? meta,
    bool? loadingMore,
  }) => SleepLogsListState(
    logs: logs ?? this.logs,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Paginated sleep-log list for the active family + selected child.
///
/// `build()` watches [childScopeProvider], so a family **or** selected-child
/// change tears the list down and reloads — no stale logs across children.
class SleepLogsController extends AsyncNotifier<SleepLogsListState> {
  static const _perPage = 20;

  ({String familyId, String childId})? _scope() {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  @override
  Future<SleepLogsListState> build() async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return SleepLogsListState(logs: const [], meta: PageMeta.single(0));
    }
    return _load(scope.familyId!, scope.childId!);
  }

  Future<SleepLogsListState> _load(String familyId, String childId) async {
    final page = await ref
        .read(sleepRepositoryProvider)
        .list(familyId: familyId, childId: childId, page: 1, perPage: _perPage);
    return SleepLogsListState(logs: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final scope = _scope();
    if (scope == null) return;
    state = await AsyncValue.guard(() => _load(scope.familyId, scope.childId));
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
          .read(sleepRepositoryProvider)
          .list(
            familyId: scope.familyId,
            childId: scope.childId,
            page: current.meta.nextPage,
            perPage: _perPage,
          );
      state = AsyncData(
        current.copyWith(
          logs: [...current.logs, ...next.items],
          meta: next.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  void _reconcile(String? logId) {
    if (logId != null) ref.invalidate(sleepLogDetailProvider(logId));
    ref.invalidate(sleepSummaryProvider);
    bumpDashboardRefresh(ref);
  }

  Future<SleepLog> createLog(SleepLogInput input) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final log = await ref
        .read(sleepRepositoryProvider)
        .create(scope.familyId, scope.childId, input);
    await refresh();
    _reconcile(null);
    return log;
  }

  Future<SleepLog> updateLog(String logId, SleepLogInput input) async {
    final scope = _scope();
    if (scope == null) throw StateError('No active family / selected child');
    final log = await ref
        .read(sleepRepositoryProvider)
        .update(scope.familyId, scope.childId, logId, input);
    await refresh();
    _reconcile(logId);
    return log;
  }

  Future<void> deleteLog(String logId) async {
    final scope = _scope();
    if (scope == null) return;
    await ref
        .read(sleepRepositoryProvider)
        .delete(scope.familyId, scope.childId, logId);
    await refresh();
    _reconcile(logId);
  }
}

final sleepLogsControllerProvider =
    AsyncNotifierProvider<SleepLogsController, SleepLogsListState>(
      SleepLogsController.new,
    );
