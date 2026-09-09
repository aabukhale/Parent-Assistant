import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/auth/data/models/family_membership.dart';
import 'package:my_app/features/children/application/selected_child_controller.dart';
import 'package:my_app/features/children/data/models/child.dart';
import 'package:my_app/features/children/data/models/interest.dart';
import 'package:my_app/features/sleep/presentation/sleep_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: SleepScreen(),
  ),
);

/// Pump [SleepScreen] in a tall viewport so the whole scroll view is laid out
/// (the add button / retry sit below an 800×600 fold).
Future<void> _pumpTall(WidgetTester tester, TestApi api) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(api));
  await tester.pumpAndSettle();
}

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const base = '/families/family-1/children/child-1/sleep-logs';
  const membersBase = '/families/family-1/members';

  TestApi make({
    FamilyRole role = FamilyRole.owner,
    List<String>? permissions,
  }) {
    final api = TestApi.create(
      token: 'tok',
      locale: 'en',
      activeFamilyId: 'family-1',
      selectedChildId: 'child-1',
      role: role,
      overrides: [
        selectedChildProvider.overrideWithValue(
          Child(
            id: 'child-1',
            familyId: 'family-1',
            name: 'Layan',
            birthDate: DateTime(2017, 5, 4),
            age: 8,
            status: ChildStatus.active,
            interests: const <Interest>[],
          ),
        ),
      ],
    );
    api.adapter.onGet(
      membersBase,
      (s) => s.reply(
        200,
        Fixtures.membersEnvelope([
          Fixtures.memberJson(
            role: role.name,
            effectivePermissions: permissions,
          ),
        ]),
      ),
    );
    return api;
  }

  testWidgets('shows the real average and a sleep record', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter
      ..onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.sleepLogsPage([Fixtures.sleepLogJson(id: 's1')]),
        ),
      )
      ..onGet(
        '$base/summary',
        (s) => s.reply(
          200,
          Fixtures.sleepSummaryEnvelope(averageSleepMinutes: 570),
        ),
      );

    await _pumpTall(tester, api);

    expect(find.text(l.sleepAverage), findsOneWidget);
    expect(
      find.text(l.sleepDurationHm(9, 30)),
      findsWidgets,
    ); // 570 min = 9h 30m
    expect(find.text(l.sleepAdd), findsOneWidget); // owner can add
  });

  testWidgets('honest empty summary state', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter
      ..onGet(base, (s) => s.reply(200, Fixtures.sleepLogsPage(const [])))
      ..onGet(
        '$base/summary',
        (s) => s.reply(
          200,
          Fixtures.sleepSummaryEnvelope(
            nightsLogged: 0,
            totalSleepMinutes: 0,
            nights: const [],
          ),
        ),
      );

    await _pumpTall(tester, api);

    expect(find.text(l.sleepNoData), findsOneWidget);
    expect(find.text(l.sleepRecordsEmpty), findsOneWidget);
  });

  testWidgets('list error → retry → recovers', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter
      ..onGet(base, (s) => s.reply(500, {'success': false, 'message': 'x'}))
      ..onGet(
        '$base/summary',
        (s) => s.reply(200, Fixtures.sleepSummaryEnvelope()),
      );

    await _pumpTall(tester, api);
    expect(find.text(l.commonRetry), findsWidgets);

    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.sleepLogsPage([Fixtures.sleepLogJson(id: 's1')]),
      ),
    );
    await tester.tap(find.text(l.commonRetry).first);
    await tester.pumpAndSettle();
    expect(find.text(l.sleepRecordsEmpty), findsNothing);
  });

  testWidgets('caregiver without manage_sleep cannot add', (tester) async {
    final api = make(role: FamilyRole.caregiver, permissions: const []);
    addTearDown(api.dispose);
    api.adapter
      ..onGet(base, (s) => s.reply(200, Fixtures.sleepLogsPage(const [])))
      ..onGet(
        '$base/summary',
        (s) => s.reply(
          200,
          Fixtures.sleepSummaryEnvelope(nightsLogged: 0, nights: const []),
        ),
      );

    await _pumpTall(tester, api);

    expect(find.text(l.sleepAdd), findsNothing);
  });

  testWidgets('caregiver WITH manage_sleep can add', (tester) async {
    final api = make(
      role: FamilyRole.caregiver,
      permissions: const ['manage_sleep'],
    );
    addTearDown(api.dispose);
    api.adapter
      ..onGet(base, (s) => s.reply(200, Fixtures.sleepLogsPage(const [])))
      ..onGet(
        '$base/summary',
        (s) => s.reply(
          200,
          Fixtures.sleepSummaryEnvelope(nightsLogged: 0, nights: const []),
        ),
      );

    await _pumpTall(tester, api);

    expect(find.text(l.sleepAdd), findsOneWidget);
  });

  testWidgets(
    'permission fetch failure → caregiver sees the retry banner, no add',
    (tester) async {
      final api = TestApi.create(
        token: 'tok',
        locale: 'en',
        activeFamilyId: 'family-1',
        selectedChildId: 'child-1',
        role: FamilyRole.caregiver,
        overrides: [
          selectedChildProvider.overrideWithValue(
            Child(
              id: 'child-1',
              familyId: 'family-1',
              name: 'Layan',
              birthDate: DateTime(2017, 5, 4),
              age: 8,
              status: ChildStatus.active,
              interests: const <Interest>[],
            ),
          ),
        ],
      );
      addTearDown(api.dispose);
      api.adapter
        ..onGet(
          membersBase,
          (s) => s.reply(503, {'success': false, 'message': 'x'}),
        )
        ..onGet(base, (s) => s.reply(200, Fixtures.sleepLogsPage(const [])))
        ..onGet(
          '$base/summary',
          (s) => s.reply(
            200,
            Fixtures.sleepSummaryEnvelope(nightsLogged: 0, nights: const []),
          ),
        );

      await _pumpTall(tester, api);

      expect(find.text(l.permLoadFailed), findsOneWidget);
      expect(find.text(l.sleepAdd), findsNothing);
    },
  );
}
