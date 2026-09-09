import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/learning_goals/data/learning_goal_requests.dart';
import 'package:my_app/features/learning_goals/data/models/learning_goal.dart';

import '../../support/fixtures.dart';

void main() {
  group('LearningGoal.fromJson', () {
    test(
      'parses enums, backend-computed values, dates and embedded progress',
      () {
        final g = LearningGoal.fromJson(
          Fixtures.goalJson(
            metric: 'numeric',
            targetValue: 20,
            unit: 'book',
            currentValue: 5,
            progressPercentage: 25,
            status: 'active',
            progress: [
              Fixtures.goalProgressJson(id: 'p1', value: 5, note: 'week 1'),
              Fixtures.goalProgressJson(id: 'p2', value: 3),
            ],
          ),
        );

        expect(g.metric, LearningGoalMetric.numeric);
        expect(g.status, LearningGoalStatus.active);
        expect(g.targetValue, 20);
        expect(g.currentValue, 5);
        expect(g.progressPercentage, 25);
        expect(g.progressFraction, 0.25);
        expect(g.startDate, DateTime(2026, 1, 1));
        expect(g.targetDate, DateTime(2026, 6, 30));
        expect(g.progress.map((p) => p.id), ['p1', 'p2']);
        expect(g.progress.first.note, 'week 1');
      },
    );

    test('boolean goal: progressFraction is 0 or 1 from current_value', () {
      final notDone = LearningGoal.fromJson(
        Fixtures.goalJson(
          metric: 'boolean',
          targetValue: null,
          currentValue: 0,
          progressPercentage: null,
        ),
      );
      final done = LearningGoal.fromJson(
        Fixtures.goalJson(
          metric: 'boolean',
          targetValue: null,
          currentValue: 1,
          progressPercentage: null,
        ),
      );

      expect(notDone.metric, LearningGoalMetric.boolean);
      expect(notDone.isBooleanDone, isFalse);
      expect(notDone.progressFraction, 0);
      expect(done.isBooleanDone, isTrue);
      expect(done.progressFraction, 1);
    });

    test(
      'percent goal without positive target has null progress_percentage',
      () {
        final g = LearningGoal.fromJson(
          Fixtures.goalJson(
            metric: 'percent',
            targetValue: null,
            progressPercentage: null,
            currentValue: 40,
          ),
        );
        expect(g.progressPercentage, isNull);
        expect(g.progressFraction, 0);
      },
    );

    test('achieved goal keeps achieved_at', () {
      final g = LearningGoal.fromJson(
        Fixtures.goalJson(
          status: 'achieved',
          achievedAt: '2026-03-01T12:00:00.000Z',
        ),
      );
      expect(g.status, LearningGoalStatus.achieved);
      expect(g.achievedAt, isNotNull);
    });
  });

  group('inputs → toJson', () {
    test('create: numeric sends target_value + unit + dates as YYYY-MM-DD', () {
      final json = LearningGoalCreateInput(
        title: '  Read  ',
        metric: LearningGoalMetric.numeric,
        targetValue: 20,
        unit: 'book',
        startDate: DateTime(2026, 1, 2),
        targetDate: DateTime(2026, 6, 30),
      ).toJson();

      expect(json['title'], 'Read');
      expect(json['metric'], 'numeric');
      expect(json['target_value'], 20);
      expect(json['unit'], 'book');
      expect(json['start_date'], '2026-01-02');
      expect(json['target_date'], '2026-06-30');
    });

    test('create: boolean omits target_value and unit', () {
      final json = LearningGoalCreateInput(
        title: 'Tidy room',
        metric: LearningGoalMetric.boolean,
        targetValue: 5,
        unit: 'x',
      ).toJson();
      expect(json.containsKey('target_value'), isFalse);
      expect(json.containsKey('unit'), isFalse);
    });

    test('create: percent keeps target_value, drops unit', () {
      final json = LearningGoalCreateInput(
        title: 'Fluency',
        metric: LearningGoalMetric.percent,
        targetValue: 100,
        unit: 'x',
      ).toJson();
      expect(json['target_value'], 100);
      expect(json.containsKey('unit'), isFalse);
    });

    test(
      'update: clear flags send explicit nulls; metric/start_date never sent',
      () {
        final json = const LearningGoalUpdateInput(
          title: 'New title',
          clearDescription: true,
          clearTargetDate: true,
          status: LearningGoalStatus.paused,
        ).toJson();

        expect(json['title'], 'New title');
        expect(json.containsKey('description'), isTrue);
        expect(json['description'], isNull);
        expect(json['target_date'], isNull);
        expect(json['status'], 'paused');
        expect(json.containsKey('metric'), isFalse);
        expect(json.containsKey('start_date'), isFalse);
      },
    );

    test(
      'progress: value required, note optional, recorded_at ISO-8601 UTC',
      () {
        final json = LearningGoalProgressInput(
          value: 12,
          note: 'nice',
          recordedAt: DateTime.utc(2026, 2, 1, 9),
        ).toJson();
        expect(json['value'], 12);
        expect(json['note'], 'nice');
        expect(json['recorded_at'], startsWith('2026-02-01T09:00:00'));
      },
    );

    test('progress: omits note and recorded_at when not provided', () {
      final json = const LearningGoalProgressInput(value: 1).toJson();
      expect(json.keys, ['value']);
    });
  });
}
