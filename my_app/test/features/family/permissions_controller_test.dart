import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/auth/data/models/family_membership.dart';
import 'package:my_app/features/family/application/permissions_controller.dart';
import 'package:my_app/features/family/data/family_members_repository.dart';
import 'package:my_app/features/family/data/models/family_permission.dart';

import '../../support/fixtures.dart';
import '../../support/test_api.dart';

void main() {
  const base = '/families/family-1/members';

  Future<Permissions> load(TestApi api) async {
    final sub = api.container.listen(familyMembersProvider, (_, _) {});
    addTearDown(sub.close);
    await api.container.read(familyMembersProvider.future);
    return api.container.read(permissionsProvider);
  }

  test('owner: holds every permission and can manage children', () async {
    final api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      role: FamilyRole.owner,
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.membersEnvelope([Fixtures.memberJson(role: 'owner')]),
      ),
    );

    final perms = await load(api);
    expect(perms.isReady, isTrue);
    expect(perms.hasPermission(FamilyPermission.manageLearningGoals), isTrue);
    expect(perms.hasPermission(FamilyPermission.reversePoints), isTrue);
    expect(perms.canManageChildren, isTrue);
    expect(perms.effectivePermissions.length, FamilyPermission.values.length);
  });

  test('parent: same as owner', () async {
    final api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      role: FamilyRole.parent,
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.membersEnvelope([Fixtures.memberJson(role: 'parent')]),
      ),
    );

    final perms = await load(api);
    expect(perms.hasPermission(FamilyPermission.manageLearningGoals), isTrue);
    expect(perms.canManageChildren, isTrue);
  });

  test(
    'caregiver without a grant: denied everything, cannot manage children',
    () async {
      final api = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        role: FamilyRole.caregiver,
      );
      addTearDown(api.dispose);
      api.adapter.onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.membersEnvelope([
            Fixtures.memberJson(
              role: 'caregiver',
              effectivePermissions: const [],
            ),
          ]),
        ),
      );

      final perms = await load(api);
      expect(perms.isReady, isTrue);
      expect(
        perms.hasPermission(FamilyPermission.manageLearningGoals),
        isFalse,
      );
      expect(perms.canManageChildren, isFalse);
      expect(perms.effectivePermissions, isEmpty);
    },
  );

  test('caregiver with manage_learning_goals: that one only', () async {
    final api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      role: FamilyRole.caregiver,
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.membersEnvelope([
          Fixtures.memberJson(
            role: 'caregiver',
            effectivePermissions: const ['manage_learning_goals'],
          ),
        ]),
      ),
    );

    final perms = await load(api);
    expect(perms.hasPermission(FamilyPermission.manageLearningGoals), isTrue);
    expect(perms.hasPermission(FamilyPermission.manageTasks), isFalse);
    expect(
      perms.canManageChildren,
      isFalse,
      reason: 'child mgmt is role-gated',
    );
  });

  test('the authenticated user is matched by membership id', () async {
    final api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      role: FamilyRole.caregiver,
    );
    addTearDown(api.dispose);
    api.adapter.onGet(
      base,
      (s) => s.reply(
        200,
        Fixtures.membersEnvelope([
          // someone else, with a grant
          Fixtures.memberJson(
            id: 'other',
            userId: 'other-user',
            role: 'parent',
          ),
          // me
          Fixtures.memberJson(
            id: 'member-test',
            userId: 'user-test',
            role: 'caregiver',
            effectivePermissions: const ['manage_sleep'],
          ),
        ]),
      ),
    );

    final perms = await load(api);
    expect(perms.hasPermission(FamilyPermission.manageSleep), isTrue);
    expect(perms.hasPermission(FamilyPermission.manageTasks), isFalse);
  });

  test('switching family clears the old family\'s permissions', () async {
    final api = TestApi.create(
      token: 'tok',
      activeFamilyId: 'family-1',
      role: FamilyRole.caregiver,
    );
    addTearDown(api.dispose);
    api.adapter
      ..onGet(
        '/families/family-1/members',
        (s) => s.reply(
          200,
          Fixtures.membersEnvelope([
            Fixtures.memberJson(
              role: 'caregiver',
              effectivePermissions: const ['manage_learning_goals'],
            ),
          ]),
        ),
      )
      ..onGet(
        '/families/family-2/members',
        (s) => s.reply(
          200,
          Fixtures.membersEnvelope([
            Fixtures.memberJson(
              familyId: 'family-2',
              role: 'caregiver',
              effectivePermissions: const [],
            ),
          ]),
        ),
      );

    var perms = await load(api);
    expect(perms.hasPermission(FamilyPermission.manageLearningGoals), isTrue);

    api.setActiveFamily('family-2');
    // brief transition: not ready, caregiver → denied (never the old grant)
    expect(
      api.container
          .read(permissionsProvider)
          .hasPermission(FamilyPermission.manageLearningGoals),
      isFalse,
    );

    await api.container.read(familyMembersProvider.future);
    perms = api.container.read(permissionsProvider);
    expect(perms.hasPermission(FamilyPermission.manageLearningGoals), isFalse);
  });

  test(
    'members fetch failure → caregiver denied, owner still allowed',
    () async {
      final caregiver = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        role: FamilyRole.caregiver,
      );
      addTearDown(caregiver.dispose);
      caregiver.adapter.onGet(
        base,
        (s) => s.reply(503, {'success': false, 'message': 'down'}),
      );

      final sub = caregiver.container.listen(familyMembersProvider, (_, _) {});
      addTearDown(sub.close);
      try {
        await caregiver.container.read(familyMembersProvider.future);
      } catch (_) {
        /* expected */
      }
      final cPerms = caregiver.container.read(permissionsProvider);
      expect(cPerms.hasError, isTrue);
      expect(
        cPerms.hasPermission(FamilyPermission.manageLearningGoals),
        isFalse,
      );
      expect(cPerms.shouldSurfacePermissionError, isTrue);

      final owner = TestApi.create(
        token: 'tok',
        activeFamilyId: 'family-1',
        role: FamilyRole.owner,
      );
      addTearDown(owner.dispose);
      owner.adapter.onGet(
        base,
        (s) => s.reply(503, {'success': false, 'message': 'down'}),
      );
      final oSub = owner.container.listen(familyMembersProvider, (_, _) {});
      addTearDown(oSub.close);
      try {
        await owner.container.read(familyMembersProvider.future);
      } catch (_) {
        /* expected */
      }
      final oPerms = owner.container.read(permissionsProvider);
      expect(
        oPerms.hasPermission(FamilyPermission.manageLearningGoals),
        isTrue,
        reason: 'owner invariant survives a members-fetch failure',
      );
      expect(oPerms.shouldSurfacePermissionError, isFalse);
    },
  );

  test('no active family → empty members, no request', () async {
    final api = TestApi.create(token: 'tok');
    addTearDown(api.dispose);
    final members = await api.container.read(familyMembersProvider.future);
    expect(members, isEmpty);
    expect(api.requests.where((r) => r.uri.path.contains('/members')), isEmpty);
  });

  test('repository pages through all members', () async {
    final api = TestApi.create(token: 'tok', activeFamilyId: 'family-1');
    addTearDown(api.dispose);
    api.adapter
      ..onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.membersEnvelope(
            [Fixtures.memberJson(id: 'm1', userId: 'u1', role: 'owner')],
            currentPage: 1,
            lastPage: 2,
          ),
        ),
        queryParameters: {'page': '1'},
      )
      ..onGet(
        base,
        (s) => s.reply(
          200,
          Fixtures.membersEnvelope(
            [Fixtures.memberJson(id: 'm2', userId: 'u2', role: 'parent')],
            currentPage: 2,
            lastPage: 2,
          ),
        ),
        queryParameters: {'page': '2'},
      );

    final all = await api.container
        .read(familyMembersRepositoryProvider)
        .listAll('family-1');
    expect(all.map((m) => m.id), containsAll(['m1', 'm2']));
    expect(all, hasLength(2));
  });
}
