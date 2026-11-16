import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../core/errors/api_exception.dart';
import '../../core/localization/l10n.dart';
import '../family/application/permissions_controller.dart';
import '../family_hub/application/hub_providers.dart';
import '../family_hub/data/hub_models.dart';
import '../family_hub/data/hub_repository.dart';
import '../notifications/push/push_service.dart';

/// Permission (explained before asking), categories, quiet hours and
/// lock-screen privacy. The in-app inbox always receives everything.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _saving = false;

  static const _categories = [
    'approvals',
    'tasks',
    'rewards',
    'routines',
    'challenges',
    'checkins',
    'encouragement',
    'screen_time',
    'planner',
    'devices',
  ];

  String _catLabel(AppLocalizations l, String c) => switch (c) {
    'tasks' => l.notifCatTasks,
    'approvals' => l.notifCatApprovals,
    'rewards' => l.notifCatRewards,
    'routines' => l.notifCatRoutines,
    'challenges' => l.notifCatChallenges,
    'encouragement' => l.notifCatEncouragement,
    'checkins' => l.notifCatCheckins,
    'screen_time' => l.notifCatScreenTime,
    'planner' => l.notifCatPlanner,
    _ => l.notifCatDevices,
  };

  Future<void> _save(Map<String, dynamic> body) async {
    final l = context.l10n;
    setState(() => _saving = true);
    try {
      await ref.read(hubRepositoryProvider).saveNotificationPrefs(body);
      ref.invalidate(notificationPrefsProvider);
      if (mounted) showResultSnack(context, l.notifSaved);
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(l));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _pickTime(String? current) async {
    final initial = current == null
        ? const TimeOfDay(hour: 21, minute: 0)
        : TimeOfDay(
            hour: int.parse(current.substring(0, 2)),
            minute: int.parse(current.substring(3, 5)),
          );
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final push = ref.watch(pushServiceProvider);
    final prefs = ref.watch(notificationPrefsProvider);
    final canSetChildQuiet = ref.watch(permissionsProvider).canManageChildren;

    return Scaffold(
      appBar: AppBar(title: Text(l.notifPrefsTitle)),
      body: AppContentFrame(
        maxWidth: 680,
        child: prefs.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(notificationPrefsProvider),
          ),
          data: (p) => AbsorbPointer(
            absorbing: _saving,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ValueListenableBuilder<PushAvailability>(
                  valueListenable: push.availability,
                  builder: (context, availability, _) => switch (availability) {
                    PushAvailability.granted => NoticeBanner(
                      tone: AppTone.success,
                      message: l.notifEnabled,
                    ),
                    PushAvailability.denied => NoticeBanner(
                      tone: AppTone.warning,
                      message: l.notifDenied,
                    ),
                    PushAvailability.notConfigured => NoticeBanner(
                      tone: AppTone.info,
                      message: l.notifNotConfigured,
                    ),
                    PushAvailability.notDetermined => AppCard(
                      color: c.brand.background,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.notifPermissionTitle,
                            style: context.type.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l.notifPermissionBody,
                            style: context.type.bodyMedium?.copyWith(
                              color: c.ink2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: push.requestPermission,
                            child: Text(l.notifAllow),
                          ),
                        ],
                      ),
                    ),
                  },
                ),
                SectionHeader(
                  title: l.notifCategories,
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.sm,
                  ),
                ),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final cat in _categories)
                        SwitchListTile(
                          title: Text(_catLabel(l, cat)),
                          value: p.pushEnabled(cat),
                          onChanged: (v) => _save({
                            'categories': [
                              {'category': cat, 'push_enabled': v},
                            ],
                          }),
                        ),
                    ],
                  ),
                ),
                SectionHeader(
                  title: l.notifQuietHours,
                  subtitle: l.notifQuietHoursBody,
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.sm,
                  ),
                ),
                _QuietRow(
                  start: p.quietStart,
                  end: p.quietEnd,
                  onPick: (start) async {
                    final value = await _pickTime(
                      start ? p.quietStart : p.quietEnd,
                    );
                    if (value != null) {
                      await _save({
                        start ? 'quiet_hours_start' : 'quiet_hours_end': value,
                        if (start && p.quietEnd == null)
                          'quiet_hours_end': '07:00',
                        if (!start && p.quietStart == null)
                          'quiet_hours_start': '21:00',
                      });
                    }
                  },
                  onClear: () => _save({
                    'quiet_hours_start': null,
                    'quiet_hours_end': null,
                  }),
                ),
                if (canSetChildQuiet) ...[
                  SectionHeader(
                    title: l.notifChildQuiet,
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xl,
                      bottom: AppSpacing.sm,
                    ),
                  ),
                  _QuietRow(
                    start: p.childQuietStart,
                    end: p.childQuietEnd,
                    onPick: (start) async {
                      final value = await _pickTime(
                        start ? p.childQuietStart : p.childQuietEnd,
                      );
                      if (value != null) {
                        await _save({
                          start
                                  ? 'child_quiet_hours_start'
                                  : 'child_quiet_hours_end':
                              value,
                          if (start && p.childQuietEnd == null)
                            'child_quiet_hours_end': '07:00',
                          if (!start && p.childQuietStart == null)
                            'child_quiet_hours_start': '20:00',
                        });
                      }
                    },
                    onClear: () => _save({
                      'child_quiet_hours_start': null,
                      'child_quiet_hours_end': null,
                    }),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    title: Text(l.notifLockDetails),
                    subtitle: Text(l.notifLockDetailsBody),
                    value: p.showDetailsOnLockScreen,
                    onChanged: (v) => _save({'show_details_on_lock_screen': v}),
                  ),
                ),
                if (p.timezone != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    p.timezone!,
                    style: context.type.bodySmall?.copyWith(color: c.ink3),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietRow extends StatelessWidget {
  const _QuietRow({
    required this.start,
    required this.end,
    required this.onPick,
    required this.onClear,
  });

  final String? start;
  final String? end;
  final void Function(bool start) onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => onPick(true),
            child: Text('${l.notifQuietFrom} ${start ?? '—'}'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: OutlinedButton(
            onPressed: () => onPick(false),
            child: Text('${l.notifQuietTo} ${end ?? '—'}'),
          ),
        ),
        if (start != null)
          IconButton(
            tooltip: l.notifQuietOff,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }
}

/// Re-exported so the account screen can show a summary.
typedef Prefs = NotificationPrefs;
