import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/rewards/application/redemptions_controller.dart';
import 'package:my_app/features/rewards/data/models/reward_enums.dart';
import 'package:my_app/features/tasks/application/points_controller.dart';
import 'package:my_app/features/tasks/data/task_requests.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  const c = '/families/family-1/children/child-1';
  const redemptions = '$c/reward-redemptions';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
  });
  tearDown(() => api.dispose());

  Future<RedemptionsListState> settle() async {
    for (var i = 0; i < 60; i++) {
      final s = api.container.read(redemptionsControllerProvider);
      if (s.hasValue && !s.isLoading) return s.requireValue;
      await Future<void>.delayed(Duration.zero);
    }
    return api.container.read(redemptionsControllerProvider).requireValue;
  }

  void primePoints(int balance) {
    api.adapter
      ..onGet(
        '$c/points-balance',
        (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: balance)),
      )
      ..onGet(
        '$c/point-transactions',
        (s) => s.reply(200, Fixtures.pointTxPage(const [])),
      );
  }

  test('empty scope → empty, no request', () async {
    final noChild = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
    addTearDown(noChild.dispose);
    for (var i = 0; i < 20; i++) {
      if (noChild.container.read(redemptionsControllerProvider).hasValue) break;
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      noChild.container
          .read(redemptionsControllerProvider)
          .requireValue
          .redemptions,
      isEmpty,
    );
    expect(
      noChild.requests.where((r) => r.uri.path.contains('reward-redemptions')),
      isEmpty,
    );
  });

  test('loads redemptions for the selected child', () async {
    api.adapter.onGet(
      redemptions,
      (s) => s.reply(
        200,
        Fixtures.redemptionsPage([
          Fixtures.redemptionJson(id: 'r1'),
          Fixtures.redemptionJson(id: 'r2'),
        ]),
      ),
    );
    expect((await settle()).redemptions.map((r) => r.id), ['r1', 'r2']);
  });

  test('child switch reloads and drops previous redemptions', () async {
    api.adapter
      ..onGet(
        redemptions,
        (s) => s.reply(
          200,
          Fixtures.redemptionsPage([Fixtures.redemptionJson(id: 'a')]),
        ),
      )
      ..onGet(
        '/families/family-1/children/child-2/reward-redemptions',
        (s) => s.reply(
          200,
          Fixtures.redemptionsPage([
            Fixtures.redemptionJson(id: 'b', childId: 'child-2'),
          ]),
        ),
      );
    expect((await settle()).redemptions.single.id, 'a');
    api.setSelectedChild('child-2');
    expect((await settle()).redemptions.single.id, 'b');
  });

  test('family switch reloads', () async {
    api.adapter
      ..onGet(
        redemptions,
        (s) => s.reply(
          200,
          Fixtures.redemptionsPage([Fixtures.redemptionJson(id: 'f1')]),
        ),
      )
      ..onGet(
        '/families/family-2/children/child-1/reward-redemptions',
        (s) => s.reply(
          200,
          Fixtures.redemptionsPage([Fixtures.redemptionJson(id: 'f2')]),
        ),
      );
    expect((await settle()).redemptions.single.id, 'f1');
    api.setActiveFamily('family-2');
    expect((await settle()).redemptions.single.id, 'f2');
  });

  test('requestRedemption refreshes the list; no points call', () async {
    api.adapter.onGet(
      redemptions,
      (s) => s.reply(200, Fixtures.redemptionsPage(const [])),
    );
    await settle();
    api.adapter
      ..onPost(
        redemptions,
        (s) => s.reply(
          201,
          Fixtures.redemptionEnvelope(
            redemption: Fixtures.redemptionJson(id: 'new'),
          ),
        ),
        data: Matchers.any,
      )
      ..onGet(
        redemptions,
        (s) => s.reply(
          200,
          Fixtures.redemptionsPage([Fixtures.redemptionJson(id: 'new')]),
        ),
      );

    await api.container
        .read(redemptionsControllerProvider.notifier)
        .requestRedemption('rw-1');
    await Future<void>.delayed(Duration.zero);
    expect(
      api.container
          .read(redemptionsControllerProvider)
          .requireValue
          .redemptions
          .single
          .id,
      'new',
    );
    expect(
      api.requests.where((r) => r.uri.path.endsWith('/points-balance')),
      isEmpty,
    );
  });

  test(
    'approve refreshes redemptions + balance + ledger from the server',
    () async {
      primePoints(100);
      api.adapter.onGet(
        redemptions,
        (s) => s.reply(
          200,
          Fixtures.redemptionsPage([
            Fixtures.redemptionJson(
              id: 'x1',
              status: 'pending',
              pointsCost: 40,
            ),
          ]),
        ),
      );
      await settle();
      final bSub = api.container.listen(pointsBalanceProvider, (_, _) {});
      addTearDown(bSub.close);
      expect(
        (await api.container.read(pointsBalanceProvider.future)).balance,
        100,
      );

      api.adapter
        ..onPost(
          '$redemptions/x1/approve',
          (s) => s.reply(
            200,
            Fixtures.redemptionEnvelope(
              redemption: Fixtures.redemptionJson(
                id: 'x1',
                status: 'approved',
                pointsCost: 40,
                deductionTxnId: 'd1',
              ),
            ),
          ),
          data: Matchers.any,
        )
        ..onGet(
          redemptions,
          (s) => s.reply(
            200,
            Fixtures.redemptionsPage([
              Fixtures.redemptionJson(
                id: 'x1',
                status: 'approved',
                pointsCost: 40,
                deductionTxnId: 'd1',
              ),
            ]),
          ),
        )
        ..onGet(
          '$c/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 60)),
        )
        ..onGet(
          '$c/point-transactions',
          (s) => s.reply(
            200,
            Fixtures.pointTxPage([
              Fixtures.pointTxJson(
                id: 'd1',
                amount: -40,
                type: 'redemption',
                sourceType: 'reward_redemption',
              ),
            ]),
          ),
        );

      final result = await api.container
          .read(redemptionsControllerProvider.notifier)
          .approve('x1', const ReviewInput());
      await Future<void>.delayed(Duration.zero);

      expect(result.status, RedemptionStatus.approved);
      expect(
        (await api.container.read(pointsBalanceProvider.future)).balance,
        60,
        reason: 'balance re-read, not computed locally',
      );
    },
  );

  test('reject refreshes redemptions but makes no points call', () async {
    primePoints(50);
    api.adapter.onGet(
      redemptions,
      (s) => s.reply(
        200,
        Fixtures.redemptionsPage([
          Fixtures.redemptionJson(id: 'x1', status: 'pending'),
        ]),
      ),
    );
    await settle();

    api.adapter
      ..onPost(
        '$redemptions/x1/reject',
        (s) => s.reply(
          200,
          Fixtures.redemptionEnvelope(
            redemption: Fixtures.redemptionJson(id: 'x1', status: 'rejected'),
          ),
        ),
        data: Matchers.any,
      )
      ..onGet(
        redemptions,
        (s) => s.reply(
          200,
          Fixtures.redemptionsPage([
            Fixtures.redemptionJson(id: 'x1', status: 'rejected'),
          ]),
        ),
      );

    await api.container
        .read(redemptionsControllerProvider.notifier)
        .reject('x1', const ReviewInput(note: 'no'));
    await Future<void>.delayed(Duration.zero);
    expect(
      api.container
          .read(redemptionsControllerProvider)
          .requireValue
          .redemptions
          .single
          .isRejected,
      isTrue,
    );
    expect(
      api.requests.where((r) => r.uri.path.endsWith('/points-balance')),
      isEmpty,
    );
  });

  test(
    'cancel refreshes balance/ledger and surfaces the revoked override',
    () async {
      primePoints(60);
      api.adapter.onGet(
        redemptions,
        (s) => s.reply(
          200,
          Fixtures.redemptionsPage([
            Fixtures.redemptionJson(
              id: 'x1',
              status: 'approved',
              rewardType: 'screen_time',
              pointsCost: 40,
              deductionTxnId: 'd1',
              screenTimeOverride: Fixtures.screenTimeOverrideJson(
                additionalMinutes: 45,
              ),
            ),
          ]),
        ),
      );
      await settle();
      final bSub = api.container.listen(pointsBalanceProvider, (_, _) {});
      addTearDown(bSub.close);

      api.adapter
        ..onPost(
          '$redemptions/x1/cancel',
          (s) => s.reply(
            200,
            Fixtures.redemptionEnvelope(
              redemption: Fixtures.redemptionJson(
                id: 'x1',
                status: 'cancelled',
                rewardType: 'screen_time',
                pointsCost: 40,
                deductionTxnId: 'd1',
                refundTxnId: 'r1',
                screenTimeOverride: Fixtures.screenTimeOverrideJson(
                  additionalMinutes: 45,
                  revokedAt: '2026-09-08T12:00:00.000Z',
                ),
              ),
            ),
          ),
          data: Matchers.any,
        )
        ..onGet(
          redemptions,
          (s) => s.reply(
            200,
            Fixtures.redemptionsPage([
              Fixtures.redemptionJson(
                id: 'x1',
                status: 'cancelled',
                rewardType: 'screen_time',
                pointsCost: 40,
                deductionTxnId: 'd1',
                refundTxnId: 'r1',
                screenTimeOverride: Fixtures.screenTimeOverrideJson(
                  additionalMinutes: 45,
                  revokedAt: '2026-09-08T12:00:00.000Z',
                ),
              ),
            ]),
          ),
        )
        ..onGet(
          '$c/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 100)),
        );

      final result = await api.container
          .read(redemptionsControllerProvider.notifier)
          .cancel('x1', const ReviewInput());
      await Future<void>.delayed(Duration.zero);

      expect(result.status, RedemptionStatus.cancelled);
      expect(result.screenTimeOverride!.isRevoked, isTrue);
      expect(
        (await api.container.read(pointsBalanceProvider.future)).balance,
        100,
      );
    },
  );

  test('conflict on approve surfaces to the caller', () async {
    primePoints(100);
    api.adapter
      ..onGet(
        redemptions,
        (s) => s.reply(
          200,
          Fixtures.redemptionsPage([
            Fixtures.redemptionJson(id: 'x1', status: 'pending'),
          ]),
        ),
      )
      ..onPost(
        '$redemptions/x1/approve',
        (s) => s.reply(409, {
          'success': false,
          'message': 'This redemption has already been reviewed.',
        }),
        data: Matchers.any,
      );
    await settle();

    Object? err;
    try {
      await api.container
          .read(redemptionsControllerProvider.notifier)
          .approve('x1', const ReviewInput());
    } on ApiException catch (e) {
      err = e;
    }
    expect((err as ApiException).kind, ApiErrorKind.conflict);
  });
}
