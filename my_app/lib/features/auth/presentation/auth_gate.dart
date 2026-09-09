import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../family/presentation/family_selection_screen.dart';
import '../../family/presentation/no_family_screen.dart';
import '../../shell/app_shell.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import 'welcome_screen.dart';

/// Root of the widget tree. Decides — without flicker — which top-level surface
/// to show based on the session restore result.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    final child = switch (auth.phase) {
      AuthPhase.restoring => const _Splash(),
      AuthPhase.restoreFailed => Scaffold(
        body: SafeArea(
          child: ErrorRetryView(
            error: auth.restoreError!,
            onRetry: () =>
                ref.read(authControllerProvider.notifier).retryRestore(),
          ),
        ),
      ),
      AuthPhase.unauthenticated => const WelcomeScreen(),
      AuthPhase.authenticated => _authenticatedSurface(auth),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(key: ValueKey(_surfaceKey(auth)), child: child),
    );
  }

  Widget _authenticatedSurface(AuthState auth) {
    if (auth.hasNoFamily) return const NoFamilyScreen();
    if (auth.needsFamilySelection) return const FamilySelectionScreen();
    return const AppShell();
  }

  String _surfaceKey(AuthState auth) {
    if (auth.phase != AuthPhase.authenticated) return auth.phase.name;
    if (auth.hasNoFamily) return 'no-family';
    if (auth.needsFamilySelection) return 'family-selection';
    return 'shell';
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
      ),
    );
  }
}
