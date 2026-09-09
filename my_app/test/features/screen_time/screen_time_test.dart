import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/devices/application/devices_controller.dart';
import 'package:my_app/features/devices/data/devices_repository.dart';
import 'package:my_app/features/devices/data/models/device.dart';
import 'package:my_app/features/screen_time/application/screen_time_controller.dart';
import 'package:my_app/features/screen_time/data/models/screen_time_models.dart';
import 'package:my_app/features/screen_time/data/screen_time_repository.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  const c = '/families/family-1/children/child-1';

  group('models', () {
    test('ScreenTimeSummary: null limits stay null (no rule), not zero', () {
      final s = ScreenTimeSummary.fromJson(
        Fixtures.screenTimeSummaryEnvelope(usedMinutes: 40)['data']
            as Map<String, dynamic>,
      );
      expect(s.usedMinutes, 40);
      expect(s.effectiveLimitMinutes, isNull);
      expect(s.hasLimit, isFalse);
    });

    test(
      'ScreenTimeRule: default vs weekday override; 0 limit != disabled',
      () {
        final def = ScreenTimeRule.fromJson(Fixtures.screenTimeRuleJson());
        expect(def.isDefault, isTrue);
        final ov = ScreenTimeRule.fromJson(
          Fixtures.screenTimeRuleJson(
            scope: 'weekday_override',
            dayOfWeek: 6,
            dailyLimitMinutes: 0,
            isEnabled: true,
          ),
        );
        expect(ov.isDefault, isFalse);
        expect(ov.dayOfWeek, 6);
        expect(ov.dailyLimitMinutes, 0);
        expect(ov.isEnabled, isTrue);
      },
    );

    test('ScreenTimeOverride: revoked + reward source flags', () {
      final revoked = ScreenTimeOverride.fromJson(
        Fixtures.stOverrideJson(
          source: 'reward_redemption',
          revokedAt: '2026-09-09T00:00:00.000Z',
        ),
      );
      expect(revoked.isRevoked, isTrue);
      expect(revoked.isFromReward, isTrue);
    });

    test('Device: platform / mode enums tolerate unknown', () {
      final d = Device.fromJson(
        Fixtures.deviceJson(platform: 'blackberry', deviceMode: 'kiosk'),
      );
      expect(d.platform, DevicePlatform.unknown);
      expect(d.deviceMode, DeviceMode.unknown);
      expect(d.hasPushToken, isFalse);
    });

    test('ScreenTimeRulesInput: default + overrides serialise correctly', () {
      final json = const ScreenTimeRulesInput(
        defaultRule: ScreenTimeRuleInput(dailyLimitMinutes: 120),
        overrides: {6: ScreenTimeRuleInput(dailyLimitMinutes: 240)},
      ).toJson();
      expect(json['default'], containsPair('daily_limit_minutes', 120));
      expect((json['overrides'] as List).single['day_of_week'], 6);
    });

    test('UsageEvent keeps its client_event_id (idempotency key)', () {
      final e = UsageEvent(
        startedAt: DateTime.utc(2026, 9, 8, 10),
        endedAt: DateTime.utc(2026, 9, 8, 11),
        usedSeconds: 3600,
        clientEventId: 'evt-abc',
      );
      expect(e.toJson()['client_event_id'], 'evt-abc');
    });
  });

  group('screen-time repository', () {
    late TestApi api;
    late ScreenTimeRepository repo;
    setUp(() {
      api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      repo = api.container.read(screenTimeRepositoryProvider);
    });
    tearDown(() => api.dispose());

    test('rules: GET array', () async {
      api.adapter.onGet(
        '$c/screen-time-rules',
        (s) => s.reply(200, Fixtures.screenTimeRulesEnvelope()),
      );
      expect(
        (await repo.rules('family-1', 'child-1')).single.isDefault,
        isTrue,
      );
    });

    test('updateRules: PUT replaces the set', () async {
      api.adapter.onPut(
        '$c/screen-time-rules',
        (s) => s.reply(200, Fixtures.screenTimeRulesEnvelope()),
        data: Matchers.any,
      );
      await repo.updateRules(
        'family-1',
        'child-1',
        const ScreenTimeRulesInput(
          defaultRule: ScreenTimeRuleInput(dailyLimitMinutes: 90),
        ),
      );
      expect(api.lastRequest.method, 'PUT');
      expect(
        (api.lastRequest.data as Map)['default'],
        containsPair('daily_limit_minutes', 90),
      );
    });

    test('summary: forwards ?date=YYYY-MM-DD', () async {
      api.adapter.onGet(
        '$c/screen-time/summary',
        (s) => s.reply(200, Fixtures.screenTimeSummaryEnvelope()),
      );
      await repo.summary('family-1', 'child-1', date: DateTime(2026, 6, 1));
      expect(api.lastRequest.uri.queryParameters['date'], '2026-06-01');
    });

    test('grantExtraTime: POST override; revoke: DELETE', () async {
      api.adapter
        ..onPost(
          '$c/screen-time-overrides',
          (s) => s.reply(201, Fixtures.stOverrideEnvelope()),
          data: Matchers.any,
        )
        ..onDelete(
          '$c/screen-time-overrides/o1',
          (s) => s.reply(
            200,
            Fixtures.stOverrideEnvelope(
              override: Fixtures.stOverrideJson(
                revokedAt: '2026-09-09T00:00:00.000Z',
              ),
            ),
          ),
        );
      final granted = await repo.grantExtraTime(
        'family-1',
        'child-1',
        const GrantExtraTimeInput(additionalMinutes: 30),
      );
      expect(granted.additionalMinutes, 30);
      final revoked = await repo.revokeOverride('family-1', 'child-1', 'o1');
      expect(revoked.isRevoked, isTrue);
    });

    test('usage ingest: replayed batch returns replayed:true', () async {
      api.adapter.onPost(
        '$c/usage/ingest',
        (s) => s.reply(200, Fixtures.usageIngestEnvelope(replayed: true)),
        data: Matchers.any,
      );
      final result = await repo.ingestUsage(
        'family-1',
        'child-1',
        UsageIngestBatch(
          batchId: 'batch-1',
          events: [
            UsageEvent(
              startedAt: DateTime.utc(2026, 9, 8, 10),
              endedAt: DateTime.utc(2026, 9, 8, 11),
              usedSeconds: 3600,
              clientEventId: 'evt-1',
            ),
          ],
        ),
      );
      expect(result.replayed, isTrue);
      expect((api.lastRequest.data as Map)['batch_id'], 'batch-1');
    });

    test('rules update without manage_screen_time → 403', () async {
      api.adapter.onPut(
        '$c/screen-time-rules',
        (s) => s.reply(403, {
          'success': false,
          'message': 'This action is unauthorized.',
        }),
        data: Matchers.any,
      );
      try {
        await repo.updateRules(
          'family-1',
          'child-1',
          const ScreenTimeRulesInput(
            defaultRule: ScreenTimeRuleInput(dailyLimitMinutes: 60),
          ),
        );
        fail('expected');
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.forbidden);
      }
    });
  });

  group('devices repository', () {
    late TestApi api;
    late DevicesRepository repo;
    setUp(() {
      api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      repo = api.container.read(devicesRepositoryProvider);
    });
    tearDown(() => api.dispose());

    test('list: paginated', () async {
      api.adapter.onGet(
        '/families/family-1/devices',
        (s) => s.reply(
          200,
          Fixtures.devicesPage([
            Fixtures.deviceJson(id: 'a'),
            Fixtures.deviceJson(id: 'b', isActive: false),
          ]),
        ),
      );
      final page = await repo.list('family-1');
      expect(page.items.map((d) => d.id), ['a', 'b']);
      expect(page.items[1].isActive, isFalse);
    });

    test('register: POST with device_identifier_hash', () async {
      api.adapter.onPost(
        '/families/family-1/devices',
        (s) => s.reply(201, Fixtures.deviceEnvelope()),
        data: Matchers.any,
      );
      await repo.register(
        'family-1',
        const DeviceRegisterInput(
          name: 'My phone',
          platform: DevicePlatform.android,
          deviceMode: DeviceMode.familyShared,
          deviceIdentifierHash: 'hash-123',
        ),
      );
      final body = api.lastRequest.data as Map;
      expect(body['device_identifier_hash'], 'hash-123');
      expect(body['platform'], 'android');
    });

    test('update: PATCH is_active=false to revoke', () async {
      api.adapter.onPatch(
        '/families/family-1/devices/d1',
        (s) => s.reply(
          200,
          Fixtures.deviceEnvelope(device: Fixtures.deviceJson(isActive: false)),
        ),
        data: Matchers.any,
      );
      final d = await repo.update(
        'family-1',
        'd1',
        const DeviceUpdateInput(isActive: false),
      );
      expect(d.isActive, isFalse);
    });
  });

  group('controllers', () {
    test('overridesController.grant refreshes list + summary', () async {
      final api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          '$c/screen-time-overrides',
          (s) => s.reply(200, Fixtures.stOverridesPage(const [])),
        )
        ..onGet(
          '$c/screen-time/summary',
          (s) => s.reply(200, Fixtures.screenTimeSummaryEnvelope()),
        );
      final oSub = api.container.listen(overridesControllerProvider, (_, _) {});
      addTearDown(oSub.close);
      final sSub = api.container.listen(screenTimeSummaryProvider, (_, _) {});
      addTearDown(sSub.close);
      await api.container.read(overridesControllerProvider.future);
      await api.container.read(screenTimeSummaryProvider.future);

      api.adapter
        ..onPost(
          '$c/screen-time-overrides',
          (s) => s.reply(201, Fixtures.stOverrideEnvelope()),
          data: Matchers.any,
        )
        ..onGet(
          '$c/screen-time-overrides',
          (s) => s.reply(
            200,
            Fixtures.stOverridesPage([Fixtures.stOverrideJson(id: 'new')]),
          ),
        )
        ..onGet(
          '$c/screen-time/summary',
          (s) => s.reply(
            200,
            Fixtures.screenTimeSummaryEnvelope(
              bonusMinutes: 30,
              effectiveLimitMinutes: 150,
            ),
          ),
        );

      await api.container
          .read(overridesControllerProvider.notifier)
          .grant(const GrantExtraTimeInput(additionalMinutes: 30));
      await Future<void>.delayed(Duration.zero);
      expect(
        api.container
            .read(overridesControllerProvider)
            .requireValue
            .overrides
            .single
            .id,
        'new',
      );
      expect(
        (await api.container.read(
          screenTimeSummaryProvider.future,
        )).bonusMinutes,
        30,
      );
    });

    test('devicesController: family switch reloads', () async {
      final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          '/families/family-1/devices',
          (s) => s.reply(
            200,
            Fixtures.devicesPage([Fixtures.deviceJson(id: 'f1')]),
          ),
        )
        ..onGet(
          '/families/family-2/devices',
          (s) => s.reply(
            200,
            Fixtures.devicesPage([Fixtures.deviceJson(id: 'f2')]),
          ),
        );
      final sub = api.container.listen(devicesControllerProvider, (_, _) {});
      addTearDown(sub.close);
      expect(
        (await api.container.read(
          devicesControllerProvider.future,
        )).devices.single.id,
        'f1',
      );
      api.setActiveFamily('family-2');
      expect(
        (await api.container.read(
          devicesControllerProvider.future,
        )).devices.single.id,
        'f2',
      );
    });
  });
}
