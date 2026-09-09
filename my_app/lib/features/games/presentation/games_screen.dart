import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.gamesTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF1F8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          l.gamesPreviewNote,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final game in state.games) _GameCard(game: game),
                      if (state.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: state.loadingMore
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.coral,
                                  ),
                                )
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF7C89B8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                color: Color(0xFF7C89B8),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    gameTypeLabel(l, game.gameType),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF9AA3B5),
            ),
          ],
        ),
      ),
    );
  }
}
