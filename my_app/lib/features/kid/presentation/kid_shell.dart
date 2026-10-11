import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/deep_links.dart';
import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/presentation/inbox_screen.dart';
import '../application/kid_providers.dart';
import '../data/kid_models.dart';
import '../data/kid_repository.dart';
import 'me_screen.dart';
import 'my_day_screen.dart';
import 'kid_rewards_screen.dart';
import 'routine_run_screen.dart';
import 'task_sheet.dart';
import 'together_screen.dart';

/// The child experience: playful theme, four big tabs, data refreshed when
/// the app comes back to the foreground (no background polling).
class KidShell extends ConsumerStatefulWidget {
  const KidShell({super.key});

  @override
  ConsumerState<KidShell> createState() => _KidShellState();
}

class _KidShellState extends ConsumerState<KidShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    DeepLinks.kidOpener = _openKidRoute;
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(kidActionsProvider).refreshAll();
        ref.invalidate(unreadCountProvider);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => DeepLinks.consumePending(ref),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    if (DeepLinks.kidOpener == _openKidRoute) DeepLinks.kidOpener = null;
    super.dispose();
  }

  Future<void> _openKidRoute(NavigatorState nav, Reader read, Uri uri) async {
    final s = uri.pathSegments;
    if (s.length < 2) return;
    final tab = read(kidTabProvider.notifier);
    switch (s[1]) {
      case 'my-day':
        tab.state = 0;
      case 'rewards':
        tab.state = 1;
      case 'challenges' || 'messages':
        tab.state = 2;
      case 'requests':
        tab.state = 3;
        await nav.push(
          MaterialPageRoute<void>(builder: (_) => const KidRequestsScreen()),
        );
      case 'notifications':
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationInboxScreen(),
          ),
        );
      case 'routines' when s.length >= 3:
        tab.state = 0;
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) => RoutineRunScreen(routineId: s[2]),
          ),
        );
      case 'tasks' when s.length >= 3:
        tab.state = 0;
        try {
          final json = await read(kidRepositoryProvider).task(s[2]);
          final ctx = nav.context;
          if (ctx.mounted) {
            await showKidTaskSheet(ctx, KidTaskSummary.fromJson(json));
          }
        } catch (_) {
          // Not this child's task (404) or offline — stay on My Day.
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final index = ref.watch(kidTabProvider);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    void go(int i) => ref.read(kidTabProvider.notifier).state = i;

    return Theme(
      data: AppTheme.kid,
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            MyDayScreen(
              onOpenRewards: () => go(1),
              onOpenTogether: () => go(2),
            ),
            const KidRewardsScreen(),
            const TogetherScreen(),
            const KidMeScreen(),
          ],
        ),
        // Tab bars stay usable at large text sizes, like the system tab bar.
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: go,
            height: 76,
            destinations: [
              NavigationDestination(
                icon: const Text('🌞', style: TextStyle(fontSize: 26)),
                label: l.kidTabMyDay,
              ),
              NavigationDestination(
                icon: const Text('🎁', style: TextStyle(fontSize: 26)),
                label: l.kidTabRewards,
              ),
              NavigationDestination(
                icon: const Text('🤝', style: TextStyle(fontSize: 26)),
                label: l.kidTabTogether,
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Text('🙂', style: TextStyle(fontSize: 26)),
                ),
                label: l.kidTabMe,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
