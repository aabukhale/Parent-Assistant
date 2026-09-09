import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/learning_goals/application/learning_goal_detail_controller.dart';
import 'package:my_app/features/learning_goals/application/learning_goals_controller.dart';
import 'package:my_app/features/learning_goals/data/learning_goal_requests.dart';
import 'package:my_app/features/learning_goals/data/models/learning_goal.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  late TestApi api;
  const base = '/families/family-1/children/child-1/learning-goals';

  setUp(() {
    api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
  });
  tearDown(() => api.dispose());

  Future<LearningGoalsListState> settle() async {
    for (var i = 0; i < 60; i++) {
      final s = api.container.read(learningGoalsControllerProvider);
      if (s.hasValue && !s.isLoading) return s.requireValue;
      await Future<void>.delayed(Duration.zero);
    }
    return api.container.read(learningGoalsControllerProvider).requireValue;
  }

  test(
    'empty scope (no selected child) yields an empty list without a request',
    () async {
      final noChild = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(noChild.dispose);

      final state = await () async {
        for (var i = 0; i < 20; i++) {
          final s = noChild.container.read(learningGoalsControllerProvider);
          if (s.hasValue) return s.requireValue;
          await Future<void>.delayed(Duration.zero);
        }
        return noChild.container
            .read(learningGoalsControllerProvider)
            .requireValue;
      }();

      expect(state.goals, isEmpty);
      expect(
        noChild.requests.where((r) => r.uri.path.contains('learning-goals')),
        isEmpty,
      );
    },
  );

  test('loads goals for the active family + selected child', () async {
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.goalsPage([
          Fixtures.goalJson(id: 'g1'),
          Fixtures.goalJson(id: 'g2'),
        ]),
      ),
    );

    final state = await settle();
    expect(state.goals.map((g) => g.id), ['g1', 'g2']);
    expect(state.statusFilter, 'active');
  });

  test(
    'changing the selected child reloads and drops the previous goals',
    () async {
      api.adapter
        ..onGet(
          base,
          (s) => s.reply(
            200,
            Fixtures.goalsPage([Fixtures.goalJson(id: 'c1-goal')]),
          ),
        )
        ..onGet(
          '/families/family-1/children/child-2/learning-goals',
          (s) => s.reply(
            200,
            Fixtures.goalsPage([
              Fixtures.goalJson(id: 'c2-goal', childId: 'child-2'),
            ]),
          ),
        );

      expect((await settle()).goals.single.id, 'c1-goal');

      api.setSelectedChild('child-2');
      expect((await settle()).goals.single.id, 'c2-goal');
    },
  );

  test('changing family reloads', () async {
    api.adapter
      ..onGet(
        base,
        (s) => s.reply(200, Fixtures.goalsPage([Fixtures.goalJson(id: 'f1')])),
      )
      ..onGet(
        '/families/family-2/children/child-1/learning-goals',
        (s) => s.reply(200, Fixtures.goalsPage([Fixtures.goalJson(id: 'f2')])),
      );

    expect((await settle()).goals.single.id, 'f1');
    api.setActiveFamily('family-2');
    expect((await settle()).goals.single.id, 'f2');
  });

  test('loadMore appends the next page', () async {
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.goalsPage(
          [Fixtures.goalJson(id: 'p1')],
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
        Fixtures.goalsPage(
          [Fixtures.goalJson(id: 'p2')],
          currentPage: 2,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await api.container
        .read(learningGoalsControllerProvider.notifier)
        .loadMore();

    final state = api.container
        .read(learningGoalsControllerProvider)
        .requireValue;
    expect(state.goals.map((g) => g.id), ['p1', 'p2']);
    expect(state.hasMore, isFalse);
  });

  test('setStatusFilter refetches with the new status', () async {
    api.adapter.onGet(
      base,
      (s) =>
          s.reply(200, Fixtures.goalsPage([Fixtures.goalJson(id: 'active')])),
    );
    await settle();

    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.goalsPage([Fixtures.goalJson(id: 'arch', status: 'archived')]),
      ),
    );
    await api.container
        .read(learningGoalsControllerProvider.notifier)
        .setStatusFilter('archived');
    await settle();

    expect(
      api.container
          .read(learningGoalsControllerProvider)
          .requireValue
          .statusFilter,
      'archived',
    );
    expect(api.lastRequest.uri.queryParameters['status'], 'archived');
  });

  test('createGoal posts then refreshes the list', () async {
    api.adapter.onGet(
      base,
      (s) =>
          s.reply(200, Fixtures.goalsPage([Fixtures.goalJson(id: 'existing')])),
    );
    await settle();

    api.adapter
      ..onPost(
        base,
        (s) => s.reply(
          201,
          Fixtures.goalEnvelope(goal: Fixtures.goalJson(id: 'made')),
        ),
        data: Matchers.any,
      )
      ..onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.goalsPage([
            Fixtures.goalJson(id: 'made'),
            Fixtures.goalJson(id: 'existing'),
          ]),
        ),
      );

    final goal = await api.container
        .read(learningGoalsControllerProvider.notifier)
        .createGoal(
          LearningGoalCreateInput(
            title: 'New',
            metric: LearningGoalMetric.boolean,
          ),
        );

    expect(goal.id, 'made');
    expect(
      api.container
          .read(learningGoalsControllerProvider)
          .requireValue
          .goals
          .map((g) => g.id),
      contains('made'),
    );
  });

  test(
    'archiveGoal refreshes the list and invalidates the detail provider',
    () async {
      api.adapter
        ..onGet(
          base,
          (s) => s.reply(
            200,
            Fixtures.goalsPage([Fixtures.goalJson(id: 'goal-1')]),
          ),
        )
        ..onGet(
          '$base/goal-1',
          (s) => s.reply(
            200,
            Fixtures.goalEnvelope(goal: Fixtures.goalJson(id: 'goal-1')),
          ),
        );
      await settle();

      // Prime the detail provider.
      await api.container.read(learningGoalDetailProvider('goal-1').future);

      api.adapter
        ..onPost(
          '$base/goal-1/archive',
          (s) => s.reply(
            200,
            Fixtures.goalEnvelope(
              goal: Fixtures.goalJson(id: 'goal-1', status: 'archived'),
            ),
          ),
          data: Matchers.any,
        )
        ..onGet(base, (s) => s.reply(200, Fixtures.goalsPage(const [])))
        ..onGet(
          '$base/goal-1',
          (s) => s.reply(
            200,
            Fixtures.goalEnvelope(
              goal: Fixtures.goalJson(id: 'goal-1', status: 'archived'),
            ),
          ),
        );

      await api.container
          .read(learningGoalsControllerProvider.notifier)
          .archiveGoal('goal-1');
      await Future<void>.delayed(Duration.zero);

      final refreshed = await api.container.read(
        learningGoalDetailProvider('goal-1').future,
      );
      expect(refreshed.status, LearningGoalStatus.archived);
      expect(
        api.container.read(learningGoalsControllerProvider).requireValue.goals,
        isEmpty,
      );
    },
  );
}
