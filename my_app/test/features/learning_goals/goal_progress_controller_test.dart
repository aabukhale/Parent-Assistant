import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/learning_goals/application/learning_goal_detail_controller.dart';
import 'package:my_app/features/learning_goals/application/learning_goal_progress_controller.dart';
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

  /// Subscribe (keeping the autoDispose provider alive) and wait for the first
  /// value. Call after registering the mock handlers.
  Future<GoalProgressState> start() async {
    final sub = api.container.listen(
      goalProgressControllerProvider('goal-1'),
      (_, _) {},
    );
    addTearDown(sub.close);
    return api.container.read(goalProgressControllerProvider('goal-1').future);
  }

  GoalProgressState current() =>
      api.container.read(goalProgressControllerProvider('goal-1')).requireValue;

  test('loads the goal\'s progress history', () async {
    api.adapter.onGet(
      '$base/goal-1/progress',
      (s) => s.reply(
        200,
        Fixtures.paginated([
          Fixtures.goalProgressJson(id: 'p1'),
          Fixtures.goalProgressJson(id: 'p2'),
        ]),
      ),
    );

    final state = await start();
    expect(state.entries.map((e) => e.id), ['p1', 'p2']);
  });

  test(
    'record posts, refreshes history, reconciles the goals list and detail',
    () async {
      api.adapter
        ..onGet(
          '$base/goal-1/progress',
          (s) => s.reply(
            200,
            Fixtures.paginated([Fixtures.goalProgressJson(id: 'old')]),
          ),
        )
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

      await start();
      // prime list + detail
      await api.container.read(learningGoalsControllerProvider.future);
      await api.container.read(learningGoalDetailProvider('goal-1').future);

      // After recording, everything reports the auto-achieved goal.
      final achieved = Fixtures.goalJson(
        id: 'goal-1',
        currentValue: 20,
        progressPercentage: 100,
        status: 'achieved',
        achievedAt: '2026-02-05T10:00:00.000Z',
      );
      api.adapter
        ..onPost(
          '$base/goal-1/progress',
          (s) => s.reply(201, Fixtures.recordProgressEnvelope(goal: achieved)),
          data: Matchers.any,
        )
        ..onGet(
          '$base/goal-1/progress',
          (s) => s.reply(
            200,
            Fixtures.paginated([
              Fixtures.goalProgressJson(id: 'new', value: 20),
              Fixtures.goalProgressJson(id: 'old'),
            ]),
          ),
        )
        ..onGet(base, (s) => s.reply(200, Fixtures.goalsPage([achieved])))
        ..onGet(
          '$base/goal-1',
          (s) => s.reply(200, Fixtures.goalEnvelope(goal: achieved)),
        );

      final result = await api.container
          .read(goalProgressControllerProvider('goal-1').notifier)
          .record(const LearningGoalProgressInput(value: 20));
      await Future<void>.delayed(Duration.zero);

      expect(result.goal.status, LearningGoalStatus.achieved);
      expect(current().entries.map((e) => e.id), ['new', 'old']);
      final listGoal = api.container
          .read(learningGoalsControllerProvider)
          .requireValue
          .goals
          .single;
      expect(listGoal.status, LearningGoalStatus.achieved);
      final detail = await api.container.read(
        learningGoalDetailProvider('goal-1').future,
      );
      expect(detail.status, LearningGoalStatus.achieved);
    },
  );

  test('loadMore appends the next page of history', () async {
    api.adapter.onGet(
      '$base/goal-1/progress',
      (s) => s.reply(
        200,
        Fixtures.paginated(
          [Fixtures.goalProgressJson(id: 'a')],
          currentPage: 1,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await start();

    api.adapter.onGet(
      '$base/goal-1/progress',
      (s) => s.reply(
        200,
        Fixtures.paginated(
          [Fixtures.goalProgressJson(id: 'b')],
          currentPage: 2,
          lastPage: 2,
          total: 2,
        ),
      ),
    );
    await api.container
        .read(goalProgressControllerProvider('goal-1').notifier)
        .loadMore();

    expect(current().entries.map((e) => e.id), ['a', 'b']);
  });
}
