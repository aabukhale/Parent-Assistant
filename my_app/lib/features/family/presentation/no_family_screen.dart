import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.family_restroom_rounded,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  l.noFamilyTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l.noFamilyBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 22),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.coral,
                  ),
                  label: Text(
                    l.authLogout,
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
