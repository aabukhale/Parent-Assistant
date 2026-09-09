import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../application/screen_time_controller.dart';
import '../data/models/screen_time_models.dart';
import '../data/screen_time_repository.dart';

/// Edit the default screen-time rule + optional per-weekday overrides
/// (`PUT …/screen-time-rules`). The backend replaces the whole set with what is
/// sent. Weekday semantics (ISO 1–7, default = every day) match the backend
/// contract and are not redesigned here.
class ScreenTimeRulesEditorScreen extends ConsumerStatefulWidget {
  const ScreenTimeRulesEditorScreen({super.key});

  @override
  ConsumerState<ScreenTimeRulesEditorScreen> createState() =>
      _ScreenTimeRulesEditorScreenState();
}

class _ScreenTimeRulesEditorScreenState
    extends ConsumerState<ScreenTimeRulesEditorScreen> {
  bool _initialised = false;
  bool _saving = false;

  bool _defaultEnabled = true;
  int _defaultLimit = 120;
  final Map<int, int> _overrides = {}; // isoDay -> limit minutes

  void _seed(List<ScreenTimeRule> rules) {
    if (_initialised) return;
    final def = rules.where((r) => r.isDefault).firstOrNull;
    if (def != null) {
      _defaultEnabled = def.isEnabled;
      _defaultLimit = def.dailyLimitMinutes;
    }
    for (final r in rules.where((r) => !r.isDefault)) {
      if (r.dayOfWeek != null) _overrides[r.dayOfWeek!] = r.dailyLimitMinutes;
    }
    _initialised = true;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canManage = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageScreenTime);
    final rules = ref.watch(screenTimeRulesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.stEditRules,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: rules.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(screenTimeRulesProvider),
          ),
          data: (list) {
            _seed(list);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                if (!canManage)
                  Text(
                    l.stEditNoPermission,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                SwitchListTile(
                  value: _defaultEnabled,
                  onChanged: canManage
                      ? (v) => setState(() => _defaultEnabled = v)
                      : null,
                  title: Text(l.stRuleEnabled),
                  subtitle: Text(l.stRuleEnabledSub),
                ),
                _LimitRow(
                  label: l.stDailyLimit,
                  minutes: _defaultLimit,
                  enabled: canManage && _defaultEnabled,
                  onChanged: (v) => setState(() => _defaultLimit = v),
                ),
                const SizedBox(height: 18),
                Text(
                  l.stWeekdayOverridesTitle,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.stWeekdayOverridesHint,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                for (var day = 1; day <= 7; day++)
                  _WeekdayRow(
                    day: day,
                    limit: _overrides[day],
                    enabled: canManage,
                    onToggle: (on) => setState(() {
                      if (on) {
                        _overrides[day] = _defaultLimit;
                      } else {
                        _overrides.remove(day);
                      }
                    }),
                    onChanged: (v) => setState(() => _overrides[day] = v),
                  ),
                const SizedBox(height: 20),
                if (canManage)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l.commonSave),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await saveScreenTimeRules(
        ref,
        ScreenTimeRulesInput(
          defaultRule: ScreenTimeRuleInput(
            dailyLimitMinutes: _defaultLimit,
            isEnabled: _defaultEnabled,
          ),
          overrides: {
            for (final entry in _overrides.entries)
              entry.key: ScreenTimeRuleInput(
                dailyLimitMinutes: entry.value,
                isEnabled: true,
              ),
          },
        ),
      );
      messenger.showSnackBar(SnackBar(content: Text(l.stRulesSaved)));
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      final msg = e.kind == ApiErrorKind.validation
          ? l.stRulesInvalid
          : e.localizedMessage(l);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.label,
    required this.minutes,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int minutes;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label — ${l.stMinutesValue(minutes)}',
            style: const TextStyle(color: AppColors.navy),
          ),
          Slider(
            value: minutes.toDouble().clamp(0, 1440),
            min: 0,
            max: 480,
            divisions: 32,
            label: '$minutes',
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({
    required this.day,
    required this.limit,
    required this.enabled,
    required this.onToggle,
    required this.onChanged,
  });

  final int day;
  final int? limit;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = [
      l.stDayMon,
      l.stDayTue,
      l.stDayWed,
      l.stDayThu,
      l.stDayFri,
      l.stDaySat,
      l.stDaySun,
    ];
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: limit != null,
          onChanged: enabled ? onToggle : null,
          title: Text(names[day - 1]),
          subtitle: limit == null ? Text(l.stUsesDefault) : null,
        ),
        if (limit != null)
          _LimitRow(
            label: l.stDailyLimit,
            minutes: limit!,
            enabled: enabled,
            onChanged: onChanged,
          ),
      ],
    );
  }
}
