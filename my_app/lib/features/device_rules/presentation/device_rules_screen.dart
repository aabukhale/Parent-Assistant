import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/util/client_id.dart';
import '../application/native_enforcement.dart';
import '../data/device_rules_models.dart';
import '../data/device_rules_repository.dart';
import 'rules_editors.dart';
import 'rules_labels.dart';

/// Parent: one child's phone rules, in plain language.
///
/// Order of the page = order of what parents usually need: is it working on
/// the phone? → pause now → ready-made plans → details (times, apps, limits,
/// websites). Detail edits collect into a draft that is reviewed ("here's
/// what will change, on which phone, and what that phone can't do") before
/// saving. Presets and pauses apply directly after a short confirmation.
class DeviceRulesScreen extends ConsumerStatefulWidget {
  const DeviceRulesScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  ConsumerState<DeviceRulesScreen> createState() => _DeviceRulesScreenState();
}

class _DeviceRulesScreenState extends ConsumerState<DeviceRulesScreen> {
  DeviceRules? _draft;
  int? _draftBase;
  bool _busy = false;

  DeviceRulesRepository get _repo => ref.read(deviceRulesRepositoryProvider);

  bool _dirty(DeviceRulesState s) =>
      _draft != null &&
      _draftBase == s.version &&
      mapEquals(_normalise(_draft!.toJson()), _normalise(s.rules.toJson())) ==
          false;

  Map<String, Object?> _normalise(Map<String, dynamic> j) =>
      j.map((k, v) => MapEntry(k, v.toString()));

  void _edit(DeviceRulesState s, DeviceRules Function(DeviceRules) change) {
    setState(() {
      if (_draft == null || _draftBase != s.version) {
        _draft = s.rules;
        _draftBase = s.version;
      }
      _draft = change(_draft!);
    });
  }

  Future<void> _run(
    Future<DeviceRulesState> Function() action,
    String done,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(deviceRulesProvider(widget.childId));
      ref.invalidate(ruleHistoryProvider(widget.childId));
      if (mounted) showResultSnack(context, done);
    } on ApiException catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      if (e.kind == ApiErrorKind.conflict) {
        setState(() => _draft = null);
        ref.invalidate(deviceRulesProvider(widget.childId));
        showResultSnack(context, l.rulesConflict);
      } else {
        showResultSnack(context, e.localizedMessage(l));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(DeviceRulesState s) async {
    final l = context.l10n;
    final draft = _draft!;
    RulePreview? preview;
    try {
      preview = await _repo.preview(widget.childId, draft);
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(l));
      return;
    }
    if (!mounted) return;
    final ok = await showRulesReview(
      context,
      preview: preview,
      devices: s.devices,
    );
    if (!ok) return;
    await _run(() async {
      final r = await _repo.save(
        widget.childId,
        draft,
        expectedVersion: s.version,
      );
      if (mounted) setState(() => _draft = null);
      return r;
    }, l.rulesSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(deviceRulesProvider(widget.childId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.rulesTitle),
        actions: [
          IconButton(
            tooltip: l.rulesHistory,
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RuleHistoryScreen(childId: widget.childId),
              ),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorRetryView(
          error: e,
          onRetry: () async =>
              ref.invalidate(deviceRulesProvider(widget.childId)),
        ),
        data: (s) {
          final rules = (_draftBase == s.version ? _draft : null) ?? s.rules;
          final dirty = _dirty(s);
          return AppContentFrame(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(deviceRulesProvider(widget.childId)),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      dirty ? 120 : AppSpacing.xxxl,
                    ),
                    children: [
                      DeviceStatusSection(
                        state: s,
                        childName: widget.childName,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _PauseCard(
                        state: s,
                        childName: widget.childName,
                        busy: _busy,
                        onPause: (m) => _run(
                          () => _repo.restrictNow(widget.childId, minutes: m),
                          l.rulesSaved,
                        ),
                        onRelease: () => _run(
                          () => _repo.release(widget.childId),
                          l.rulesSaved,
                        ),
                      ),
                      RulesSection(l.rulesPresets),
                      PresetRow(
                        busy: _busy,
                        weekendDays: s.weekendDays,
                        onApply: (preset) async {
                          final r = await showPresetSheet(
                            context,
                            preset: preset,
                            weekendDays: s.weekendDays,
                            existing: s.rules.schedules
                                .where((x) => x.preset == preset)
                                .firstOrNull,
                          );
                          if (r == null) return;
                          await _run(
                            () => _repo.applyPreset(
                              widget.childId,
                              preset,
                              days: r.days,
                              start: r.start,
                              end: r.end,
                              minutes: r.minutes,
                              name: presetLabel(l, preset),
                            ),
                            l.rulesSaved,
                          );
                        },
                      ),
                      RulesSection(l.rulesSchedules),
                      if (rules.schedules.isEmpty)
                        Text(
                          l.rulesSchedulesEmpty,
                          style: context.type.bodyMedium,
                        )
                      else
                        for (final sch in rules.schedules)
                          ScheduleTile(
                            schedule: sch,
                            onToggle: (v) => _edit(
                              s,
                              (r) => r.copyWith(
                                schedules: [
                                  for (final x in r.schedules)
                                    x.id == sch.id ? x.copyWith(enabled: v) : x,
                                ],
                              ),
                            ),
                            onEdit: () async {
                              final r = await showPresetSheet(
                                context,
                                preset: sch.preset,
                                weekendDays: s.weekendDays,
                                existing: sch,
                              );
                              if (r == null) return;
                              _edit(
                                s,
                                (rr) => rr.copyWith(
                                  schedules: [
                                    for (final x in rr.schedules)
                                      x.id == sch.id
                                          ? x.copyWith(
                                              days: r.days,
                                              start: r.start,
                                              end: r.end,
                                            )
                                          : x,
                                  ],
                                ),
                              );
                            },
                            onDelete: () => _edit(
                              s,
                              (r) => r.copyWith(
                                schedules: r.schedules
                                    .where((x) => x.id != sch.id)
                                    .toList(),
                              ),
                            ),
                          ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l.presetCustom),
                        onPressed: () async {
                          final r = await showPresetSheet(
                            context,
                            preset: 'custom',
                            weekendDays: s.weekendDays,
                          );
                          if (r == null) return;
                          _edit(
                            s,
                            (rr) => rr.copyWith(
                              schedules: [
                                ...rr.schedules,
                                RuleSchedule(
                                  id: 'custom-${newClientId().substring(0, 8)}',
                                  preset: 'custom',
                                  name: l.presetCustom,
                                  days: r.days!,
                                  start: r.start!,
                                  end: r.end!,
                                  restriction: 'allow_only',
                                  enabled: true,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      RulesSection(l.rulesApps),
                      AppListEntry(
                        icon: Icons.block_rounded,
                        title: l.rulesBlockedApps,
                        apps: rules.blockedApps,
                        onEdit: () async {
                          final picked = await pickChildApps(
                            context,
                            ref,
                            childId: widget.childId,
                            childName: widget.childName,
                            selected: rules.blockedApps,
                            exclude: rules.allowedApps,
                          );
                          if (picked != null) {
                            _edit(s, (r) => r.copyWith(blockedApps: picked));
                          }
                        },
                      ),
                      AppListEntry(
                        icon: Icons.verified_user_rounded,
                        title: l.rulesAllowedApps,
                        subtitle: l.rulesAllowedAppsBody,
                        apps: rules.allowedApps,
                        onEdit: () async {
                          final picked = await pickChildApps(
                            context,
                            ref,
                            childId: widget.childId,
                            childName: widget.childName,
                            selected: rules.allowedApps,
                            exclude: rules.blockedApps,
                          );
                          if (picked != null) {
                            _edit(s, (r) => r.copyWith(allowedApps: picked));
                          }
                        },
                      ),
                      RulesSection(l.rulesLimits),
                      LimitsEditor(
                        limits: rules.appLimits,
                        onChanged: (v) =>
                            _edit(s, (r) => r.copyWith(appLimits: v)),
                      ),
                      RulesSection(l.rulesWeb),
                      WebRulesEditor(
                        web: rules.web,
                        onChanged: (v) => _edit(s, (r) => r.copyWith(web: v)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      NoticeBanner(
                        tone: AppTone.info,
                        icon: Icons.phone_in_talk_rounded,
                        message: l.rulesEssentials,
                      ),
                    ],
                  ),
                ),
                if (dirty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Material(
                      elevation: 8,
                      color: context.mamily.surface,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _draft = null),
                                child: Text(l.commonCancel),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy ? null : () => _review(s),
                                  icon: const Icon(Icons.fact_check_rounded),
                                  label: Text(l.rulesReviewSave),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Per-phone status with a plain explanation and what each phone can do.
class DeviceStatusSection extends StatelessWidget {
  const DeviceStatusSection({
    super.key,
    required this.state,
    required this.childName,
  });

  final DeviceRulesState state;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    if (state.devices.isEmpty) {
      final t = deviceStateText(l, 'no_device', childName: childName);
      return NoticeBanner(
        tone: t.tone,
        icon: t.icon,
        title: t.title,
        message: t.body,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l.rulesOnPhones(childName),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        for (final d in state.devices) ...[
          Builder(
            builder: (context) {
              final when = (d.observedAt ?? d.appliedAt ?? d.lastContactAt);
              final t = deviceStateText(
                l,
                state.hasRules ? d.state : 'no_rules',
                childName: childName,
                when: when == null ? null : relativeTime(context, when),
              );
              return AppCard(
                tone: t.tone,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          d.platform == 'ios'
                              ? Icons.phone_iphone_rounded
                              : Icons.phone_android_rounded,
                          color: c.ink2,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            d.deviceName,
                            style: context.type.titleSmall,
                          ),
                        ),
                        StatusPill(label: t.title, tone: t.tone, icon: t.icon),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(t.body, style: context.type.bodyMedium),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          l.rulesCanDo,
                          style: context.type.labelLarge,
                        ),
                        children: [
                          for (final key in NativeEnforcement.capabilityKeys)
                            _CapabilityRow(
                              label: capabilityLabel(l, key),
                              value: d.capability(key),
                            ),
                          if (d.capabilities.values.contains('setup_needed') ||
                              d.capabilities.values.contains('unsupported'))
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Text(
                                d.platform == 'ios'
                                    ? l.capSetupHelpIos
                                    : l.capSetupHelpAndroid,
                                style: context.type.bodySmall?.copyWith(
                                  color: c.ink2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final v = capabilityValue(context.l10n, value);
    final t = context.mamily.tone(v.tone);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(v.icon, size: 20, color: t.foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: context.type.bodyMedium)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              v.text,
              textAlign: TextAlign.end,
              style: context.type.bodySmall?.copyWith(color: t.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseCard extends StatelessWidget {
  const _PauseCard({
    required this.state,
    required this.childName,
    required this.busy,
    required this.onPause,
    required this.onRelease,
  });

  final DeviceRulesState state;
  final String childName;
  final bool busy;
  final void Function(int? minutes) onPause;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = state.rules.restrictNow;
    final on = r != null && state.restrictState == 'on';

    Future<void> ask(int? minutes, String duration) async {
      final ok = await confirmAction(
        context,
        title: l.rulesPauseConfirm(childName, duration),
        body: l.rulesPauseBody,
        confirmLabel: l.rulesPauseTitle,
      );
      if (ok) onPause(minutes);
    }

    return AppCard(
      tone: on ? AppTone.sleep : AppTone.neutral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.pause_circle_rounded,
                tone: AppTone.sleep,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  on
                      ? (r.until == null
                            ? l.rulesPausedOpen
                            : l.rulesPausedUntil(hhmmOf(context, r.until!)))
                      : l.rulesPauseTitle,
                  style: context.type.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l.rulesPauseBody, style: context.type.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          if (on)
            FilledButton.icon(
              onPressed: busy ? null : onRelease,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.rulesRelease),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => ask(30, l.rulesPause30),
                  child: Text(l.rulesPause30),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => ask(60, l.rulesPause60),
                  child: Text(l.rulesPause60),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => ask(null, l.rulesPauseUntil),
                  child: Text(l.rulesPauseUntil),
                ),
              ],
            ),
          if (state.restrictState == 'expired') ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l.rulesPauseExpired, style: context.type.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Changes over time, with "go back to this" (restores as a new version).
class RuleHistoryScreen extends ConsumerWidget {
  const RuleHistoryScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(ruleHistoryProvider(childId));
    return Scaffold(
      appBar: AppBar(title: Text(l.rulesHistory)),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(ruleHistoryProvider(childId)),
          ),
          data: (items) => items.isEmpty
              ? EmptyView(icon: Icons.history_rounded, message: l.commonEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final v = items[i];
                    final when = v.createdAt == null
                        ? ''
                        : relativeTime(context, v.createdAt!);
                    return AppListTile(
                      leading: const IconBadge(icon: Icons.tune_rounded),
                      title: historyKindLabel(l, v.changeKind),
                      subtitle: [
                        if ((v.summary ?? '').isNotEmpty) v.summary!,
                        l.rulesHistoryBy(v.changedBy ?? '—', when),
                      ].join('\n'),
                      trailing: v.canUndoTo
                          ? TextButton(
                              onPressed: () async {
                                final ok = await confirmAction(
                                  context,
                                  title: l.rulesUndoTo,
                                  body: l.rulesUndoConfirm(when),
                                  confirmLabel: l.rulesUndoTo,
                                );
                                if (!ok) return;
                                try {
                                  await ref
                                      .read(deviceRulesRepositoryProvider)
                                      .undoTo(childId, v.version);
                                  ref
                                    ..invalidate(ruleHistoryProvider(childId))
                                    ..invalidate(deviceRulesProvider(childId));
                                  if (context.mounted) {
                                    showResultSnack(context, l.rulesUndone);
                                  }
                                } on ApiException catch (e) {
                                  if (context.mounted) {
                                    showResultSnack(
                                      context,
                                      e.localizedMessage(l),
                                    );
                                  }
                                }
                              },
                              child: Text(l.rulesUndoTo),
                            )
                          : null,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
