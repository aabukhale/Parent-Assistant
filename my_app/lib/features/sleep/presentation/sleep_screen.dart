import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.sleepTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await logsController.refresh();
            ref.invalidate(sleepSummaryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              if (permissions.shouldSurfacePermissionError)
                _PermissionBanner(onRetry: () => refreshPermissions(ref)),
              const _SummarySection(),
              const SizedBox(height: 24),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l.sleepRecordsTitle,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              logs.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  ),
                ),
                error: (e, _) =>
                    ErrorRetryView(error: e, onRetry: logsController.refresh),
                data: (state) => state.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            l.sleepRecordsEmpty,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
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
                              padding: const EdgeInsets.only(top: 4),
                              child: state.loadingMore
                                  ? const CircularProgressIndicator(
                                      color: AppColors.coral,
                                    )
                                  : OutlinedButton(
                                      onPressed: () => _loadMore(context, ref),
                                      child: Text(l.sleepLoadMore),
                                    ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              if (canManage)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SleepFormScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(l.sleepAdd),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
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
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.bedtime_rounded,
                color: Color(0xFFB8B5E8),
                size: 46,
              ),
              const SizedBox(height: 10),
              Text(
                l.sleepAverage,
                style: const TextStyle(color: Color(0xFFD8DDEC)),
              ),
              const SizedBox(height: 6),
              summary.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    e is ApiException ? e.localizedMessage(l) : l.errorUnknown,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFC9C0),
                      fontSize: 13,
                    ),
                  ),
                ),
                data: (s) => s.hasSufficientData
                    ? Text(
                        formatSleepDuration(context, s.averageSleepMinutes),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          l.sleepNoData,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFD8DDEC),
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              _PeriodToggle(current: period),
            ],
          ),
        ),
        const SizedBox(height: 16),
        summary.maybeWhen(
          data: (s) => Row(
            children: [
              Expanded(
                child: _Stat(
                  title: l.sleepNightsLogged,
                  value: '${s.nightsLogged}',
                  icon: Icons.nightlight_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  title: l.sleepTotal,
                  value: s.hasSufficientData
                      ? formatSleepDuration(context, s.totalSleepMinutes)
                      : '—',
                  icon: Icons.summarize_rounded,
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

class _PeriodToggle extends ConsumerWidget {
  const _PeriodToggle({required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final entry in {
          'weekly': l.sleepPeriodWeekly,
          'monthly': l.sleepPeriodMonthly,
        }.entries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: current == entry.key,
              onSelected: (_) =>
                  ref.read(sleepPeriodProvider.notifier).state = entry.key,
              selectedColor: AppColors.teal,
              backgroundColor: const Color(0xFF3E4C7A),
              labelStyle: TextStyle(
                color: current == entry.key ? AppColors.navy : Colors.white,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7C89B8), size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.bedtime_rounded, color: Color(0xFF7C89B8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatSleepDate(context, log.startedAtLocal),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${formatSleepTime(context, log.startedAtLocal)} → '
                        '${formatSleepTime(context, log.endedAtLocal)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (log.crossesMidnightLocal) ...[
                        const SizedBox(width: 6),
                        Text(
                          l.sleepNextDay,
                          style: const TextStyle(
                            color: Color(0xFF7C89B8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              formatSleepDuration(context, log.durationMinutes),
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF9AA3B5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.amber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.permLoadFailed,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
        ],
      ),
    );
  }
}
