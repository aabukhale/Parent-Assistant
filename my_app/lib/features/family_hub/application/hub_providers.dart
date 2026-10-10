import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../kid/data/kid_models.dart';
import '../data/hub_models.dart';
import '../data/hub_repository.dart';

final pulseProvider = FutureProvider.autoDispose<Fresh<FamilyPulse>>(
  (ref) => ref.watch(hubRepositoryProvider).pulse(),
);

final familyInboxProvider = FutureProvider.autoDispose
    .family<Fresh<FamilyInbox>, String?>(
      (ref, childId) =>
          ref.watch(hubRepositoryProvider).inbox(childId: childId),
    );

final recapProvider = FutureProvider.autoDispose.family<WeeklyRecap, String?>(
  (ref, weekStart) =>
      ref.watch(hubRepositoryProvider).recap(weekStart: weekStart),
);

typedef PlannerRange = ({String from, String to, String? childId});

final plannerProvider = FutureProvider.autoDispose
    .family<Fresh<List<PlannerItem>>, PlannerRange>(
      (ref, r) => ref
          .watch(hubRepositoryProvider)
          .planner(from: r.from, to: r.to, childId: r.childId),
    );

final challengesProvider = FutureProvider.autoDispose<List<FamilyChallenge>>(
  (ref) => ref.watch(hubRepositoryProvider).challenges(),
);

final challengeProvider = FutureProvider.autoDispose
    .family<FamilyChallenge, String>(
      (ref, id) => ref.watch(hubRepositoryProvider).challenge(id),
    );

final childRoutinesProvider = FutureProvider.autoDispose
    .family<List<Routine>, String>(
      (ref, childId) => ref.watch(hubRepositoryProvider).routines(childId),
    );

final childCheckinsProvider = FutureProvider.autoDispose
    .family<List<MoodCheckin>, String?>(
      (ref, childId) =>
          ref.watch(hubRepositoryProvider).checkins(childId: childId),
    );

final childEncouragementsProvider = FutureProvider.autoDispose
    .family<List<Encouragement>, String>(
      (ref, childId) =>
          ref.watch(hubRepositoryProvider).encouragements(childId),
    );

final childMealsProvider = FutureProvider.autoDispose
    .family<List<MealLog>, String>(
      (ref, childId) => ref.watch(hubRepositoryProvider).meals(childId),
    );

final childDevicesProvider = FutureProvider.autoDispose
    .family<List<ChildDevice>, String>(
      (ref, childId) => ref.watch(hubRepositoryProvider).childDevices(childId),
    );

final notificationPrefsProvider = FutureProvider.autoDispose<NotificationPrefs>(
  (ref) => ref.watch(hubRepositoryProvider).notificationPrefs(),
);

/// Refresh everything the Today/Inbox views derive from (after an action or
/// when the app returns to the foreground).
void refreshFamilyOverview(Ref ref) {
  ref
    ..invalidate(pulseProvider)
    ..invalidate(familyInboxProvider)
    ..invalidate(challengesProvider);
}
