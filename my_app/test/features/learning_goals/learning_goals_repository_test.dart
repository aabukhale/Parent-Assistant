import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/learning_goals/data/learning_goal_requests.dart';
import 'package:my_app/features/learning_goals/data/learning_goals_repository.dart';
import 'package:my_app/features/learning_goals/data/models/learning_goal.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  late LearningGoalsRepository repo;

  const base = '/families/family-1/children/child-1/learning-goals';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
    repo = api.container.read(learningGoalsRepositoryProvider);
  });
  tearDown(() => api.dispose());

  test(
    'list sends page/per_page, forwards a status filter, parses meta',
    () async {
      api.adapter.onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.goalsPage(
            [Fixtures.goalJson(id: 'g1'), Fixtures.goalJson(id: 'g2')],
            currentPage: 1,
            lastPage: 2,
            total: 8,
          ),
        ),
      );

      final page = await repo.list(
        familyId: 'family-1',
        childId: 'child-1',
        status: 'active',
      );

      expect(page.items.map((g) => g.id), ['g1', 'g2']);
      expect(page.meta.total, 8);
      expect(page.meta.hasMore, isTrue);
      final q = api.lastRequest.uri.queryParameters;
      expect(q['status'], 'active');
      expect(q['page'], '1');
    },
  );

  test('list with status "all" omits the status query param', () async {
    api.adapter.onGet(base, (s) => s.reply(200, Fixtures.goalsPage(const [])));
    await repo.list(familyId: 'family-1', childId: 'child-1', status: 'all');
    expect(api.lastRequest.uri.queryParameters.containsKey('status'), isFalse);
  });

  test('create POSTs the payload and returns the goal', () async {
    api.adapter.onPost(
      base,
      (s) => s.reply(
        201,
        Fixtures.goalEnvelope(goal: Fixtures.goalJson(id: 'new')),
      ),
      data: Matchers.any,
    );

    final goal = await repo.create(
      'family-1',
      'child-1',
      LearningGoalCreateInput(
        title: 'Read',
        metric: LearningGoalMetric.numeric,
        targetValue: 20,
        unit: 'book',
      ),
    );

    final body = api.lastRequest.data as Map<String, dynamic>;
    expect(goal.id, 'new');
    expect(body['metric'], 'numeric');
    expect(body['target_value'], 20);
  });

  test('update issues a PATCH', () async {
    api.adapter.onPatch(
      '$base/goal-1',
      (s) => s.reply(
        200,
        Fixtures.goalEnvelope(goal: Fixtures.goalJson(title: 'Renamed')),
      ),
      data: Matchers.any,
    );

    final goal = await repo.update(
      'family-1',
      'child-1',
      'goal-1',
      const LearningGoalUpdateInput(title: 'Renamed'),
    );
    expect(goal.title, 'Renamed');
    expect(api.lastRequest.method, 'PATCH');
  });

  test('archive POSTs to /archive and returns the archived goal', () async {
    api.adapter.onPost(
      '$base/goal-1/archive',
      (s) => s.reply(
        200,
        Fixtures.goalEnvelope(goal: Fixtures.goalJson(status: 'archived')),
      ),
      data: Matchers.any,
    );

    final goal = await repo.archive('family-1', 'child-1', 'goal-1');
    expect(goal.status, LearningGoalStatus.archived);
    expect(api.lastRequest.uri.path, endsWith('/goal-1/archive'));
  });

  test('progressHistory parses a paginated list', () async {
    api.adapter.onGet(
      '$base/goal-1/progress',
      (s) => s.reply(
        200,
        Fixtures.paginated(
          [
            Fixtures.goalProgressJson(id: 'p1'),
            Fixtures.goalProgressJson(id: 'p2'),
          ],
          currentPage: 1,
          lastPage: 1,
        ),
      ),
    );

    final page = await repo.progressHistory(
      familyId: 'family-1',
      childId: 'child-1',
      goalId: 'goal-1',
    );
    expect(page.items.map((e) => e.id), ['p1', 'p2']);
  });

  test('recordProgress parses the nested {progress, goal} envelope', () async {
    api.adapter.onPost(
      '$base/goal-1/progress',
      (s) => s.reply(201, Fixtures.recordProgressEnvelope()),
      data: Matchers.any,
    );

    final result = await repo.recordProgress(
      'family-1',
      'child-1',
      'goal-1',
      const LearningGoalProgressInput(value: 20),
    );

    expect(result.progress.value, 20);
    expect(result.goal.status, LearningGoalStatus.achieved);
    expect(result.goal.achievedAt, isNotNull);
  });

  test('caregiver without permission → 403 forbidden', () async {
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
        LearningGoalCreateInput(title: 'x', metric: LearningGoalMetric.boolean),
      ),
    );
    expect(err.kind, ApiErrorKind.forbidden);
  });

  test('goal not belonging to child → 404 notFound', () async {
    api.adapter.onGet(
      '$base/ghost',
      (s) => s.reply(404, {'success': false, 'message': 'Resource not found.'}),
    );
    final err = await _capture(() => repo.show('family-1', 'child-1', 'ghost'));
    expect(err.kind, ApiErrorKind.notFound);
  });

  test('422 on create surfaces field errors', () async {
    api.adapter.onPost(
      base,
      (s) => s.reply(
        422,
        Fixtures.validationError(
          errors: {
            'target_value': ['The target value field is required.'],
          },
        ),
      ),
      data: Matchers.any,
    );
    final err = await _capture(
      () => repo.create(
        'family-1',
        'child-1',
        LearningGoalCreateInput(title: 'x', metric: LearningGoalMetric.numeric),
      ),
    );
    expect(err.kind, ApiErrorKind.validation);
    expect(err.fieldError('target_value'), contains('required'));
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
