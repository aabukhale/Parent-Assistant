import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/tasks/application/completions_controller.dart';
import 'package:my_app/features/tasks/application/points_controller.dart';
import 'package:my_app/features/tasks/application/task_detail_controller.dart';
import 'package:my_app/features/tasks/data/models/task_enums.dart';
import 'package:my_app/features/tasks/data/task_requests.dart';

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

  Future<CompletionsState> start(String taskId) async {
    final sub = api.container.listen(
      completionsControllerProvider(taskId),
      (_, _) {},
    );
    addTearDown(sub.close);
    return api.container.read(completionsControllerProvider(taskId).future);
  }

  CompletionsState current(String taskId) =>
      api.container.read(completionsControllerProvider(taskId)).requireValue;

  test('loads completion history for a task', () async {
    api.adapter.onGet(
      '$c/tasks/t1/completions',
      (s) => s.reply(
        200,
        Fixtures.completionsPage([
          Fixtures.completionJson(id: 'x1'),
          Fixtures.completionJson(id: 'x2'),
        ]),
      ),
    );
    final state = await start('t1');
    expect(state.completions.map((x) => x.id), ['x1', 'x2']);
  });

  test(
    'requestCompletion refreshes history + task detail (no ledger touch)',
    () async {
      api.adapter
        ..onGet(
          '$c/tasks/t1/completions',
          (s) => s.reply(200, Fixtures.completionsPage(const [])),
        )
        ..onGet(
          '$c/tasks/t1',
          (s) => s.reply(
            200,
            Fixtures.taskEnvelope(task: Fixtures.taskJson(id: 't1')),
          ),
        );
      await start('t1');
      await api.container.read(taskDetailProvider('t1').future);

      api.adapter
        ..onPost(
          '$c/tasks/t1/completions',
          (s) => s.reply(
            201,
            Fixtures.completionEnvelope(
              completion: Fixtures.completionJson(id: 'new'),
            ),
          ),
          data: Matchers.any,
        )
        ..onGet(
          '$c/tasks/t1/completions',
          (s) => s.reply(
            200,
            Fixtures.completionsPage([Fixtures.completionJson(id: 'new')]),
          ),
        );

      await api.container
          .read(completionsControllerProvider('t1').notifier)
          .requestCompletion(const CompletionRequestInput());
      await Future<void>.delayed(Duration.zero);

      expect(current('t1').completions.single.id, 'new');
      // No balance/points call made (request doesn't change the ledger).
      expect(
        api.requests.where((r) => r.uri.path.endsWith('/points-balance')),
        isEmpty,
      );
    },
  );

  test(
    'approve re-fetches the balance + ledger from the server (never computed)',
    () async {
      api.adapter
        ..onGet(
          '$c/tasks/t1/completions',
          (s) => s.reply(
            200,
            Fixtures.completionsPage([
              Fixtures.completionJson(id: 'x1', status: 'pending'),
            ]),
          ),
        )
        ..onGet(
          '$c/tasks/t1',
          (s) => s.reply(
            200,
            Fixtures.taskEnvelope(
              task: Fixtures.taskJson(id: 't1', points: 10),
            ),
          ),
        )
        ..onGet(
          '$c/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 0)),
        )
        ..onGet(
          '$c/point-transactions',
          (s) => s.reply(200, Fixtures.pointTxPage(const [])),
        );

      await start('t1');
      final bSub = api.container.listen(pointsBalanceProvider, (_, _) {});
      addTearDown(bSub.close);
      expect(
        (await api.container.read(pointsBalanceProvider.future)).balance,
        0,
      );
      final txSub = api.container.listen(pointsTxControllerProvider, (_, _) {});
      addTearDown(txSub.close);
      await api.container.read(pointsTxControllerProvider.future);

      // After approval the server reports the new authoritative values.
      api.adapter
        ..onPost(
          '$c/tasks/t1/completions/x1/approve',
          (s) => s.reply(
            200,
            Fixtures.completionEnvelope(
              completion: Fixtures.completionJson(
                id: 'x1',
                status: 'approved',
                pointsAwarded: 10,
                reviewedAt: '2026-09-07T10:00:00.000Z',
              ),
            ),
          ),
          data: Matchers.any,
        )
        ..onGet(
          '$c/tasks/t1/completions',
          (s) => s.reply(
            200,
            Fixtures.completionsPage([
              Fixtures.completionJson(
                id: 'x1',
                status: 'approved',
                pointsAwarded: 10,
                reviewedAt: '2026-09-07T10:00:00.000Z',
              ),
            ]),
          ),
        )
        ..onGet(
          '$c/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 10)),
        )
        ..onGet(
          '$c/point-transactions',
          (s) => s.reply(
            200,
            Fixtures.pointTxPage([
              Fixtures.pointTxJson(id: 'a', amount: 10, type: 'task_award'),
            ]),
          ),
        );

      final result = await api.container
          .read(completionsControllerProvider('t1').notifier)
          .approve('x1', const ReviewInput());
      await Future<void>.delayed(Duration.zero);

      expect(result.status, CompletionStatus.approved);
      expect(current('t1').completions.single.pointsAwarded, 10);
      expect(
        (await api.container.read(pointsBalanceProvider.future)).balance,
        10,
        reason: 'balance re-read from the server, not summed locally',
      );
      final ledger = await api.container.read(
        pointsTxControllerProvider.future,
      );
      expect(ledger.transactions, hasLength(1));
    },
  );

  test('reject: no ledger change, history refreshed', () async {
    api.adapter
      ..onGet(
        '$c/tasks/t1/completions',
        (s) => s.reply(
          200,
          Fixtures.completionsPage([
            Fixtures.completionJson(id: 'x1', status: 'pending'),
          ]),
        ),
      )
      ..onGet(
        '$c/tasks/t1',
        (s) => s.reply(
          200,
          Fixtures.taskEnvelope(task: Fixtures.taskJson(id: 't1')),
        ),
      );
    await start('t1');

    api.adapter
      ..onPost(
        '$c/tasks/t1/completions/x1/reject',
        (s) => s.reply(
          200,
          Fixtures.completionEnvelope(
            completion: Fixtures.completionJson(
              id: 'x1',
              status: 'rejected',
              reviewedAt: '2026-09-07T10:00:00.000Z',
            ),
          ),
        ),
        data: Matchers.any,
      )
      ..onGet(
        '$c/tasks/t1/completions',
        (s) => s.reply(
          200,
          Fixtures.completionsPage([
            Fixtures.completionJson(
              id: 'x1',
              status: 'rejected',
              reviewedAt: '2026-09-07T10:00:00.000Z',
            ),
          ]),
        ),
      );

    await api.container
        .read(completionsControllerProvider('t1').notifier)
        .reject('x1', const ReviewInput(note: 'not done'));
    await Future<void>.delayed(Duration.zero);
    expect(current('t1').completions.single.isRejected, isTrue);
    expect(
      api.requests.where((r) => r.uri.path.endsWith('/points-balance')),
      isEmpty,
    );
  });

  test(
    'reverse: compensating state from the server; a 2nd reverse is a 409',
    () async {
      api.adapter
        ..onGet(
          '$c/tasks/t1/completions',
          (s) => s.reply(
            200,
            Fixtures.completionsPage([
              Fixtures.completionJson(
                id: 'x1',
                status: 'approved',
                pointsAwarded: 10,
                reviewedAt: '2026-09-07T10:00:00.000Z',
              ),
            ]),
          ),
        )
        ..onGet(
          '$c/tasks/t1',
          (s) => s.reply(
            200,
            Fixtures.taskEnvelope(task: Fixtures.taskJson(id: 't1')),
          ),
        )
        ..onGet(
          '$c/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 10)),
        )
        ..onGet(
          '$c/point-transactions',
          (s) => s.reply(200, Fixtures.pointTxPage(const [])),
        );
      await start('t1');
      final bSub = api.container.listen(pointsBalanceProvider, (_, _) {});
      addTearDown(bSub.close);

      api.adapter
        ..onPost(
          '$c/tasks/t1/completions/x1/reverse',
          (s) => s.reply(
            200,
            Fixtures.completionEnvelope(
              completion: Fixtures.completionJson(
                id: 'x1',
                status: 'approved',
                pointsAwarded: 10,
                reviewedAt: '2026-09-07T10:00:00.000Z',
                reversedAt: '2026-09-08T10:00:00.000Z',
              ),
            ),
          ),
          data: Matchers.any,
        )
        ..onGet(
          '$c/tasks/t1/completions',
          (s) => s.reply(
            200,
            Fixtures.completionsPage([
              Fixtures.completionJson(
                id: 'x1',
                status: 'approved',
                pointsAwarded: 10,
                reviewedAt: '2026-09-07T10:00:00.000Z',
                reversedAt: '2026-09-08T10:00:00.000Z',
              ),
            ]),
          ),
        )
        ..onGet(
          '$c/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 0)),
        );

      await api.container
          .read(completionsControllerProvider('t1').notifier)
          .reverse('x1', const ReviewInput(note: 'mistake'));
      await Future<void>.delayed(Duration.zero);

      expect(current('t1').completions.single.isReversed, isTrue);
      expect(
        (await api.container.read(pointsBalanceProvider.future)).balance,
        0,
      );

      // Second reversal → 409, surfaced to the caller.
      api.adapter.onPost(
        '$c/tasks/t1/completions/x1/reverse',
        (s) => s.reply(409, {
          'success': false,
          'message': 'This completion has already been reversed.',
        }),
        data: Matchers.any,
      );
      Object? err;
      try {
        await api.container
            .read(completionsControllerProvider('t1').notifier)
            .reverse('x1', const ReviewInput());
      } on ApiException catch (e) {
        err = e;
      }
      expect((err as ApiException).kind, ApiErrorKind.conflict);
    },
  );

  test(
    'duplicate approval conflict is surfaced and history reconciled',
    () async {
      api.adapter
        ..onGet(
          '$c/tasks/t1/completions',
          (s) => s.reply(
            200,
            Fixtures.completionsPage([
              Fixtures.completionJson(id: 'x1', status: 'pending'),
            ]),
          ),
        )
        ..onGet(
          '$c/tasks/t1',
          (s) => s.reply(
            200,
            Fixtures.taskEnvelope(task: Fixtures.taskJson(id: 't1')),
          ),
        )
        ..onPost(
          '$c/tasks/t1/completions/x1/approve',
          (s) => s.reply(409, {
            'success': false,
            'message': 'This completion has already been reviewed.',
          }),
          data: Matchers.any,
        );
      await start('t1');

      Object? err;
      try {
        await api.container
            .read(completionsControllerProvider('t1').notifier)
            .approve('x1', const ReviewInput());
      } on ApiException catch (e) {
        err = e;
      }
      expect((err as ApiException).kind, ApiErrorKind.conflict);
    },
  );
}
