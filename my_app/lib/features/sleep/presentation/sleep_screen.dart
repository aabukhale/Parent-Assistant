import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/sleep_logs_controller.dart';
import '../application/sleep_summary_controller.dart';
import '../data/models/sleep_log.dart';
import 'sleep_form_screen.dart';
import 'sleep_widgets.dart';

/// Sleep tracking for the selected child. Reached from the child details screen.
/// Visual design preserved from Anwar's original `SleepScreen`; all data is now
/// real (`…/sleep-logs` + `…/sleep-logs/summary`).
class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final logs = ref.watch(sleepLogsControllerProvider);
    final logsController = ref.read(sleepLogsControllerProvider.notifier);
    final permissions = ref.watch(permissionsProvider);
    final canManage = permissions.hasPermission(FamilyPermission.manageSleep);

    return Scaffold(
      appBar: AppBar(title: Text(l.sleepTitle)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: () async {
            await logsController.refresh();
            ref.invalidate(sleepSummaryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              if (permissions.shouldSurfacePermissionError)
                PermissionNotice(onRetry: () => refreshPermissions(ref)),
              const _SummarySection(),
              const SizedBox(height: AppSpacing.xxl),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l.sleepRecordsTitle,
                  style: context.type.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              logs.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    ErrorRetryView(error: e, onRetry: logsController.refresh),
                data: (state) => state.isEmpty
                    ? EmptyView(emoji: '🌙', message: l.sleepRecordsEmpty)
                    : Column(
                        children: [
                          for (final log in state.logs)
                            _SleepRecord(
                              log: log,
                              onTap: canManage
                                  ? () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SleepFormScreen(logId: log.id),
                                      ),
                                    )
                                  : null,
                            ),
                          if (state.hasMore)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: state.loadingMore
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton(
                                      onPressed: () => _loadMore(context, ref),
                                      child: Text(l.sleepLoadMore),
                                    ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (canManage)
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SleepFormScreen()),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.sleepAdd),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(sleepLogsControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }
}

class _SummarySection extends ConsumerWidget {
  const _SummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final period = ref.watch(sleepPeriodProvider);
    final summary = ref.watch(sleepSummaryProvider(period));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroMetricCard(
          label: l.sleepAverage,
          emoji: '🌙',
          tone: AppTone.sleep,
          valueWidget: summary.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            error: (e, _) => Text(
              e is ApiException ? e.localizedMessage(l) : l.errorUnknown,
              style: context.type.bodyMedium?.copyWith(
                color: context.mamily.danger.foreground,
              ),
            ),
            data: (s) => s.hasSufficientData
                ? Text(
                    formatSleepDuration(context, s.averageSleepMinutes),
                    style: context.type.headlineMedium,
                  )
                : Text(l.sleepNoData, style: context.type.bodyLarge),
          ),
          footer: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: ChoiceChipBar<String>(
              options: {
                'weekly': l.sleepPeriodWeekly,
                'monthly': l.sleepPeriodMonthly,
              },
              selected: period,
              onSelected: (p) =>
                  ref.read(sleepPeriodProvider.notifier).state = p,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        summary.maybeWhen(
          data: (s) => Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l.sleepNightsLogged,
                  value: '${s.nightsLogged}',
                  icon: Icons.nightlight_rounded,
                  tone: AppTone.sleep,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: l.sleepTotal,
                  value: s.hasSufficientData
                      ? formatSleepDuration(context, s.totalSleepMinutes)
                      : '—',
                  icon: Icons.summarize_rounded,
                  tone: AppTone.sleep,
                ),
              ),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SleepRecord extends StatelessWidget {
  const _SleepRecord({required this.log, this.onTap});
  final SleepLog log;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final times =
        '${formatSleepTime(context, log.startedAtLocal)} → '
        '${formatSleepTime(context, log.endedAtLocal)}';
    return AppListTile(
      leading: const IconBadge(emoji: '🌙', tone: AppTone.sleep, size: 40),
      title: formatSleepDate(context, log.startedAtLocal),
      subtitle: log.crossesMidnightLocal ? '$times · ${l.sleepNextDay}' : times,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatSleepDuration(context, log.durationMinutes),
            style: context.type.labelLarge?.copyWith(
              color: context.mamily.sleep.foreground,
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: context.mamily.ink3),
        ],
      ),
    );
  }
}
