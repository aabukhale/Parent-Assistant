import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/hub_providers.dart';
import '../data/hub_models.dart';

/// Weekly Family Recap — built only from what was recorded this week.
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key});

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  String? _weekStart;

  void _shift(WeeklyRecap r, int days) {
    final start = DateTime.parse(r.weekStart).add(Duration(days: days));
    setState(
      () => _weekStart =
          '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final async = ref.watch(recapProvider(_weekStart));
    return Scaffold(
      appBar: AppBar(title: Text(l.recapTitle)),
      body: AppContentFrame(
        maxWidth: 760,
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(recapProvider(_weekStart)),
          ),
          data: (r) {
            final range =
                '${DateFormat.MMMd(locale).format(DateTime.parse(r.weekStart))} – ${DateFormat.MMMd(locale).format(DateTime.parse(r.weekEnd))}';
            final isCurrent = DateTime.parse(
              r.weekEnd,
            ).isAfter(DateTime.now().subtract(const Duration(days: 1)));
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l.recapPrevious,
                      onPressed: () => _shift(r, -7),
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        range,
                        textAlign: TextAlign.center,
                        style: context.type.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l.recapNext,
                      onPressed: isCurrent ? null : () => _shift(r, 7),
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: r.hasData ? c.warning.background : c.surfaceMuted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.recapHighlights, style: context.type.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      for (final h in r.highlights)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.hasData ? '✨ ' : '🌙 '),
                              Expanded(
                                child: Text(h, style: context.type.bodyLarge),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (r.hasData) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final (key, label, icon, tone) in [
                        (
                          'tasks_completed',
                          l.recapTasks,
                          Icons.task_alt_rounded,
                          AppTone.success,
                        ),
                        (
                          'routines_completed',
                          l.recapRoutines,
                          Icons.wb_sunny_rounded,
                          AppTone.accent,
                        ),
                        (
                          'points_earned',
                          l.recapPointsEarned,
                          Icons.star_rounded,
                          AppTone.warning,
                        ),
                        (
                          'points_spent',
                          l.recapPointsSpent,
                          Icons.card_giftcard_rounded,
                          AppTone.brand,
                        ),
                        (
                          'rewards_redeemed',
                          l.recapRewards,
                          Icons.redeem_rounded,
                          AppTone.brand,
                        ),
                        (
                          'checkins',
                          l.recapCheckins,
                          Icons.favorite_rounded,
                          AppTone.sleep,
                        ),
                        (
                          'goal_updates',
                          l.recapGoals,
                          Icons.flag_rounded,
                          AppTone.info,
                        ),
                      ])
                        SizedBox(
                          width: 160,
                          child: StatTile(
                            label: label,
                            value: '${r.familyTotals[key] ?? 0}',
                            icon: icon,
                            tone: tone,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.recapHonest,
                  style: context.type.bodySmall?.copyWith(color: c.ink3),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
