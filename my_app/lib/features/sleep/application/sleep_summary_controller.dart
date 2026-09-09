import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../children/application/selected_child_controller.dart';
import '../data/models/sleep_summary.dart';
import '../data/sleep_repository.dart';

/// The period toggle on the sleep screen (`weekly` | `monthly`). Auto-disposes
/// so it resets to weekly each time the screen is opened.
final sleepPeriodProvider = StateProvider.autoDispose<String>((_) => 'weekly');

/// `GET …/sleep-logs/summary?period=` for the active family + selected child,
/// keyed by period (`weekly` | `monthly`).
///
/// Child-scoped: rebuilds / clears on a family or selected-child change.
/// Invalidated by the list controller after any create / update / delete so the
/// averages stay in step. Cached otherwise (no repeated requests).
final sleepSummaryProvider = FutureProvider.autoDispose
    .family<SleepSummary, String>((ref, period) {
      final scope = ref.watch(childScopeProvider);
      if (scope.familyId == null || scope.childId == null) {
        throw StateError('No active family / selected child');
      }
      return ref
          .watch(sleepRepositoryProvider)
          .summary(
            familyId: scope.familyId!,
            childId: scope.childId!,
            period: period,
          );
    });
