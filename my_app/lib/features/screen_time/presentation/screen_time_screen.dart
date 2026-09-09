import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.stTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(screenTimeSummaryProvider);
            ref.invalidate(screenTimeRulesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF1F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  l.stEnforcementNote,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              summary.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  ),
                ),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () async =>
                      ref.invalidate(screenTimeSummaryProvider),
                ),
                data: (s) => _SummaryCard(summary: s),
              ),
              const SizedBox(height: 20),
              rules.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () async => ref.invalidate(screenTimeRulesProvider),
                ),
                data: (list) => _RulesSummary(rules: list),
              ),
              const SizedBox(height: 16),
              _NavTile(
                icon: Icons.tune_rounded,
                title: l.stEditRules,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScreenTimeRulesEditorScreen(),
                  ),
                ),
              ),
              _NavTile(
                icon: Icons.more_time_rounded,
                title: l.stExtraTime,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExtraTimeScreen()),
                ),
              ),
              _NavTile(
                icon: Icons.devices_rounded,
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
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                l.stUsedToday,
                style: const TextStyle(color: Color(0xFFD8DDEC), fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                formatDurationMinutes(context, s.usedMinutes),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.hasLimit
                    ? l.stOfLimit(
                        formatDurationMinutes(
                          context,
                          s.effectiveLimitMinutes!,
                        ),
                      )
                    : l.stNoLimit,
                style: const TextStyle(color: Color(0xFFD8DDEC), fontSize: 12),
              ),
              if (s.bonusMinutes > 0)
                Text(
                  l.stBonus(formatDurationMinutes(context, s.bonusMinutes)),
                  style: const TextStyle(
                    color: Color(0xFF9BE7C4),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!s.hasSufficientData)
          Text(
            l.stNoUsageData,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          )
        else if (s.perApp.isNotEmpty) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l.stPerApp,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final app in s.perApp)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      app.appName ?? app.appIdentifier ?? app.category ?? '—',
                      style: const TextStyle(color: AppColors.navy),
                    ),
                  ),
                  Text(
                    formatDurationMinutes(context, app.usedMinutes),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.stDailyRule,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            def == null
                ? l.stNoRule
                : !def.isEnabled
                ? l.stRuleDisabled
                : l.stDailyLimitValue(
                    formatDurationMinutes(context, def.dailyLimitMinutes),
                  ),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          if (overrideCount > 0)
            Text(
              l.stWeekdayOverrides(overrideCount),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      leading: Icon(icon, color: AppColors.coral),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFF9AA3B5),
      ),
      onTap: onTap,
    ),
  );
}
