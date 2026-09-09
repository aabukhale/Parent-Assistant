import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/api/api_envelope.dart';
import 'package:my_app/features/tasks/data/models/child_task.dart';
import 'package:my_app/features/tasks/data/models/point_transaction.dart';
import 'package:my_app/features/tasks/data/models/task_completion.dart';
import 'package:my_app/features/tasks/data/models/task_enums.dart';
import 'package:my_app/features/tasks/data/task_requests.dart';

import '../../support/fixtures.dart';

void main() {
  group('recurrence', () {
    test('one_time / daily parse with null config', () {
      for (final t in ['one_time', 'daily']) {
        final task = ChildTask.fromJson(Fixtures.taskJson(recurrenceType: t));
        expect(task.recurrenceConfig, isNull);
      }
      expect(
        ChildTask.fromJson(
          Fixtures.taskJson(recurrenceType: 'one_time'),
        ).recurrenceType,
        TaskRecurrence.oneTime,
      );
      expect(
        ChildTask.fromJson(
          Fixtures.taskJson(recurrenceType: 'daily'),
        ).recurrenceType,
        TaskRecurrence.daily,
      );
    });

    test('weekly parses days_of_week', () {
      final task = ChildTask.fromJson(
        Fixtures.taskJson(
          recurrenceType: 'weekly',
          recurrenceConfig: {
            'days_of_week': [1, 3, 5],
          },
        ),
      );
      expect(task.recurrenceType, TaskRecurrence.weekly);
      expect(task.recurrenceConfig!.daysOfWeek, [1, 3, 5]);
    });

    test('custom parses explicit dates', () {
      final task = ChildTask.fromJson(
        Fixtures.taskJson(
          recurrenceType: 'custom',
          recurrenceConfig: {
            'dates': ['2026-09-10', '2026-09-20'],
          },
        ),
      );
      expect(task.recurrenceConfig!.dates, ['2026-09-10', '2026-09-20']);
      expect(task.recurrenceConfig!.isIntervalForm, isFalse);
    });

    test('custom parses interval + anchor', () {
      final task = ChildTask.fromJson(
        Fixtures.taskJson(
          recurrenceType: 'custom',
          recurrenceConfig: {'interval_days': 3, 'anchor_date': '2026-09-01'},
        ),
      );
      expect(task.recurrenceConfig!.intervalDays, 3);
      expect(task.recurrenceConfig!.anchorDate, '2026-09-01');
      expect(task.recurrenceConfig!.isIntervalForm, isTrue);
    });

    test('RecurrenceConfig.toJson only emits documented, non-empty keys', () {
      expect(const RecurrenceConfig(daysOfWeek: [2, 4]).toJson(), {
        'days_of_week': [2, 4],
      });
      expect(const RecurrenceConfig(dates: ['2026-01-01']).toJson(), {
        'dates': ['2026-01-01'],
      });
      expect(
        const RecurrenceConfig(
          intervalDays: 5,
          anchorDate: '2026-01-01',
        ).toJson(),
        {'interval_days': 5, 'anchor_date': '2026-01-01'},
      );
      expect(const RecurrenceConfig().toJson(), isEmpty);
    });
  });

  group('statuses & nullable fields', () {
    test('task status enum', () {
      expect(
        ChildTask.fromJson(Fixtures.taskJson(status: 'archived')).status,
        TaskStatus.archived,
      );
      expect(
        ChildTask.fromJson(Fixtures.taskJson(status: 'active')).isArchived,
        isFalse,
      );
    });

    test('task tolerates null description / deadline / category', () {
      final task = ChildTask.fromJson(
        Fixtures.taskJson(description: null, deadlineAt: null, category: null),
      );
      expect(task.description, isNull);
      expect(task.deadlineAt, isNull);
      expect(task.category, isNull);
      expect(task.completions, isEmpty);
    });

    test('completion status + reversed flag', () {
      final pending = TaskCompletion.fromJson(
        Fixtures.completionJson(status: 'pending'),
      );
      expect(pending.status, CompletionStatus.pending);
      expect(pending.canApproveOrReject, isTrue);
      expect(pending.canReverse, isFalse);

      final approved = TaskCompletion.fromJson(
        Fixtures.completionJson(
          status: 'approved',
          pointsAwarded: 10,
          reviewedAt: '2026-09-07T10:00:00.000Z',
        ),
      );
      expect(approved.isApproved, isTrue);
      expect(approved.canReverse, isTrue);
      expect(approved.pointsAwarded, 10);

      final reversed = TaskCompletion.fromJson(
        Fixtures.completionJson(
          status: 'approved',
          pointsAwarded: 10,
          reviewedAt: '2026-09-07T10:00:00.000Z',
          reversedAt: '2026-09-08T10:00:00.000Z',
          reversalNote: 'mistake',
        ),
      );
      expect(reversed.status, CompletionStatus.approved);
      expect(reversed.isReversed, isTrue);
      expect(reversed.canReverse, isFalse, reason: 'cannot reverse twice');
      expect(reversed.reversalNote, 'mistake');

      final rejected = TaskCompletion.fromJson(
        Fixtures.completionJson(status: 'rejected'),
      );
      expect(rejected.isRejected, isTrue);
      expect(rejected.canApproveOrReject, isFalse);
    });

    test('completion tolerates null points_awarded / occurrence_date', () {
      final c = TaskCompletion.fromJson(
        Fixtures.completionJson()
          ..['points_awarded'] = null
          ..['occurrence_date'] = null,
      );
      expect(c.pointsAwarded, isNull);
      expect(c.occurrenceDate, isNull);
    });
  });

  group('point transactions', () {
    test('all types parse and amount sign is preserved', () {
      for (final t in [
        'task_award',
        'task_reversal',
        'activity_award',
        'activity_reversal',
        'redemption',
        'redemption_refund',
        'adjustment',
      ]) {
        expect(
          PointTransaction.fromJson(Fixtures.pointTxJson(type: t)).type,
          PointTransactionType.fromWire(t),
        );
      }
      final debit = PointTransaction.fromJson(
        Fixtures.pointTxJson(amount: -15, type: 'task_reversal'),
      );
      expect(debit.amount, -15);
      expect(debit.isCredit, isFalse);
    });

    test('unknown source_type → null, unknown type → adjustment', () {
      final tx = PointTransaction.fromJson(
        Fixtures.pointTxJson(type: 'weird', sourceType: 'weird'),
      );
      expect(tx.type, PointTransactionType.adjustment);
      expect(tx.sourceType, isNull);
    });

    test('PointsBalance parses child_id + balance', () {
      final b = PointsBalance.fromJson({'child_id': 'child-9', 'balance': 42});
      expect(b.childId, 'child-9');
      expect(b.balance, 42);
    });
  });

  group('request payloads', () {
    test('TaskCreateInput drops recurrence_config for one_time/daily', () {
      final json = TaskCreateInput(
        title: 'X',
        points: 5,
        recurrenceType: TaskRecurrence.daily,
        recurrenceConfig: const RecurrenceConfig(daysOfWeek: [1]),
      ).toJson();
      expect(json.containsKey('recurrence_config'), isFalse);
      expect(json['recurrence_type'], 'daily');
    });

    test('TaskCreateInput sends weekly days_of_week', () {
      final json = TaskCreateInput(
        title: 'X',
        points: 5,
        recurrenceType: TaskRecurrence.weekly,
        recurrenceConfig: const RecurrenceConfig(daysOfWeek: [1, 4]),
      ).toJson();
      expect(json['recurrence_config'], {
        'days_of_week': [1, 4],
      });
    });

    test('TaskUpdateInput never sends recurrence and honours clear flags', () {
      final json = const TaskUpdateInput(
        title: 'New',
        clearDeadline: true,
        clearCategory: true,
        status: TaskStatus.archived,
      ).toJson();
      expect(json.containsKey('recurrence_type'), isFalse);
      expect(json['deadline_at'], isNull);
      expect(json['category'], isNull);
      expect(json['status'], 'archived');
    });

    test(
      'CompletionRequestInput sends occurrence_date as YYYY-MM-DD only when set',
      () {
        expect(const CompletionRequestInput().toJson(), isEmpty);
        expect(
          CompletionRequestInput(occurrenceDate: DateTime(2026, 9, 7)).toJson(),
          {'occurrence_date': '2026-09-07'},
        );
      },
    );

    test('ReviewInput omits an empty note', () {
      expect(const ReviewInput().toJson(), isEmpty);
      expect(const ReviewInput(note: '  ').toJson(), isEmpty);
      expect(const ReviewInput(note: 'ok').toJson(), {'note': 'ok'});
    });
  });

  test('Paginated.from parses task pages', () {
    final env = ApiEnvelope.fromJson(
      Fixtures.tasksPage(
        [Fixtures.taskJson(id: 't1'), Fixtures.taskJson(id: 't2')],
        currentPage: 1,
        lastPage: 3,
        total: 7,
      ),
    );
    final page = Paginated.from<ChildTask>(env, ChildTask.fromJson);
    expect(page.items.map((t) => t.id), ['t1', 't2']);
    expect(page.meta.hasMore, isTrue);
    expect(page.meta.total, 7);
  });
}
