import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/bottom_navigation.dart';
import '../activities/presentation/activities_screen.dart';
import '../children/presentation/children_screen.dart';
import '../dashboard/presentation/development_report_screen.dart';
import '../dashboard/presentation/home_screen.dart';
import '../profile/profile_screen.dart';

/// Authenticated app shell: the 5-tab bottom navigation from the original
/// design. Tabs are swapped, state is kept alive per tab.
///
/// All five tabs are backend-connected (see docs/flutter-integration.md §14):
///  0 Home        — mother dashboard (`/families/{family}/dashboard`)
///  1 Children    — list / add / details / edit / delete + selected-child context
///  2 Activities  — catalog (`/activities`) + assign / completion workflow
///  3 Development  — weekly/monthly report for the selected child
///  4 Profile     — session, edit profile, language, logout
///
/// Deep screens reached from child-details cover learning goals, sleep, tasks &
/// points, rewards, screen time, devices, content controls, library, and games.
/// AI coach and nutrition have no backend and show an honest unavailable state.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    HomeScreen(),
    ChildrenScreen(),
    ActivitiesScreen(),
    DevelopmentReportScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
