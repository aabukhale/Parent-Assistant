import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/util/client_id.dart';
import '../../auth/application/auth_controller.dart';
import '../../kid/data/kid_models.dart';
import 'safety_models.dart';

List<Map<String, dynamic>> _l(Object? d) => d is List
    ? d.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
    : const [];
Map<String, dynamic> _m(Object? d) => (d as Map).cast<String, dynamic>();

/// Read-through helper: network first, last good payload when offline.
Future<Fresh<T>> _cachedGet<T>(
  ApiClient client,
  OfflineCache cache,
  String scope,
  String path,
  String key,
  T Function(Object? data) parse, {
  Map<String, dynamic>? query,
}) async {
  try {
    final env = await client.get(path, query: query);
    await cache.write(scope, key, env.data);
    return Fresh(parse(env.data), fetchedAt: DateTime.now());
  } on ApiException catch (e) {
    if (e.kind != ApiErrorKind.network && e.kind != ApiErrorKind.timeout) {
      rethrow;
    }
    final cached = await cache.read(scope, key);
    if (cached == null) rethrow;
    return Fresh(
      parse(cached.data),
      fetchedAt: cached.savedAt,
      fromCache: true,
    );
  }
}

/// Child-session safety endpoints. Child and family come from the token.
class KidSafetyRepository {
  KidSafetyRepository(this._client, this._cache, this._scope);

  final ApiClient _client;
  final OfflineCache _cache;
  final String _scope;

  /// Cached so "Call my parent" works offline — this is exactly when the
  /// safety centre is needed most.
  Future<Fresh<SafetyCentre>> centre() => _cachedGet(
    _client,
    _cache,
    _scope,
    '/child/safety-centre',
    'safety_centre',
    (d) => SafetyCentre.fromJson(_m(d)),
  );

  Future<({bool sharing, bool informed})> locationSettings() async {
    final d = (await _client.get('/child/location-settings')).dataMap;
    return (
      sharing: d['sharing_enabled'] as bool? ?? false,
      informed: d['child_informed'] as bool? ?? false,
    );
  }

  Future<void> markInformed() =>
      _client.post('/child/location-settings/informed');

  Future<void> uploadLocations(List<Map<String, dynamic>> points) =>
      _client.post('/child/locations', body: {'points': points});

  Future<List<SafePlace>> safePlaces() async => _l(
    (await _client.get('/child/safe-places')).data,
  ).map(SafePlace.fromJson).toList();

  Future<void> placeEvent({
    required String placeId,
    required String type,
    required DateTime occurredAt,
    required String clientEventId,
  }) => _client.post(
    '/child/place-events',
    body: {
      'safe_place_id': placeId,
      'type': type,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'client_event_id': clientEventId,
    },
  );

  Future<Journey?> activeJourney() async {
    final d = (await _client.get('/child/journeys/active')).data;
    return d is Map ? Journey.fromJson(d.cast<String, dynamic>()) : null;
  }

  Future<Journey> startJourney({
    String? safePlaceId,
    String? destinationName,
    required DateTime expectedAt,
    required String clientId,
  }) async => Journey.fromJson(
    (await _client.post(
      '/child/journeys',
      body: {
        'safe_place_id': ?safePlaceId,
        'destination_name': ?destinationName,
        'expected_at': expectedAt.toUtc().toIso8601String(),
        'client_id': clientId,
      },
    )).dataMap,
  );

  Future<Journey> finishJourney(String id, {required bool arrived}) async =>
      Journey.fromJson(
        (await _client.post(
          '/child/journeys/$id/finish',
          body: {'how': arrived ? 'arrived' : 'cancelled'},
        )).dataMap,
      );

  Future<Journey> extendJourney(String id, int minutes) async =>
      Journey.fromJson(
        (await _client.post(
          '/child/journeys/$id/extend',
          body: {'minutes': minutes},
        )).dataMap,
      );

  /// [clientId] must be reused for retries of the same check-in.
  Future<SafetyCheckin> checkin(
    String kind, {
    required String clientId,
    GeoPoint? at,
    String? note,
  }) async => SafetyCheckin.fromJson(
    (await _client.post(
      '/child/safety-checkins',
      body: {
        'kind': kind,
        'client_id': clientId,
        'note': ?note,
        if (at != null) ...{
          'latitude': at.latitude,
          'longitude': at.longitude,
          'accuracy_m': ?at.accuracyM,
        },
      },
    )).dataMap,
  );

  Future<List<SafetyCheckin>> checkins() async => _l(
    (await _client.get('/child/safety-checkins')).data,
  ).map(SafetyCheckin.fromJson).toList();

  /// Retry-safe: the same [clientId] returns the same alert.
  Future<HelpAlert> raiseHelp({
    required String clientId,
    GeoPoint? at,
    int? batteryPct,
    String? message,
    List<String>? recipientIds,
  }) async => HelpAlert.fromJson(
    (await _client.post(
      '/child/help-alerts',
      body: {
        'client_id': clientId,
        'message': ?message,
        'battery_pct': ?batteryPct,
        'recipient_user_ids': ?recipientIds,
        if (at != null) ...{
          'latitude': at.latitude,
          'longitude': at.longitude,
          'accuracy_m': ?at.accuracyM,
        },
      },
    )).dataMap,
  );

  Future<HelpAlert> help(String id) async =>
      HelpAlert.fromJson((await _client.get('/child/help-alerts/$id')).dataMap);

  Future<HelpAlert> cancelHelp(String id) async => HelpAlert.fromJson(
    (await _client.post('/child/help-alerts/$id/cancel')).dataMap,
  );

  Future<List<Agreement>> agreements() async => _l(
    (await _client.get('/child/agreements')).data,
  ).map(Agreement.fromJson).toList();

  Future<void> agree(String id) => _client.post('/child/agreements/$id/agree');

  Future<List<LessonProgress>> lessons() async => _l(
    (await _client.get('/child/lessons')).data,
  ).map(LessonProgress.fromJson).toList();

  Future<void> completeLesson(String key) =>
      _client.post('/child/lessons/complete', body: {'key': key});

  Future<void> reportDeviceStatus(Map<String, dynamic> status) =>
      _client.put('/child/device-status', body: status);
}

final kidSafetyRepositoryProvider = Provider<KidSafetyRepository>((ref) {
  final childId = ref.watch(childSessionProvider)?.childId ?? 'none';
  return KidSafetyRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineCacheProvider),
    'child_$childId',
  );
});

/// Parent/caregiver safety endpoints for the active family.
class SafetyRepository {
  SafetyRepository(this._client, this._cache, this.familyId);

  final ApiClient _client;
  final OfflineCache _cache;
  final String familyId;

  String get _f => '/families/$familyId';
  String get _scope => 'family_$familyId';

  Future<Fresh<FamilyMap>> map() => _cachedGet(
    _client,
    _cache,
    _scope,
    '$_f/location-map',
    'location_map',
    (d) => FamilyMap.fromJson(_m(d)),
  );

  Future<ChildLocationSnapshot> setSharing(String childId, bool on) async =>
      ChildLocationSnapshot.fromJson(
        (await _client.put(
          '$_f/children/$childId/location-settings',
          body: {'sharing_enabled': on},
        )).dataMap,
      );

  Future<List<SafePlace>> places() async => _l(
    (await _client.get('$_f/safe-places')).data,
  ).map(SafePlace.fromJson).toList();

  Future<SafePlace> savePlace(SafePlace place, {String? id}) async {
    final env = id == null
        ? await _client.post('$_f/safe-places', body: place.toJson())
        : await _client.patch('$_f/safe-places/$id', body: place.toJson());
    return SafePlace.fromJson(env.dataMap);
  }

  Future<void> deletePlace(String id) => _client.delete('$_f/safe-places/$id');

  Future<List<Journey>> journeys({bool liveOnly = true}) async => _l(
    (await _client.get(
      '$_f/journeys',
      query: {'status': liveOnly ? 'live' : 'all'},
    )).data,
  ).map(Journey.fromJson).toList();

  Future<List<SafetyCheckin>> checkins() async => _l(
    (await _client.get('$_f/safety-checkins')).data,
  ).map(SafetyCheckin.fromJson).toList();

  Future<void> acknowledgeCheckin(String id) =>
      _client.post('$_f/safety-checkins/$id/acknowledge');

  Future<List<HelpAlert>> helpAlerts({bool openOnly = true}) async => _l(
    (await _client.get(
      '$_f/help-alerts',
      query: {'status': openOnly ? 'open' : 'all'},
    )).data,
  ).map(HelpAlert.fromJson).toList();

  Future<HelpAlert> acknowledgeHelp(String id) async => HelpAlert.fromJson(
    (await _client.post('$_f/help-alerts/$id/acknowledge')).dataMap,
  );

  Future<HelpAlert> resolveHelp(String id) async => HelpAlert.fromJson(
    (await _client.post('$_f/help-alerts/$id/resolve')).dataMap,
  );

  Future<Fresh<SafetyCentre>> centre() => _cachedGet(
    _client,
    _cache,
    _scope,
    '$_f/safety-centre',
    'safety_centre',
    (d) => SafetyCentre.fromJson(_m(d)),
  );

  Future<void> updateCentre({String? pickup, String? emergencyNumber}) =>
      _client.put(
        '$_f/safety-centre',
        body: {
          'pickup_instructions': pickup,
          'emergency_number': emergencyNumber,
        },
      );

  Future<void> setMyContactPhone(String? phone) =>
      _client.put('$_f/my-contact', body: {'contact_phone': phone});

  Future<void> saveContact(Map<String, dynamic> body, {String? id}) =>
      id == null
      ? _client.post('$_f/emergency-contacts', body: body)
      : _client.patch('$_f/emergency-contacts/$id', body: body);

  Future<void> deleteContact(String id) =>
      _client.delete('$_f/emergency-contacts/$id');

  Future<void> updateMemberAccess(
    String memberId, {
    bool? urgent,
    String? childScope,
    List<String>? childIds,
  }) => _client.put(
    '$_f/members/$memberId/access',
    body: {
      'receives_urgent_alerts': ?urgent,
      'child_scope': ?childScope,
      'child_ids': ?childIds,
    },
  );

  Future<List<AccessLogEntry>> accessLog({
    String? childId,
    int page = 1,
  }) async => _l(
    (await _client.get(
      '$_f/access-log',
      query: {'child_id': ?childId, 'page': page},
    )).dataMap['items'],
  ).map(AccessLogEntry.fromJson).toList();

  Future<({List<Agreement> agreements, List<LessonProgress> lessons})>
  agreements(String childId) async {
    final d = (await _client.get('$_f/children/$childId/agreements')).dataMap;
    return (
      agreements: _l(d['agreements']).map(Agreement.fromJson).toList(),
      lessons: _l(d['lessons']).map(LessonProgress.fromJson).toList(),
    );
  }

  Future<void> saveAgreement(
    String childId,
    String title,
    List<({String section, String text})> items, {
    String? id,
  }) {
    final body = {
      'title': title,
      'items': [
        for (final i in items) {'section': i.section, 'text': i.text},
      ],
    };
    return id == null
        ? _client.post('$_f/children/$childId/agreements', body: body)
        : _client.patch('$_f/children/$childId/agreements/$id', body: body);
  }

  Future<void> deleteAgreement(String childId, String id) =>
      _client.delete('$_f/children/$childId/agreements/$id');
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(
    ref.watch(apiClientProvider),
    ref.watch(offlineCacheProvider),
    ref.watch(activeFamilyIdProvider) ?? '',
  ),
);

/// New idempotency key — exposed so screens keep one per user action.
String safetyClientId() => newClientId();
