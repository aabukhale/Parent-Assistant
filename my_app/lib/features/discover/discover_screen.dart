import 'package:flutter/material.dart';

import '../../core/design_system.dart';
import '../../core/localization/l10n.dart';
import '../activities/presentation/activities_screen.dart';
import '../ai_parenting/ai_parenting_screen.dart';
import '../dashboard/presentation/home_screen.dart';
import '../family_hub/presentation/challenges_screen.dart';
import '../family_hub/presentation/hub_widgets.dart';
import '../family_hub/presentation/planner_screen.dart';
import '../family_hub/presentation/recap_screen.dart';
import '../games/presentation/games_screen.dart';
import '../library/presentation/library_screen.dart';

/// Ideas, plans and things to do together.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    void open(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    final tiles = [
      NavTile(
        icon: Icons.groups_rounded,
        tone: AppTone.accent,
        title: l.discoverChallenges,
        subtitle: l.discoverChallengesBody,
        onTap: () => open(const ChallengesScreen()),
      ),
      NavTile(
        icon: Icons.event_rounded,
        tone: AppTone.info,
        title: l.discoverPlanner,
        subtitle: l.discoverPlannerBody,
        onTap: () => open(const PlannerScreen()),
      ),
      NavTile(
        icon: Icons.auto_graph_rounded,
        tone: AppTone.warning,
        title: l.discoverRecap,
        subtitle: l.discoverRecapBody,
        onTap: () => open(const RecapScreen()),
      ),
      NavTile(
        icon: Icons.dashboard_rounded,
        tone: AppTone.neutral,
        title: l.discoverDashboard,
        subtitle: l.discoverDashboardBody,
        onTap: () => open(const HomeScreen()),
      ),
      NavTile(
        icon: Icons.extension_rounded,
        tone: AppTone.success,
        title: l.discoverActivities,
        subtitle: l.discoverActivitiesBody,
        onTap: () => open(const ActivitiesScreen()),
      ),
      NavTile(
        icon: Icons.menu_book_rounded,
        tone: AppTone.sleep,
        title: l.discoverLibrary,
        subtitle: l.discoverLibraryBody,
        onTap: () => open(const LibraryScreen()),
      ),
      NavTile(
        icon: Icons.sports_esports_rounded,
        tone: AppTone.brand,
        title: l.discoverGames,
        subtitle: l.discoverGamesBody,
        onTap: () => open(const GamesScreen()),
      ),
      NavTile(
        icon: Icons.support_agent_rounded,
        tone: AppTone.neutral,
        title: l.discoverCoach,
        subtitle: l.discoverCoachBody,
        onTap: () => open(const AiParentingScreen()),
      ),
    ];
    return SafeArea(
      child: AppContentFrame(
        maxWidth: 860,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            PageTitle(title: l.discoverTitle, subtitle: l.discoverSubtitle),
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 640 ? 2 : 1;
                final w = columns == 1
                    ? box.maxWidth
                    : (box.maxWidth - AppSpacing.md) / 2;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final t in tiles) SizedBox(width: w, child: t),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
