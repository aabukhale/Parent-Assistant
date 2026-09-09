import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/sleep/application/sleep_log_detail_controller.dart';
import 'package:my_app/features/sleep/application/sleep_logs_controller.dart';
import 'package:my_app/features/sleep/application/sleep_summary_controller.dart';
import 'package:my_app/features/sleep/data/sleep_requests.dart';
import 'package:my_app/features/sleep/data/models/sleep_log.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  const base = '/families/family-1/children/child-1/sleep-logs';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
  });
  tearDown(() => api.dispose());

  Future<SleepLogsListState> settle() async {
    for (var i = 0; i < 60; i++) {
      final s = api.container.read(sleepLogsControllerProvider);
      if (s.hasValue && !s.isLoading) return s.requireValue;
      await Future<void>.delayed(Duration.zero);
    }
    return api.container.read(sleepLogsControllerProvider).requireValue;
  }

  test('empty scope (no selected child) → empty, no request', () async {
    final noChild = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
    addTearDown(noChild.dispose);
    final state = await () async {
      for (var i = 0; i < 20; i++) {
        final s = noChild.container.read(sleepLogsControllerProvider);
        if (s.hasValue) return s.requireValue;
        await Future<void>.delayed(Duration.zero);
      }
      return noChild.container.read(sleepLogsControllerProvider).requireValue;
    }();
    expect(state.logs, isEmpty);
    expect(
      noChild.requests.where((r) => r.uri.path.contains('sleep-logs')),
      isEmpty,
    );
  });

  test('loads logs for the active family + selected child', () async {
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.sleepLogsPage([
          Fixtures.sleepLogJson(id: 's1'),
          Fixtures.sleepLogJson(id: 's2'),
        ]),
      ),
    );
    final state = await settle();
    expect(state.logs.map((l) => l.id), ['s1', 's2']);
  });

  test('changing the selected child reloads and drops previous logs', () async {
    api.adapter
      ..onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.sleepLogsPage([Fixtures.sleepLogJson(id: 'c1')]),
        ),
      )
      ..onGet(
        '/families/family-1/children/child-2/sleep-logs',
        (s) => s.reply(
          200,
          Fixtures.sleepLogsPage([
            Fixtures.sleepLogJson(id: 'c2', childId: 'child-2'),
          ]),
        ),
      );

    expect((await settle()).logs.single.id, 'c1');
    api.setSelectedChild('child-2');
    expect((await settle()).logs.single.id, 'c2');
  });

  test('changing family reloads', () async {
    api.adapter
      ..onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.sleepLogsPage([Fixtures.sleepLogJson(id: 'f1')]),
        ),
      )
      ..onGet(
        '/families/family-2/children/child-1/sleep-logs',
        (s) => s.reply(
          200,
          Fixtures.sleepLogsPage([Fixtures.sleepLogJson(id: 'f2')]),
        ),
      );

    expect((await settle()).logs.single.id, 'f1');
    api.setActiveFamily('family-2');
    expect((await settle()).logs.single.id, 'f2');
  });

  test('loadMore appends the next page', () async {
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.sleepLogsPage(
          [Fixtures.sleepLogJson(id: 'p1')],
          currentPage: 1,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await settle();
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.sleepLogsPage(
          [Fixtures.sleepLogJson(id: 'p2')],
          currentPage: 2,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await api.container.read(sleepLogsControllerProvider.notifier).loadMore();
    expect(
      api.container
          .read(sleepLogsControllerProvider)
          .requireValue
          .logs
          .map((l) => l.id),
      ['p1', 'p2'],
    );
  });

  test('createLog refreshes the list and invalidates the summary', () async {
    api.adapter
      ..onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.sleepLogsPage([Fixtures.sleepLogJson(id: 'old')]),
        ),
      )
      ..onGet(
        '$base/summary',
        (s) => s.reply(200, Fixtures.sleepSummaryEnvelope(nightsLogged: 1)),
      );
    await settle();

    final sub = api.container.listen(sleepSummaryProvider('weekly'), (_, _) {});
    addTearDown(sub.close);
    await api.container.read(sleepSummaryProvider('weekly').future);

    var summaryFetches = api.requests
        .where((r) => r.uri.path.endsWith('/summary'))
        .length;
    expect(summaryFetches, 1);

    api.adapter
      ..onPost(
        base,
        (s) => s.reply(
          201,
          Fixtures.sleepLogEnvelope(log: Fixtures.sleepLogJson(id: 'made')),
        ),
        data: Matchers.any,
      )
      ..onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.sleepLogsPage([
            Fixtures.sleepLogJson(id: 'made'),
            Fixtures.sleepLogJson(id: 'old'),
          ]),
        ),
      )
      ..onGet(
        '$base/summary',
        (s) => s.reply(200, Fixtures.sleepSummaryEnvelope(nightsLogged: 2)),
      );

    await api.container
        .read(sleepLogsControllerProvider.notifier)
        .createLog(
          SleepLogInput(
            startedAt: DateTime(2026, 9, 6, 21),
            endedAt: DateTime(2026, 9, 7, 7),
            source: SleepSource.manual,
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(
      api.container
          .read(sleepLogsControllerProvider)
          .requireValue
          .logs
          .map((l) => l.id),
      contains('made'),
    );
    // The summary was invalidated → re-fetched.
    final refreshed = await api.container.read(
      sleepSummaryProvider('weekly').future,
    );
    expect(refreshed.nightsLogged, 2);
  });

  test(
    'deleteLog refreshes the list and invalidates the detail provider',
    () async {
      api.adapter
        ..onGet(
          base,
          (s) => s.reply(
            200,
            Fixtures.sleepLogsPage([Fixtures.sleepLogJson(id: 's1')]),
          ),
        )
        ..onGet(
          '$base/s1',
          (s) => s.reply(
            200,
            Fixtures.sleepLogEnvelope(log: Fixtures.sleepLogJson(id: 's1')),
          ),
        );
      await settle();
      final sub = api.container.listen(sleepLogDetailProvider('s1'), (_, _) {});
      addTearDown(sub.close);
      await api.container.read(sleepLogDetailProvider('s1').future);

      api.adapter
        ..onDelete(
          '$base/s1',
          (s) => s.reply(200, Fixtures.messageEnvelope('deleted')),
        )
        ..onGet(base, (s) => s.reply(200, Fixtures.sleepLogsPage(const [])))
        ..onGet(
          '$base/s1',
          (s) => s.reply(404, {
            'success': false,
            'message': 'Resource not found.',
          }),
        );

      await api.container
          .read(sleepLogsControllerProvider.notifier)
          .deleteLog('s1');
      await Future<void>.delayed(Duration.zero);

      expect(
        api.container.read(sleepLogsControllerProvider).requireValue.logs,
        isEmpty,
      );
      // detail re-fetch now 404s
      expect(
        () => api.container.read(sleepLogDetailProvider('s1').future),
        throwsA(anything),
      );
    },
  );
}
