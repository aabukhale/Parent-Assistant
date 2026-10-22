import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/cache/offline_cache.dart';
import 'package:my_app/features/safety/data/safety_models.dart';
import 'package:my_app/features/safety/data/safety_repository.dart';

import '../../support/test_api.dart';

Map<String, dynamic> _ok(Object? data) => {'success': true, 'data': data};

Map<String, dynamic> _help({String status = 'open', int pushQueued = 0}) => {
  'id': 'h1',
  'child_id': 'child-1',
  'child_name': 'Omar',
  'status': status,
  'location': {'latitude': 31.9, 'longitude': 35.2, 'accuracy_m': 8},
  'battery_pct': 41,
  'recipients': [
    {'id': 'u1', 'name': 'Dana'},
  ],
  'push_queued': pushQueued,
  'created_at': '2026-10-22T19:00:00Z',
};

Map<String, dynamic> _centre() => {
  'people': [
    {'id': 'u1', 'name': 'Dana', 'phone': '+970599000000'},
  ],
  'contacts': [
    {
      'id': 'c1',
      'name': 'Grandma',
      'phone': '+970598000000',
      'can_pick_up': true,
    },
  ],
  'pickup_instructions': 'Wait at the school gate.',
  'emergency_number': '100',
  'open_help': null,
};

/// Body of the last request to [path] (the auth bootstrap may interleave).
Map<dynamic, dynamic> _sent(TestApi api, String path) =>
    api.requests.lastWhere((r) => r.path.endsWith(path)).data as Map;

DioException _offline(String path) => DioException(
  requestOptions: RequestOptions(path: path),
  type: DioExceptionType.connectionError,
);

void main() {
  group('models', () {
    test('location snapshot keeps the age and status, never "live"', () {
      final s = ChildLocationSnapshot.fromJson(const {
        'child_id': 'child-1',
        'child_name': 'Omar',
        'status': 'stale',
        'sharing_enabled': true,
        'child_informed': true,
        'location': {
          'latitude': 31.9,
          'longitude': 35.2,
          'accuracy_m': 12,
          'recorded_at': '2026-10-22T18:00:00Z',
          'age_minutes': 40,
        },
        'device': {
          'name': 'Pixel',
          'platform': 'android',
          'location_permission': 'while_in_use',
          'battery_pct': null,
        },
      });
      expect(s.status, 'stale');
      expect(s.hasLocation, isTrue);
      expect(s.ageMinutes, 40);
      expect(s.location!.accuracyM, 12);
      // Battery not reported is unknown, not 0 %.
      expect(s.batteryPct, isNull);
    });

    test('no coordinates → no location (not 0,0)', () {
      final s = ChildLocationSnapshot.fromJson(const {
        'child_id': 'c',
        'status': 'permission_missing',
        'location': {'latitude': null, 'longitude': 35.2},
      });
      expect(s.hasLocation, isFalse);
      expect(s.status, 'permission_missing');
    });

    test('help alert: push_queued 0 means nobody was reachable by push', () {
      final h = HelpAlert.fromJson(_help());
      expect(h.isOpen, isTrue);
      expect(h.pushQueued, 0);
      expect(h.recipients.single.name, 'Dana');
      expect(h.location!.latitude, 31.9);
      expect(
        HelpAlert.fromJson(_help(status: 'resolved')).isAcknowledged,
        isTrue,
      );
    });

    test('urgent check-ins and live journeys', () {
      expect(
        SafetyCheckin.fromJson(const {
          'id': 'x',
          'kind': 'pick_me_up',
        }).isUrgent,
        isTrue,
      );
      expect(
        SafetyCheckin.fromJson(const {'id': 'x', 'kind': 'arrived'}).isUrgent,
        isFalse,
      );
      final j = Journey.fromJson(const {'id': 'j', 'status': 'overdue'});
      expect(j.isLive, isTrue);
      expect(j.isOverdue, isTrue);
      expect(
        Journey.fromJson(const {'id': 'j', 'status': 'arrived'}).isLive,
        isFalse,
      );
    });

    test('safety centre: child view people, caregiver contact phone', () {
      final c = SafetyCentre.fromJson({
        ..._centre(),
        'caregivers': [
          {
            'member_id': 'm1',
            'name': 'Dana',
            'contact_phone': '+970599000000',
            'is_me': true,
          },
        ],
      });
      expect(c.people.single.phone, '+970599000000');
      expect(c.contacts.single.canPickUp, isTrue);
      expect(c.emergencyNumber, '100');
      expect(c.caregivers.single.isMe, isTrue);
      expect(c.caregivers.single.contactPhone, '+970599000000');
    });
  });

  group('child repository', () {
    late TestApi api;
    late Directory cacheDir;
    late KidSafetyRepository repo;

    setUp(() {
      cacheDir = Directory.systemTemp.createTempSync('safety_cache');
      api = TestApi.create(
        token: 'child-token',
        locale: 'en',
        overrides: [
          offlineCacheProvider.overrideWithValue(
            OfflineCache(baseDir: () async => cacheDir),
          ),
        ],
      );
      repo = api.container.read(kidSafetyRepositoryProvider);
    });
    tearDown(() {
      api.dispose();
      if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
    });

    test(
      '"Call my parent" numbers still load offline from the cache',
      () async {
        api.adapter.onGet(
          '/child/safety-centre',
          (s) => s.reply(200, _ok(_centre())),
        );
        final live = await repo.centre();
        expect(live.fromCache, isFalse);

        api.adapter.onGet(
          '/child/safety-centre',
          (s) => s.throws(0, _offline('/child/safety-centre')),
        );
        final cached = await repo.centre();
        expect(cached.fromCache, isTrue);
        expect(cached.value.people.single.phone, '+970599000000');
        expect(cached.value.emergencyNumber, '100');
      },
    );

    test('SOS sends a retry key, location and battery', () async {
      api.adapter.onPost(
        '/child/help-alerts',
        (s) => s.reply(201, _ok(_help())),
        data: Matchers.any,
      );
      final h = await repo.raiseHelp(
        clientId: 'sos-1',
        at: const GeoPoint(latitude: 31.9, longitude: 35.2, accuracyM: 8),
        batteryPct: 41,
        recipientIds: ['u1'],
      );
      final body = _sent(api, '/child/help-alerts');
      expect(body['client_id'], 'sos-1');
      expect(body['latitude'], 31.9);
      expect(body['accuracy_m'], 8);
      expect(body['battery_pct'], 41);
      expect(body['recipient_user_ids'], ['u1']);
      expect(body.containsKey('message'), isFalse);
      expect(h.id, 'h1');
    });

    test('SOS without a location fix omits coordinates', () async {
      api.adapter.onPost(
        '/child/help-alerts',
        (s) => s.reply(201, _ok(_help())),
        data: Matchers.any,
      );
      await repo.raiseHelp(clientId: 'sos-2');
      final body = _sent(api, '/child/help-alerts');
      expect(body.containsKey('latitude'), isFalse);
      expect(body.containsKey('longitude'), isFalse);
    });

    test('check-in and journey bodies', () async {
      api.adapter
        ..onPost(
          '/child/safety-checkins',
          (s) => s.reply(
            201,
            _ok({'id': 'k1', 'child_id': 'child-1', 'kind': 'pick_me_up'}),
          ),
          data: Matchers.any,
        )
        ..onPost(
          '/child/journeys/j1/finish',
          (s) => s.reply(200, _ok({'id': 'j1', 'status': 'cancelled'})),
          data: Matchers.any,
        );
      final k = await repo.checkin('pick_me_up', clientId: 'k-1');
      expect(k.isUrgent, isTrue);
      expect(_sent(api, '/child/safety-checkins')['client_id'], 'k-1');

      final j = await repo.finishJourney('j1', arrived: false);
      expect(_sent(api, '/finish')['how'], 'cancelled');
      expect(j.isLive, isFalse);
    });

    test('no active journey → null', () async {
      api.adapter.onGet(
        '/child/journeys/active',
        (s) => s.reply(200, _ok(null)),
      );
      expect(await repo.activeJourney(), isNull);
    });

    test('place events are sent in UTC with their idempotency key', () async {
      api.adapter.onPost(
        '/child/place-events',
        (s) => s.reply(201, _ok({'recorded': true})),
        data: Matchers.any,
      );
      await repo.placeEvent(
        placeId: 'p1',
        type: 'arrive',
        occurredAt: DateTime.utc(2026, 10, 22, 7, 30),
        clientEventId: 'p1:arrive:1',
      );
      final body = _sent(api, '/child/place-events');
      expect(body['occurred_at'], '2026-10-22T07:30:00.000Z');
      expect(body['client_event_id'], 'p1:arrive:1');
    });
  });

  group('parent repository', () {
    late TestApi api;
    late SafetyRepository repo;
    const f = '/families/family-1';

    setUp(() {
      api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      repo = api.container.read(safetyRepositoryProvider);
    });
    tearDown(() => api.dispose());

    test('help alerts: open filter, acknowledge path', () async {
      api.adapter
        ..onGet(
          '$f/help-alerts',
          (s) => s.reply(200, _ok([_help()])),
          queryParameters: {'status': 'open'},
        )
        ..onPost(
          '$f/help-alerts/h1/acknowledge',
          (s) => s.reply(200, _ok(_help(status: 'acknowledged'))),
        );
      expect((await repo.helpAlerts()).single.isOpen, isTrue);
      expect((await repo.acknowledgeHelp('h1')).isAcknowledged, isTrue);
    });

    test('sharing toggle and my contact phone', () async {
      api.adapter
        ..onPut(
          '$f/children/child-1/location-settings',
          (s) => s.reply(
            200,
            _ok({
              'child_id': 'child-1',
              'status': 'no_location_yet',
              'sharing_enabled': true,
            }),
          ),
          data: Matchers.any,
        )
        ..onPut(
          '$f/my-contact',
          (s) => s.reply(200, _ok(null)),
          data: Matchers.any,
        );
      final s = await repo.setSharing('child-1', true);
      expect((api.lastRequest.data as Map)['sharing_enabled'], isTrue);
      expect(s.status, 'no_location_yet');

      await repo.setMyContactPhone(null);
      final body = api.lastRequest.data as Map;
      expect(body.containsKey('contact_phone'), isTrue);
      expect(body['contact_phone'], isNull);
    });

    test('journeys: live filter', () async {
      api.adapter.onGet(
        '$f/journeys',
        (s) => s.reply(
          200,
          _ok([
            {'id': 'j1', 'status': 'overdue', 'child_name': 'Omar'},
          ]),
        ),
        queryParameters: {'status': 'live'},
      );
      expect((await repo.journeys()).single.isOverdue, isTrue);
    });
  });
}
