import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../children/application/selected_child_controller.dart';
import '../data/models/sleep_log.dart';
import '../data/sleep_repository.dart';

/// `GET …/sleep-logs/{sleepLog}` for one log, keyed by log id.
///
/// Child-scoped: rebuilds / clears when the active family or selected child
/// changes; invalidated by the list controller after update / delete.
final sleepLogDetailProvider = FutureProvider.autoDispose
    .family<SleepLog, String>((ref, logId) {
      final scope = ref.watch(childScopeProvider);
      if (scope.familyId == null || scope.childId == null) {
        throw StateError('No active family / selected child');
      }
      return ref
          .watch(sleepRepositoryProvider)
          .show(scope.familyId!, scope.childId!, logId);
    });
