import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/tasks/data/models/child_task.dart';
import 'package:my_app/features/tasks/data/models/task_enums.dart';
import 'package:my_app/features/tasks/data/task_requests.dart';
import 'package:my_app/features/tasks/data/tasks_repository.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  late TasksRepository repo;
  const c = '/families/family-1/children/child-1';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
    repo = api.container.read(tasksRepositoryProvider);
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

  test('listTasks: GET /tasks with page/per_page/status', () async {
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(
        200,
        Fixtures.tasksPage(
          [Fixtures.taskJson(id: 't1')],
          currentPage: 1,
          lastPage: 2,
          total: 3,
        ),
      ),
    );
    final page = await repo.listTasks(
      familyId: 'family-1',
      childId: 'child-1',
      status: 'active',
    );
    expect(page.items.single.id, 't1');
    expect(page.meta.hasMore, isTrue);
    final q = api.lastRequest.uri.queryParameters;
    expect(q['status'], 'active');
    expect(q['per_page'], '20');
  });

  test('listTasks status "all" omits the filter', () async {
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(200, Fixtures.tasksPage(const [])),
    );
    await repo.listTasks(
      familyId: 'family-1',
      childId: 'child-1',
      status: 'all',
    );
    expect(api.lastRequest.uri.queryParameters.containsKey('status'), isFalse);
  });

  test('showTask: GET /tasks/{id}', () async {
    api.adapter.onGet(
      '$c/tasks/t1',
      (s) => s.reply(
        200,
        Fixtures.taskEnvelope(task: Fixtures.taskJson(id: 't1')),
      ),
    );
    final task = await repo.showTask('family-1', 'child-1', 't1');
    expect(task.id, 't1');
  });

  test('createTask: POST /tasks with the exact JSON', () async {
    api.adapter.onPost(
      '$c/tasks',
      (s) => s.reply(
        201,
        Fixtures.taskEnvelope(task: Fixtures.taskJson(id: 'new')),
      ),
      data: Matchers.any,
    );

    final task = await repo.createTask(
      'family-1',
      'child-1',
      TaskCreateInput(
        title: 'Read',
        points: 15,
        recurrenceType: TaskRecurrence.weekly,
        recurrenceConfig: const RecurrenceConfig(daysOfWeek: [1, 3]),
      ),
    );
    final body = api.lastRequest.data as Map<String, dynamic>;
    expect(task.id, 'new');
    expect(body['recurrence_type'], 'weekly');
    expect(body['recurrence_config'], {
      'days_of_week': [1, 3],
    });
    expect(body['points'], 15);
  });

  test('updateTask: PATCH /tasks/{id}', () async {
    api.adapter.onPatch(
      '$c/tasks/t1',
      (s) => s.reply(
        200,
        Fixtures.taskEnvelope(
          task: Fixtures.taskJson(id: 't1', title: 'Renamed'),
        ),
      ),
      data: Matchers.any,
    );
    final task = await repo.updateTask(
      'family-1',
      'child-1',
      't1',
      const TaskUpdateInput(title: 'Renamed'),
    );
    expect(task.title, 'Renamed');
    expect(api.lastRequest.method, 'PATCH');
  });

  test('archiveTask: DELETE /tasks/{id} → archived task', () async {
    api.adapter.onDelete(
      '$c/tasks/t1',
      (s) => s.reply(
        200,
        Fixtures.taskEnvelope(
          task: Fixtures.taskJson(id: 't1', status: 'archived'),
        ),
      ),
    );
    final task = await repo.archiveTask('family-1', 'child-1', 't1');
    expect(task.status, TaskStatus.archived);
    expect(api.lastRequest.method, 'DELETE');
  });

  test('listCompletions: GET /tasks/{id}/completions paginated', () async {
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
    final page = await repo.listCompletions(
      familyId: 'family-1',
      childId: 'child-1',
      taskId: 't1',
    );
    expect(page.items.map((x) => x.id), ['x1', 'x2']);
  });

  test('requestCompletion: POST /completions', () async {
    api.adapter.onPost(
      '$c/tasks/t1/completions',
      (s) => s.reply(201, Fixtures.completionEnvelope()),
      data: Matchers.any,
    );
    final comp = await repo.requestCompletion(
      'family-1',
      'child-1',
      't1',
      CompletionRequestInput(occurrenceDate: DateTime(2026, 9, 7)),
    );
    expect(comp.isPending, isTrue);
    expect((api.lastRequest.data as Map)['occurrence_date'], '2026-09-07');
  });

  test('approve / reject / reverse post to the right sub-path', () async {
    for (final verb in ['approve', 'reject', 'reverse']) {
      api.adapter.onPost(
        '$c/tasks/t1/completions/x1/$verb',
        (s) => s.reply(200, Fixtures.completionEnvelope()),
        data: Matchers.any,
      );
    }
    await repo.approveCompletion(
      'family-1',
      'child-1',
      't1',
      'x1',
      const ReviewInput(),
    );
    expect(api.lastRequest.uri.path, endsWith('/completions/x1/approve'));
    await repo.rejectCompletion(
      'family-1',
      'child-1',
      't1',
      'x1',
      const ReviewInput(note: 'no'),
    );
    expect(api.lastRequest.uri.path, endsWith('/completions/x1/reject'));
    await repo.reverseCompletion(
      'family-1',
      'child-1',
      't1',
      'x1',
      const ReviewInput(),
    );
    expect(api.lastRequest.uri.path, endsWith('/completions/x1/reverse'));
  });

  test('pointsBalance: GET /points-balance', () async {
    api.adapter.onGet(
      '$c/points-balance',
      (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 55)),
    );
    final b = await repo.pointsBalance('family-1', 'child-1');
    expect(b.balance, 55);
  });

  test('pointTransactions: GET /point-transactions paginated', () async {
    api.adapter.onGet(
      '$c/point-transactions',
      (s) => s.reply(
        200,
        Fixtures.pointTxPage([
          Fixtures.pointTxJson(id: 'a'),
          Fixtures.pointTxJson(id: 'b', amount: -10, type: 'task_reversal'),
        ]),
      ),
    );
    final page = await repo.pointTransactions(
      familyId: 'family-1',
      childId: 'child-1',
    );
    expect(page.items.map((t) => t.id), ['a', 'b']);
    expect(page.items[1].amount, -10);
  });

  group('error mapping', () {
    test('403 on create', () async {
      api.adapter.onPost(
        '$c/tasks',
        (s) => s.reply(403, {
          'success': false,
          'message': 'This action is unauthorized.',
        }),
        data: Matchers.any,
      );
      final e = await capture(
        () => repo.createTask(
          'family-1',
          'child-1',
          TaskCreateInput(
            title: 'x',
            points: 1,
            recurrenceType: TaskRecurrence.daily,
          ),
        ),
      );
      expect(e.kind, ApiErrorKind.forbidden);
    });

    test('404 on show', () async {
      api.adapter.onGet(
        '$c/tasks/ghost',
        (s) =>
            s.reply(404, {'success': false, 'message': 'Resource not found.'}),
      );
      final e = await capture(
        () => repo.showTask('family-1', 'child-1', 'ghost'),
      );
      expect(e.kind, ApiErrorKind.notFound);
    });

    test('409 on completion request (duplicate occurrence)', () async {
      api.adapter.onPost(
        '$c/tasks/t1/completions',
        (s) => s.reply(409, {
          'success': false,
          'message': 'A completion for this occurrence already exists.',
        }),
        data: Matchers.any,
      );
      final e = await capture(
        () => repo.requestCompletion(
          'family-1',
          'child-1',
          't1',
          const CompletionRequestInput(),
        ),
      );
      expect(e.kind, ApiErrorKind.conflict);
    });

    test(
      '409 on approve (already reviewed) / reverse (already reversed)',
      () async {
        api.adapter.onPost(
          '$c/tasks/t1/completions/x1/approve',
          (s) => s.reply(409, {
            'success': false,
            'message': 'This completion has already been reviewed.',
          }),
          data: Matchers.any,
        );
        final e = await capture(
          () => repo.approveCompletion(
            'family-1',
            'child-1',
            't1',
            'x1',
            const ReviewInput(),
          ),
        );
        expect(e.kind, ApiErrorKind.conflict);
      },
    );

    test('422 on completion request (invalid occurrence)', () async {
      api.adapter.onPost(
        '$c/tasks/t1/completions',
        (s) => s.reply(
          422,
          Fixtures.validationError(
            errors: {
              'occurrence_date': [
                'That date is not a scheduled occurrence for this task.',
              ],
            },
          ),
        ),
        data: Matchers.any,
      );
      final e = await capture(
        () => repo.requestCompletion(
          'family-1',
          'child-1',
          't1',
          const CompletionRequestInput(),
        ),
      );
      expect(e.kind, ApiErrorKind.validation);
      expect(
        e.fieldError('occurrence_date'),
        contains('not a scheduled occurrence'),
      );
    });

    test('422 on create (weekly needs a weekday)', () async {
      api.adapter.onPost(
        '$c/tasks',
        (s) => s.reply(
          422,
          Fixtures.validationError(
            errors: {
              'recurrence_config.days_of_week': [
                'Weekly tasks need at least one weekday.',
              ],
            },
          ),
        ),
        data: Matchers.any,
      );
      final e = await capture(
        () => repo.createTask(
          'family-1',
          'child-1',
          TaskCreateInput(
            title: 'x',
            points: 1,
            recurrenceType: TaskRecurrence.weekly,
          ),
        ),
      );
      expect(
        e.fieldError('recurrence_config.days_of_week'),
        contains('at least one weekday'),
      );
    });
  });
}
