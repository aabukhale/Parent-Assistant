import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/activities/presentation/activities_screen.dart';
import 'package:my_app/features/activities/presentation/child_activities_screen.dart';
import 'package:my_app/features/auth/data/models/family_membership.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Widget _host(TestApi api, Widget home, {String locale = 'en'}) =>
    UncontrolledProviderScope(
      container: api.container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(locale),
        home: home,
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  TestApi api,
  Widget home, {
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(api, home, locale: locale));
  await tester.pumpAndSettle();
}

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const c = '/families/family-1/children/child-1';

  testWidgets('catalog renders real activities + source labels', (
    tester,
  ) async {
    final api = TestApi.create(
      token: 'tok',
      locale: 'en',
      activeFamilyId: 'family-1',
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      '/activities',
      (s) => s.reply(
        200,
        Fixtures.activitiesPage([
          Fixtures.activityJson(id: 'g', title: 'Star gazing'),
          Fixtures.activityJson(
            id: 'f',
            familyId: 'family-1',
            source: 'family',
            title: 'Our craft',
          ),
        ]),
      ),
    );
    await _pump(tester, api, const ActivitiesScreen());

    expect(find.text('Star gazing'), findsOneWidget);
    expect(find.text('Our craft'), findsOneWidget);
    expect(find.text(l.activitySourceFamily), findsOneWidget);
  });

  testWidgets('catalog empty + error/retry', (tester) async {
    final api = TestApi.create(
      token: 'tok',
      locale: 'en',
      activeFamilyId: 'family-1',
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      '/activities',
      (s) => s.reply(500, {'success': false, 'message': 'x'}),
    );
    await _pump(tester, api, const ActivitiesScreen());
    expect(find.text(l.commonRetry), findsOneWidget);

    api.adapter.onGet(
      '/activities',
      (s) => s.reply(
        200,
        Fixtures.activitiesPage([Fixtures.activityJson(title: 'Recovered')]),
      ),
    );
    await tester.tap(find.text(l.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets(
    'child activities: assignment + parent-managed completion states',
    (tester) async {
      final api = TestApi.create(
        token: 'tok',
        locale: 'en',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
        role: FamilyRole.owner,
      );
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          '/families/family-1/members',
          (s) => s.reply(
            200,
            Fixtures.membersEnvelope([Fixtures.memberJson(role: 'owner')]),
          ),
        )
        ..onGet(
          '$c/activity-assignments',
          (s) => s.reply(
            200,
            Fixtures.activityAssignmentsPage([
              Fixtures.activityAssignmentJson(
                id: 'a1',
                pointsReward: 20,
                activity: Fixtures.activityJson(title: 'Read together'),
                completions: [
                  Fixtures.activityCompletionJson(id: 'c1', status: 'pending'),
                ],
              ),
            ]),
          ),
        );
      await _pump(tester, api, const ChildActivitiesScreen());

      expect(find.text('Read together'), findsOneWidget);
      expect(find.text(l.activityRewardPoints(20)), findsOneWidget);
      // owner can review the pending completion
      expect(find.text(l.redemptionApprove), findsOneWidget);
      expect(find.text(l.redemptionReject), findsOneWidget);
      // and the honest on-behalf note is present
      expect(find.text(l.activityOnBehalfNote), findsWidgets);
    },
  );

  testWidgets('child activities empty state', (tester) async {
    final api = TestApi.create(
      token: 'tok',
      locale: 'en',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
    );
    addTearDown(api.dispose);
    api.adapter
      ..onGet(
        '/families/family-1/members',
        (s) => s.reply(
          200,
          Fixtures.membersEnvelope([Fixtures.memberJson(role: 'owner')]),
        ),
      )
      ..onGet(
        '$c/activity-assignments',
        (s) => s.reply(200, Fixtures.activityAssignmentsPage(const [])),
      );
    await _pump(tester, api, const ChildActivitiesScreen());
    expect(find.text(l.activitiesAssignedEmpty), findsOneWidget);
  });

  testWidgets('RTL smoke (Arabic)', (tester) async {
    final api = TestApi.create(
      token: 'tok',
      locale: 'ar',
      activeFamilyId: 'family-1',
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      '/activities',
      (s) => s.reply(
        200,
        Fixtures.activitiesPage([Fixtures.activityJson(title: 'نشاط')]),
      ),
    );
    await _pump(tester, api, const ActivitiesScreen(), locale: 'ar');
    expect(
      Directionality.of(tester.element(find.text('نشاط'))),
      TextDirection.rtl,
    );
  });
}
