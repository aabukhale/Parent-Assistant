import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../application/games_controller.dart';
import '../data/models/game.dart';
import 'game_details_screen.dart';

/// Parent-preview game catalog (`GET /games`). Replaces Anwar's hardcoded games
/// grid + decorative "play" screen. Games are **not playable inside this app** —
/// there is no game engine — so the details screen shows an honest state and
/// real per-child progress only.
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(gamesCatalogControllerProvider);
    final controller = ref.read(gamesCatalogControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.gamesTitle)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: async.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) => ListView(
              children: [
                const SizedBox(height: 120),
                ErrorRetryView(error: e, onRetry: controller.refresh),
              ],
            ),
            data: (state) => state.isEmpty
                ? EmptyView(
                    icon: Icons.sports_esports_rounded,
                    message: l.gamesEmpty,
                    onRefresh: controller.refresh,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xxxl,
                    ),
                    children: [
                      NoticeBanner(
                        tone: AppTone.info,
                        message: l.gamesPreviewNote,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final game in state.games) _GameCard(game: game),
                      if (state.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: state.loadingMore
                              ? const Center(child: CircularProgressIndicator())
                              : OutlinedButton(
                                  onPressed: () => _loadMore(context, ref),
                                  child: Text(l.libraryLoadMore),
                                ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(gamesCatalogControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }
}

String gameTypeLabel(AppLocalizations l, GameType t) => switch (t) {
  GameType.memory => l.gameTypeMemory,
  GameType.puzzle => l.gameTypePuzzle,
  GameType.quiz => l.gameTypeQuiz,
  GameType.matching => l.gameTypeMatching,
  GameType.drawing => l.gameTypeDrawing,
  GameType.other => l.gameTypeOther,
};

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameDetailsScreen(gameSlug: game.slug),
        ),
      ),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            IconBadge(
              icon: Icons.sports_esports_rounded,
              tone: AppTone.info,
              size: 52,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    gameTypeLabel(l, game.gameType),
                    style: context.type.bodySmall?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.mamily.ink3,
            ),
          ],
        ),
      ),
    );
  }
}
