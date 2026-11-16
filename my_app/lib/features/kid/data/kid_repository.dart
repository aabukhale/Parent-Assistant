import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/util/client_id.dart';
import '../../auth/application/auth_controller.dart';
import 'kid_models.dart';

/// All child-session endpoints. The child and family are implied by the
/// token — nothing here takes a child id, so a child cannot ask for another
/// child's data even by tampering with the app.
class KidRepository {
  KidRepository(this._client, this._cache, this._scope);

  final ApiClient _client;
  final OfflineCache _cache;

  /// Cache namespace for this child session.
  final String _scope;

  /// GET with an offline fallback: a network/timeout failure serves the last
  /// cached payload (marked `fromCache`), any other error propagates.
  Future<Fresh<T>> _cachedGet<T>(
    String path,
    String key,
    T Function(Object? data, Map<String, dynamic>? meta) parse, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final env = await _client.get(path, query: query);
      await _cache.write(_scope, key, {'data': env.data, 'meta': env.meta});
      return Fresh(parse(env.data, env.meta), fetchedAt: DateTime.now());
    } on ApiException catch (e) {
      final offline =
          e.kind == ApiErrorKind.network || e.kind == ApiErrorKind.timeout;
      if (!offline) rethrow;
      final cached = await _cache.read(_scope, key);
      if (cached == null) rethrow;
      final payload = (cached.data as Map).cast<String, dynamic>();
      return Fresh(
        parse(
          payload['data'],
          (payload['meta'] as Map?)?.cast<String, dynamic>(),
        ),
        fetchedAt: cached.savedAt,
        fromCache: true,
      );
    }
  }

  Map<String, dynamic> _asMap(Object? d) => (d as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> _asList(Object? d) => (d as List)
      .whereType<Map>()
      .map((m) => m.cast<String, dynamic>())
      .toList();

  // ---- My Day / planner ---------------------------------------------------

  Future<Fresh<MyDay>> myDay() => _cachedGet(
    '/child/my-day',
    'my_day',
    (d, _) => MyDay.fromJson(_asMap(d)),
  );

  Future<Fresh<List<Map<String, dynamic>>>> planner({
    String? from,
    String? to,
  }) => _cachedGet(
    '/child/planner',
    'planner_${from ?? 'today'}',
    (d, _) => _asList(_asMap(d)['items']),
    query: {'from': ?from, 'to': ?to},
  );

  // ---- Tasks -------------------------------------------------------------

  Future<Fresh<List<KidTaskSummary>>> tasks() => _cachedGet(
    '/child/tasks',
    'tasks',
    (d, _) => _asList(_asMap(d)['items']).map(KidTaskSummary.fromJson).toList(),
  );

  Future<Map<String, dynamic>> task(String id) async =>
      (await _client.get('/child/tasks/$id')).dataMap;

  /// "I did it!" — submits today's occurrence for parent review.
  Future<void> completeTask(String id) =>
      _client.post('/child/tasks/$id/complete');

  // ---- Routines ----------------------------------------------------------

  Future<Fresh<List<Routine>>> routines() => _cachedGet(
    '/child/routines',
    'routines',
    (d, _) => _asList(_asMap(d)['routines']).map(Routine.fromJson).toList(),
  );

  Future<Routine> routine(String id) async =>
      Routine.fromJson((await _client.get('/child/routines/$id')).dataMap);

  Future<Routine> checkStep(String routineId, String stepId) async =>
      Routine.fromJson(
        (await _client.post(
          '/child/routines/$routineId/steps/$stepId/check',
        )).dataMap,
      );

  Future<Routine> uncheckStep(String routineId, String stepId) async =>
      Routine.fromJson(
        (await _client.delete(
          '/child/routines/$routineId/steps/$stepId/check',
        )).dataMap,
      );

  // ---- Points, rewards, wishes -------------------------------------------

  Future<Fresh<KidRewardsCatalog>> rewards() => _cachedGet(
    '/child/rewards',
    'rewards',
    (d, _) => KidRewardsCatalog.fromJson(_asMap(d)),
  );

  Future<Fresh<KidPoints>> points() => _cachedGet(
    '/child/points',
    'points',
    (d, meta) => KidPoints(
      balance: (meta?['balance'] as num?)?.toInt() ?? 0,
      entries: _asList(d).map(LedgerEntry.fromJson).toList(),
    ),
    query: {'per_page': 30},
  );

  Future<void> requestReward(String rewardId) =>
      _client.post('/child/redemptions', body: {'reward_id': rewardId});

  Future<void> setSavingFor(String? rewardId) =>
      _client.put('/child/saving-for', body: {'reward_id': rewardId});

  Future<Fresh<List<RewardWish>>> wishes() => _cachedGet(
    '/child/wishes',
    'wishes',
    (d, _) => _asList(d).map(RewardWish.fromJson).toList(),
  );

  Future<void> suggestWish(String title, {String? note}) =>
      _client.post('/child/wishes', body: {'title': title, 'note': ?note});

  Future<void> withdrawWish(String id) =>
      _client.post('/child/wishes/$id/withdraw');

  // ---- Mood, messages, challenges ------------------------------------------

  Future<Fresh<List<MoodCheckin>>> checkins() => _cachedGet(
    '/child/checkins',
    'checkins',
    (d, _) => _asList(d).map(MoodCheckin.fromJson).toList(),
  );

  Future<void> checkIn(String mood, {String? note}) =>
      _client.post('/child/checkins', body: {'mood': mood, 'note': ?note});

  Future<Fresh<List<Encouragement>>> encouragements() => _cachedGet(
    '/child/encouragements',
    'encouragements',
    (d, _) => _asList(d).map(Encouragement.fromJson).toList(),
  );

  Future<void> markEncouragementSeen(String id) =>
      _client.post('/child/encouragements/$id/seen');

  Future<Fresh<List<FamilyChallenge>>> challenges() => _cachedGet(
    '/child/challenges',
    'challenges',
    (d, _) => _asList(d).map(FamilyChallenge.fromJson).toList(),
  );

  /// [clientId] must be reused when retrying the same contribution.
  Future<void> contribute(
    String challengeId,
    int amount, {
    String? note,
    String? clientId,
  }) => _client.post(
    '/child/challenges/$challengeId/contributions',
    body: {
      'amount': amount,
      'note': ?note,
      'client_id': clientId ?? newClientId(),
    },
  );

  // ---- Screen time & requests ---------------------------------------------

  Future<Fresh<KidScreenTime>> screenTime() => _cachedGet(
    '/child/screen-time',
    'screen_time',
    (d, _) => KidScreenTime.fromJson(_asMap(d)),
  );

  Future<void> askForScreenTime(int minutes, {String? reason}) => _client.post(
    '/child/screen-time/requests',
    body: {'minutes': minutes, 'reason': ?reason},
  );

  Future<void> cancelScreenTimeRequest(String id) =>
      _client.post('/child/screen-time/requests/$id/cancel');

  Future<Fresh<KidRequests>> requests() => _cachedGet(
    '/child/requests',
    'requests',
    (d, _) => KidRequests.fromJson(_asMap(d)),
  );

  // ---- Activities & goals ----------------------------------------------------

  Future<Fresh<List<Map<String, dynamic>>>> activities() =>
      _cachedGet('/child/activities', 'activities', (d, _) => _asList(d));

  Future<void> completeActivity(String assignmentId, {String? note}) => _client
      .post('/child/activities/$assignmentId/complete', body: {'note': ?note});

  Future<Fresh<List<Map<String, dynamic>>>> goals() =>
      _cachedGet('/child/goals', 'goals', (d, _) => _asList(d));
}

/// Scoped to the signed-in child; rebuilt (fresh cache scope) whenever the
/// child session changes.
final kidRepositoryProvider = Provider<KidRepository>((ref) {
  final childId = ref.watch(childSessionProvider)?.childId ?? 'none';
  return KidRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineCacheProvider),
    'child_$childId',
  );
});
