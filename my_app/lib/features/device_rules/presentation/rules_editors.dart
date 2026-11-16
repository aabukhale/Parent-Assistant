import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/device_rules_sync.dart';
import '../data/device_rules_models.dart';
import '../data/device_rules_repository.dart';
import 'rules_labels.dart';

class RulesSection extends StatelessWidget {
  const RulesSection(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => SectionHeader(
    title: title,
    padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
  );
}

/// The four friendly plans.
class PresetRow extends StatelessWidget {
  const PresetRow({
    super.key,
    required this.onApply,
    required this.busy,
    required this.weekendDays,
  });

  final void Function(String preset) onApply;
  final bool busy;
  final List<int> weekendDays;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      ('school', l.presetSchoolBody, AppTone.info),
      ('homework', l.presetHomeworkBody, AppTone.accent),
      ('bedtime', l.presetBedtimeBody, AppTone.sleep),
      ('weekend', l.presetWeekendBody, AppTone.success),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 560 ? 4 : 2;
        final w = (box.maxWidth - AppSpacing.sm * (cols - 1)) / cols;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (key, body, tone) in items)
              SizedBox(
                width: w,
                child: AppCard(
                  tone: tone,
                  onTap: busy ? null : () => onApply(key),
                  semanticLabel: '${presetLabel(l, key)}. $body',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        presetIcon(key),
                        color: context.mamily.tone(tone).foreground,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(presetLabel(l, key), style: context.type.titleSmall),
                      Text(body, style: context.type.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

typedef PresetResult = ({
  List<int>? days,
  String? start,
  String? end,
  int? minutes,
});

String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parse(String s) {
  final p = s.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

/// Days + times (or minutes for Weekend), with a live one-line explanation of
/// the effect before anything is saved.
Future<PresetResult?> showPresetSheet(
  BuildContext context, {
  required String preset,
  required List<int> weekendDays,
  RuleSchedule? existing,
}) {
  final schoolDays = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
  ].where((d) => !weekendDays.contains(d)).toList();
  final defaults = switch (preset) {
    'school' => (days: schoolDays, start: '08:00', end: '14:00'),
    'homework' => (days: schoolDays, start: '16:00', end: '18:00'),
    'bedtime' => (days: [1, 2, 3, 4, 5, 6, 7], start: '21:00', end: '07:00'),
    _ => (days: schoolDays, start: '17:00', end: '19:00'),
  };
  var days = List<int>.of(
    existing?.days ?? (preset == 'weekend' ? weekendDays : defaults.days),
  );
  var start = _parse(existing?.start ?? defaults.start);
  var end = _parse(existing?.end ?? defaults.end);
  var minutes = 180;

  return showModalBottomSheet<PresetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, set) {
        final l = context.l10n;
        final explain = preset == 'weekend'
            ? l.rulesExplainWeekend(daysText(l, days), minutes)
            : l.rulesExplainSchedule(daysText(l, days), _fmt(start), _fmt(end));
        Future<void> pick(bool isStart) async {
          final t = await showTimePicker(
            context: context,
            initialTime: isStart ? start : end,
          );
          if (t != null) set(() => isStart ? start = t : end = t);
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(presetIcon(preset)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      presetLabel(l, preset),
                      style: context.type.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FormSectionLabel(l.rulesDays),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final d in const [7, 1, 2, 3, 4, 5, 6])
                      FilterChip(
                        label: Text(weekdayShort(l, d)),
                        selected: days.contains(d),
                        onSelected: (v) => set(() {
                          v ? days.add(d) : days.remove(d);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (preset == 'weekend') ...[
                  FormSectionLabel(l.rulesMinutesPerDay),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final m in const [60, 90, 120, 180, 240, 300])
                        ChoiceChip(
                          label: Text(l.kidMinutes(m)),
                          selected: minutes == m,
                          onSelected: (_) => set(() => minutes = m),
                        ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: PickerField(
                          icon: Icons.schedule_rounded,
                          label: l.rulesFrom,
                          value: start.format(context),
                          onTap: () => pick(true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PickerField(
                          icon: Icons.schedule_rounded,
                          label: l.rulesTo,
                          value: end.format(context),
                          onTap: () => pick(false),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.lg),
                NoticeBanner(
                  tone: AppTone.info,
                  icon: Icons.lightbulb_rounded,
                  message: explain,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed:
                      days.isEmpty ||
                          (preset != 'weekend' && _fmt(start) == _fmt(end))
                      ? null
                      : () => Navigator.of(sheet).pop((
                          days: (days..sort()),
                          start: preset == 'weekend' ? null : _fmt(start),
                          end: preset == 'weekend' ? null : _fmt(end),
                          minutes: preset == 'weekend' ? minutes : null,
                        )),
                  child: Text(l.commonSave),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    super.key,
    required this.schedule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final RuleSchedule schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = schedule;
    final explain = s.restriction == 'allow_only'
        ? l.rulesExplainSchedule(daysText(l, s.days), s.start, s.end)
        : l.rulesExplainScheduleBlock(daysText(l, s.days), s.start, s.end);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onEdit,
        child: Row(
          children: [
            IconBadge(icon: presetIcon(s.preset), tone: AppTone.sleep),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presetLabel(l, s.preset),
                    style: context.type.titleSmall,
                  ),
                  Text(explain, style: context.type.bodySmall),
                ],
              ),
            ),
            Switch(value: s.enabled, onChanged: onToggle),
            IconButton(
              tooltip: l.commonDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class AppListEntry extends StatelessWidget {
  const AppListEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.apps,
    required this.onEdit,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<AppRef> apps;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = apps.map((a) => a.name).take(4).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppListTile(
        leading: IconBadge(icon: icon),
        title: '$title · ${l.rulesAppCount(apps.length)}',
        subtitle: [?subtitle, if (names.isNotEmpty) names].join('\n'),
        onTap: onEdit,
      ),
    );
  }
}

/// Choose apps for the child. Android: from the list the child's phone
/// reported. iOS: Apple's picker, which only works on the child's own
/// iPhone (parent signed in there) and returns opaque tokens.
Future<List<AppRef>?> pickChildApps(
  BuildContext context,
  WidgetRef ref, {
  required String childId,
  required String childName,
  required List<AppRef> selected,
  required List<AppRef> exclude,
  required List<String> childPlatforms,
}) async {
  final l = context.l10n;
  // Decided by the *child's* phones, not the phone the parent is holding:
  // Android apps come from the list the child's phone reported; iPhone apps
  // can only be chosen with Apple's picker on the child's own iPhone.
  if (!childPlatforms.contains('android')) {
    if (childPlatforms.contains('ios') &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      final picked = await ref.read(nativeEnforcementProvider).pickApps();
      if (picked != null) {
        return [
          ...selected.where((a) => a.platform != 'ios'),
          for (final p in picked)
            AppRef(
              platform: 'ios',
              id: p['id'] ?? '',
              name: p['name'] ?? 'iPhone app',
            ),
        ];
      }
    }
    if (context.mounted) {
      showResultSnack(context, l.rulesIosPickOnPhone(childName));
    }
    return null;
  }

  final inventory = await ref.read(deviceRulesRepositoryProvider).apps(childId);
  if (!context.mounted) return null;
  final iosSelected = selected.where((a) => a.platform == 'ios').toList();
  if (inventory.apps.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(l.rulesNoAppList(childName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: Text(MaterialLocalizations.of(d).okButtonLabel),
          ),
        ],
      ),
    );
    return null;
  }
  final chosen = {for (final a in selected) a.key};
  final excluded = {for (final a in exclude) a.key};
  var query = '';
  final result = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, set) {
        final shown = inventory.apps
            .where((a) => !excluded.contains(a.key))
            .where(
              (a) =>
                  query.isEmpty ||
                  a.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      labelText: l.rulesChooseApps,
                    ),
                    onChanged: (v) => set(() => query = v),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final a in shown)
                        CheckboxListTile(
                          value: chosen.contains(a.key),
                          title: Text(a.name),
                          onChanged: (v) => set(
                            () => v == true
                                ? chosen.add(a.key)
                                : chosen.remove(a.key),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheet).pop(chosen),
                      child: Text(l.commonDone),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (result == null) return null;
  final byKey = {
    for (final a in [...inventory.apps, ...selected]) a.key: a,
  };
  return [
    ...iosSelected,
    for (final k in result)
      if (byKey[k] != null && byKey[k]!.platform == 'android') byKey[k]!,
  ];
}

class LimitsEditor extends StatelessWidget {
  const LimitsEditor({
    super.key,
    required this.limits,
    required this.onChanged,
  });

  final List<AppLimit> limits;
  final ValueChanged<List<AppLimit>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cats = limits.where((x) => x.category != null).toList();
    final used = {for (final c in cats) c.category};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (limits.isEmpty)
          Text(l.rulesLimitsEmpty, style: context.type.bodyMedium),
        for (final x in limits)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppListTile(
              leading: const IconBadge(icon: Icons.hourglass_bottom_rounded),
              title: l.rulesLimitLine(
                x.category != null
                    ? categoryLabel(l, x.category)
                    : (x.app?.name ?? ''),
                x.minutes,
              ),
              trailing: IconButton(
                tooltip: l.commonDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () =>
                    onChanged(limits.where((y) => !identical(y, x)).toList()),
              ),
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: Text(l.rulesAddLimit),
          onPressed: () async {
            String? cat = ruleCategories.firstWhere(
              (c) => !used.contains(c),
              orElse: () => 'other',
            );
            var minutes = 60;
            final ok = await confirmAction(
              context,
              title: l.rulesAddLimit,
              confirmLabel: l.commonSave,
              extra: StatefulBuilder(
                builder: (context, set) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final c in ruleCategories)
                          ChoiceChip(
                            label: Text(categoryLabel(l, c)),
                            selected: cat == c,
                            onSelected: (_) => set(() => cat = c),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final m in const [15, 30, 45, 60, 90, 120])
                          ChoiceChip(
                            label: Text(l.kidMinutes(m)),
                            selected: minutes == m,
                            onSelected: (_) => set(() => minutes = m),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            if (ok && cat != null) {
              onChanged([
                ...limits.where((x) => x.category != cat),
                AppLimit(category: cat, minutes: minutes),
              ]);
            }
          },
        ),
      ],
    );
  }
}

class WebRulesEditor extends StatelessWidget {
  const WebRulesEditor({super.key, required this.web, required this.onChanged});

  final WebRules web;
  final ValueChanged<WebRules> onChanged;

  static final _domain = RegExp(r'^(\*\.)?([a-z0-9-]+\.)+[a-z]{2,}$');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = web.mode == 'approved_only' ? web.allowed : web.blocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (mode, label) in [
          ('off', l.rulesWebOff),
          ('block_listed', l.rulesWebBlock),
          ('approved_only', l.rulesWebOnly),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: RadioOptionCard<String>(
              value: mode,
              groupValue: web.mode,
              title: label,
              onChanged: (m) => onChanged(
                WebRules(mode: m, blocked: web.blocked, allowed: web.allowed),
              ),
            ),
          ),
        if (web.mode != 'off') ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final d in list)
                InputChip(
                  label: Text(d),
                  onDeleted: () {
                    final next = list.where((x) => x != d).toList();
                    onChanged(
                      web.mode == 'approved_only'
                          ? WebRules(
                              mode: web.mode,
                              blocked: web.blocked,
                              allowed: next,
                            )
                          : WebRules(
                              mode: web.mode,
                              blocked: next,
                              allowed: web.allowed,
                            ),
                    );
                  },
                ),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(l.rulesWebAdd),
            onPressed: () async {
              final c = TextEditingController();
              final ok = await confirmAction(
                context,
                title: l.rulesWebAdd,
                confirmLabel: l.commonSave,
                extra: TextField(
                  controller: c,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(hintText: l.rulesWebHint),
                ),
              );
              var v = c.text.trim().toLowerCase();
              c.dispose();
              v = v
                  .replaceFirst(RegExp(r'^https?://'), '')
                  .split('/')
                  .first
                  .replaceFirst(RegExp(r'^www\.'), '');
              if (!ok || v.isEmpty) return;
              if (!_domain.hasMatch(v)) {
                if (context.mounted) {
                  showResultSnack(context, l.rulesWebInvalid);
                }
                return;
              }
              final next = {...list, v}.toList();
              onChanged(
                web.mode == 'approved_only'
                    ? WebRules(
                        mode: web.mode,
                        blocked: web.blocked,
                        allowed: next,
                      )
                    : WebRules(
                        mode: web.mode,
                        blocked: next,
                        allowed: web.allowed,
                      ),
              );
            },
          ),
          Text(l.rulesWebNote, style: context.type.bodySmall),
        ],
      ],
    );
  }
}

/// "Here's what will change": plain list of changes, which phones it
/// applies to, and what each phone cannot do. Returns true to save.
Future<bool> showRulesReview(
  BuildContext context, {
  required RulePreview preview,
  required List<DeviceRuleDeviceState> devices,
}) async {
  final l = context.l10n;
  String change(Map<String, dynamic> c) {
    final name = (c['name'] as String?) ?? '';
    return switch (c['kind']) {
      'blocked_apps_added' => l.rulesChangeAddedBlocked(name),
      'blocked_apps_removed' => l.rulesChangeRemovedBlocked(name),
      'allowed_apps_added' => l.rulesChangeAddedAllowed(name),
      'allowed_apps_removed' => l.rulesChangeRemovedAllowed(name),
      'schedule_added' || 'schedule_changed' => l.rulesChangeSchedule(
        name,
        '${c['start']}',
        '${c['end']}',
      ),
      'schedule_removed' => l.rulesChangeScheduleRemoved(name),
      'app_limits_changed' => l.rulesChangeLimits,
      'web_changed' => l.rulesChangeWeb,
      _ => '${c['kind']}',
    };
  }

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.rulesReviewTitle, style: sheet.type.titleLarge),
            const SizedBox(height: AppSpacing.md),
            for (final c in preview.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right_rounded),
                    Expanded(
                      child: Text(change(c), style: sheet.type.bodyLarge),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              devices.isEmpty
                  ? l.rulesReviewAppliesNone
                  : l.rulesReviewApplies(
                      devices.map((d) => d.deviceName).join(', '),
                    ),
              style: sheet.type.bodyMedium,
            ),
            for (final d in preview.deviceLimits)
              if (d.limits.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: NoticeBanner(
                    tone: AppTone.warning,
                    message: l.rulesReviewLimits(
                      d.deviceName,
                      d.limits
                          .map((x) => capabilityLabel(l, x.capability))
                          .join(', '),
                    ),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
            Text(l.rulesReviewAfter, style: sheet.type.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(sheet).pop(true),
              child: Text(l.commonSave),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(false),
              child: Text(l.commonCancel),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
