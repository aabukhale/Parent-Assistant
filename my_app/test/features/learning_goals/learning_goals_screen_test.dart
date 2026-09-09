import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/auth/data/models/family_membership.dart';
import 'package:my_app/features/children/application/selected_child_controller.dart';
import 'package:my_app/features/children/data/models/child.dart';
import 'package:my_app/features/children/data/models/interest.dart';
import 'package:my_app/features/learning_goals/presentation/learning_goals_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: LearningGoalsScreen(),
  ),
);

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const base = '/families/family-1/children/child-1/learning-goals';
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
        // selectedChildProvider is derived from the children list; stub it.
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

  testWidgets('empty state renders and offers add for an owner', (
    tester,
  ) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(base, (s) => s.reply(200, Fixtures.goalsPage(const [])));

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text(l.lgEmpty), findsOneWidget);
    expect(find.text(l.lgAddGoal), findsWidgets);
  });

  testWidgets('list renders goal titles and status', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.goalsPage([
          Fixtures.goalJson(id: 'g1', title: 'Read 20 books', status: 'active'),
          Fixtures.goalJson(
            id: 'g2',
            title: 'Tidy room',
            metric: 'boolean',
            targetValue: null,
            status: 'achieved',
            progressPercentage: null,
            currentValue: 1,
          ),
        ]),
      ),
    );

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('Read 20 books'), findsOneWidget);
    expect(find.text('Tidy room'), findsOneWidget);
    expect(find.text(l.lgStatusAchieved), findsWidgets);
  });

  testWidgets('error → retry → recovers', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      base,
      (s) => s.reply(500, {'success': false, 'message': 'x'}),
    );

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    expect(find.text(l.commonRetry), findsOneWidget);

    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.goalsPage([
          Fixtures.goalJson(id: 'g1', title: 'Recovered goal'),
        ]),
      ),
    );
    await tester.tap(find.text(l.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text('Recovered goal'), findsOneWidget);
  });

  testWidgets('caregiver without manage_learning_goals sees no add action', (
    tester,
  ) async {
    final api = make(role: FamilyRole.caregiver, permissions: const []);
    addTearDown(api.dispose);
    api.adapter.onGet(base, (s) => s.reply(200, Fixtures.goalsPage(const [])));

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text(l.lgEmpty), findsOneWidget);
    expect(find.text(l.lgAddGoal), findsNothing);
  });

  testWidgets('caregiver WITH manage_learning_goals sees the add action', (
    tester,
  ) async {
    final api = make(
      role: FamilyRole.caregiver,
      permissions: const ['manage_learning_goals'],
    );
    addTearDown(api.dispose);
    api.adapter.onGet(base, (s) => s.reply(200, Fixtures.goalsPage(const [])));

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text(l.lgAddGoal), findsWidgets);
  });

  testWidgets(
    'permission fetch failure hides actions for a caregiver + shows retry',
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
        ..onGet(base, (s) => s.reply(200, Fixtures.goalsPage(const [])));

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.text(l.permLoadFailed), findsOneWidget);
      expect(find.text(l.lgAddGoal), findsNothing);
    },
  );
}
