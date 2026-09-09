import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/rewards/application/rewards_controller.dart';
import 'package:my_app/features/rewards/data/models/reward_enums.dart';
import 'package:my_app/features/rewards/data/reward_requests.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  const rewards = '/families/family-1/rewards';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
  });
  tearDown(() => api.dispose());

  Future<RewardsListState> settle() async {
    for (var i = 0; i < 60; i++) {
      final s = api.container.read(rewardsControllerProvider);
      if (s.hasValue && !s.isLoading) return s.requireValue;
      await Future<void>.delayed(Duration.zero);
    }
    return api.container.read(rewardsControllerProvider).requireValue;
  }

  test('no family → empty, no request', () async {
    final noFamily = TestApi.create(token: 'tok');
    addTearDown(noFamily.dispose);
    for (var i = 0; i < 20; i++) {
      if (noFamily.container.read(rewardsControllerProvider).hasValue) break;
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      noFamily.container.read(rewardsControllerProvider).requireValue.rewards,
      isEmpty,
    );
    expect(
      noFamily.requests.where((r) => r.uri.path.endsWith('/rewards')),
      isEmpty,
    );
  });

  test('loads catalog and splits global vs family', () async {
    api.adapter.onGet(
      rewards,
      (s) => s.reply(
        200,
        Fixtures.rewardsPage([
          Fixtures.rewardJson(id: 'g', familyId: null),
          Fixtures.rewardJson(id: 'f', familyId: 'family-1'),
        ]),
      ),
    );
    final state = await settle();
    expect(state.global.map((r) => r.id), ['g']);
    expect(state.family.map((r) => r.id), ['f']);
  });

  test('family switch reloads the catalog', () async {
    api.adapter
      ..onGet(
        rewards,
        (s) =>
            s.reply(200, Fixtures.rewardsPage([Fixtures.rewardJson(id: 'f1')])),
      )
      ..onGet(
        '/families/family-2/rewards',
        (s) => s.reply(
          200,
          Fixtures.rewardsPage([
            Fixtures.rewardJson(id: 'f2', familyId: 'family-2'),
          ]),
        ),
      );
    expect((await settle()).rewards.single.id, 'f1');
    api.setActiveFamily('family-2');
    expect((await settle()).rewards.single.id, 'f2');
  });

  test('setIncludeInactive refetches with the flag', () async {
    api.adapter.onGet(
      rewards,
      (s) => s.reply(200, Fixtures.rewardsPage([Fixtures.rewardJson(id: 'a')])),
    );
    await settle();
    api.adapter.onGet(
      rewards,
      (s) => s.reply(
        200,
        Fixtures.rewardsPage([
          Fixtures.rewardJson(id: 'a'),
          Fixtures.rewardJson(id: 'b', isActive: false),
        ]),
      ),
    );
    await api.container
        .read(rewardsControllerProvider.notifier)
        .setIncludeInactive(true);
    await settle();
    expect(
      api.container.read(rewardsControllerProvider).requireValue.rewards,
      hasLength(2),
    );
    expect(api.lastRequest.uri.queryParameters['include_inactive'], 'true');
  });

  test('createReward / updateReward / deleteReward refresh the list', () async {
    api.adapter.onGet(
      rewards,
      (s) => s.reply(200, Fixtures.rewardsPage([Fixtures.rewardJson(id: 'a')])),
    );
    await settle();

    api.adapter
      ..onPost(
        rewards,
        (s) => s.reply(
          201,
          Fixtures.rewardEnvelope(reward: Fixtures.rewardJson(id: 'made')),
        ),
        data: Matchers.any,
      )
      ..onGet(
        rewards,
        (s) => s.reply(
          200,
          Fixtures.rewardsPage([
            Fixtures.rewardJson(id: 'made'),
            Fixtures.rewardJson(id: 'a'),
          ]),
        ),
      );
    await api.container
        .read(rewardsControllerProvider.notifier)
        .createReward(
          RewardCreateInput(
            title: 'N',
            type: RewardType.privilege,
            pointsCost: 10,
          ),
        );
    expect(
      api.container
          .read(rewardsControllerProvider)
          .requireValue
          .rewards
          .map((r) => r.id),
      contains('made'),
    );

    api.adapter
      ..onDelete(
        '$rewards/made',
        (s) => s.reply(200, Fixtures.messageEnvelope('deleted')),
      )
      ..onGet(
        rewards,
        (s) =>
            s.reply(200, Fixtures.rewardsPage([Fixtures.rewardJson(id: 'a')])),
      );
    await api.container
        .read(rewardsControllerProvider.notifier)
        .deleteReward('made');
    expect(
      api.container
          .read(rewardsControllerProvider)
          .requireValue
          .rewards
          .map((r) => r.id),
      ['a'],
    );
  });

  test('loadMore appends', () async {
    api.adapter.onGet(
      rewards,
      (s) => s.reply(
        200,
        Fixtures.rewardsPage(
          [Fixtures.rewardJson(id: 'p1')],
          currentPage: 1,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await settle();
    api.adapter.onGet(
      rewards,
      (s) => s.reply(
        200,
        Fixtures.rewardsPage(
          [Fixtures.rewardJson(id: 'p2')],
          currentPage: 2,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await api.container.read(rewardsControllerProvider.notifier).loadMore();
    expect(
      api.container
          .read(rewardsControllerProvider)
          .requireValue
          .rewards
          .map((r) => r.id),
      ['p1', 'p2'],
    );
  });
}
