import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/auth/data/models/family_membership.dart';
import 'package:my_app/features/dashboard/presentation/development_report_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Widget _host(TestApi api, {String locale = 'en'}) => UncontrolledProviderScope(
  container: api.container,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale(locale),
    home: const DevelopmentReportScreen(),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  TestApi api, {
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(api, locale: locale));
  await tester.pumpAndSettle();
}

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const weekly = '/families/family-1/children/child-1/reports/weekly';
  const monthly = '/families/family-1/children/child-1/reports/monthly';

  TestApi make({
    FamilyRole role = FamilyRole.owner,
    List<String>? permissions,
    String? selectedChildId = 'child-1',
    Map<String, dynamic>? weeklyReport,
  }) {
    final api = TestApi.create(
      token: 'tok',
      locale: 'en',
      activeFamilyId: 'family-1',
      selectedChildId: selectedChildId,
      role: role,
    );
    api.adapter
      ..onGet(
        '/families/family-1/children',
        (s) => s.reply(
          200,
          Fixtures.childrenPage([
            Fixtures.childJson(id: 'child-1', name: 'Layan'),
          ]),
        ),
      )
      ..onGet(
        '/families/family-1/members',
        (s) => s.reply(
          200,
          Fixtures.membersEnvelope([
            Fixtures.memberJson(
              role: role.name,
              effectivePermissions: permissions,
            ),
          ]),
        ),
      )
      ..onGet(
        weekly,
        (s) => s.reply(
          200,
          Fixtures.developmentReportEnvelope(report: weeklyReport),
        ),
      );
    return api;
  }

  testWidgets('renders real section metrics for a populated report', (
    tester,
  ) async {
    final api = make(
      weeklyReport: Fixtures.developmentReportJson(
        sleepData: true,
        sleepNights: 5,
        sleepTotal: 2400,
        sleepAverage: 480,
        pointsData: true,
        pointsNet: 40,
        pointsTransactions: 6,
      ),
    );
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.dashReportFor('Layan')), findsOneWidget);
    expect(find.text(l.dashSectionSleep), findsOneWidget);
    expect(find.text('5'), findsWidgets); // nights logged
    expect(find.text('8h'), findsOneWidget); // average per night (480m)
    expect(find.text('+40'), findsOneWidget); // net points change (signed)
    expect(find.text('6'), findsWidgets); // transaction count
  });

  testWidgets('a section with no data says so instead of showing zeros', (
    tester,
  ) async {
    final api = make(
      weeklyReport: Fixtures.developmentReportJson(sleepData: true),
    );
    addTearDown(api.dispose);
    await _pump(tester, api);

    // sleep has data, games does not → games card shows the "no data" line.
    expect(find.text(l.dashSectionNoData), findsWidgets);
  });

  testWidgets('has_sufficient_data=false surfaces the honest banner', (
    tester,
  ) async {
    final api = make(weeklyReport: Fixtures.developmentReportJson());
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.dashReportNoData), findsOneWidget);
  });

  testWidgets('caregiver without view_reports sees the restricted state', (
    tester,
  ) async {
    final api = make(role: FamilyRole.caregiver, permissions: const []);
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.dashReportsRestricted), findsOneWidget);
    expect(find.text(l.dashSectionSleep), findsNothing);
  });

  testWidgets('caregiver with view_reports sees the report', (tester) async {
    final api = make(
      role: FamilyRole.caregiver,
      permissions: const ['view_reports'],
      weeklyReport: Fixtures.developmentReportJson(tasksData: true),
    );
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.dashSectionTasks), findsOneWidget);
  });

  testWidgets('no selected child → choose-a-child empty state', (tester) async {
    final api = make(selectedChildId: null);
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.dashNoChildSelected), findsOneWidget);
  });

  testWidgets('period toggle requests the monthly report', (tester) async {
    final api = make(
      weeklyReport: Fixtures.developmentReportJson(sleepData: true),
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      monthly,
      (s) => s.reply(
        200,
        Fixtures.developmentReportEnvelope(
          report: Fixtures.developmentReportJson(
            period: 'monthly',
            periodStart: '2026-09-01',
            periodEnd: '2026-09-30',
            gamesData: true,
            gamesSessions: 3,
          ),
        ),
      ),
    );
    await _pump(tester, api);

    await tester.tap(find.text(l.dashPeriodMonthly));
    await tester.pumpAndSettle();

    expect(
      api.requests.where((r) => r.uri.path.endsWith('/reports/monthly')),
      isNotEmpty,
    );
    expect(find.text('3'), findsWidgets); // monthly games sessions
  });

  testWidgets('error → retry', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      weekly,
      (s) => s.reply(500, {'success': false, 'message': 'x'}),
    );
    await _pump(tester, api);

    expect(find.text(l.commonRetry), findsWidgets);
  });

  testWidgets('RTL smoke test (Arabic)', (tester) async {
    final api = make(
      weeklyReport: Fixtures.developmentReportJson(sleepData: true),
    );
    addTearDown(api.dispose);
    await _pump(tester, api, locale: 'ar');

    final arL = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(arL.dashSectionSleep), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text(arL.dashSectionSleep))),
      TextDirection.rtl,
    );
  });
}
