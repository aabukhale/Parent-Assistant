import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/providers.dart';
import 'package:my_app/features/dashboard/application/dashboard_controllers.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  const dashboard = '/families/family-1/dashboard';
  const summary = '/families/family-1/children/child-1/summary';
  const weekly = '/families/family-1/children/child-1/reports/weekly';
  const monthly = '/families/family-1/children/child-1/reports/monthly';

  group('parentDashboardProvider', () {
    test('no active family → error state, no request', () async {
      final api = TestApi.create(token: 'tok');
      addTearDown(api.dispose);
      final sub = api.container.listen(parentDashboardProvider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(
        api.container.read(parentDashboardProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(
        api.requests.where((r) => r.uri.path.contains('/dashboard')),
        isEmpty,
      );
    });

    test('loads the active family dashboard', () async {
      final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(api.dispose);
      api.adapter.onGet(
        dashboard,
        (s) => s.reply(
          200,
          Fixtures.parentDashboardEnvelope(
            dashboard: Fixtures.parentDashboardJson(
              children: [Fixtures.childSummaryJson(childId: 'a')],
            ),
          ),
        ),
      );
      final sub = api.container.listen(parentDashboardProvider, (_, _) {});
      addTearDown(sub.close);

      final d = await api.container.read(parentDashboardProvider.future);
      expect(d.children.single.childId, 'a');
    });

    test('family switch drops the previous family data', () async {
      final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          dashboard,
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
        );
      final sub = api.container.listen(parentDashboardProvider, (_, _) {});
      addTearDown(sub.close);

      expect(
        (await api.container.read(parentDashboardProvider.future)).familyId,
        'family-1',
      );
      api.setActiveFamily('family-2');
      expect(
        (await api.container.read(parentDashboardProvider.future)).familyId,
        'family-2',
      );
    });

    test('a dashboard-refresh signal triggers a refetch', () async {
      final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(api.dispose);
      api.adapter.onGet(
        dashboard,
        (s) => s.reply(200, Fixtures.parentDashboardEnvelope()),
      );
      final sub = api.container.listen(parentDashboardProvider, (_, _) {});
      addTearDown(sub.close);
      await api.container.read(parentDashboardProvider.future);
      final before = api.requests
          .where((r) => r.uri.path.contains('/dashboard'))
          .length;

      api.container.read(dashboardRefreshSignalProvider.notifier).state++;
      await Future<void>.delayed(Duration.zero);
      await api.container.read(parentDashboardProvider.future);
      final after = api.requests
          .where((r) => r.uri.path.contains('/dashboard'))
          .length;
      expect(after, greaterThan(before));
    });
  });

  group('childSummaryProvider', () {
    test('loads for the given child', () async {
      final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(api.dispose);
      api.adapter.onGet(
        summary,
        (s) => s.reply(
          200,
          Fixtures.childSummaryEnvelope(
            summary: Fixtures.childSummaryJson(pointsBalance: 42),
          ),
        ),
      );
      final sub = api.container.listen(
        childSummaryProvider('child-1'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final s = await api.container.read(
        childSummaryProvider('child-1').future,
      );
      expect(s.pointsBalance, 42);
    });

    test('no active family → error', () async {
      final api = TestApi.create(token: 'tok');
      addTearDown(api.dispose);
      final sub = api.container.listen(
        childSummaryProvider('child-1'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await expectLater(
        api.container.read(childSummaryProvider('child-1').future),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('developmentReportProvider', () {
    test('no selected child → error, no request', () async {
      final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
      addTearDown(api.dispose);
      final sub = api.container.listen(
        developmentReportProvider('weekly'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await expectLater(
        api.container.read(developmentReportProvider('weekly').future),
        throwsA(isA<StateError>()),
      );
      expect(
        api.requests.where((r) => r.uri.path.contains('/reports/')),
        isEmpty,
      );
    });

    test(
      'loads the weekly report for the active family + selected child',
      () async {
        final api = TestApi.create(
          token: 'tok',
          activeFamilyId: 'family-1',
          selectedChildId: 'child-1',
        );
        addTearDown(api.dispose);
        api.adapter.onGet(
          weekly,
          (s) => s.reply(
            200,
            Fixtures.developmentReportEnvelope(
              report: Fixtures.developmentReportJson(sleepData: true),
            ),
          ),
        );
        final sub = api.container.listen(
          developmentReportProvider('weekly'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final r = await api.container.read(
          developmentReportProvider('weekly').future,
        );
        expect(r.period, 'weekly');
        expect(r.sections.sleep.hasData, isTrue);
      },
    );

    test(
      'weekly and monthly are separate keys — switching does not show stale',
      () async {
        final api = TestApi.create(
          token: 'tok',
          activeFamilyId: 'family-1',
          selectedChildId: 'child-1',
        );
        addTearDown(api.dispose);
        api.adapter
          ..onGet(
            weekly,
            (s) => s.reply(
              200,
              Fixtures.developmentReportEnvelope(
                report: Fixtures.developmentReportJson(period: 'weekly'),
              ),
            ),
          )
          ..onGet(
            monthly,
            (s) => s.reply(
              200,
              Fixtures.developmentReportEnvelope(
                report: Fixtures.developmentReportJson(
                  period: 'monthly',
                  periodStart: '2026-09-01',
                  periodEnd: '2026-09-30',
                ),
              ),
            ),
          );
        final w = api.container.listen(
          developmentReportProvider('weekly'),
          (_, _) {},
        );
        addTearDown(w.close);
        final m = api.container.listen(
          developmentReportProvider('monthly'),
          (_, _) {},
        );
        addTearDown(m.close);

        expect(
          (await api.container.read(
            developmentReportProvider('weekly').future,
          )).period,
          'weekly',
        );
        expect(
          (await api.container.read(
            developmentReportProvider('monthly').future,
          )).period,
          'monthly',
        );
      },
    );

    test('selected-child switch reloads the report', () async {
      final api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
      );
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          weekly,
          (s) => s.reply(
            200,
            Fixtures.developmentReportEnvelope(
              report: Fixtures.developmentReportJson(sleepData: true),
            ),
          ),
        )
        ..onGet(
          '/families/family-1/children/child-2/reports/weekly',
          (s) => s.reply(
            200,
            Fixtures.developmentReportEnvelope(
              report: Fixtures.developmentReportJson(tasksData: true),
            ),
          ),
        );
      final sub = api.container.listen(
        developmentReportProvider('weekly'),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        (await api.container.read(
          developmentReportProvider('weekly').future,
        )).sections.sleep.hasData,
        isTrue,
      );
      api.setSelectedChild('child-2');
      expect(
        (await api.container.read(
          developmentReportProvider('weekly').future,
        )).sections.tasks.hasData,
        isTrue,
      );
    });
  });
}
