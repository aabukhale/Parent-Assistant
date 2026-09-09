import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../children/application/selected_child_controller.dart';
import '../data/dashboard_repository.dart';
import '../data/models/child_summary.dart';
import '../data/models/development_report.dart';
import '../data/models/parent_dashboard.dart';

/// `GET /families/{family}/dashboard` for the active family.
///
/// Family-scoped: `build` watches [activeFamilyIdProvider], so switching family
/// tears the old data down and refetches — the previous family's numbers are
/// never shown. Also watches [dashboardRefreshSignalProvider] so a mutation
/// elsewhere (points, tasks, sleep, goals, children, redemptions) refreshes it.
/// `null` family → a [StateError] the UI renders as an error/retry state.
final parentDashboardProvider = FutureProvider.autoDispose<ParentDashboard>((
  ref,
) {
  ref.watch(dashboardRefreshSignalProvider);
  final familyId = ref.watch(activeFamilyIdProvider);
  if (familyId == null) {
    throw StateError('No active family');
  }
  return ref.watch(dashboardRepositoryProvider).parentDashboard(familyId);
});

/// `GET /families/{family}/children/{child}/summary`, keyed by child UUID.
///
/// Child-scoped: rebuilds when the active family changes; each key auto-disposes
/// when its screen leaves, so a fresh visit always refetches. `view_reports` on
/// the backend — a caregiver without the grant gets a 403 the UI surfaces.
final childSummaryProvider = FutureProvider.autoDispose
    .family<ChildSummary, String>((ref, childId) {
      ref.watch(dashboardRefreshSignalProvider);
      final familyId = ref.watch(activeFamilyIdProvider);
      if (familyId == null) {
        throw StateError('No active family');
      }
      return ref
          .watch(dashboardRepositoryProvider)
          .childSummary(familyId, childId);
    });

/// The weekly/monthly toggle on the development report screen. Auto-disposes, so
/// it resets to `weekly` each time the screen opens.
final reportPeriodProvider = StateProvider.autoDispose<String>((_) => 'weekly');

/// `GET /families/{family}/children/{child}/reports/{period}` for the active
/// family + selected child, keyed by `weekly` / `monthly`.
///
/// Child-scoped through [childScopeProvider]: a family or selected-child change
/// rebuilds and clears it. Switching the period requests the other key (old
/// period's data is not shown under the new one). `view_reports` on the backend.
final developmentReportProvider = FutureProvider.autoDispose
    .family<DevelopmentReport, String>((ref, period) {
      ref.watch(dashboardRefreshSignalProvider);
      final scope = ref.watch(childScopeProvider);
      if (scope.familyId == null || scope.childId == null) {
        throw StateError('No active family / selected child');
      }
      return ref
          .watch(dashboardRepositoryProvider)
          .report(
            familyId: scope.familyId!,
            childId: scope.childId!,
            period: period,
          );
    });
