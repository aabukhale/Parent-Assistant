import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../dashboard/presentation/dashboard_widgets.dart';
import '../../devices/presentation/devices_screen.dart';
import '../application/screen_time_controller.dart';
import '../data/models/screen_time_models.dart';
import 'extra_time_screen.dart';
import 'screen_time_rules_editor_screen.dart';

/// Per-child screen time. Replaces Anwar's local-only slider + fake app list.
/// The usage figures come from `GET …/screen-time/summary` (server-computed);
/// the rules come from `GET …/screen-time-rules`. The app shows and configures
/// **policy** — it does not and cannot enforce screen time on the device.
class ScreenTimeScreen extends ConsumerWidget {
  const ScreenTimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final summary = ref.watch(screenTimeSummaryProvider);
    final rules = ref.watch(screenTimeRulesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.stTitle)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(screenTimeSummaryProvider);
            ref.invalidate(screenTimeRulesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              NoticeBanner(tone: AppTone.info, message: l.stEnforcementNote),
              const SizedBox(height: AppSpacing.md),
              summary.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () async =>
                      ref.invalidate(screenTimeSummaryProvider),
                ),
                data: (s) => _SummaryCard(summary: s),
              ),
              const SizedBox(height: AppSpacing.xl),
              rules.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () async => ref.invalidate(screenTimeRulesProvider),
                ),
                data: (list) => _RulesSummary(rules: list),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppListTile(
                leading: IconBadge(
                  icon: Icons.tune_rounded,
                  tone: AppTone.info,
                ),
                title: l.stEditRules,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScreenTimeRulesEditorScreen(),
                  ),
                ),
              ),
              AppListTile(
                leading: IconBadge(
                  icon: Icons.more_time_rounded,
                  tone: AppTone.info,
                ),
                title: l.stExtraTime,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExtraTimeScreen()),
                ),
              ),
              AppListTile(
                leading: IconBadge(
                  icon: Icons.devices_rounded,
                  tone: AppTone.info,
                ),
                title: l.devicesTitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DevicesScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final ScreenTimeSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroMetricCard(
          label: l.stUsedToday,
          icon: Icons.smartphone_rounded,
          tone: AppTone.info,
          value: formatDurationMinutes(context, s.usedMinutes),
          caption: s.hasLimit
              ? l.stOfLimit(
                  formatDurationMinutes(context, s.effectiveLimitMinutes!),
                )
              : l.stNoLimit,
          footer: s.bonusMinutes > 0
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: StatusPill(
                    label: l.stBonus(
                      formatDurationMinutes(context, s.bonusMinutes),
                    ),
                    tone: AppTone.success,
                    icon: Icons.add_alarm_rounded,
                  ),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        if (!s.hasSufficientData)
          Text(
            l.stNoUsageData,
            style: context.type.bodySmall?.copyWith(color: context.mamily.ink2),
          )
        else if (s.perApp.isNotEmpty) ...[
          SectionHeader(title: l.stPerApp),
          for (final app in s.perApp)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      app.appName ?? app.appIdentifier ?? app.category ?? '—',
                      style: context.type.bodyMedium,
                    ),
                  ),
                  Text(
                    formatDurationMinutes(context, app.usedMinutes),
                    style: context.type.bodySmall?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _RulesSummary extends StatelessWidget {
  const _RulesSummary({required this.rules});
  final List<ScreenTimeRule> rules;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final def = rules.where((r) => r.isDefault).firstOrNull;
    final overrideCount = rules.where((r) => !r.isDefault).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.stDailyRule, style: context.type.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            def == null
                ? l.stNoRule
                : !def.isEnabled
                ? l.stRuleDisabled
                : l.stDailyLimitValue(
                    formatDurationMinutes(context, def.dailyLimitMinutes),
                  ),
            style: context.type.bodyMedium?.copyWith(
              color: context.mamily.ink2,
            ),
          ),
          if (overrideCount > 0)
            Text(
              l.stWeekdayOverrides(overrideCount),
              style: context.type.bodySmall?.copyWith(
                color: context.mamily.ink2,
              ),
            ),
        ],
      ),
    );
  }
}
