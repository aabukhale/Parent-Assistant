import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../children/application/selected_child_controller.dart';
import '../data/learning_goals_repository.dart';
import '../data/models/learning_goal.dart';

/// One learning goal (`GET …/learning-goals/{goal}`), keyed by goal id.
///
/// Child-scoped: watches [childScopeProvider] so it rebuilds / clears when the
/// active family or selected child changes. Invalidated by the goals controller
/// after update / archive, and by the progress controller after a new entry.
final learningGoalDetailProvider = FutureProvider.autoDispose
    .family<LearningGoal, String>((ref, goalId) {
      final scope = ref.watch(childScopeProvider);
      if (scope.familyId == null || scope.childId == null) {
        throw StateError('No active family / selected child');
      }
      return ref
          .watch(learningGoalsRepositoryProvider)
          .show(scope.familyId!, scope.childId!, goalId);
    });
