import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/device_rules/data/device_rules_models.dart';
import 'package:my_app/features/device_rules/data/device_rules_repository.dart';

import '../../support/test_api.dart';

Map<String, dynamic> _device({
  String state = 'active',
  int? applied = 3,
  Map<String, String> caps = const {'app_blocking': 'available'},
}) => {
  'device_id': 'd1',
  'device_name': 'Omar’s phone',
  'platform': 'android',
  'state': state,
  'received_version': 3,
  'applied_version': applied,
  'applied_at': '2026-10-22T10:00:00Z',
  'capabilities': caps,
  'results': [
    {'rule': 'web_filter', 'state': 'unsupported'},
  ],
};

Map<String, dynamic> _state({
  int version = 3,
  String summary = 'active',
  List<Map<String, dynamic>>? devices,
}) => {
  'success': true,
  'data': {
    'child_id': 'child-1',
    'version': version,
    'timezone': 'Asia/Hebron',
    'weekend_days': [5, 6],
    'rules': {
      'blocked_apps': [
        {'platform': 'android', 'id': 'com.google.android.gm', 'name': 'Gmail'},
      ],
      'schedules': [
        {
          'id': 's1',
          'preset': 'bedtime',
          'name': 'Bedtime',
          'days': [1, 2, 3, 4, 5, 6, 7],
          'start': '21:00',
          'end': '07:00',
          'restriction': 'allow_only',
        },
      ],
      'web': {
        'mode': 'block_listed',
        'blocked_domains': ['example.com'],
      },
      'restrict_now': {'started_at': '2026-10-22T10:00:00Z', 'until': null},
    },
    'status': {
      'summary': summary,
      'has_rules': true,
      'devices': devices ?? [_device()],
      'current': {'kind': 'restrict_now'},
      'restrict_now': {'state': 'on'},
    },
  },
};

void main() {
  const base = '/families/family-1/children/child-1/device-rules';

  group('models', () {
    test(
      'state parses rules, per-device layers and the current restriction',
      () {
        final s = DeviceRulesState.fromJson(
          _state()['data'] as Map<String, dynamic>,
        );
        expect(s.version, 3);
        expect(s.weekendDays, [5, 6]);
        expect(s.rules.blockedApps.single.key, 'android:com.google.android.gm');
        expect(s.rules.schedules.single.crossesMidnight, isTrue);
        expect(s.rules.web.blocked, ['example.com']);
        expect(s.rules.restrictNow?.until, isNull);
        expect(s.current?.kind, 'restrict_now');
        expect(s.restrictState, 'on');
        final d = s.devices.single;
        expect(d.receivedVersion, 3);
        expect(d.appliedVersion, 3);
        expect(d.capability('app_blocking'), 'available');
        // Unknown capability is never assumed available.
        expect(d.capability('device_lock'), 'unknown');
        expect(d.results.single.state, 'unsupported');
      },
    );

    test('a missing status means no rules, not active', () {
      final s = DeviceRulesState.fromJson(const {'version': 0});
      expect(s.summary, 'no_rules');
      expect(s.hasRules, isFalse);
      expect(s.devices, isEmpty);
      expect(s.weekendDays, [6, 7]);
    });

    test('a device without a state is "not confirmed"', () {
      final d = DeviceRuleDeviceState.fromJson(const {'device_id': 'd2'});
      expect(d.state, 'not_confirmed');
      expect(d.appliedVersion, isNull);
    });

    test('rules serialise without the server-owned restrict_now', () {
      final s = DeviceRulesState.fromJson(
        _state()['data'] as Map<String, dynamic>,
      );
      final json = s.rules.toJson();
      expect(json.containsKey('restrict_now'), isFalse);
      expect((json['web'] as Map)['mode'], 'block_listed');
      expect((json['schedules'] as List).single['end'], '07:00');
    });

    test('preview lists what each phone cannot enforce', () {
      final p = RulePreview.fromJson(const {
        'changes': [
          {'kind': 'blocked_apps_added', 'count': 1},
        ],
        'devices': [
          {
            'device_name': 'iPad',
            'limitations': [
              {'capability': 'app_limits', 'state': 'unsupported'},
            ],
          },
        ],
      });
      expect(p.changes.single['kind'], 'blocked_apps_added');
      expect(p.deviceLimits.single.deviceName, 'iPad');
      expect(p.deviceLimits.single.limits.single.capability, 'app_limits');
    });
  });

  group('repository', () {
    late TestApi api;
    late DeviceRulesRepository repo;
    setUp(() {
      api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      repo = api.container.read(deviceRulesRepositoryProvider);
    });
    tearDown(() => api.dispose());

    test('save sends the rules with expected_version', () async {
      api.adapter.onPut(
        base,
        (s) => s.reply(200, _state(version: 4, summary: 'waiting_for_device')),
        data: Matchers.any,
      );
      final rules = const DeviceRules(
        blockedApps: [AppRef(platform: 'android', id: 'a.b', name: 'AB')],
      );
      final s = await repo.save(
        'child-1',
        rules,
        expectedVersion: 3,
        summary: 'Block AB',
      );
      final body = api.lastRequest.data as Map;
      expect(body['expected_version'], 3);
      expect(body['summary'], 'Block AB');
      expect((body['blocked_apps'] as List).single['id'], 'a.b');
      // The server's answer is what the UI shows: waiting, not active.
      expect(s.summary, 'waiting_for_device');
    });

    test('a concurrent edit surfaces as a conflict', () async {
      api.adapter.onPut(
        base,
        (s) => s.reply(409, {
          'success': false,
          'message': 'The rules changed meanwhile.',
        }),
        data: Matchers.any,
      );
      await expectLater(
        repo.save('child-1', const DeviceRules(), expectedVersion: 1),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.conflict,
          ),
        ),
      );
    });

    test('restrict now: null minutes means until released', () async {
      api.adapter.onPost(
        '$base/restrict-now',
        (s) => s.reply(200, _state()),
        data: Matchers.any,
      );
      await repo.restrictNow('child-1');
      expect((api.lastRequest.data as Map)['minutes'], isNull);
      await repo.restrictNow('child-1', minutes: 30);
      expect((api.lastRequest.data as Map)['minutes'], 30);
    });

    test('presets omit unset fields', () async {
      api.adapter.onPost(
        '$base/presets',
        (s) => s.reply(200, _state()),
        data: Matchers.any,
      );
      await repo.applyPreset('child-1', 'bedtime', start: '21:00');
      final body = api.lastRequest.data as Map;
      expect(body['preset'], 'bedtime');
      expect(body['start'], '21:00');
      expect(body.containsKey('days'), isFalse);
      expect(body.containsKey('minutes'), isFalse);
    });

    test('undo posts the target version', () async {
      api.adapter.onPost(
        '$base/undo',
        (s) => s.reply(200, _state(version: 5)),
        data: Matchers.any,
      );
      final s = await repo.undoTo('child-1', 2);
      expect((api.lastRequest.data as Map)['version'], 2);
      expect(s.version, 5);
    });

    test('app inventory: apps and when they were reported', () async {
      api.adapter.onGet(
        '$base/apps',
        (s) => s.reply(200, {
          'success': true,
          'data': {
            'apps': [
              {'platform': 'android', 'id': 'com.x', 'name': 'X'},
              'garbage',
            ],
            'reported_at': '2026-10-22T09:00:00Z',
          },
        }),
      );
      final r = await repo.apps('child-1');
      expect(r.apps.single.name, 'X');
      expect(r.reportedAt, isNotNull);
    });

    test('app inventory: never reported', () async {
      api.adapter.onGet(
        '$base/apps',
        (s) => s.reply(200, {
          'success': true,
          'data': {'apps': [], 'reported_at': null},
        }),
      );
      final r = await repo.apps('child-1');
      expect(r.apps, isEmpty);
      expect(r.reportedAt, isNull);
    });

    test('history parses versions', () async {
      api.adapter.onGet(
        '$base/history',
        (s) => s.reply(200, {
          'success': true,
          'data': {
            'items': [
              {
                'version': 2,
                'change_kind': 'undo',
                'summary': 'Back to v1',
                'can_undo_to': true,
              },
            ],
          },
        }),
      );
      final h = await repo.history('child-1');
      expect(h.single.changeKind, 'undo');
      expect(h.single.canUndoTo, isTrue);
    });
  });
}
