import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/auth/data/models/family_membership.dart';
import 'package:my_app/features/children/application/selected_child_controller.dart';
import 'package:my_app/features/children/data/models/child.dart';
import 'package:my_app/features/children/data/models/interest.dart';
import 'package:my_app/features/tasks/presentation/task_detail_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: TaskDetailScreen(taskId: 't1'),
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
    required List<Map<String, dynamic>> completions,
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
        '$c/tasks/t1',
        (s) => s.reply(
          200,
          Fixtures.taskEnvelope(
            task: Fixtures.taskJson(id: 't1', title: 'Read'),
          ),
        ),
      )
      ..onGet(
        '$c/tasks/t1/completions',
        (s) => s.reply(200, Fixtures.completionsPage(completions)),
      );
    return api;
  }

  testWidgets('pending completion: owner sees Approve + Reject', (
    tester,
  ) async {
    final api = make(
      completions: [Fixtures.completionJson(id: 'x1', status: 'pending')],
    );
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.completionStatusPending), findsOneWidget);
    expect(find.text(l.completionApprove), findsOneWidget);
    expect(find.text(l.completionReject), findsOneWidget);
    expect(find.text(l.completionReverse), findsNothing);
  });

  testWidgets('approved completion: Reverse only (with reverse_points)', (
    tester,
  ) async {
    final api = make(
      completions: [
        Fixtures.completionJson(
          id: 'x1',
          status: 'approved',
          pointsAwarded: 20,
          reviewedAt: '2026-09-07T10:00:00.000Z',
        ),
      ],
    );
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.completionStatusApproved), findsOneWidget);
    expect(find.textContaining('+20'), findsOneWidget);
    expect(find.text(l.completionApprove), findsNothing);
    expect(find.text(l.completionReverse), findsOneWidget);
  });

  testWidgets('reversed completion: badge shown, no actions', (tester) async {
    final api = make(
      completions: [
        Fixtures.completionJson(
          id: 'x1',
          status: 'approved',
          pointsAwarded: 20,
          reviewedAt: '2026-09-07T10:00:00.000Z',
          reversedAt: '2026-09-08T10:00:00.000Z',
        ),
      ],
    );
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.completionReversedBadge), findsWidgets);
    expect(find.text(l.completionReverse), findsNothing);
    expect(find.text(l.completionApprove), findsNothing);
  });

  testWidgets('rejected completion: no actions', (tester) async {
    final api = make(
      completions: [
        Fixtures.completionJson(
          id: 'x1',
          status: 'rejected',
          reviewedAt: '2026-09-07T10:00:00.000Z',
        ),
      ],
    );
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.completionStatusRejected), findsOneWidget);
    expect(find.text(l.completionApprove), findsNothing);
    expect(find.text(l.completionReject), findsNothing);
    expect(find.text(l.completionReverse), findsNothing);
  });

  testWidgets('caregiver without approve_task_completions: no review buttons', (
    tester,
  ) async {
    final api = make(
      role: FamilyRole.caregiver,
      permissions: const [],
      completions: [Fixtures.completionJson(id: 'x1', status: 'pending')],
    );
    addTearDown(api.dispose);
    await _pump(tester, api);

    expect(find.text(l.completionStatusPending), findsOneWidget);
    expect(find.text(l.completionApprove), findsNothing);
    expect(
      find.text(l.completionRequest),
      findsOneWidget,
      reason: 'any member may still request a completion',
    );
  });

  testWidgets('caregiver with approve but not reverse: Approve/Reject only', (
    tester,
  ) async {
    final api = make(
      role: FamilyRole.caregiver,
      permissions: const ['approve_task_completions'],
      completions: [
        Fixtures.completionJson(
          id: 'x1',
          status: 'approved',
          pointsAwarded: 5,
          reviewedAt: '2026-09-07T10:00:00.000Z',
        ),
      ],
    );
    addTearDown(api.dispose);
    await _pump(tester, api);
    // approved → only reverse could apply, and caregiver lacks reverse_points
    expect(find.text(l.completionReverse), findsNothing);
  });

  testWidgets(
    'caregiver with reverse_points sees Reverse on an approved completion',
    (tester) async {
      final api = make(
        role: FamilyRole.caregiver,
        permissions: const ['reverse_points'],
        completions: [
          Fixtures.completionJson(
            id: 'x1',
            status: 'approved',
            pointsAwarded: 5,
            reviewedAt: '2026-09-07T10:00:00.000Z',
          ),
        ],
      );
      addTearDown(api.dispose);
      await _pump(tester, api);
      expect(find.text(l.completionReverse), findsOneWidget);
    },
  );
}
