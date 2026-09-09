import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/child_requests.dart';
import '../data/children_repository.dart';
import '../data/models/child.dart';
import 'child_detail_controller.dart';

@immutable
class ChildrenListState {
  const ChildrenListState({
    required this.children,
    required this.meta,
    this.loadingMore = false,
    this.statusFilter = 'active',
  });

  final List<Child> children;
  final PageMeta meta;
  final bool loadingMore;
  final String statusFilter;

  bool get isEmpty => children.isEmpty;
  bool get hasMore => meta.hasMore;

  ChildrenListState copyWith({
    List<Child>? children,
    PageMeta? meta,
    bool? loadingMore,
    String? statusFilter,
  }) => ChildrenListState(
    children: children ?? this.children,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
    statusFilter: statusFilter ?? this.statusFilter,
  );
}

/// Family-scoped, paginated children list.
///
/// `build()` watches [activeFamilyIdProvider], so switching families throws the
/// whole list away and reloads — no stale rows from the previous family.
class ChildrenController extends AsyncNotifier<ChildrenListState> {
  static const _perPage = 20;

  String? get _familyId => ref.read(activeFamilyIdProvider);

  @override
  Future<ChildrenListState> build() async {
    final familyId = ref.watch(activeFamilyIdProvider);
    if (familyId == null) {
      return ChildrenListState(children: const [], meta: PageMeta.single(0));
    }
    return _load(familyId, status: 'active');
  }

  Future<ChildrenListState> _load(
    String familyId, {
    required String status,
  }) async {
    final page = await ref
        .read(childrenRepositoryProvider)
        .list(familyId: familyId, page: 1, perPage: _perPage, status: status);
    return ChildrenListState(
      children: page.items,
      meta: page.meta,
      statusFilter: status,
    );
  }

  Future<void> refresh() async {
    final familyId = _familyId;
    if (familyId == null) return;
    final status = state.valueOrNull?.statusFilter ?? 'active';
    state = await AsyncValue.guard(() => _load(familyId, status: status));
  }

  Future<void> setStatusFilter(String status) async {
    final familyId = _familyId;
    if (familyId == null || status == state.valueOrNull?.statusFilter) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(familyId, status: status));
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
          .read(childrenRepositoryProvider)
          .list(
            familyId: familyId,
            page: current.meta.nextPage,
            perPage: _perPage,
            status: current.statusFilter,
          );
      state = AsyncData(
        current.copyWith(
          children: [...current.children, ...next.items],
          meta: next.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      // Keep the rows already shown; let the caller surface the failure.
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// Create a child, refresh the list, and return the new record.
  Future<Child> createChild(ChildInput input) async {
    final familyId = _familyId;
    if (familyId == null) {
      throw StateError('No active family');
    }
    final child = await ref
        .read(childrenRepositoryProvider)
        .create(familyId, input);
    await refresh();
    bumpDashboardRefresh(ref);
    return child;
  }

  Future<Child> updateChild(String childId, ChildInput input) async {
    final familyId = _familyId;
    if (familyId == null) {
      throw StateError('No active family');
    }
    final child = await ref
        .read(childrenRepositoryProvider)
        .update(familyId, childId, input);
    ref.invalidate(childDetailProvider(childId));
    await refresh();
    bumpDashboardRefresh(ref);
    return child;
  }

  Future<void> deleteChild(String childId) async {
    final familyId = _familyId;
    if (familyId == null) return;
    await ref.read(childrenRepositoryProvider).delete(familyId, childId);
    ref.invalidate(childDetailProvider(childId));
    // The list refresh re-emits without this child; SelectedChildController's
    // listener then drops it from the selection (avoids a provider cycle).
    await refresh();
    bumpDashboardRefresh(ref);
  }
}

final childrenControllerProvider =
    AsyncNotifierProvider<ChildrenController, ChildrenListState>(
      ChildrenController.new,
    );
