import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../family/application/permissions_controller.dart';
import '../../family/data/models/family_permission.dart';
import '../../kid/data/kid_models.dart';
import '../../kid/presentation/kid_widgets.dart';
import '../application/hub_actions.dart';
import '../application/hub_providers.dart';
import '../data/hub_models.dart';
import '../data/hub_repository.dart';
import 'hub_widgets.dart';
import 'pairing_sheet.dart';
import 'praise_sheet.dart';

String routineKindLabel(AppLocalizations l, String kind) => switch (kind) {
  'morning' => l.routineKindMorning,
  'after_school' => l.routineKindAfterSchool,
  'bedtime' => l.routineKindBedtime,
  _ => l.routineKindCustom,
};

// ============================================================================
// Routines
// ============================================================================

class ChildRoutinesScreen extends ConsumerWidget {
  const ChildRoutinesScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final canManage = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageRoutines);
    final async = ref.watch(childRoutinesProvider(childId));
    void edit([Routine? r]) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineFormScreen(childId: childId, existing: r),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${l.routinesTitle} · $childName')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: edit,
              icon: const Icon(Icons.add_rounded),
              label: Text(l.routinesNew),
            )
          : null,
      body: AppContentFrame(
        maxWidth: 760,
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(childRoutinesProvider(childId)),
          ),
          data: (list) => list.isEmpty
              ? EmptyView(
                  icon: Icons.wb_sunny_rounded,
                  message: l.routinesEmpty,
                  action: canManage
                      ? FilledButton.icon(
                          onPressed: edit,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(l.routineFromTemplate),
                        )
                      : null,
                )
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(childRoutinesProvider(childId)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      96,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) {
                      final r = list[i];
                      final run = r.todayRun;
                      return AppCard(
                        onTap: canManage ? () => edit(r) : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconTile(icon: routineIcon(r.kind), size: 48),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.title,
                                        style: context.type.titleSmall,
                                      ),
                                      Text(
                                        [
                                          ?r.startTime,
                                          r.daysOfWeek.length == 7
                                              ? null
                                              : r.daysOfWeek
                                                    .map(
                                                      (d) => weekdayShort(l, d),
                                                    )
                                                    .join(' '),
                                          l.kidRoutineStepsLeft(r.steps.length),
                                        ].whereType<String>().join(' · '),
                                        style: context.type.bodySmall?.copyWith(
                                          color: c.ink2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusPill(
                                  label: r.isActive
                                      ? l.routineActive
                                      : l.routinePaused,
                                  tone: r.isActive
                                      ? AppTone.success
                                      : AppTone.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (r.scheduledToday == false)
                              Text(
                                l.routineNotToday,
                                style: context.type.bodySmall?.copyWith(
                                  color: c.ink3,
                                ),
                              )
                            else ...[
                              ProgressBar(
                                value: run == null ? 0 : run.progress,
                                color: c.success.foreground,
                                semanticsLabel: r.title,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: [
                                  Text(
                                    l.routineTodayProgress(
                                      run?.stepsDone ?? 0,
                                      r.steps.length,
                                    ),
                                    style: context.type.bodySmall?.copyWith(
                                      color: c.ink2,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (run != null)
                                    KidStateBadge(state: run.status),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class RoutineFormScreen extends ConsumerStatefulWidget {
  const RoutineFormScreen({super.key, required this.childId, this.existing});

  final String childId;
  final Routine? existing;

  @override
  ConsumerState<RoutineFormScreen> createState() => _RoutineFormScreenState();
}

class _StepDraft {
  _StepDraft({this.id, required String title, this.iconKey, this.minutes})
    : controller = TextEditingController(text: title);

  final String? id;
  final TextEditingController controller;
  String? iconKey;
  int? minutes;
}

class _RoutineFormScreenState extends ConsumerState<RoutineFormScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late String _kind = widget.existing?.kind ?? 'morning';
  late TimeOfDay? _start =
      _parse(widget.existing?.startTime) ?? const TimeOfDay(hour: 7, minute: 0);
  late final Set<int> _days = {...?widget.existing?.daysOfWeek};
  late final _bonus = TextEditingController(
    text: '${widget.existing?.bonusPoints ?? 0}',
  );
  late bool _reminder = widget.existing?.reminderEnabled ?? true;
  late bool _active = widget.existing?.isActive ?? true;
  late final List<_StepDraft> _steps = [
    for (final s in widget.existing?.steps ?? const <RoutineStep>[])
      _StepDraft(
        id: s.id,
        title: s.title,
        iconKey: s.iconKey,
        minutes: s.durationMinutes,
      ),
  ];
  bool _busy = false;
  String? _error;

  static TimeOfDay? _parse(String? hhmm) {
    if (hhmm == null || hhmm.length < 5) return null;
    return TimeOfDay(
      hour: int.parse(hhmm.substring(0, 2)),
      minute: int.parse(hhmm.substring(3, 5)),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_days.isEmpty) _days.addAll(const [1, 2, 3, 4, 5, 6, 7]);
  }

  @override
  void dispose() {
    _title.dispose();
    _bonus.dispose();
    for (final s in _steps) {
      s.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _applyTemplate() async {
    final templates = await ref.read(hubRepositoryProvider).routineTemplates();
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final t in templates)
              ListTile(
                leading: Icon(
                  routineIcon(t['kind'] as String),
                  size: 28,
                  color: context.mamily.brand.foreground,
                ),
                title: Text(t['title'] as String),
                subtitle: Text(
                  ((t['steps'] as List).map(
                    (s) => (s as Map)['title'],
                  )).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(sheet).pop(t),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _title.text = picked['title'] as String;
      _kind = picked['kind'] as String;
      _start = _parse(picked['start_time'] as String?);
      _days
        ..clear()
        ..addAll(
          ((picked['days_of_week'] as List?) ?? const []).map(
            (e) => (e as num).toInt(),
          ),
        );
      for (final s in _steps) {
        s.controller.dispose();
      }
      _steps
        ..clear()
        ..addAll([
          for (final s in (picked['steps'] as List).cast<Map>())
            _StepDraft(
              title: s['title'] as String,
              iconKey: s['icon_key'] as String?,
              minutes: (s['duration_minutes'] as num?)?.toInt(),
            ),
        ]);
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    final steps = _steps
        .where((s) => s.controller.text.trim().isNotEmpty)
        .toList();
    if (_title.text.trim().length < 2) {
      setState(() => _error = l.validationRequired);
      return;
    }
    if (steps.isEmpty) {
      setState(() => _error = l.routineStepsRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    try {
      await ref.read(hubRepositoryProvider).saveRoutine(widget.childId, {
        'title': _title.text.trim(),
        'kind': _kind,
        'start_time': _start == null ? null : fmt(_start!),
        'days_of_week': (_days.toList()..sort()),
        'bonus_points': int.tryParse(_bonus.text.trim()) ?? 0,
        'reminder_enabled': _reminder,
        'is_active': _active,
        'steps': [
          for (final s in steps)
            {
              'id': ?s.id,
              'title': s.controller.text.trim(),
              'icon_key': s.iconKey,
              'duration_minutes': s.minutes,
            },
        ],
      }, routineId: widget.existing?.id);
      ref.invalidate(childRoutinesProvider(widget.childId));
      if (!mounted) return;
      showResultSnack(context, l.routineSaved);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.localizedMessage(l));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? l.routinesNew : l.routineEdit),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: l.routineDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final ok = await confirmAction(
                  context,
                  title: l.routineDelete,
                  body: l.routineDeleteBody,
                  confirmLabel: l.routineDelete,
                  destructive: true,
                );
                if (!ok) return;
                await ref
                    .read(hubRepositoryProvider)
                    .deleteRoutine(widget.childId, widget.existing!.id);
                ref.invalidate(childRoutinesProvider(widget.childId));
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: AppContentFrame(
        maxWidth: 640,
        child: ReorderableListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            120 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.existing == null) ...[
                OutlinedButton.icon(
                  onPressed: _applyTemplate,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(l.routineFromTemplate),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (_error != null) ...[
                NoticeBanner(tone: AppTone.danger, message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(
                controller: _title,
                maxLength: 120,
                decoration: InputDecoration(labelText: l.routineName),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final k in const [
                    'morning',
                    'after_school',
                    'bedtime',
                    'custom',
                  ])
                    ChoiceChip(
                      avatar: Icon(routineIcon(k), size: 18),
                      label: Text(routineKindLabel(l, k)),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  '${l.routineStartTime}: ${_start?.format(context) ?? '—'}',
                ),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _start ?? const TimeOfDay(hour: 7, minute: 0),
                  );
                  if (picked != null) setState(() => _start = picked);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(l.routineDays, style: context.type.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(weekdayShort(l, d)),
                      selected: _days.contains(d),
                      onSelected: (s) => setState(
                        () => s
                            ? _days.add(d)
                            : (_days.length > 1 ? _days.remove(d) : null),
                      ),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.routineReminder),
                value: _reminder,
                onChanged: (v) => setState(() => _reminder = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.routineActive),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              TextField(
                controller: _bonus,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.routineBonus),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l.routineSteps, style: context.type.titleMedium),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
          footer: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(
                  onPressed: _steps.length >= 20
                      ? null
                      : () => setState(() => _steps.add(_StepDraft(title: ''))),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.routineAddStep),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(l.commonSave),
                ),
              ],
            ),
          ),
          onReorderItem: (from, to) => setState(() {
            final item = _steps.removeAt(from);
            _steps.insert(to, item);
          }),
          children: [
            for (var i = 0; i < _steps.length; i++)
              Padding(
                key: ObjectKey(_steps[i]),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: AppRadii.mediumAll,
                      onTap: () async {
                        final step = _steps[i];
                        final key = await pickIconKey(
                          context,
                          current: step.iconKey,
                        );
                        if (key != null && mounted) {
                          setState(() => step.iconKey = key);
                        }
                      },
                      child: Tooltip(
                        message: l.taskFieldIcon,
                        child: IconTile(
                          icon: taskIcon(_steps[i].iconKey),
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _steps[i].controller,
                        maxLength: 120,
                        decoration: InputDecoration(
                          hintText: l.routineStepHint,
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.commonCancel,
                      onPressed: () => setState(
                        () => _steps.removeAt(i).controller.dispose(),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Check-ins & praise
// ============================================================================

class ChildCheckinsScreen extends ConsumerWidget {
  const ChildCheckinsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final checkins = ref.watch(childCheckinsProvider(childId));
    final praise = ref.watch(childEncouragementsProvider(childId));
    return Scaffold(
      appBar: AppBar(title: Text(l.checkinsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showPraiseSheet(context, childId: childId, childName: childName),
        icon: const Icon(Icons.favorite_rounded),
        label: Text(l.praiseNew),
      ),
      body: AppContentFrame(
        maxWidth: 760,
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(childCheckinsProvider(childId))
              ..invalidate(childEncouragementsProvider(childId));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              96,
            ),
            children: [
              NoticeBanner(tone: AppTone.info, message: l.inboxCheckinNote),
              const SizedBox(height: AppSpacing.lg),
              ...checkins.when(
                loading: () => [const LoadingView()],
                error: (e, _) => [
                  ErrorRetryView(
                    error: e,
                    onRetry: () async =>
                        ref.invalidate(childCheckinsProvider(childId)),
                  ),
                ],
                data: (list) => list.isEmpty
                    ? [
                        EmptyView(
                          icon: Icons.chat_bubble_rounded,
                          message: l.checkinsEmpty(childName),
                        ),
                      ]
                    : [
                        for (final m in list)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    moodIcon(m.mood),
                                    size: 32,
                                    color: context.mamily.info.foreground,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          moodLabel(l, m.mood),
                                          style: context.type.titleSmall,
                                        ),
                                        if ((m.note ?? '').isNotEmpty)
                                          Text(
                                            m.note!,
                                            style: context.type.bodyMedium,
                                          ),
                                        if (m.createdAt != null)
                                          Text(
                                            relativeTime(context, m.createdAt!),
                                            style: context.type.bodySmall
                                                ?.copyWith(color: c.ink2),
                                          ),
                                        if (m.hasReply)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: AppSpacing.xs,
                                            ),
                                            child: Text(
                                              '↩︎ ${m.repliedByName ?? ''}: ${m.reply ?? ''}',
                                              style: context.type.bodySmall
                                                  ?.copyWith(
                                                    color: c.accent.foreground,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (!m.hasReply)
                                    _ReplyButton(
                                      checkin: m,
                                      childName: childName,
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
              ),
              SectionHeader(
                title: l.praiseHistory,
                padding: const EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.md,
                ),
              ),
              ...praise.when(
                loading: () => [const LoadingView()],
                error: (e, _) => [ErrorRetryView(error: e)],
                data: (list) => [
                  for (final e in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        child: Row(
                          children: [
                            Icon(
                              badgeIcon(e.badgeKey),
                              size: 28,
                              color: context.mamily.sleep.foreground,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                e.message,
                                style: context.type.bodyLarge,
                              ),
                            ),
                            if (e.createdAt != null)
                              Text(
                                relativeTime(context, e.createdAt!),
                                style: context.type.bodySmall?.copyWith(
                                  color: c.ink2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyButton extends ConsumerWidget {
  const _ReplyButton({required this.checkin, required this.childName});

  final MoodCheckin checkin;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return TextButton(
      onPressed: () async {
        final controller = TextEditingController();
        final ok = await confirmAction(
          context,
          title: l.inboxReplyTitle(childName),
          confirmLabel: l.commonSend,
          extra: TextField(
            controller: controller,
            maxLength: 200,
            maxLines: 2,
            decoration: InputDecoration(hintText: l.inboxReplyHint),
          ),
        );
        final text = controller.text.trim();
        controller.dispose();
        if (!ok || text.isEmpty) return;
        try {
          await ref
              .read(hubActionsProvider)
              .replyCheckin(checkin.id, reply: text);
          if (context.mounted) showResultSnack(context, l.inboxReplySent);
        } on ApiException catch (e) {
          if (context.mounted) showResultSnack(context, e.localizedMessage(l));
        }
      },
      child: Text(l.inboxReply),
    );
  }
}

// ============================================================================
// Meals
// ============================================================================

String mealLabel(AppLocalizations l, String t) => switch (t) {
  'breakfast' => l.mealBreakfast,
  'lunch' => l.mealLunch,
  'dinner' => l.mealDinner,
  _ => l.mealSnack,
};

String appetiteLabel(AppLocalizations l, String a) => switch (a) {
  'all' => l.appetiteAll,
  'most' => l.appetiteMost,
  'some' => l.appetiteSome,
  'little' => l.appetiteLittle,
  _ => l.appetiteNone,
};

class ChildMealsScreen extends ConsumerWidget {
  const ChildMealsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final canManage = ref
        .watch(permissionsProvider)
        .hasPermission(FamilyPermission.manageMeals);
    final async = ref.watch(childMealsProvider(childId));
    return Scaffold(
      appBar: AppBar(title: Text('${l.mealsTitle} · $childName')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _mealSheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.mealsAdd),
            )
          : null,
      body: AppContentFrame(
        maxWidth: 760,
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(childMealsProvider(childId)),
          ),
          data: (list) => list.isEmpty
              ? EmptyView(icon: Icons.restaurant_rounded, message: l.mealsEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    96,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final m = list[i];
                    return AppCard(
                      onTap: canManage
                          ? () => _mealSheet(context, ref, existing: m)
                          : null,
                      child: Row(
                        children: [
                          IconTile(
                            icon: switch (m.mealType) {
                              'breakfast' => Icons.breakfast_dining_rounded,
                              'lunch' => Icons.lunch_dining_rounded,
                              'dinner' => Icons.dinner_dining_rounded,
                              _ => Icons.cookie_rounded,
                            },
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${mealLabel(l, m.mealType)} · ${DateFormat.MMMd(locale).add_jm().format(m.eatenAt)}',
                                  style: context.type.titleSmall,
                                ),
                                if ((m.description ?? '').isNotEmpty)
                                  Text(
                                    m.description!,
                                    style: context.type.bodyMedium,
                                  ),
                                if (m.appetite != null)
                                  Text(
                                    appetiteLabel(l, m.appetite!),
                                    style: context.type.bodySmall?.copyWith(
                                      color: c.ink2,
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
        ),
      ),
    );
  }

  Future<void> _mealSheet(
    BuildContext context,
    WidgetRef ref, {
    MealLog? existing,
  }) async {
    final l = context.l10n;
    var type =
        existing?.mealType ??
        (DateTime.now().hour < 11
            ? 'breakfast'
            : DateTime.now().hour < 16
            ? 'lunch'
            : 'dinner');
    String? appetite = existing?.appetite;
    var when = existing?.eatenAt ?? DateTime.now();
    final what = TextEditingController(text: existing?.description ?? '');
    final ok = await confirmAction(
      context,
      title: l.mealsAdd,
      confirmLabel: l.commonSave,
      extra: StatefulBuilder(
        builder: (context, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in const ['breakfast', 'lunch', 'dinner', 'snack'])
                  ChoiceChip(
                    label: Text(mealLabel(l, t)),
                    selected: type == t,
                    onSelected: (_) => set(() => type = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: what,
              maxLength: 200,
              decoration: InputDecoration(labelText: l.mealWhat),
            ),
            Text(l.mealAppetite, style: context.type.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final a in const ['all', 'most', 'some', 'little', 'none'])
                  ChoiceChip(
                    label: Text(appetiteLabel(l, a)),
                    selected: appetite == a,
                    onSelected: (s) => set(() => appetite = s ? a : null),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_rounded),
              label: Text(
                '${l.mealWhen}: ${TimeOfDay.fromDateTime(when).format(context)}',
              ),
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(when),
                );
                if (t != null) {
                  set(
                    () => when = DateTime(
                      when.year,
                      when.month,
                      when.day,
                      t.hour,
                      t.minute,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
    final description = what.text.trim();
    what.dispose();
    if (!ok) return;
    String two(int n) => n.toString().padLeft(2, '0');
    try {
      await ref.read(hubRepositoryProvider).saveMeal(childId, {
        'meal_type': type,
        'description': description.isEmpty ? null : description,
        'appetite': appetite,
        'eaten_at':
            '${when.year}-${two(when.month)}-${two(when.day)} ${two(when.hour)}:${two(when.minute)}',
      }, mealId: existing?.id);
      ref.invalidate(childMealsProvider(childId));
      if (context.mounted) showResultSnack(context, l.mealSaved);
    } on ApiException catch (e) {
      if (context.mounted) showResultSnack(context, e.localizedMessage(l));
    }
  }
}

// ============================================================================
// Devices & pairing
// ============================================================================

class ChildDevicesScreen extends ConsumerWidget {
  const ChildDevicesScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final canPair = ref.watch(permissionsProvider).canManageChildren;
    final async = ref.watch(childDevicesProvider(childId));
    return Scaffold(
      appBar: AppBar(title: Text(l.hubDevices)),
      body: AppContentFrame(
        maxWidth: 760,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(childDevicesProvider(childId)),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (canPair)
                FilledButton.icon(
                  onPressed: () async {
                    await showPairingSheet(
                      context,
                      childId: childId,
                      childName: childName,
                    );
                    ref.invalidate(childDevicesProvider(childId));
                  },
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: Text(l.pairCreate),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l.pulseDeviceExplain,
                style: context.type.bodySmall?.copyWith(color: c.ink2),
              ),
              SectionHeader(
                title: l.pairedDevices,
                padding: const EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.md,
                ),
              ),
              ...async.when(
                loading: () => [const LoadingView()],
                error: (e, _) => [
                  ErrorRetryView(
                    error: e,
                    onRetry: () async =>
                        ref.invalidate(childDevicesProvider(childId)),
                  ),
                ],
                data: (list) => list.isEmpty
                    ? [
                        EmptyView(
                          icon: Icons.smartphone_rounded,
                          message: l.pairedNone,
                        ),
                      ]
                    : [
                        for (final d in list)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Icon(
                                    d.platform == 'ios'
                                        ? Icons.phone_iphone_rounded
                                        : Icons.phone_android_rounded,
                                    color: c.ink2,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.name,
                                          style: context.type.titleSmall,
                                        ),
                                        Text(
                                          d.deviceMode == 'family_shared'
                                              ? l.pairModeShared
                                              : l.pairModeDedicated,
                                          style: context.type.bodySmall
                                              ?.copyWith(color: c.ink2),
                                        ),
                                        if (d.lastSeenAt != null)
                                          Text(
                                            l.pulseDeviceStale(
                                              relativeTime(
                                                context,
                                                d.lastSeenAt!,
                                              ),
                                            ),
                                            style: context.type.bodySmall
                                                ?.copyWith(color: c.ink2),
                                          ),
                                      ],
                                    ),
                                  ),
                                  StatusPill(
                                    label: d.isActive && d.hasChildSession
                                        ? l.pairedActive
                                        : l.pairedInactive,
                                    tone: d.isActive && d.hasChildSession
                                        ? AppTone.success
                                        : AppTone.neutral,
                                  ),
                                  if (canPair && d.isActive)
                                    IconButton(
                                      tooltip: l.pairUnpair,
                                      icon: const Icon(Icons.link_off_rounded),
                                      onPressed: () async {
                                        final ok = await confirmAction(
                                          context,
                                          title: l.pairUnpairConfirm(d.name),
                                          body: l.pairUnpairBody,
                                          confirmLabel: l.pairUnpair,
                                          destructive: true,
                                        );
                                        if (!ok) return;
                                        try {
                                          await ref
                                              .read(hubRepositoryProvider)
                                              .unpairDevice(childId, d.id);
                                          ref
                                            ..invalidate(
                                              childDevicesProvider(childId),
                                            )
                                            ..invalidate(pulseProvider);
                                          if (context.mounted) {
                                            showResultSnack(
                                              context,
                                              l.pairUnpaired,
                                            );
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
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
