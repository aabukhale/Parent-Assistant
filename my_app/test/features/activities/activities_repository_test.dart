import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/errors/api_exception.dart';
import 'package:my_app/features/activities/data/activities_repository.dart';
import 'package:my_app/features/activities/data/activity_requests.dart';
import 'package:my_app/features/tasks/data/task_requests.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  late ActivitiesRepository repo;
  const c = '/families/family-1/children/child-1';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
    repo = api.container.read(activitiesRepositoryProvider);
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

  test('listActivities: GET /activities with family_id + paging', () async {
    api.adapter.onGet(
      '/activities',
      (s) => s.reply(
        200,
        Fixtures.activitiesPage([
          Fixtures.activityJson(id: 'g'),
          Fixtures.activityJson(
            id: 'f',
            familyId: 'family-1',
            source: 'family',
          ),
        ]),
      ),
    );
    final page = await repo.listActivities(familyId: 'family-1');
    expect(page.items.map((a) => a.id), ['g', 'f']);
    expect(api.lastRequest.uri.queryParameters['family_id'], 'family-1');
  });

  test('listActivities forwards source/age/interest filters', () async {
    api.adapter.onGet(
      '/activities',
      (s) => s.reply(200, Fixtures.activitiesPage(const [])),
    );
    await repo.listActivities(
      familyId: 'family-1',
      source: 'ai',
      age: 6,
      interestId: 'int-1',
    );
    final q = api.lastRequest.uri.queryParameters;
    expect(q['source'], 'ai');
    expect(q['age'], '6');
    expect(q['interest'], 'int-1');
  });

  test('showActivity: GET /activities/{id}', () async {
    api.adapter.onGet(
      '/activities/a1',
      (s) => s.reply(
        200,
        Fixtures.activityEnvelope(activity: Fixtures.activityJson(id: 'a1')),
      ),
    );
    expect((await repo.showActivity('a1')).id, 'a1');
  });

  test('showActivity 404 for an inaccessible/inactive activity', () async {
    api.adapter.onGet(
      '/activities/x',
      (s) => s.reply(404, {'success': false, 'message': 'Not found.'}),
    );
    final e = await capture(() => repo.showActivity('x'));
    expect(e.kind, ApiErrorKind.notFound);
  });

  test('generate → 503 surfaces as unavailable, never fabricates', () async {
    api.adapter.onPost(
      '$c/activities/generate',
      (s) => s.reply(503, {
        'success': false,
        'message': 'AI activity generation is not configured.',
      }),
      data: Matchers.any,
    );
    final e = await capture(
      () => repo.generate(
        'family-1',
        'child-1',
        const GenerateActivityInput(theme: 'space'),
      ),
    );
    expect(e.kind, ApiErrorKind.unavailable);
  });

  test(
    'listAssignments: GET child-scoped, embeds activity + completions',
    () async {
      api.adapter.onGet(
        '$c/activity-assignments',
        (s) => s.reply(
          200,
          Fixtures.activityAssignmentsPage([
            Fixtures.activityAssignmentJson(id: 'a1'),
            Fixtures.activityAssignmentJson(id: 'a2', pointsReward: 20),
          ]),
        ),
      );
      final page = await repo.listAssignments(
        familyId: 'family-1',
        childId: 'child-1',
      );
      expect(page.items.map((a) => a.id), ['a1', 'a2']);
      expect(page.items[1].requiresApproval, isTrue);
    },
  );

  test('createAssignment: POST body', () async {
    api.adapter.onPost(
      '$c/activity-assignments',
      (s) => s.reply(
        201,
        Fixtures.activityAssignmentEnvelope(
          assignment: Fixtures.activityAssignmentJson(id: 'new'),
        ),
      ),
      data: Matchers.any,
    );
    final a = await repo.createAssignment(
      'family-1',
      'child-1',
      const ActivityAssignInput(activityId: 'act-9', pointsReward: 10),
    );
    expect(a.id, 'new');
    final body = api.lastRequest.data as Map;
    expect(body['activity_id'], 'act-9');
    expect(body['points_reward'], 10);
  });

  test('complete: POST .../complete', () async {
    api.adapter.onPost(
      '$c/activity-assignments/as1/complete',
      (s) => s.reply(
        201,
        Fixtures.activityCompletionEnvelope(
          completion: Fixtures.activityCompletionJson(status: 'approved'),
        ),
      ),
      data: Matchers.any,
    );
    final result = await repo.complete(
      'family-1',
      'child-1',
      'as1',
      const ReviewInput(),
    );
    expect(result.isApproved, isTrue);
  });

  test('approve/reject/reverse post to the right sub-path', () async {
    for (final verb in ['approve', 'reject', 'reverse']) {
      api.adapter.onPost(
        '$c/activity-assignments/as1/completions/c1/$verb',
        (s) => s.reply(200, Fixtures.activityCompletionEnvelope()),
        data: Matchers.any,
      );
    }
    await repo.approve('family-1', 'child-1', 'as1', 'c1', const ReviewInput());
    expect(api.lastRequest.uri.path, endsWith('/c1/approve'));
    await repo.reject('family-1', 'child-1', 'as1', 'c1', const ReviewInput());
    expect(api.lastRequest.uri.path, endsWith('/c1/reject'));
    await repo.reverse('family-1', 'child-1', 'as1', 'c1', const ReviewInput());
    expect(api.lastRequest.uri.path, endsWith('/c1/reverse'));
  });

  test('completing an already-completed assignment → 409', () async {
    api.adapter.onPost(
      '$c/activity-assignments/as1/complete',
      (s) => s.reply(409, {
        'success': false,
        'message': 'This assignment has already been completed.',
      }),
      data: Matchers.any,
    );
    final e = await capture(
      () => repo.complete('family-1', 'child-1', 'as1', const ReviewInput()),
    );
    expect(e.kind, ApiErrorKind.conflict);
  });

  test('assign without manage_activities → 403', () async {
    api.adapter.onPost(
      '$c/activity-assignments',
      (s) => s.reply(403, {
        'success': false,
        'message': 'This action is unauthorized.',
      }),
      data: Matchers.any,
    );
    final e = await capture(
      () => repo.createAssignment(
        'family-1',
        'child-1',
        const ActivityAssignInput(activityId: 'a'),
      ),
    );
    expect(e.kind, ApiErrorKind.forbidden);
  });
}
