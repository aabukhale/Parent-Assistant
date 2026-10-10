import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kid_models.dart';
import '../data/kid_repository.dart';

final kidMyDayProvider = FutureProvider.autoDispose<Fresh<MyDay>>(
  (ref) => ref.watch(kidRepositoryProvider).myDay(),
);

final kidRoutinesProvider = FutureProvider.autoDispose<Fresh<List<Routine>>>(
  (ref) => ref.watch(kidRepositoryProvider).routines(),
);

final kidRoutineProvider = FutureProvider.autoDispose.family<Routine, String>(
  (ref, id) => ref.watch(kidRepositoryProvider).routine(id),
);

final kidTasksProvider =
    FutureProvider.autoDispose<Fresh<List<KidTaskSummary>>>(
      (ref) => ref.watch(kidRepositoryProvider).tasks(),
    );

final kidRewardsProvider = FutureProvider.autoDispose<Fresh<KidRewardsCatalog>>(
  (ref) => ref.watch(kidRepositoryProvider).rewards(),
);

final kidPointsProvider = FutureProvider.autoDispose<Fresh<KidPoints>>(
  (ref) => ref.watch(kidRepositoryProvider).points(),
);

final kidWishesProvider = FutureProvider.autoDispose<Fresh<List<RewardWish>>>(
  (ref) => ref.watch(kidRepositoryProvider).wishes(),
);

final kidChallengesProvider =
    FutureProvider.autoDispose<Fresh<List<FamilyChallenge>>>(
      (ref) => ref.watch(kidRepositoryProvider).challenges(),
    );

final kidEncouragementsProvider =
    FutureProvider.autoDispose<Fresh<List<Encouragement>>>(
      (ref) => ref.watch(kidRepositoryProvider).encouragements(),
    );

final kidCheckinsProvider =
    FutureProvider.autoDispose<Fresh<List<MoodCheckin>>>(
      (ref) => ref.watch(kidRepositoryProvider).checkins(),
    );

final kidRequestsProvider = FutureProvider.autoDispose<Fresh<KidRequests>>(
  (ref) => ref.watch(kidRepositoryProvider).requests(),
);

final kidScreenTimeProvider = FutureProvider.autoDispose<Fresh<KidScreenTime>>(
  (ref) => ref.watch(kidRepositoryProvider).screenTime(),
);

final kidActivitiesProvider =
    FutureProvider.autoDispose<Fresh<List<Map<String, dynamic>>>>(
      (ref) => ref.watch(kidRepositoryProvider).activities(),
    );

final kidGoalsProvider =
    FutureProvider.autoDispose<Fresh<List<Map<String, dynamic>>>>(
      (ref) => ref.watch(kidRepositoryProvider).goals(),
    );

/// Child-side mutations. Each refreshes exactly the views it affects; the
/// server stays the source of truth (no optimistic points).
class KidActions {
  KidActions(this._ref);

  final Ref _ref;

  KidRepository get _repo => _ref.read(kidRepositoryProvider);

  void refreshAll() {
    for (final p in [
      kidMyDayProvider,
      kidRoutinesProvider,
      kidTasksProvider,
      kidRewardsProvider,
      kidPointsProvider,
      kidWishesProvider,
      kidChallengesProvider,
      kidEncouragementsProvider,
      kidCheckinsProvider,
      kidRequestsProvider,
      kidScreenTimeProvider,
      kidActivitiesProvider,
      kidGoalsProvider,
    ]) {
      _ref.invalidate(p);
    }
  }

  Future<void> completeTask(String taskId) async {
    await _repo.completeTask(taskId);
    _ref
      ..invalidate(kidMyDayProvider)
      ..invalidate(kidTasksProvider)
      ..invalidate(kidRequestsProvider);
  }

  Future<Routine> checkStep(String routineId, String stepId) async {
    final r = await _repo.checkStep(routineId, stepId);
    _afterRoutine(routineId);
    return r;
  }

  Future<Routine> uncheckStep(String routineId, String stepId) async {
    final r = await _repo.uncheckStep(routineId, stepId);
    _afterRoutine(routineId);
    return r;
  }

  void _afterRoutine(String routineId) {
    _ref
      ..invalidate(kidMyDayProvider)
      ..invalidate(kidRoutinesProvider)
      ..invalidate(kidRoutineProvider(routineId))
      ..invalidate(kidChallengesProvider)
      ..invalidate(kidRequestsProvider);
  }

  Future<void> requestReward(String rewardId) async {
    await _repo.requestReward(rewardId);
    _ref
      ..invalidate(kidRewardsProvider)
      ..invalidate(kidRequestsProvider);
  }

  Future<void> setSavingFor(String? rewardId) async {
    await _repo.setSavingFor(rewardId);
    _ref
      ..invalidate(kidRewardsProvider)
      ..invalidate(kidMyDayProvider);
  }

  Future<void> suggestWish(String title, {String? note}) async {
    await _repo.suggestWish(title, note: note);
    _ref
      ..invalidate(kidWishesProvider)
      ..invalidate(kidRequestsProvider);
  }

  Future<void> withdrawWish(String id) async {
    await _repo.withdrawWish(id);
    _ref
      ..invalidate(kidWishesProvider)
      ..invalidate(kidRequestsProvider);
  }

  Future<void> checkIn(String mood, {String? note}) async {
    await _repo.checkIn(mood, note: note);
    _ref
      ..invalidate(kidCheckinsProvider)
      ..invalidate(kidMyDayProvider);
  }

  Future<void> markSeen(String encouragementId) async {
    await _repo.markEncouragementSeen(encouragementId);
    _ref
      ..invalidate(kidEncouragementsProvider)
      ..invalidate(kidMyDayProvider);
  }

  Future<void> contribute(
    String challengeId,
    int amount, {
    required String clientId,
  }) async {
    await _repo.contribute(challengeId, amount, clientId: clientId);
    _ref.invalidate(kidChallengesProvider);
  }

  Future<void> askForScreenTime(int minutes, {String? reason}) async {
    await _repo.askForScreenTime(minutes, reason: reason);
    _ref
      ..invalidate(kidScreenTimeProvider)
      ..invalidate(kidRequestsProvider);
  }

  Future<void> cancelScreenTime(String id) async {
    await _repo.cancelScreenTimeRequest(id);
    _ref
      ..invalidate(kidScreenTimeProvider)
      ..invalidate(kidRequestsProvider);
  }

  Future<void> completeActivity(String assignmentId) async {
    await _repo.completeActivity(assignmentId);
    _ref
      ..invalidate(kidActivitiesProvider)
      ..invalidate(kidRequestsProvider);
  }
}

final kidActionsProvider = Provider<KidActions>(KidActions.new);
