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
import '../../device_rules/application/device_rules_sync.dart';
import '../../remote/presentation/kid_remote_layer.dart';
import '../../safety/application/kid_safety_providers.dart';
import '../../safety/application/location_reporter.dart';
import '../../safety/presentation/kid_help_screen.dart';
import '../../safety/presentation/kid_safety_widgets.dart';
import 'kid_family_screen.dart';
import 'kid_requests_screen.dart';
import 'kid_rewards_screen.dart';
import 'my_day_screen.dart';
import 'routine_run_screen.dart';
import 'task_sheet.dart';
import 'together_screen.dart';

/// The child experience: three labelled destinations (Today, Rewards,
/// Family), help one tap away on Today, data refreshed when the app comes back
/// to the foreground. Device rules and location sync here too — visibly
/// (rules state is reported to the parent, location only when shared).
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
        ref.invalidate(kidJourneyProvider);
        _backgroundWork();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinks.consumePending(ref);
      _backgroundWork();
      ref.read(deviceRulesSyncProvider).startPeriodic();
    });
  }

  /// Rules sync, location (only if shared) and the one-time explanation
  /// that location is shared with the family.
  Future<void> _backgroundWork() async {
    ref.read(deviceRulesSyncProvider).sync();
    final reporter = ref.read(locationReporterProvider);
    await reporter.refresh();
    final journey = await ref
        .read(kidJourneyProvider.future)
        .catchError((_) => null);
    if (journey != null && journey.isLive) {
      reporter.startJourneyTracking();
    } else {
      reporter.stopJourneyTracking();
    }
    try {
      final s = await ref.read(kidLocationSettingsProvider.future);
      if (s.sharing && !s.informed && mounted) {
        await showLocationExplainSheet(context, ref);
      }
    } catch (_) {}
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
    // A link (widget, floating card, notification) starts from the root,
    // so repeated taps don't stack the same screen again and again.
    nav.popUntil((r) => r.isFirst);
    final tab = read(kidTabProvider.notifier);
    switch (s[1]) {
      case 'my-day' || 'today':
        tab.state = 0;
      case 'rewards':
        tab.state = 1;
      case 'family':
        tab.state = 2;
      case 'challenges' || 'messages':
        tab.state = 2;
        await nav.push(
          MaterialPageRoute<void>(
            builder: (ctx) => Scaffold(
              appBar: AppBar(title: Text(ctx.l10n.kidMessages)),
              body: const TogetherScreen(),
            ),
          ),
        );
      case 'requests':
        tab.state = 2;
        await nav.push(
          MaterialPageRoute<void>(builder: (_) => const KidRequestsScreen()),
        );
      case 'safety' || 'help':
        tab.state = 0;
        await nav.push(
          MaterialPageRoute<void>(builder: (_) => const KidHelpScreen()),
        );
      case 'remote':
        // The remote layer shows the request itself once it polls.
        tab.state = 0;
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
      child: KidRemoteLayer(
        child: Scaffold(
          body: IndexedStack(
            index: index.clamp(0, 2),
            children: [
              MyDayScreen(
                onOpenRewards: () => go(1),
                onOpenTogether: () => go(2),
              ),
              const KidRewardsScreen(),
              const KidFamilyScreen(),
            ],
          ),
          // Tab bars stay usable at large text sizes, like the system tab bar.
          // Every destination has an icon *and* a word.
          bottomNavigationBar: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: NavigationBar(
              selectedIndex: index.clamp(0, 2),
              onDestinationSelected: go,
              height: 76,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.wb_sunny_outlined, size: 28),
                  selectedIcon: const Icon(Icons.wb_sunny_rounded, size: 28),
                  label: l.kidTabToday,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.card_giftcard_outlined, size: 28),
                  selectedIcon: const Icon(
                    Icons.card_giftcard_rounded,
                    size: 28,
                  ),
                  label: l.kidTabRewards,
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.diversity_3_outlined, size: 28),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.diversity_3_rounded, size: 28),
                  ),
                  label: l.kidTabFamily,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
