import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../children/application/selected_child_controller.dart';
import '../data/models/child_task.dart';
import '../data/tasks_repository.dart';

/// `GET …/tasks/{task}` for one task (with its `completions`), keyed by task id.
///
/// Child-scoped: rebuilds / clears on a family or selected-child change.
/// Invalidated by the tasks controller after update / archive, and by the
/// completions controller after any completion action.
final taskDetailProvider = FutureProvider.autoDispose.family<ChildTask, String>(
  (ref, taskId) {
    final scope = ref.watch(childScopeProvider);
    if (scope.familyId == null || scope.childId == null) {
      throw StateError('No active family / selected child');
    }
    return ref
        .watch(tasksRepositoryProvider)
        .showTask(scope.familyId!, scope.childId!, taskId);
  },
);
