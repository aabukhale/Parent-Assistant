import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/deep_links.dart';
import '../../core/localization/l10n.dart';
import '../../core/providers.dart';
import '../account/account_screen.dart';
import '../children/presentation/children_screen.dart';
import '../discover/discover_screen.dart';
import '../family_hub/application/hub_providers.dart';
import '../family_hub/presentation/challenges_screen.dart';
import '../family_hub/presentation/child_hub_screen.dart';
import '../family_hub/presentation/child_sections.dart';
import '../family_hub/presentation/planner_screen.dart';
import '../family_hub/presentation/recap_screen.dart';
import '../family_hub/presentation/requests_inbox_screen.dart';
import '../family_hub/presentation/today_screen.dart';
import '../notifications/application/notifications_controller.dart';
import '../notifications/presentation/inbox_screen.dart';
import '../notifications/push/push_service.dart';
import '../surfaces/surface_sync.dart';
import '../tasks/presentation/task_detail_screen.dart';

/// Parent experience: Today · Children · Discover · Account.
///
/// Data refreshes when the app returns to the foreground; there is no
/// background polling. The out-of-app widget/overlay is refreshed at the same
/// moments.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    DeepLinks.parentOpener = _openParentRoute;
    _lifecycle = AppLifecycleListener(onResume: _refreshAll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await DeepLinks.consumePending(ref);
      await ref.read(pushServiceProvider).registerCurrentSession();
      await ref.read(surfaceSyncProvider).refresh();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    if (DeepLinks.parentOpener == _openParentRoute) {
      DeepLinks.parentOpener = null;
    }
    super.dispose();
  }

  void _refreshAll() {
    ref
      ..invalidate(pulseProvider)
      ..invalidate(familyInboxProvider)
      ..invalidate(challengesProvider)
      ..invalidate(unreadCountProvider);
    ref.read(dashboardRefreshSignalProvider.notifier).state++;
    ref.read(surfaceSyncProvider).refresh();
  }

  Future<void> _openParentRoute(
    NavigatorState nav,
    Reader read,
    Uri uri,
  ) async {
    final s = uri.pathSegments;
    if (s.length < 2) return;
    // A link (widget, floating card, notification) starts from the root,
    // so repeated taps don't stack the same screen again and again.
    nav.popUntil((r) => r.isFirst);
    // Not awaited: a nested route (hub → check-ins) must stack both screens
    // now, not open the second only after the first is popped.
    void push(Widget w) =>
        unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => w)));
    switch (s[1]) {
      case 'inbox':
        read(parentTabProvider.notifier).state = 0;
        push(const RequestsInboxScreen());
      case 'notifications':
        push(const NotificationInboxScreen());
      case 'planner':
        push(const PlannerScreen());
      case 'recap':
        push(const RecapScreen());
      case 'challenges' when s.length >= 3:
        push(ChallengeDetailScreen(challengeId: s[2]));
      case 'challenges':
        push(const ChallengesScreen());
      case 'children' when s.length >= 3:
        final childId = s[2];
        read(parentTabProvider.notifier).state = 1;
        push(ChildHubScreen(childId: childId));
        if (s.length >= 4) {
          switch (s[3]) {
            case 'checkins':
              push(ChildCheckinsScreen(childId: childId, childName: ''));
            case 'routines':
              push(ChildRoutinesScreen(childId: childId, childName: ''));
            case 'tasks' when s.length >= 5:
              push(TaskDetailScreen(taskId: s[4]));
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final index = ref.watch(parentTabProvider);
    final waiting =
        ref.watch(familyInboxProvider(null)).valueOrNull?.value.items.length ??
        0;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          TodayScreen(),
          ChildrenScreen(),
          DiscoverScreen(),
          AccountScreen(),
        ],
      ),
      // Tab bars stay usable at large text sizes, like the system tab bar.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) =>
              ref.read(parentTabProvider.notifier).state = i,
          destinations: [
            NavigationDestination(
              icon: Badge(
                isLabelVisible: waiting > 0,
                label: Text('$waiting'),
                child: const Icon(Icons.wb_sunny_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: waiting > 0,
                label: Text('$waiting'),
                child: const Icon(Icons.wb_sunny_rounded),
              ),
              label: l.tabToday,
            ),
            NavigationDestination(
              icon: const Icon(Icons.family_restroom_outlined),
              selectedIcon: const Icon(Icons.family_restroom_rounded),
              label: l.tabChildren,
            ),
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore_rounded),
              label: l.tabDiscover,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l.tabAccount,
            ),
          ],
        ),
      ),
    );
  }
}
