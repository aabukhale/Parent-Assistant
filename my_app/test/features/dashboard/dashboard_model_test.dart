import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/dashboard/data/models/child_summary.dart';
import 'package:my_app/features/dashboard/data/models/development_report.dart';
import 'package:my_app/features/dashboard/data/models/parent_dashboard.dart';

import '../../support/fixtures.dart';

void main() {
  group('ChildSummary.fromJson', () {
    test('parses a fully-populated digest', () {
      final s = ChildSummary.fromJson(
        Fixtures.childSummaryJson(
          pointsBalance: 120,
          usedMinutes: 75,
          effectiveLimitMinutes: 120,
          remainingMinutes: 45,
          lastSleep: Fixtures.lastSleepJson(durationMinutes: 540),
          activeTasks: 3,
          pendingApproval: 2,
          activeGoals: 4,
          achievedGoals: 1,
        ),
      );
      expect(s.pointsBalance, 120);
      expect(s.screenTimeToday.usedMinutes, 75);
      expect(s.screenTimeToday.effectiveLimitMinutes, 120);
      expect(s.screenTimeToday.hasLimit, isTrue);
      expect(s.lastSleep!.durationMinutes, 540);
      expect(s.tasks.pendingApproval, 2);
      expect(s.learningGoals.achieved, 1);
    });

    test(
      'null screen-time limit stays null (no rule configured, not zero)',
      () {
        final s = ChildSummary.fromJson(
          Fixtures.childSummaryJson(
            usedMinutes: 30,
            effectiveLimitMinutes: null,
            remainingMinutes: null,
          ),
        );
        expect(s.screenTimeToday.usedMinutes, 30);
        expect(s.screenTimeToday.effectiveLimitMinutes, isNull);
        expect(s.screenTimeToday.remainingMinutes, isNull);
        expect(s.screenTimeToday.hasLimit, isFalse);
      },
    );

    test('null last_sleep → null (distinct from a 0-minute sleep)', () {
      final none = ChildSummary.fromJson(Fixtures.childSummaryJson());
      expect(none.lastSleep, isNull);
      final zero = ChildSummary.fromJson(
        Fixtures.childSummaryJson(
          lastSleep: Fixtures.lastSleepJson(durationMinutes: 0),
        ),
      );
      expect(zero.lastSleep, isNotNull);
      expect(zero.lastSleep!.durationMinutes, 0);
    });

    test('zero counts parse as zero, not missing', () {
      final s = ChildSummary.fromJson(Fixtures.childSummaryJson());
      expect(s.pointsBalance, 0);
      expect(s.tasks.active, 0);
      expect(s.tasks.pendingApproval, 0);
      expect(s.learningGoals.active, 0);
    });

    test('null age is tolerated', () {
      final s = ChildSummary.fromJson(Fixtures.childSummaryJson(age: null));
      expect(s.age, isNull);
    });

    test('missing nested objects fall back to empty, not a crash', () {
      final s = ChildSummary.fromJson({'child_id': 'c', 'name': 'X'});
      expect(s.screenTimeToday.usedMinutes, 0);
      expect(s.lastSleep, isNull);
      expect(s.tasks.active, 0);
      expect(s.learningGoals.achieved, 0);
    });
  });

  group('ParentDashboard.fromJson', () {
    test('parses the family roll-up and each child digest', () {
      final d = ParentDashboard.fromJson(
        Fixtures.parentDashboardJson(
          children: [
            Fixtures.childSummaryJson(
              childId: 'a',
              name: 'A',
              pointsBalance: 5,
            ),
            Fixtures.childSummaryJson(
              childId: 'b',
              name: 'B',
              pointsBalance: 9,
            ),
          ],
        ),
      );
      expect(d.familyId, 'family-1');
      expect(d.childrenCount, 2);
      expect(d.children.map((c) => c.childId), ['a', 'b']);
      expect(d.isEmpty, isFalse);
    });

    test('empty family → no children, isEmpty', () {
      final d = ParentDashboard.fromJson(
        Fixtures.parentDashboardJson(children: const []),
      );
      expect(d.childrenCount, 0);
      expect(d.isEmpty, isTrue);
    });
  });

  group('DevelopmentReport.fromJson', () {
    test('empty report: every section has_data=false and zeroed metrics', () {
      final r = DevelopmentReport.fromJson(Fixtures.developmentReportJson());
      expect(r.period, 'weekly');
      expect(r.hasSufficientData, isFalse);
      expect(r.sections.screenTime.hasData, isFalse);
      expect(r.sections.screenTime.metric('total_minutes'), 0);
      expect(r.sections.sleep.metric('average_minutes'), 0);
      expect(r.sections.points.metric('net_change'), 0);
    });

    test('populated sections expose their metrics', () {
      final r = DevelopmentReport.fromJson(
        Fixtures.developmentReportJson(
          period: 'monthly',
          periodStart: '2026-06-01',
          periodEnd: '2026-06-30',
          screenTimeData: true,
          screenTimeTotal: 420,
          screenTimeDailyAverage: 60,
          daysWithUsage: 7,
          sleepData: true,
          sleepNights: 5,
          pointsData: true,
          pointsNet: -30,
        ),
      );
      expect(r.period, 'monthly');
      expect(r.periodStart, DateTime(2026, 6, 1));
      expect(r.periodEnd, DateTime(2026, 6, 30));
      expect(r.hasSufficientData, isTrue);
      expect(r.sections.screenTime.hasData, isTrue);
      expect(r.sections.screenTime.metric('total_minutes'), 420);
      expect(r.sections.screenTime.metric('days_with_usage'), 7);
      expect(r.sections.sleep.metric('nights_logged'), 5);
      expect(r.sections.points.metric('net_change'), -30);
    });

    test('unknown period string is kept verbatim, not coerced', () {
      final r = DevelopmentReport.fromJson(
        Fixtures.developmentReportJson(period: 'quarterly'),
      );
      expect(r.period, 'quarterly');
    });

    test('missing sections object → all-empty sections, no throw', () {
      final r = DevelopmentReport.fromJson({
        'period': 'weekly',
        'period_start': '2026-09-01',
        'period_end': '2026-09-07',
        'has_sufficient_data': false,
      });
      expect(r.sections.games.hasData, isFalse);
      expect(r.sections.tasks.metric('points_from_tasks'), 0);
    });

    test('malformed dates become null rather than crashing', () {
      final r = DevelopmentReport.fromJson(
        Fixtures.developmentReportJson(periodStart: 'not-a-date'),
      );
      expect(r.periodStart, isNull);
      expect(r.periodEnd, isNotNull);
    });
  });
}
