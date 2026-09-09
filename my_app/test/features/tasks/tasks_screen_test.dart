import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/auth/data/models/family_membership.dart';
import 'package:my_app/features/children/application/selected_child_controller.dart';
import 'package:my_app/features/children/data/models/child.dart';
import 'package:my_app/features/children/data/models/interest.dart';
import 'package:my_app/features/tasks/presentation/tasks_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: TasksScreen(),
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
  const c = '/families/family-1/children/child-1';

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
    api.adapter
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
        '$c/points-balance',
        (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: 240)),
      );
    return api;
  }

  testWidgets('real task list + real balance', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(
        200,
        Fixtures.tasksPage([
          Fixtures.taskJson(id: 't1', title: 'Tidy the room', points: 20),
        ]),
      ),
    );

    await _pump(tester, api);

    expect(find.text('Tidy the room'), findsOneWidget);
    expect(find.text('240'), findsOneWidget); // real balance
    expect(find.text(l.tasksAdd), findsOneWidget); // owner can add
  });

  testWidgets('empty task state', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(200, Fixtures.tasksPage(const [])),
    );

    await _pump(tester, api);
    expect(find.text(l.tasksEmpty), findsOneWidget);
  });

  testWidgets('list error → retry → recovers', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(500, {'success': false, 'message': 'x'}),
    );

    await _pump(tester, api);
    expect(find.text(l.commonRetry), findsWidgets);

    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(
        200,
        Fixtures.tasksPage([
          Fixtures.taskJson(id: 't1', title: 'Recovered task'),
        ]),
      ),
    );
    await tester.tap(find.text(l.commonRetry).first);
    await tester.pumpAndSettle();
    expect(find.text('Recovered task'), findsOneWidget);
  });

  testWidgets('caregiver without manage_tasks cannot add', (tester) async {
    final api = make(role: FamilyRole.caregiver, permissions: const []);
    addTearDown(api.dispose);
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(200, Fixtures.tasksPage(const [])),
    );

    await _pump(tester, api);
    expect(find.text(l.tasksAdd), findsNothing);
  });

  testWidgets('caregiver WITH manage_tasks can add', (tester) async {
    final api = make(
      role: FamilyRole.caregiver,
      permissions: const ['manage_tasks'],
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      '$c/tasks',
      (s) => s.reply(200, Fixtures.tasksPage([Fixtures.taskJson(id: 't1')])),
    );

    await _pump(tester, api);
    expect(find.text(l.tasksAdd), findsWidgets);
  });

  testWidgets(
    'permission fetch failure → caregiver sees retry banner, no add',
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
          '/families/family-1/members',
          (s) => s.reply(503, {'success': false, 'message': 'x'}),
        )
        ..onGet(
          '$c/points-balance',
          (s) => s.reply(200, Fixtures.pointsBalanceEnvelope()),
        )
        ..onGet('$c/tasks', (s) => s.reply(200, Fixtures.tasksPage(const [])));

      await _pump(tester, api);
      expect(find.text(l.permLoadFailed), findsOneWidget);
      expect(find.text(l.tasksAdd), findsNothing);
    },
  );
}
