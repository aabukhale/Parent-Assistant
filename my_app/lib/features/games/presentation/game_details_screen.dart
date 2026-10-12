import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
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
      appBar: AppBar(
        title: Text(
          async.valueOrNull?.title ?? l.gamesTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type.titleSmall,
        ),
      ),
      body: AppContentFrame(
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              children: [
                Text(
                  gameTypeLabel(l, game.gameType),
                  style: context.type.labelMedium?.copyWith(
                    color: context.mamily.actionText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(game.title, style: context.type.titleLarge),
                if ((game.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(game.description!, style: context.type.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.xl),
                NoticeBanner(tone: AppTone.info, message: l.gamesNotPlayable),
                const SizedBox(height: AppSpacing.xl),
                Text(l.gamesProgressTitle, style: context.type.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                progress.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => ErrorRetryView(
                    error: e,
                    onRetry: () async => ref.invalidate(gameProgressProvider),
                  ),
                  data: (_) => gp == null
                      ? Text(
                          l.gamesNoProgress,
                          style: context.type.bodyMedium?.copyWith(
                            color: context.mamily.ink2,
                          ),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            context,
            l.gamesBestScore,
            progress.bestScore?.toString() ?? '—',
          ),
          _row(context, l.gamesAttempts, '${progress.totalAttempts}'),
          _row(context, l.gamesPlayTime, l.gamesMinutes(minutes)),
          if (progress.lastPlayedAt != null)
            _row(
              context,
              l.gamesLastPlayed,
              DateFormat.yMMMd(tag).format(progress.lastPlayedAt!),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.type.bodyMedium?.copyWith(
              color: context.mamily.ink2,
            ),
          ),
        ),
        Text(value, style: context.type.titleSmall),
      ],
    ),
  );
}
