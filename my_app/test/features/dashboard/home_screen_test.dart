import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/dashboard/presentation/home_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: HomeScreen(),
  ),
);

Future<void> _pump(WidgetTester tester, TestApi api) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(api));
  await tester.pumpAndSettle();
}

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const dashboard = '/families/family-1/dashboard';

  TestApi make() =>
      TestApi.create(token: 'tok', locale: 'en', activeFamilyId: 'family-1');

  testWidgets('renders real per-child figures; zero shows as zero', (
    tester,
  ) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      dashboard,
      (s) => s.reply(
        200,
        Fixtures.parentDashboardEnvelope(
          dashboard: Fixtures.parentDashboardJson(
            children: [
              Fixtures.childSummaryJson(
                childId: 'a',
                name: 'Layan',
                pointsBalance: 120,
                usedMinutes: 90,
                effectiveLimitMinutes: 120,
                remainingMinutes: 30,
                pendingApproval: 0,
              ),
            ],
          ),
        ),
      ),
    );
    await _pump(tester, api);

    expect(find.text('Layan'), findsOneWidget);
    expect(find.text('120'), findsOneWidget); // points
    expect(find.text('1h 30m'), findsOneWidget); // screen time used
    expect(find.text(l.dashScreenTimeOfLimit('2h')), findsOneWidget);
    expect(find.text('0'), findsOneWidget); // pending approvals = real zero
  });

  testWidgets('screen-time with no limit shows "No limit set", not a number', (
    tester,
  ) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      dashboard,
      (s) => s.reply(
        200,
        Fixtures.parentDashboardEnvelope(
          dashboard: Fixtures.parentDashboardJson(
            children: [
              Fixtures.childSummaryJson(
                usedMinutes: 20,
                effectiveLimitMinutes: null,
                remainingMinutes: null,
              ),
            ],
          ),
        ),
      ),
    );
    await _pump(tester, api);

    expect(find.text(l.dashScreenTimeNoLimit), findsOneWidget);
  });

  testWidgets('no last sleep → "None yet" rather than 0', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      dashboard,
      (s) => s.reply(
        200,
        Fixtures.parentDashboardEnvelope(
          dashboard: Fixtures.parentDashboardJson(
            children: [Fixtures.childSummaryJson()],
          ),
        ),
      ),
    );
    await _pump(tester, api);

    expect(find.text(l.dashNone), findsOneWidget);
  });

  testWidgets('empty family shows the honest empty state', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      dashboard,
      (s) => s.reply(
        200,
        Fixtures.parentDashboardEnvelope(
          dashboard: Fixtures.parentDashboardJson(children: const []),
        ),
      ),
    );
    await _pump(tester, api);

    expect(find.text(l.homeNoChildren), findsOneWidget);
  });

  testWidgets('error → retry recovers', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      dashboard,
      (s) => s.reply(500, {'success': false, 'message': 'x'}),
    );
    await _pump(tester, api);
    expect(find.text(l.commonRetry), findsOneWidget);

    api.adapter.onGet(
      dashboard,
      (s) => s.reply(
        200,
        Fixtures.parentDashboardEnvelope(
          dashboard: Fixtures.parentDashboardJson(
            children: [Fixtures.childSummaryJson(name: 'Recovered')],
          ),
        ),
      ),
    );
    await tester.tap(find.text(l.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets('loading shows no fabricated numbers', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      dashboard,
      (s) => s.reply(
        200,
        Fixtures.parentDashboardEnvelope(),
        delay: const Duration(milliseconds: 200),
      ),
    );
    await tester.pumpWidget(_host(api));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('0'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('RTL smoke test (Arabic)', (tester) async {
    final api = TestApi.create(
      token: 'tok',
      locale: 'ar',
      activeFamilyId: 'family-1',
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      dashboard,
      (s) => s.reply(
        200,
        Fixtures.parentDashboardEnvelope(
          dashboard: Fixtures.parentDashboardJson(
            children: [Fixtures.childSummaryJson(name: 'ليان')],
          ),
        ),
      ),
    );
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: api.container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ar'),
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.text('ليان'))),
      TextDirection.rtl,
    );
  });
}
