import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/sleep/data/models/sleep_log.dart';
import 'package:my_app/features/sleep/data/sleep_repository.dart';
import 'package:my_app/features/sleep/data/sleep_requests.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  late SleepRepository repo;
  const base = '/families/family-1/children/child-1/sleep-logs';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
    repo = api.container.read(sleepRepositoryProvider);
  });
  tearDown(() => api.dispose());

  test('list sends page/per_page and parses pagination', () async {
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.sleepLogsPage(
          [Fixtures.sleepLogJson(id: 's1'), Fixtures.sleepLogJson(id: 's2')],
          currentPage: 1,
          lastPage: 2,
          total: 5,
        ),
      ),
    );

    final page = await repo.list(familyId: 'family-1', childId: 'child-1');
    expect(page.items.map((l) => l.id), ['s1', 's2']);
    expect(page.meta.hasMore, isTrue);
    expect(api.lastRequest.uri.queryParameters['per_page'], '20');
  });

  test('create POSTs UTC ISO timestamps + source, returns the log', () async {
    api.adapter.onPost(
      base,
      (s) => s.reply(
        201,
        Fixtures.sleepLogEnvelope(log: Fixtures.sleepLogJson(id: 'new')),
      ),
      data: Matchers.any,
    );

    final log = await repo.create(
      'family-1',
      'child-1',
      SleepLogInput(
        startedAt: DateTime(2026, 9, 6, 21, 30),
        endedAt: DateTime(2026, 9, 7, 7, 0),
        source: SleepSource.manual,
      ),
    );

    final body = api.lastRequest.data as Map<String, dynamic>;
    expect(log.id, 'new');
    expect(body['source'], 'manual');
    expect(DateTime.parse(body['started_at'] as String).isUtc, isTrue);
    expect(
      body.containsKey('duration_minutes'),
      isFalse,
      reason: 'duration is server-derived',
    );
  });

  test('update issues a PATCH with both timestamps', () async {
    api.adapter.onPatch(
      '$base/s1',
      (s) => s.reply(
        200,
        Fixtures.sleepLogEnvelope(log: Fixtures.sleepLogJson(id: 's1')),
      ),
      data: Matchers.any,
    );

    await repo.update(
      'family-1',
      'child-1',
      's1',
      SleepLogInput(
        startedAt: DateTime(2026, 9, 6, 22),
        endedAt: DateTime(2026, 9, 7, 6),
      ),
    );

    expect(api.lastRequest.method, 'PATCH');
    final body = api.lastRequest.data as Map<String, dynamic>;
    expect(body.keys.toSet(), {'started_at', 'ended_at'});
  });

  test('delete issues a DELETE', () async {
    api.adapter.onDelete(
      '$base/s1',
      (s) => s.reply(
        200,
        Fixtures.messageEnvelope('Sleep log deleted successfully.'),
      ),
    );
    await repo.delete('family-1', 'child-1', 's1');
    expect(api.lastRequest.method, 'DELETE');
  });

  test('summary forwards the period param and parses the shape', () async {
    api.adapter.onGet(
      '$base/summary',
      (s) => s.reply(200, Fixtures.sleepSummaryEnvelope(period: 'monthly')),
    );

    final summary = await repo.summary(
      familyId: 'family-1',
      childId: 'child-1',
      period: 'monthly',
    );
    expect(summary.period, 'monthly');
    expect(summary.averageSleepMinutes, 570);
    expect(api.lastRequest.uri.queryParameters['period'], 'monthly');
  });

  test('overlapping period → 409 conflict', () async {
    api.adapter.onPost(
      base,
      (s) => s.reply(409, {
        'success': false,
        'message':
            'This sleep period overlaps an existing sleep log for this child.',
      }),
      data: Matchers.any,
    );
    final err = await _capture(
      () => repo.create(
        'family-1',
        'child-1',
        SleepLogInput(
          startedAt: DateTime(2026, 9, 6, 21),
          endedAt: DateTime(2026, 9, 7, 7),
        ),
      ),
    );
    expect(err.kind, ApiErrorKind.conflict);
  });

  test('invalid range → 422 with a started_at field error', () async {
    api.adapter.onPost(
      base,
      (s) => s.reply(
        422,
        Fixtures.validationError(
          errors: {
            'started_at': [
              'The started at field must be a date before ended at.',
            ],
          },
        ),
      ),
      data: Matchers.any,
    );
    final err = await _capture(
      () => repo.create(
        'family-1',
        'child-1',
        SleepLogInput(
          startedAt: DateTime(2026, 9, 7, 7),
          endedAt: DateTime(2026, 9, 6, 21),
        ),
      ),
    );
    expect(err.kind, ApiErrorKind.validation);
    expect(err.fieldError('started_at'), contains('before ended at'));
  });

  test('caregiver without manage_sleep → 403', () async {
    api.adapter.onPost(
      base,
      (s) => s.reply(403, {
        'success': false,
        'message': 'This action is unauthorized.',
      }),
      data: Matchers.any,
    );
    final err = await _capture(
      () => repo.create(
        'family-1',
        'child-1',
        SleepLogInput(
          startedAt: DateTime(2026, 9, 6, 21),
          endedAt: DateTime(2026, 9, 7, 7),
        ),
      ),
    );
    expect(err.kind, ApiErrorKind.forbidden);
  });

  test('log not belonging to child → 404', () async {
    api.adapter.onGet(
      '$base/ghost',
      (s) => s.reply(404, {'success': false, 'message': 'Resource not found.'}),
    );
    final err = await _capture(() => repo.show('family-1', 'child-1', 'ghost'));
    expect(err.kind, ApiErrorKind.notFound);
  });
}

Future<ApiException> _capture(Future<void> Function() action) async {
  try {
    await action();
    fail('expected an ApiException');
  } on ApiException catch (e) {
    return e;
  }
}
