import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../auth/application/auth_controller.dart';

/// The authenticated user has no active family membership. Registration always
/// creates one, so this is an edge case (e.g. membership revoked). Honest dead
/// end rather than a broken shell.
class NoFamilyScreen extends ConsumerWidget {
  const NoFamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      body: AppContentFrame(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconBadge(
                  icon: Icons.home_rounded,
                  tone: AppTone.accent,
                  size: 80,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.noFamilyTitle,
                  textAlign: TextAlign.center,
                  style: context.type.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.noFamilyBody,
                  textAlign: TextAlign.center,
                  style: context.type.bodyMedium?.copyWith(
                    color: context.mamily.ink2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l.authLogout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
