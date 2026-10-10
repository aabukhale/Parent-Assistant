import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/util/client_id.dart';
import '../../auth/application/auth_controller.dart';
import '../../kid/data/kid_models.dart';
import 'hub_models.dart';

/// Parent-side family endpoints added for the redesign. Everything is scoped
/// to the active family; the server re-checks membership and permissions.
class HubRepository {
  HubRepository(this._client, this._cache, this.familyId);

  final ApiClient _client;
  final OfflineCache _cache;
  final String familyId;

  String get _f => '/families/$familyId';

  Future<Fresh<T>> _cached<T>(
    String path,
    String key,
    T Function(Object? data) parse, {
    Map<String, dynamic>? query,
  }) async {
    final scope = 'family_$familyId';
    try {
      final env = await _client.get(path, query: query);
      await _cache.write(scope, key, env.data);
      return Fresh(parse(env.data), fetchedAt: DateTime.now());
    } on ApiException catch (e) {
      if (e.kind != ApiErrorKind.network && e.kind != ApiErrorKind.timeout) {
        rethrow;
      }
      final cached = await _cache.read(scope, key);
      if (cached == null) rethrow;
      return Fresh(
        parse(cached.data),
        fetchedAt: cached.savedAt,
        fromCache: true,
      );
    }
  }

  Map<String, dynamic> _m(Object? d) => (d as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> _l(Object? d) => (d as List)
      .whereType<Map>()
      .map((m) => m.cast<String, dynamic>())
      .toList();

  // ---- Overview -----------------------------------------------------------

  Future<Fresh<FamilyPulse>> pulse() =>
      _cached('$_f/pulse', 'pulse', (d) => FamilyPulse.fromJson(_m(d)));

  Future<Fresh<FamilyInbox>> inbox({String? childId}) => _cached(
    '$_f/inbox',
    'inbox_${childId ?? 'all'}',
    (d) => FamilyInbox.fromJson(_m(d)),
    query: {'child_id': ?childId},
  );

  Future<WeeklyRecap> recap({String? weekStart}) async => WeeklyRecap.fromJson(
    (await _client.get(
      '$_f/recap/weekly',
      query: {'week_start': ?weekStart},
    )).dataMap,
  );

  Future<Fresh<List<PlannerItem>>> planner({
    required String from,
    required String to,
    String? childId,
  }) => _cached(
    '$_f/planner',
    'planner_${from}_${to}_${childId ?? 'all'}',
    (d) => _l(_m(d)['items']).map(PlannerItem.fromJson).toList(),
    query: {'from': from, 'to': to, 'child_id': ?childId},
  );

  // ---- Inbox actions ----------------------------------------------------------

  Future<void> approveTask(
    String childId,
    String taskId,
    String completionId, {
    String? note,
  }) => _client.post(
    '$_f/children/$childId/tasks/$taskId/completions/$completionId/approve',
    body: {'note': ?note},
  );

  Future<void> rejectTask(
    String childId,
    String taskId,
    String completionId, {
    String? note,
  }) => _client.post(
    '$_f/children/$childId/tasks/$taskId/completions/$completionId/reject',
    body: {'note': ?note},
  );

  Future<void> reverseTask(
    String childId,
    String taskId,
    String completionId,
  ) => _client.post(
    '$_f/children/$childId/tasks/$taskId/completions/$completionId/reverse',
  );

  Future<void> approveActivity(
    String childId,
    String assignmentId,
    String completionId, {
    String? note,
  }) => _client.post(
    '$_f/children/$childId/activity-assignments/$assignmentId/completions/$completionId/approve',
    body: {'note': ?note},
  );

  Future<void> rejectActivity(
    String childId,
    String assignmentId,
    String completionId, {
    String? note,
  }) => _client.post(
    '$_f/children/$childId/activity-assignments/$assignmentId/completions/$completionId/reject',
    body: {'note': ?note},
  );

  Future<void> approveRedemption(String childId, String id, {String? note}) =>
      _client.post(
        '$_f/children/$childId/reward-redemptions/$id/approve',
        body: {'note': ?note},
      );

  Future<void> rejectRedemption(String childId, String id, {String? note}) =>
      _client.post(
        '$_f/children/$childId/reward-redemptions/$id/reject',
        body: {'note': ?note},
      );

  Future<void> cancelRedemption(String childId, String id) =>
      _client.post('$_f/children/$childId/reward-redemptions/$id/cancel');

  Future<void> approveWish(
    String id, {
    required int pointsCost,
    String? title,
    String? type,
    int? minutes,
    String? note,
  }) => _client.post(
    '$_f/reward-wishes/$id/approve',
    body: {
      'points_cost': pointsCost,
      'title': ?title,
      'type': ?type,
      'minutes': ?minutes,
      'note': ?note,
    },
  );

  Future<void> declineWish(String id, {String? note}) =>
      _client.post('$_f/reward-wishes/$id/decline', body: {'note': ?note});

  Future<void> approveScreenTime(String id, {int? minutes, String? note}) =>
      _client.post(
        '$_f/screen-time-requests/$id/approve',
        body: {'minutes': ?minutes, 'note': ?note},
      );

  Future<void> declineScreenTime(String id, {String? note}) => _client.post(
    '$_f/screen-time-requests/$id/decline',
    body: {'note': ?note},
  );

  Future<void> approveRoutine(String childId, String runId, {String? note}) =>
      _client.post(
        '$_f/children/$childId/routine-runs/$runId/approve',
        body: {'note': ?note},
      );

  Future<void> rejectRoutine(String childId, String runId, {String? note}) =>
      _client.post(
        '$_f/children/$childId/routine-runs/$runId/reject',
        body: {'note': ?note},
      );

  Future<void> replyCheckin(
    String checkinId, {
    String? reply,
    String? sticker,
  }) => _client.post(
    '$_f/checkins/$checkinId/reply',
    body: {'reply': ?reply, 'reply_sticker': ?sticker},
  );

  // ---- Check-ins, encouragement --------------------------------------------------

  Future<List<MoodCheckin>> checkins({String? childId}) async =>
      (await _client.get(
            '$_f/checkins',
            query: {'child_id': ?childId, 'per_page': 30},
          )).dataList
          .whereType<Map>()
          .map((m) => MoodCheckin.fromJson(m.cast<String, dynamic>()))
          .toList();

  Future<List<Encouragement>> encouragements(String childId) async =>
      (await _client.get('$_f/children/$childId/encouragements')).dataList
          .whereType<Map>()
          .map((m) => Encouragement.fromJson(m.cast<String, dynamic>()))
          .toList();

  Future<void> sendEncouragement(
    String childId, {
    required String message,
    String? badgeKey,
    String? subjectType,
    String? subjectId,
  }) => _client.post(
    '$_f/children/$childId/encouragements',
    body: {
      'message': message,
      'badge_key': ?badgeKey,
      'subject_type': ?subjectType,
      'subject_id': ?subjectId,
    },
  );

  // ---- Routines ---------------------------------------------------------------

  Future<List<Routine>> routines(String childId) async => _l(
    _m((await _client.get('$_f/children/$childId/routines')).data)['routines'],
  ).map(Routine.fromJson).toList();

  Future<List<Map<String, dynamic>>> routineTemplates() async =>
      _l((await _client.get('/routine-templates')).data);

  Future<Routine> saveRoutine(
    String childId,
    Map<String, dynamic> body, {
    String? routineId,
  }) async {
    final env = routineId == null
        ? await _client.post('$_f/children/$childId/routines', body: body)
        : await _client.patch(
            '$_f/children/$childId/routines/$routineId',
            body: body,
          );
    return Routine.fromJson(env.dataMap);
  }

  Future<void> deleteRoutine(String childId, String routineId) =>
      _client.delete('$_f/children/$childId/routines/$routineId');

  Future<List<RoutineRunInfo>> routineRuns(
    String childId, {
    String? routineId,
  }) async =>
      (await _client.get(
            '$_f/children/$childId/routine-runs',
            query: {'routine_id': ?routineId},
          )).dataList
          .whereType<Map>()
          .map((m) => RoutineRunInfo.fromJson(m.cast<String, dynamic>()))
          .toList();

  // ---- Challenges ---------------------------------------------------------------

  Future<List<FamilyChallenge>> challenges() async => _l(
    (await _client.get('$_f/challenges')).data,
  ).map(FamilyChallenge.fromJson).toList();

  Future<FamilyChallenge> challenge(String id) async =>
      FamilyChallenge.fromJson(
        (await _client.get('$_f/challenges/$id')).dataMap,
      );

  Future<FamilyChallenge> createChallenge(Map<String, dynamic> body) async =>
      FamilyChallenge.fromJson(
        (await _client.post('$_f/challenges', body: body)).dataMap,
      );

  Future<void> cancelChallenge(String id) =>
      _client.post('$_f/challenges/$id/cancel');

  Future<void> awardChallenge(String id) =>
      _client.post('$_f/challenges/$id/award');

  Future<void> contributeChallenge(
    String id,
    int amount, {
    String? childId,
    String? note,
    String? clientId,
  }) => _client.post(
    '$_f/challenges/$id/contributions',
    body: {
      'amount': amount,
      'child_id': ?childId,
      'note': ?note,
      'client_id': clientId ?? newClientId(),
    },
  );

  // ---- Planner ---------------------------------------------------------------------

  Future<void> saveEvent(Map<String, dynamic> body, {String? eventId}) =>
      eventId == null
      ? _client.post('$_f/events', body: body)
      : _client.patch('$_f/events/$eventId', body: body);

  Future<Map<String, dynamic>> event(String id) async =>
      (await _client.get('$_f/events/$id')).dataMap;

  Future<void> deleteEvent(String id) => _client.delete('$_f/events/$id');

  // ---- Wishes / screen time lists ------------------------------------------------------

  Future<List<RewardWish>> wishes({String? status}) async =>
      (await _client.get('$_f/reward-wishes', query: {'status': ?status}))
          .dataList
          .whereType<Map>()
          .map((m) => RewardWish.fromJson(m.cast<String, dynamic>()))
          .toList();

  // ---- Meals ---------------------------------------------------------------------------

  Future<List<MealLog>> meals(String childId, {String? date}) async =>
      (await _client.get(
            '$_f/children/$childId/meal-logs',
            query: {'date': ?date, 'per_page': 50},
          )).dataList
          .whereType<Map>()
          .map((m) => MealLog.fromJson(m.cast<String, dynamic>()))
          .toList();

  Future<void> saveMeal(
    String childId,
    Map<String, dynamic> body, {
    String? mealId,
  }) => mealId == null
      ? _client.post('$_f/children/$childId/meal-logs', body: body)
      : _client.patch('$_f/children/$childId/meal-logs/$mealId', body: body);

  Future<void> deleteMeal(String childId, String mealId) =>
      _client.delete('$_f/children/$childId/meal-logs/$mealId');

  // ---- Pairing & child devices ------------------------------------------------------------

  Future<PairingCode> createPairingCode(
    String childId, {
    String deviceMode = 'child_dedicated',
  }) async => PairingCode.fromJson(
    (await _client.post(
      '$_f/children/$childId/pairing-codes',
      body: {'device_mode': deviceMode},
    )).dataMap,
  );

  Future<void> revokePairingCode(String childId, String codeId) =>
      _client.delete('$_f/children/$childId/pairing-codes/$codeId');

  Future<List<ChildDevice>> childDevices(String childId) async => _l(
    (await _client.get('$_f/children/$childId/devices')).data,
  ).map(ChildDevice.fromJson).toList();

  Future<void> unpairDevice(String childId, String deviceId) =>
      _client.delete('$_f/children/$childId/devices/$deviceId');

  // ---- Notification preferences --------------------------------------------------------------

  Future<NotificationPrefs> notificationPrefs() async =>
      NotificationPrefs.fromJson(
        (await _client.get('$_f/notification-preferences')).dataMap,
      );

  Future<NotificationPrefs> saveNotificationPrefs(
    Map<String, dynamic> body,
  ) async => NotificationPrefs.fromJson(
    (await _client.put('$_f/notification-preferences', body: body)).dataMap,
  );
}

final hubRepositoryProvider = Provider<HubRepository>((ref) {
  final familyId = ref.watch(activeFamilyIdProvider) ?? '';
  return HubRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineCacheProvider),
    familyId,
  );
});
