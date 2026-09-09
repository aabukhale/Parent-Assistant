import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/models/screen_time_models.dart';
import '../data/screen_time_repository.dart';

({String familyId, String childId})? _scope(Ref ref) {
  final scope = ref.watch(childScopeProvider);
  if (scope.familyId == null || scope.childId == null) return null;
  return (familyId: scope.familyId!, childId: scope.childId!);
}

/// Today's screen-time summary (server-computed, family timezone). Child-scoped.
final screenTimeSummaryProvider = FutureProvider.autoDispose<ScreenTimeSummary>(
  (ref) {
    final scope = _scope(ref);
    if (scope == null) throw StateError('No active family / selected child');
    return ref
        .watch(screenTimeRepositoryProvider)
        .summary(scope.familyId, scope.childId);
  },
);

/// The child's screen-time rules (default + weekday overrides). Child-scoped.
final screenTimeRulesProvider =
    FutureProvider.autoDispose<List<ScreenTimeRule>>((ref) {
      final scope = _scope(ref);
      if (scope == null) throw StateError('No active family / selected child');
      return ref
          .watch(screenTimeRepositoryProvider)
          .rules(scope.familyId, scope.childId);
    });

@immutable
class OverridesState {
  const OverridesState({required this.overrides, required this.meta});
  final List<ScreenTimeOverride> overrides;
  final PageMeta meta;
  bool get isEmpty => overrides.isEmpty;
}

/// Manual + reward-created screen-time overrides. Child-scoped. A grant/revoke
/// refreshes the list, the summary, and the dashboard.
class OverridesController extends AsyncNotifier<OverridesState> {
  ({String familyId, String childId})? _s() {
    final scope = ref.read(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) return null;
    return (familyId: scope.familyId!, childId: scope.childId!);
  }

  @override
  Future<OverridesState> build() async {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      return OverridesState(overrides: const [], meta: PageMeta.single(0));
    }
    final page = await ref
        .read(screenTimeRepositoryProvider)
        .overrides(scope.familyId!, scope.childId!);
    return OverridesState(overrides: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final scope = _s();
    if (scope == null) return;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(screenTimeRepositoryProvider)
          .overrides(scope.familyId, scope.childId);
      return OverridesState(overrides: page.items, meta: page.meta);
    });
  }

  void _afterChange() {
    ref.invalidate(screenTimeSummaryProvider);
    bumpDashboardRefresh(ref);
  }

  Future<ScreenTimeOverride> grant(GrantExtraTimeInput input) async {
    final scope = _s();
    if (scope == null) throw StateError('No active family / selected child');
    final result = await ref
        .read(screenTimeRepositoryProvider)
        .grantExtraTime(scope.familyId, scope.childId, input);
    await refresh();
    _afterChange();
    return result;
  }

  Future<void> revoke(String overrideId) async {
    final scope = _s();
    if (scope == null) return;
    await ref
        .read(screenTimeRepositoryProvider)
        .revokeOverride(scope.familyId, scope.childId, overrideId);
    await refresh();
    _afterChange();
  }
}

final overridesControllerProvider =
    AsyncNotifierProvider<OverridesController, OverridesState>(
      OverridesController.new,
    );

/// Mutates the rule set. Not a notifier — the screen calls this and then
/// invalidates [screenTimeRulesProvider] + [screenTimeSummaryProvider].
Future<void> saveScreenTimeRules(
  WidgetRef ref,
  ScreenTimeRulesInput input,
) async {
  final scope = ref.read(childScopeProvider);
  if (scope.familyId == null || scope.childId == null) {
    throw StateError('No active family / selected child');
  }
  await ref
      .read(screenTimeRepositoryProvider)
      .updateRules(scope.familyId!, scope.childId!, input);
  ref.invalidate(screenTimeRulesProvider);
  ref.invalidate(screenTimeSummaryProvider);
  ref.read(dashboardRefreshSignalProvider.notifier).state++;
}
