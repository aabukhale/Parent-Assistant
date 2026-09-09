import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/tasks/application/points_controller.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  const c = '/families/family-1/children/child-1';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
  });
  tearDown(() => api.dispose());

  test('balance loads from the endpoint', () async {
    api.adapter.onGet(
      '$c/points-balance',
      (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 240)),
    );
    final sub = api.container.listen(pointsBalanceProvider, (_, _) {});
    addTearDown(sub.close);
    final b = await api.container.read(pointsBalanceProvider.future);
    expect(b.balance, 240);
  });

  test('balance re-fetches on child switch (no stale value)', () async {
    api.adapter
      ..onGet(
        '$c/points-balance',
        (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 10)),
      )
      ..onGet(
        '/families/family-1/children/child-2/points-balance',
        (s) => s.reply(
          200,
          Fixtures.pointsBalanceEnvelope(childId: 'child-2', balance: 99),
        ),
      );

    var sub = api.container.listen(pointsBalanceProvider, (_, _) {});
    addTearDown(sub.close);
    expect(
      (await api.container.read(pointsBalanceProvider.future)).balance,
      10,
    );

    api.setSelectedChild('child-2');
    expect(
      (await api.container.read(pointsBalanceProvider.future)).balance,
      99,
    );
  });

  group('transactions', () {
    Future<PointsTxState> settle() async {
      for (var i = 0; i < 40; i++) {
        final s = api.container.read(pointsTxControllerProvider);
        if (s.hasValue && !s.isLoading) return s.requireValue;
        await Future<void>.delayed(Duration.zero);
      }
      return api.container.read(pointsTxControllerProvider).requireValue;
    }

    test('loads newest-first ledger', () async {
      api.adapter.onGet(
        '$c/point-transactions',
        (s) => s.reply(
          200,
          Fixtures.pointTxPage([
            Fixtures.pointTxJson(id: 'a', amount: 10),
            Fixtures.pointTxJson(id: 'b', amount: -10, type: 'task_reversal'),
          ]),
        ),
      );
      final state = await settle();
      expect(state.transactions.map((t) => t.id), ['a', 'b']);
    });

    test('loadMore appends', () async {
      api.adapter.onGet(
        '$c/point-transactions',
        (s) => s.reply(
          200,
          Fixtures.pointTxPage(
            [Fixtures.pointTxJson(id: 'p1')],
            currentPage: 1,
            lastPage: 2,
            total: 2,
          ),
        ),
      );
      await settle();
      api.adapter.onGet(
        '$c/point-transactions',
        (s) => s.reply(
          200,
          Fixtures.pointTxPage(
            [Fixtures.pointTxJson(id: 'p2')],
            currentPage: 2,
            lastPage: 2,
            total: 2,
          ),
        ),
      );
      await api.container.read(pointsTxControllerProvider.notifier).loadMore();
      expect(
        api.container
            .read(pointsTxControllerProvider)
            .requireValue
            .transactions
            .map((t) => t.id),
        ['p1', 'p2'],
      );
    });

    test('family switch reloads the ledger', () async {
      api.adapter
        ..onGet(
          '$c/point-transactions',
          (s) => s.reply(
            200,
            Fixtures.pointTxPage([Fixtures.pointTxJson(id: 'f1')]),
          ),
        )
        ..onGet(
          '/families/family-2/children/child-1/point-transactions',
          (s) => s.reply(
            200,
            Fixtures.pointTxPage([Fixtures.pointTxJson(id: 'f2')]),
          ),
        );
      expect((await settle()).transactions.single.id, 'f1');
      api.setActiveFamily('family-2');
      expect((await settle()).transactions.single.id, 'f2');
    });
  });
}
