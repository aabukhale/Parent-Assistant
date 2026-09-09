import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/tasks/application/task_detail_controller.dart';
import 'package:my_app/features/tasks/application/tasks_controller.dart';
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

  Future<TasksListState> settle() async {
    for (var i = 0; i < 60; i++) {
      final s = api.container.read(tasksControllerProvider);
      if (s.hasValue && !s.isLoading) return s.requireValue;
      await Future<void>.delayed(Duration.zero);
    }
    return api.container.read(tasksControllerProvider).requireValue;
  }

  test('empty scope → empty, no request', () async {
    final noChild = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
    addTearDown(noChild.dispose);
    for (var i = 0; i < 20; i++) {
      if (noChild.container.read(tasksControllerProvider).hasValue) break;
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      noChild.container.read(tasksControllerProvider).requireValue.tasks,
      isEmpty,
    );
    expect(
      noChild.requests.where((r) => r.uri.path.endsWith('/tasks')),
      isEmpty,
    );
  });

  test('initial load', () async {
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(
        200,
        Fixtures.tasksPage([
          Fixtures.taskJson(id: 't1'),
          Fixtures.taskJson(id: 't2'),
        ]),
      ),
    );
    expect((await settle()).tasks.map((t) => t.id), ['t1', 't2']);
  });

  test('child switch reloads and drops previous tasks', () async {
    api.adapter
      ..onGet(
        '$c/tasks',
        (s) => s.reply(200, Fixtures.tasksPage([Fixtures.taskJson(id: 'c1')])),
      )
      ..onGet(
        '/families/family-1/children/child-2/tasks',
        (s) => s.reply(
          200,
          Fixtures.tasksPage([Fixtures.taskJson(id: 'c2', childId: 'child-2')]),
        ),
      );
    expect((await settle()).tasks.single.id, 'c1');
    api.setSelectedChild('child-2');
    expect((await settle()).tasks.single.id, 'c2');
  });

  test('family switch reloads', () async {
    api.adapter
      ..onGet(
        '$c/tasks',
        (s) => s.reply(200, Fixtures.tasksPage([Fixtures.taskJson(id: 'f1')])),
      )
      ..onGet(
        '/families/family-2/children/child-1/tasks',
        (s) => s.reply(200, Fixtures.tasksPage([Fixtures.taskJson(id: 'f2')])),
      );
    expect((await settle()).tasks.single.id, 'f1');
    api.setActiveFamily('family-2');
    expect((await settle()).tasks.single.id, 'f2');
  });

  test('loadMore appends the next page', () async {
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(
        200,
        Fixtures.tasksPage(
          [Fixtures.taskJson(id: 'p1')],
          currentPage: 1,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await settle();
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(
        200,
        Fixtures.tasksPage(
          [Fixtures.taskJson(id: 'p2')],
          currentPage: 2,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await api.container.read(tasksControllerProvider.notifier).loadMore();
    expect(
      api.container
          .read(tasksControllerProvider)
          .requireValue
          .tasks
          .map((t) => t.id),
      ['p1', 'p2'],
    );
  });

  test('setStatusFilter refetches', () async {
    api.adapter.onGet(
      '$c/tasks',
      (s) =>
          s.reply(200, Fixtures.tasksPage([Fixtures.taskJson(id: 'active')])),
    );
    await settle();
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(
        200,
        Fixtures.tasksPage([Fixtures.taskJson(id: 'arch', status: 'archived')]),
      ),
    );
    await api.container
        .read(tasksControllerProvider.notifier)
        .setStatusFilter('archived');
    await settle();
    expect(
      api.container.read(tasksControllerProvider).requireValue.statusFilter,
      'archived',
    );
    expect(api.lastRequest.uri.queryParameters['status'], 'archived');
  });

  test('createTask refreshes the list', () async {
    api.adapter.onGet(
      '$c/tasks',
      (s) =>
          s.reply(200, Fixtures.tasksPage([Fixtures.taskJson(id: 'existing')])),
    );
    await settle();
    api.adapter
      ..onPost(
        '$c/tasks',
        (s) => s.reply(
          201,
          Fixtures.taskEnvelope(task: Fixtures.taskJson(id: 'made')),
        ),
        data: Matchers.any,
      )
      ..onGet(
        '$c/tasks',
        (s) => s.reply(
          200,
          Fixtures.tasksPage([
            Fixtures.taskJson(id: 'made'),
            Fixtures.taskJson(id: 'existing'),
          ]),
        ),
      );
    await api.container
        .read(tasksControllerProvider.notifier)
        .createTask(
          TaskCreateInput(
            title: 'N',
            points: 5,
            recurrenceType: TaskRecurrence.daily,
          ),
        );
    expect(
      api.container
          .read(tasksControllerProvider)
          .requireValue
          .tasks
          .map((t) => t.id),
      contains('made'),
    );
  });

  test(
    'archiveTask refreshes list + invalidates the detail provider',
    () async {
      api.adapter
        ..onGet(
          '$c/tasks',
          (s) =>
              s.reply(200, Fixtures.tasksPage([Fixtures.taskJson(id: 't1')])),
        )
        ..onGet(
          '$c/tasks/t1',
          (s) => s.reply(
            200,
            Fixtures.taskEnvelope(task: Fixtures.taskJson(id: 't1')),
          ),
        );
      await settle();
      await api.container.read(taskDetailProvider('t1').future);

      api.adapter
        ..onDelete(
          '$c/tasks/t1',
          (s) => s.reply(
            200,
            Fixtures.taskEnvelope(
              task: Fixtures.taskJson(id: 't1', status: 'archived'),
            ),
          ),
        )
        ..onGet('$c/tasks', (s) => s.reply(200, Fixtures.tasksPage(const [])))
        ..onGet(
          '$c/tasks/t1',
          (s) => s.reply(
            200,
            Fixtures.taskEnvelope(
              task: Fixtures.taskJson(id: 't1', status: 'archived'),
            ),
          ),
        );

      await api.container
          .read(tasksControllerProvider.notifier)
          .archiveTask('t1');
      await Future<void>.delayed(Duration.zero);

      expect(
        api.container.read(tasksControllerProvider).requireValue.tasks,
        isEmpty,
      );
      final refreshed = await api.container.read(
        taskDetailProvider('t1').future,
      );
      expect(refreshed.status, TaskStatus.archived);
    },
  );
}
