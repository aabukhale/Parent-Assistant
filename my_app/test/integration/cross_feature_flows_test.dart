import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/core/providers.dart';
import 'package:my_app/features/activities/application/activity_assignments_controller.dart';
import 'package:my_app/features/content_control/application/content_controller.dart';
import 'package:my_app/features/dashboard/application/dashboard_controllers.dart';
import 'package:my_app/features/screen_time/application/screen_time_controller.dart';
import 'package:my_app/features/tasks/application/points_controller.dart';
import 'package:my_app/features/tasks/data/task_requests.dart';

import '../support/fixtures.dart';
import '../support/test_api.dart';

void main() {
  const c1 = '/families/family-1/children/child-1';
  const c2 = '/families/family-2/children/child-2';

  test(
    'family + child switch: no feature provider serves stale data',
    () async {
      final api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      addTearDown(api.dispose);

      api.adapter
        ..onGet(
          '/families/family-1/dashboard',
          (s) => s.reply(
            200,
            Fixtures.parentDashboardEnvelope(
              dashboard: Fixtures.parentDashboardJson(familyId: 'family-1'),
            ),
          ),
        )
        ..onGet(
          '/families/family-2/dashboard',
          (s) => s.reply(
            200,
            Fixtures.parentDashboardEnvelope(
              dashboard: Fixtures.parentDashboardJson(familyId: 'family-2'),
            ),
          ),
        )
        ..onGet(
          '$c1/content-policy',
          (s) =>
              s.reply(200, Fixtures.contentPolicyEnvelope(childId: 'child-1')),
        )
        ..onGet(
          '$c2/content-policy',
          (s) =>
              s.reply(200, Fixtures.contentPolicyEnvelope(childId: 'child-2')),
        )
        ..onGet(
          '$c1/screen-time/summary',
          (s) =>
              s.reply(200, Fixtures.screenTimeSummaryEnvelope(usedMinutes: 10)),
        )
        ..onGet(
          '$c2/screen-time/summary',
          (s) =>
              s.reply(200, Fixtures.screenTimeSummaryEnvelope(usedMinutes: 99)),
        );

      final subs = [
        api.container.listen(parentDashboardProvider, (_, _) {}),
        api.container.listen(contentPolicyProvider, (_, _) {}),
        api.container.listen(screenTimeSummaryProvider, (_, _) {}),
      ];
      addTearDown(() {
        for (final s in subs) {
          s.close();
        }
      });

      expect(
        (await api.container.read(parentDashboardProvider.future)).familyId,
        'family-1',
      );
      expect(
        (await api.container.read(contentPolicyProvider.future)).childId,
        'child-1',
      );
      expect(
        (await api.container.read(
          screenTimeSummaryProvider.future,
        )).usedMinutes,
        10,
      );

      api.setActiveFamily('family-2');
      api.setSelectedChild('child-2');

      expect(
        (await api.container.read(parentDashboardProvider.future)).familyId,
        'family-2',
      );
      expect(
        (await api.container.read(contentPolicyProvider.future)).childId,
        'child-2',
      );
      expect(
        (await api.container.read(
          screenTimeSummaryProvider.future,
        )).usedMinutes,
        99,
      );
    },
  );

  test(
    'mutation in one feature → dashboard refresh signal fires for the mother dashboard',
    () async {
      final api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      addTearDown(api.dispose);

      api.adapter
        ..onGet(
          '/families/family-1/dashboard',
          (s) => s.reply(200, Fixtures.parentDashboardEnvelope()),
        )
        ..onGet(
          '$c1/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 0)),
        )
        ..onGet(
          '$c1/point-transactions',
          (s) => s.reply(200, Fixtures.pointTxPage(const [])),
        )
        ..onGet(
          '$c1/activity-assignments',
          (s) => s.reply(
            200,
            Fixtures.activityAssignmentsPage([
              Fixtures.activityAssignmentJson(
                id: 'as1',
                pointsReward: 10,
                completions: [
                  Fixtures.activityCompletionJson(id: 'ac1', status: 'pending'),
                ],
              ),
            ]),
          ),
        );

      final dashSub = api.container.listen(parentDashboardProvider, (_, _) {});
      addTearDown(dashSub.close);
      await api.container.read(parentDashboardProvider.future);
      await api.container.read(activityAssignmentsControllerProvider.future);
      final before = api.requests
          .where((r) => r.uri.path.endsWith('/dashboard'))
          .length;

      api.adapter
        ..onPost(
          '$c1/activity-assignments/as1/completions/ac1/approve',
          (s) => s.reply(
            200,
            Fixtures.activityCompletionEnvelope(
              completion: Fixtures.activityCompletionJson(
                id: 'ac1',
                status: 'approved',
                pointsAwarded: 10,
              ),
            ),
          ),
          data: Matchers.any,
        )
        ..onGet(
          '$c1/activity-assignments',
          (s) => s.reply(200, Fixtures.activityAssignmentsPage(const [])),
        )
        ..onGet(
          '$c1/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 10)),
        );

      await api.container
          .read(activityAssignmentsControllerProvider.notifier)
          .approve('as1', 'ac1', const ReviewInput());
      await Future<void>.delayed(Duration.zero);
      // the signal invalidated the dashboard provider
      await api.container.read(parentDashboardProvider.future);
      final after = api.requests
          .where((r) => r.uri.path.endsWith('/dashboard'))
          .length;
      expect(after, greaterThan(before));
      // and the balance was re-read from the server, not computed
      expect(
        (await api.container.read(pointsBalanceProvider.future)).balance,
        10,
      );
    },
  );

  test('bumpDashboardRefresh is a safe no-op when nothing observes it', () {
    final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
    addTearDown(api.dispose);
    expect(
      () => api.container.read(dashboardRefreshSignalProvider.notifier).state++,
      returnsNormally,
    );
  });
}
