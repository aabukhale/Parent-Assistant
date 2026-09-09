import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/activities/data/activity_requests.dart';
import 'package:my_app/features/activities/data/models/activity.dart';
import 'package:my_app/features/activities/data/models/activity_assignment.dart';
import 'package:my_app/features/activities/data/models/activity_completion.dart';
import 'package:my_app/features/tasks/data/models/task_enums.dart';

import '../../support/fixtures.dart';

void main() {
  group('Activity.fromJson', () {
    test('all sources parse; unknown → global', () {
      expect(
        Activity.fromJson(Fixtures.activityJson(source: 'ai')).source,
        ActivitySource.ai,
      );
      expect(
        Activity.fromJson(Fixtures.activityJson(source: 'family')).source,
        ActivitySource.family,
      );
      expect(
        Activity.fromJson(Fixtures.activityJson(source: 'weird')).source,
        ActivitySource.global,
      );
    });

    test('global vs family scope', () {
      expect(Activity.fromJson(Fixtures.activityJson()).isFamily, isFalse);
      expect(
        Activity.fromJson(
          Fixtures.activityJson(familyId: 'family-1', source: 'family'),
        ).isFamily,
        isTrue,
      );
    });

    test('materials / steps default to empty lists, never null', () {
      final a = Activity.fromJson(
        Fixtures.activityJson()
          ..['materials'] = null
          ..['steps'] = null,
      );
      expect(a.materials, isEmpty);
      expect(a.steps, isEmpty);
      final b = Activity.fromJson(
        Fixtures.activityJson(materials: ['glue'], steps: ['cut', 'paste']),
      );
      expect(b.materials, ['glue']);
      expect(b.steps, ['cut', 'paste']);
    });

    test('null age bounds tolerated', () {
      final a = Activity.fromJson(
        Fixtures.activityJson(minAge: null, maxAge: null),
      );
      expect(a.minAge, isNull);
      expect(a.maxAge, isNull);
    });
  });

  group('ActivityAssignment.fromJson', () {
    test('requires_approval + status parse; unknown status → assigned', () {
      final needsApproval = ActivityAssignment.fromJson(
        Fixtures.activityAssignmentJson(pointsReward: 20),
      );
      expect(needsApproval.requiresApproval, isTrue);
      final free = ActivityAssignment.fromJson(
        Fixtures.activityAssignmentJson(),
      );
      expect(free.requiresApproval, isFalse);
      expect(
        ActivityAssignment.fromJson(
          Fixtures.activityAssignmentJson(status: '??'),
        ).status,
        AssignmentStatus.assigned,
      );
    });

    test('canComplete: true when no completion or last rejected', () {
      expect(
        ActivityAssignment.fromJson(
          Fixtures.activityAssignmentJson(),
        ).canComplete,
        isTrue,
      );
      final pending = ActivityAssignment.fromJson(
        Fixtures.activityAssignmentJson(
          completions: [Fixtures.activityCompletionJson(status: 'pending')],
        ),
      );
      expect(pending.canComplete, isFalse);
      final rejected = ActivityAssignment.fromJson(
        Fixtures.activityAssignmentJson(
          completions: [Fixtures.activityCompletionJson(status: 'rejected')],
        ),
      );
      expect(rejected.canComplete, isTrue);
      final cancelled = ActivityAssignment.fromJson(
        Fixtures.activityAssignmentJson(status: 'cancelled'),
      );
      expect(cancelled.canComplete, isFalse);
    });

    test('embeds the activity and completions', () {
      final a = ActivityAssignment.fromJson(
        Fixtures.activityAssignmentJson(
          activity: Fixtures.activityJson(title: 'Nature walk'),
          completions: [Fixtures.activityCompletionJson(id: 'c1')],
        ),
      );
      expect(a.activity!.title, 'Nature walk');
      expect(a.latestCompletion!.id, 'c1');
    });
  });

  group('ActivityCompletion.fromJson', () {
    test('status machine + reversed flag', () {
      expect(
        ActivityCompletion.fromJson(
          Fixtures.activityCompletionJson(status: 'pending'),
        ).canApproveOrReject,
        isTrue,
      );
      final approved = ActivityCompletion.fromJson(
        Fixtures.activityCompletionJson(
          status: 'approved',
          reviewedAt: '2026-09-08T11:00:00.000Z',
          pointsAwarded: 20,
        ),
      );
      expect(approved.canReverse, isTrue);
      expect(approved.isReversed, isFalse);
      final reversed = ActivityCompletion.fromJson(
        Fixtures.activityCompletionJson(
          status: 'approved',
          reversedAt: '2026-09-09T00:00:00.000Z',
          pointsAwarded: 20,
        ),
      );
      expect(reversed.isReversed, isTrue);
      expect(reversed.canReverse, isFalse);
      expect(reversed.status, CompletionStatus.approved);
    });
  });

  group('request payloads', () {
    test('ActivityAssignInput omits null fields; formats due_date', () {
      expect(const ActivityAssignInput(activityId: 'a').toJson(), {
        'activity_id': 'a',
      });
      final full = ActivityAssignInput(
        activityId: 'a',
        pointsReward: 15,
        dueDate: DateTime(2026, 9, 20),
      ).toJson();
      expect(full['points_reward'], 15);
      expect(full['due_date'], '2026-09-20');
    });

    test('GenerateActivityInput trims + omits empties', () {
      expect(const GenerateActivityInput().toJson(), isEmpty);
      expect(
        const GenerateActivityInput(theme: '  space  ', count: 3).toJson(),
        {'theme': 'space', 'count': 3},
      );
    });
  });
}
