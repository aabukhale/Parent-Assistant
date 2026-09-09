import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/auth/data/models/family_membership.dart';
import 'package:my_app/features/children/application/selected_child_controller.dart';
import 'package:my_app/features/children/data/models/child.dart';
import 'package:my_app/features/children/data/models/interest.dart';
import 'package:my_app/features/rewards/presentation/rewards_store_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

Widget _host(TestApi api) => UncontrolledProviderScope(
  container: api.container,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: RewardsStoreScreen(),
  ),
);

Future<void> _pump(WidgetTester tester, TestApi api) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(api));
  await tester.pumpAndSettle();
}

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  const rewards = '/families/family-1/rewards';
  const c = '/families/family-1/children/child-1';

  TestApi make({
    FamilyRole role = FamilyRole.owner,
    List<String>? permissions,
    int balance = 200,
    List<Map<String, dynamic>>? catalog,
    List<Map<String, dynamic>>? redemptions,
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
        (s) => s.reply(200, Fixtures.pointsBalanceEnvelope(balance: balance)),
      )
      ..onGet(
        '$c/point-transactions',
        (s) => s.reply(200, Fixtures.pointTxPage(const [])),
      )
      ..onGet(
        rewards,
        (s) => s.reply(
          200,
          Fixtures.rewardsPage(
            catalog ??
                [
                  Fixtures.rewardJson(
                    id: 'g',
                    familyId: null,
                    title: 'Global treat',
                    pointsCost: 100,
                  ),
                  Fixtures.rewardJson(
                    id: 'f',
                    familyId: 'family-1',
                    title: 'Our reward',
                    pointsCost: 300,
                  ),
                ],
          ),
        ),
      )
      ..onGet(
        '$c/reward-redemptions',
        (s) => s.reply(200, Fixtures.redemptionsPage(redemptions ?? const [])),
      );
    return api;
  }

  testWidgets(
    'catalog: global + family rewards with scope badges + real balance',
    (tester) async {
      final api = make();
      addTearDown(api.dispose);
      await _pump(tester, api);

      expect(find.text('Global treat'), findsOneWidget);
      expect(find.text('Our reward'), findsOneWidget);
      expect(find.text(l.rewardScopeGlobal), findsOneWidget);
      expect(find.text(l.rewardScopeFamily), findsOneWidget);
      expect(find.text('200'), findsOneWidget); // real balance
      expect(find.text(l.rewardsAdd), findsOneWidget); // owner can add
    },
  );

  testWidgets(
    'affordability hint: affordable vs needs-more from cached balance',
    (tester) async {
      final api = make(
        balance: 150,
        catalog: [
          Fixtures.rewardJson(id: 'a', title: 'Cheap', pointsCost: 100),
          Fixtures.rewardJson(id: 'b', title: 'Pricey', pointsCost: 500),
        ],
      );
      addTearDown(api.dispose);
      await _pump(tester, api);

      expect(find.text(l.rewardAffordCan), findsWidgets);
      expect(find.text(l.rewardAffordNeed(350)), findsOneWidget); // 500 - 150
    },
  );

  testWidgets('catalog empty state', (tester) async {
    final api = make(catalog: const []);
    addTearDown(api.dispose);
    await _pump(tester, api);
    expect(find.text(l.rewardsCatalogEmpty), findsOneWidget);
  });

  testWidgets('catalog error → retry recovers', (tester) async {
    final api = make();
    addTearDown(api.dispose);
    api.adapter.onGet(
      rewards,
      (s) => s.reply(500, {'success': false, 'message': 'x'}),
    );
    await _pump(tester, api);
    expect(find.text(l.commonRetry), findsWidgets);

    api.adapter.onGet(
      rewards,
      (s) => s.reply(
        200,
        Fixtures.rewardsPage([
          Fixtures.rewardJson(id: 'g', title: 'Recovered'),
        ]),
      ),
    );
    await tester.tap(find.text(l.commonRetry).first);
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets('redemptions tab: pending/approved/rejected/cancelled states', (
    tester,
  ) async {
    final api = make(
      redemptions: [
        Fixtures.redemptionJson(
          id: 'p',
          status: 'pending',
          rewardTitle: 'Pending one',
        ),
        Fixtures.redemptionJson(
          id: 'a',
          status: 'approved',
          rewardTitle: 'Approved one',
          deductionTxnId: 'd',
        ),
        Fixtures.redemptionJson(
          id: 'r',
          status: 'rejected',
          rewardTitle: 'Rejected one',
        ),
        Fixtures.redemptionJson(
          id: 'x',
          status: 'cancelled',
          rewardTitle: 'Cancelled one',
          refundTxnId: 'rf',
        ),
      ],
    );
    addTearDown(api.dispose);
    await _pump(tester, api);
    await tester.tap(find.text(l.rewardsTabHistory));
    await tester.pumpAndSettle();

    expect(find.text(l.redemptionStatusPending), findsOneWidget);
    expect(find.text(l.redemptionStatusApproved), findsOneWidget);
    expect(find.text(l.redemptionStatusRejected), findsOneWidget);
    expect(find.text(l.redemptionStatusCancelled), findsOneWidget);
    // owner can approve the pending one and cancel the approved one
    expect(find.text(l.redemptionApprove), findsOneWidget);
    expect(find.text(l.redemptionCancel), findsOneWidget);
  });

  testWidgets('screen-time override card shows minutes + policy note', (
    tester,
  ) async {
    final api = make(
      redemptions: [
        Fixtures.redemptionJson(
          id: 'a',
          status: 'approved',
          rewardType: 'screen_time',
          deductionTxnId: 'd',
          screenTimeOverride: Fixtures.screenTimeOverrideJson(
            additionalMinutes: 45,
          ),
        ),
      ],
    );
    addTearDown(api.dispose);
    await _pump(tester, api);
    await tester.tap(find.text(l.rewardsTabHistory));
    await tester.pumpAndSettle();

    expect(find.text(l.screenTimeGranted(45)), findsOneWidget);
    expect(find.text(l.screenTimePolicyNote), findsOneWidget);
  });

  testWidgets(
    'caregiver without manage_rewards: no add, no family-reward menu',
    (tester) async {
      final api = make(role: FamilyRole.caregiver, permissions: const []);
      addTearDown(api.dispose);
      await _pump(tester, api);
      expect(find.text(l.rewardsAdd), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    },
  );

  testWidgets('caregiver with manage_rewards: add + family-reward menu', (
    tester,
  ) async {
    final api = make(
      role: FamilyRole.caregiver,
      permissions: const ['manage_rewards'],
    );
    addTearDown(api.dispose);
    await _pump(tester, api);
    expect(find.text(l.rewardsAdd), findsWidgets);
    expect(
      find.byIcon(Icons.more_vert_rounded),
      findsOneWidget,
    ); // only the family reward
  });

  testWidgets(
    'caregiver without approve_redemptions: no review buttons; can still request',
    (tester) async {
      final api = make(
        role: FamilyRole.caregiver,
        permissions: const [],
        redemptions: [Fixtures.redemptionJson(id: 'p', status: 'pending')],
      );
      addTearDown(api.dispose);
      await _pump(tester, api);
      expect(
        find.text(l.rewardRequest),
        findsWidgets,
      ); // catalog redeem buttons
      await tester.tap(find.text(l.rewardsTabHistory));
      await tester.pumpAndSettle();
      expect(find.text(l.redemptionApprove), findsNothing);
      expect(find.text(l.redemptionCancel), findsNothing);
    },
  );

  testWidgets(
    'caregiver with approve_redemptions: approve/reject/cancel visible',
    (tester) async {
      final api = make(
        role: FamilyRole.caregiver,
        permissions: const ['approve_redemptions'],
        redemptions: [
          Fixtures.redemptionJson(id: 'p', status: 'pending'),
          Fixtures.redemptionJson(
            id: 'a',
            status: 'approved',
            deductionTxnId: 'd',
          ),
        ],
      );
      addTearDown(api.dispose);
      await _pump(tester, api);
      await tester.tap(find.text(l.rewardsTabHistory));
      await tester.pumpAndSettle();
      expect(find.text(l.redemptionApprove), findsOneWidget);
      expect(find.text(l.redemptionReject), findsOneWidget);
      expect(find.text(l.redemptionCancel), findsOneWidget);
    },
  );

  testWidgets(
    'permission fetch failure → caregiver sees retry banner, no management',
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
        ..onGet(
          '$c/point-transactions',
          (s) => s.reply(200, Fixtures.pointTxPage(const [])),
        )
        ..onGet(
          rewards,
          (s) => s.reply(
            200,
            Fixtures.rewardsPage([
              Fixtures.rewardJson(id: 'f', familyId: 'family-1'),
            ]),
          ),
        )
        ..onGet(
          '$c/reward-redemptions',
          (s) => s.reply(200, Fixtures.redemptionsPage(const [])),
        );

      await _pump(tester, api);
      expect(find.text(l.permLoadFailed), findsOneWidget);
      expect(find.text(l.rewardsAdd), findsNothing);
    },
  );
}
