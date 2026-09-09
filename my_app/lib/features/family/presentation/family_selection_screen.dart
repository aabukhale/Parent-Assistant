import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
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
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: memberships.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final m = memberships[i];
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              leading: const CircleAvatar(
                backgroundColor: AppColors.teal,
                child: Icon(
                  Icons.family_restroom_rounded,
                  color: AppColors.navy,
                ),
              ),
              title: Text(
                m.family.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              subtitle: Text(m.role.name),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
