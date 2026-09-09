import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../application/games_controller.dart';
import '../data/models/game.dart';
import 'games_screen.dart' show gameTypeLabel;

/// Real game details (`GET /games/{game}`) + the selected child's real progress
/// (`GET …/game-progress`). Gameplay itself is **not available in the app** —
/// there is no game engine — so this screen says so honestly instead of showing
/// a decorative play surface.
class GameDetailsScreen extends ConsumerWidget {
  const GameDetailsScreen({super.key, required this.gameSlug});

  final String gameSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(gameDetailProvider(gameSlug));
    final progress = ref.watch(gameProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          async.valueOrNull?.title ?? l.gamesTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(gameDetailProvider(gameSlug)),
          ),
          data: (game) {
            final gp = progress.valueOrNull
                ?.where((p) => p.gameId == game.id)
                .firstOrNull;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Text(
                  gameTypeLabel(l, game.gameType),
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  game.title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((game.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    game.description!,
                    style: const TextStyle(color: AppColors.navy, height: 1.6),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF1F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.gamesNotPlayable,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l.gamesProgressTitle,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                progress.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.coral),
                    ),
                  ),
                  error: (e, _) => ErrorRetryView(
                    error: e,
                    onRetry: () async => ref.invalidate(gameProgressProvider),
                  ),
                  data: (_) => gp == null
                      ? Text(
                          l.gamesNoProgress,
                          style: const TextStyle(color: AppColors.textMuted),
                        )
                      : _ProgressCard(progress: gp),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tag = Localizations.localeOf(context).toLanguageTag();
    final minutes = (progress.totalPlaySeconds / 60).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(l.gamesBestScore, progress.bestScore?.toString() ?? '—'),
          _row(l.gamesAttempts, '${progress.totalAttempts}'),
          _row(l.gamesPlayTime, l.gamesMinutes(minutes)),
          if (progress.lastPlayedAt != null)
            _row(
              l.gamesLastPlayed,
              DateFormat.yMMMd(tag).format(progress.lastPlayedAt!),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
