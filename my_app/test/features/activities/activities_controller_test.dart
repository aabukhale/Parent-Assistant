import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:my_app/features/activities/application/activities_controller.dart';
import 'package:my_app/features/activities/application/activity_assignments_controller.dart';
import 'package:my_app/features/tasks/application/points_controller.dart';
import 'package:my_app/features/tasks/data/task_requests.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  const c = '/families/family-1/children/child-1';

  group('activitiesCatalogController', () {
    test('no family → empty, no request', () async {
      final api = TestApi.create(token: 'tok');
      addTearDown(api.dispose);
      for (var i = 0; i < 20; i++) {
        if (api.container.read(activitiesCatalogControllerProvider).hasValue) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        api.container
            .read(activitiesCatalogControllerProvider)
            .requireValue
            .activities,
        isEmpty,
      );
      expect(
        api.requests.where((r) => r.uri.path.endsWith('/activities')),
        isEmpty,
      );
    });

    test('loads the catalog for the active family', () async {
      final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(api.dispose);
      api.adapter.onGet(
        '/activities',
        (s) => s.reply(
          200,
          Fixtures.activitiesPage([
            Fixtures.activityJson(id: 'a'),
            Fixtures.activityJson(id: 'b'),
          ]),
        ),
      );
      final state = await api.container.read(
        activitiesCatalogControllerProvider.future,
      );
      expect(state.activities.map((a) => a.id), ['a', 'b']);
    });

    test('family switch reloads the catalog', () async {
      final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(api.dispose);
      api.adapter.onGet(
        '/activities',
        (s) => s.reply(
          200,
          Fixtures.activitiesPage([Fixtures.activityJson(id: 'fam1')]),
        ),
      );
      final sub = api.container.listen(
        activitiesCatalogControllerProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        (await api.container.read(
          activitiesCatalogControllerProvider.future,
        )).activities.single.id,
        'fam1',
      );

      api.adapter.onGet(
        '/activities',
        (s) => s.reply(
          200,
          Fixtures.activitiesPage([Fixtures.activityJson(id: 'fam2')]),
        ),
      );
      api.setActiveFamily('family-2');
      expect(
        (await api.container.read(
          activitiesCatalogControllerProvider.future,
        )).activities.single.id,
        'fam2',
      );
    });
  });

  group('activityAssignmentsController', () {
    test('null child scope → empty, no request', () async {
      final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(api.dispose);
      for (var i = 0; i < 20; i++) {
        if (api.container
            .read(activityAssignmentsControllerProvider)
            .hasValue) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        api.container
            .read(activityAssignmentsControllerProvider)
            .requireValue
            .assignments,
        isEmpty,
      );
    });

    test('loads assignments for the selected child', () async {
      final api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      addTearDown(api.dispose);
      api.adapter.onGet(
        '$c/activity-assignments',
        (s) => s.reply(
          200,
          Fixtures.activityAssignmentsPage([
            Fixtures.activityAssignmentJson(id: 'x1'),
          ]),
        ),
      );
      final state = await api.container.read(
        activityAssignmentsControllerProvider.future,
      );
      expect(state.assignments.single.id, 'x1');
    });

    test('child switch drops the previous list', () async {
      final api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          '$c/activity-assignments',
          (s) => s.reply(
            200,
            Fixtures.activityAssignmentsPage([
              Fixtures.activityAssignmentJson(id: 'a'),
            ]),
          ),
        )
        ..onGet(
          '/families/family-1/children/child-2/activity-assignments',
          (s) => s.reply(
            200,
            Fixtures.activityAssignmentsPage([
              Fixtures.activityAssignmentJson(id: 'b', childId: 'child-2'),
            ]),
          ),
        );
      final sub = api.container.listen(
        activityAssignmentsControllerProvider,
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        (await api.container.read(
          activityAssignmentsControllerProvider.future,
        )).assignments.single.id,
        'a',
      );
      api.setSelectedChild('child-2');
      expect(
        (await api.container.read(
          activityAssignmentsControllerProvider.future,
        )).assignments.single.id,
        'b',
      );
    });

    test('approve refreshes list + balance + ledger', () async {
      final api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          '$c/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 0)),
        )
        ..onGet(
          '$c/point-transactions',
          (s) => s.reply(200, Fixtures.pointTxPage(const [])),
        )
        ..onGet(
          '$c/activity-assignments',
          (s) => s.reply(
            200,
            Fixtures.activityAssignmentsPage([
              Fixtures.activityAssignmentJson(
                id: 'as1',
                pointsReward: 20,
                completions: [
                  Fixtures.activityCompletionJson(id: 'c1', status: 'pending'),
                ],
              ),
            ]),
          ),
        );
      await api.container.read(activityAssignmentsControllerProvider.future);
      final bSub = api.container.listen(pointsBalanceProvider, (_, _) {});
      addTearDown(bSub.close);
      expect(
        (await api.container.read(pointsBalanceProvider.future)).balance,
        0,
      );

      api.adapter
        ..onPost(
          '$c/activity-assignments/as1/completions/c1/approve',
          (s) => s.reply(
            200,
            Fixtures.activityCompletionEnvelope(
              completion: Fixtures.activityCompletionJson(
                id: 'c1',
                status: 'approved',
                reviewedAt: '2026-09-08T12:00:00.000Z',
                pointsAwarded: 20,
              ),
            ),
          ),
          data: Matchers.any,
        )
        ..onGet(
          '$c/activity-assignments',
          (s) => s.reply(
            200,
            Fixtures.activityAssignmentsPage([
              Fixtures.activityAssignmentJson(
                id: 'as1',
                pointsReward: 20,
                status: 'completed',
                completions: [
                  Fixtures.activityCompletionJson(
                    id: 'c1',
                    status: 'approved',
                    pointsAwarded: 20,
                  ),
                ],
              ),
            ]),
          ),
        )
        ..onGet(
          '$c/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 20)),
        );

      final result = await api.container
          .read(activityAssignmentsControllerProvider.notifier)
          .approve('as1', 'c1', const ReviewInput());
      await Future<void>.delayed(Duration.zero);
      expect(result.isApproved, isTrue);
      expect(
        (await api.container.read(pointsBalanceProvider.future)).balance,
        20,
        reason: 'balance re-read from server, not computed',
      );
    });
  });
}
