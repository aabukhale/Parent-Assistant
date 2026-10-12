import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/family_membership.dart';

/// Minimal family picker shown only when the authenticated user belongs to more
/// than one family and none is stored as active. No redesign — a plain list.
class FamilySelectionScreen extends ConsumerWidget {
  const FamilySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships =
        ref.watch(authControllerProvider).session?.memberships ??
        const <FamilyMembership>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.familySelectTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: AppContentFrame(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          itemCount: memberships.length,
          itemBuilder: (context, i) {
            final m = memberships[i];
            return AppListTile(
              leading: const IconBadge(emoji: '🏡', tone: AppTone.accent),
              title: m.family.name,
              subtitle: switch (m.role) {
                FamilyRole.owner => context.l10n.profileRoleOwner,
                FamilyRole.parent => context.l10n.profileRoleParent,
                FamilyRole.caregiver => context.l10n.profileRoleCaregiver,
              },
              onTap: () => ref
                  .read(authControllerProvider.notifier)
                  .selectActiveFamily(m.id),
            );
          },
        ),
      ),
    );
  }
}
