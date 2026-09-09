import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/rewards/data/models/reward_enums.dart';
import 'package:my_app/features/rewards/data/reward_requests.dart';
import 'package:my_app/features/rewards/data/rewards_repository.dart';
import 'package:my_app/features/tasks/data/task_requests.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  late RewardsRepository repo;
  const rewards = '/families/family-1/rewards';
  const redemptions = '/families/family-1/children/child-1/reward-redemptions';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
    repo = api.container.read(rewardsRepositoryProvider);
  });
  tearDown(() => api.dispose());

  Future<ApiException> capture(Future<void> Function() f) async {
    try {
      await f();
      fail('expected ApiException');
    } on ApiException catch (e) {
      return e;
    }
  }

  test(
    'listRewards: GET with page/per_page, no include_inactive by default',
    () async {
      api.adapter.onGet(
        rewards,
        (s) => s.reply(
          200,
          Fixtures.rewardsPage(
            [
              Fixtures.rewardJson(id: 'g', familyId: null),
              Fixtures.rewardJson(id: 'f', familyId: 'family-1'),
            ],
            currentPage: 1,
            lastPage: 2,
            total: 3,
          ),
        ),
      );

      final page = await repo.listRewards(familyId: 'family-1');
      expect(page.items.map((r) => r.id), ['g', 'f']);
      expect(page.items.first.isGlobal, isTrue);
      expect(page.meta.hasMore, isTrue);
      expect(
        api.lastRequest.uri.queryParameters.containsKey('include_inactive'),
        isFalse,
      );
    },
  );

  test('listRewards forwards include_inactive', () async {
    api.adapter.onGet(
      rewards,
      (s) => s.reply(200, Fixtures.rewardsPage(const [])),
    );
    await repo.listRewards(familyId: 'family-1', includeInactive: true);
    expect(api.lastRequest.uri.queryParameters['include_inactive'], 'true');
  });

  test('createReward: POST with the payload', () async {
    api.adapter.onPost(
      rewards,
      (s) => s.reply(
        201,
        Fixtures.rewardEnvelope(reward: Fixtures.rewardJson(id: 'new')),
      ),
      data: Matchers.any,
    );
    final r = await repo.createReward(
      'family-1',
      RewardCreateInput(
        title: 'Screen',
        type: RewardType.screenTime,
        pointsCost: 100,
        screenTimeMinutes: 30,
      ),
    );
    final body = api.lastRequest.data as Map<String, dynamic>;
    expect(r.id, 'new');
    expect(body['type'], 'screen_time');
    expect(body['metadata'], {'minutes': 30});
  });

  test('updateReward: PATCH /rewards/{id}', () async {
    api.adapter.onPatch(
      '$rewards/r1',
      (s) => s.reply(
        200,
        Fixtures.rewardEnvelope(
          reward: Fixtures.rewardJson(id: 'r1', title: 'Renamed'),
        ),
      ),
      data: Matchers.any,
    );
    final r = await repo.updateReward(
      'family-1',
      'r1',
      const RewardUpdateInput(title: 'Renamed'),
    );
    expect(r.title, 'Renamed');
    expect(api.lastRequest.method, 'PATCH');
  });

  test('deleteReward: DELETE /rewards/{id}', () async {
    api.adapter.onDelete(
      '$rewards/r1',
      (s) => s.reply(
        200,
        Fixtures.messageEnvelope('Reward deleted successfully.'),
      ),
    );
    await repo.deleteReward('family-1', 'r1');
    expect(api.lastRequest.method, 'DELETE');
  });

  test('editing a global template → 404 (read-only)', () async {
    api.adapter.onPatch(
      '$rewards/global-1',
      (s) => s.reply(404, {'success': false, 'message': 'Resource not found.'}),
      data: Matchers.any,
    );
    final e = await capture(
      () => repo.updateReward(
        'family-1',
        'global-1',
        const RewardUpdateInput(title: 'x'),
      ),
    );
    expect(e.kind, ApiErrorKind.notFound);
  });

  test('createReward without manage_rewards → 403', () async {
    api.adapter.onPost(
      rewards,
      (s) => s.reply(403, {
        'success': false,
        'message': 'This action is unauthorized.',
      }),
      data: Matchers.any,
    );
    final e = await capture(
      () => repo.createReward(
        'family-1',
        RewardCreateInput(
          title: 'x',
          type: RewardType.privilege,
          pointsCost: 5,
        ),
      ),
    );
    expect(e.kind, ApiErrorKind.forbidden);
  });

  test('listRedemptions: GET child-scoped, paginated', () async {
    api.adapter.onGet(
      redemptions,
      (s) => s.reply(
        200,
        Fixtures.redemptionsPage([
          Fixtures.redemptionJson(id: 'a'),
          Fixtures.redemptionJson(id: 'b'),
        ]),
      ),
    );
    final page = await repo.listRedemptions(
      familyId: 'family-1',
      childId: 'child-1',
    );
    expect(page.items.map((r) => r.id), ['a', 'b']);
  });

  test('requestRedemption: POST {reward_id}', () async {
    api.adapter.onPost(
      redemptions,
      (s) => s.reply(201, Fixtures.redemptionEnvelope()),
      data: Matchers.any,
    );
    final r = await repo.requestRedemption(
      'family-1',
      'child-1',
      const RedemptionRequestInput(rewardId: 'rw-1'),
    );
    expect(r.isPending, isTrue);
    expect((api.lastRequest.data as Map)['reward_id'], 'rw-1');
  });

  test('approve / reject / cancel post to the right sub-path', () async {
    for (final verb in ['approve', 'reject', 'cancel']) {
      api.adapter.onPost(
        '$redemptions/x1/$verb',
        (s) => s.reply(200, Fixtures.redemptionEnvelope()),
        data: Matchers.any,
      );
    }
    await repo.approveRedemption(
      'family-1',
      'child-1',
      'x1',
      const ReviewInput(),
    );
    expect(api.lastRequest.uri.path, endsWith('/x1/approve'));
    await repo.rejectRedemption(
      'family-1',
      'child-1',
      'x1',
      const ReviewInput(note: 'no'),
    );
    expect(api.lastRequest.uri.path, endsWith('/x1/reject'));
    await repo.cancelRedemption(
      'family-1',
      'child-1',
      'x1',
      const ReviewInput(),
    );
    expect(api.lastRequest.uri.path, endsWith('/x1/cancel'));
  });

  test('approve returns the embedded screen_time_override', () async {
    api.adapter.onPost(
      '$redemptions/x1/approve',
      (s) => s.reply(
        200,
        Fixtures.redemptionEnvelope(
          redemption: Fixtures.redemptionJson(
            id: 'x1',
            status: 'approved',
            rewardType: 'screen_time',
            deductionTxnId: 'd',
            screenTimeOverride: Fixtures.screenTimeOverrideJson(
              additionalMinutes: 45,
            ),
          ),
        ),
      ),
      data: Matchers.any,
    );
    final r = await repo.approveRedemption(
      'family-1',
      'child-1',
      'x1',
      const ReviewInput(),
    );
    expect(r.screenTimeOverride!.additionalMinutes, 45);
  });

  group('domain errors', () {
    test('duplicate pending redemption → 409', () async {
      api.adapter.onPost(
        redemptions,
        (s) => s.reply(409, {
          'success': false,
          'message': 'There is already a pending redemption for this reward.',
        }),
        data: Matchers.any,
      );
      final e = await capture(
        () => repo.requestRedemption(
          'family-1',
          'child-1',
          const RedemptionRequestInput(rewardId: 'rw-1'),
        ),
      );
      expect(e.kind, ApiErrorKind.conflict);
    });

    test('inactive reward on request → 422', () async {
      api.adapter.onPost(
        redemptions,
        (s) => s.reply(
          422,
          Fixtures.validationError(
            errors: {
              'reward_id': ['This reward is not available.'],
            },
          ),
        ),
        data: Matchers.any,
      );
      final e = await capture(
        () => repo.requestRedemption(
          'family-1',
          'child-1',
          const RedemptionRequestInput(rewardId: 'rw-1'),
        ),
      );
      expect(e.kind, ApiErrorKind.validation);
      expect(e.fieldError('reward_id'), contains('not available'));
    });

    test('insufficient balance on approval → 422', () async {
      api.adapter.onPost(
        '$redemptions/x1/approve',
        (s) => s.reply(422, {
          'success': false,
          'message': 'The child does not have enough points for this reward.',
        }),
        data: Matchers.any,
      );
      final e = await capture(
        () => repo.approveRedemption(
          'family-1',
          'child-1',
          'x1',
          const ReviewInput(),
        ),
      );
      expect(e.kind, ApiErrorKind.validation);
    });

    test('already-reviewed redemption → 409', () async {
      api.adapter.onPost(
        '$redemptions/x1/approve',
        (s) => s.reply(409, {
          'success': false,
          'message': 'This redemption has already been reviewed.',
        }),
        data: Matchers.any,
      );
      final e = await capture(
        () => repo.approveRedemption(
          'family-1',
          'child-1',
          'x1',
          const ReviewInput(),
        ),
      );
      expect(e.kind, ApiErrorKind.conflict);
    });

    test('cancel a non-approved redemption → 409', () async {
      api.adapter.onPost(
        '$redemptions/x1/cancel',
        (s) => s.reply(409, {
          'success': false,
          'message': 'Only an approved redemption can be cancelled.',
        }),
        data: Matchers.any,
      );
      final e = await capture(
        () => repo.cancelRedemption(
          'family-1',
          'child-1',
          'x1',
          const ReviewInput(),
        ),
      );
      expect(e.kind, ApiErrorKind.conflict);
    });

    test('redemption for a cross-family child → 404', () async {
      api.adapter.onGet(
        redemptions,
        (s) =>
            s.reply(404, {'success': false, 'message': 'Resource not found.'}),
      );
      final e = await capture(
        () => repo.listRedemptions(familyId: 'family-1', childId: 'child-1'),
      );
      expect(e.kind, ApiErrorKind.notFound);
    });
  });
}
