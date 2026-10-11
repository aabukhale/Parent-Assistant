import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../application/hub_providers.dart';
import '../data/hub_models.dart';
import '../data/hub_repository.dart';
import 'hub_widgets.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Shared family planner: a week at a time, routines + task deadlines + events.
class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late DateTime _weekStart = _startOfWeek(DateTime.now());
  String? _child;

  static DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final from = _ymd(_weekStart);
    final to = _ymd(_weekStart.add(const Duration(days: 6)));
    final async = ref.watch(
      plannerProvider((from: from, to: to, childId: _child)),
    );
    final children = ref.watch(childLookupProvider).values.toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.plannerTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showEventSheet(context);
          ref.invalidate(plannerProvider);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l.plannerNewEvent),
      ),
      body: AppContentFrame(
        maxWidth: 760,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l.recapPrevious,
                    onPressed: () => setState(
                      () => _weekStart = _weekStart.subtract(
                        const Duration(days: 7),
                      ),
                    ),
                    icon: Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${DateFormat.MMMd(locale).format(_weekStart)} – ${DateFormat.MMMd(locale).format(_weekStart.add(const Duration(days: 6)))}',
                      textAlign: TextAlign.center,
                      style: context.type.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l.recapNext,
                    onPressed: () => setState(
                      () =>
                          _weekStart = _weekStart.add(const Duration(days: 7)),
                    ),
                    icon: Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            if (children.length > 1)
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  children: [
                    ChoiceChip(
                      label: Text(l.plannerEveryone),
                      selected: _child == null,
                      onSelected: (_) => setState(() => _child = null),
                    ),
                    for (final ch in children) ...[
                      const SizedBox(width: AppSpacing.sm),
                      ChoiceChip(
                        avatar: ChildAvatarById(childId: ch.id, size: 24),
                        label: Text(ch.name),
                        selected: _child == ch.id,
                        onSelected: (_) => setState(() => _child = ch.id),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: async.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () async => ref.invalidate(plannerProvider),
                ),
                data: (fresh) {
                  final byDay = <String, List<PlannerItem>>{};
                  for (final i in fresh.value) {
                    byDay.putIfAbsent(i.date, () => []).add(i);
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(plannerProvider),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        96,
                      ),
                      children: [
                        if (fresh.fromCache)
                          FreshnessLine(
                            fetchedAt: fresh.fetchedAt,
                            fromCache: true,
                          ),
                        for (var d = 0; d < 7; d++) ...[
                          Builder(
                            builder: (context) {
                              final day = _weekStart.add(Duration(days: d));
                              final isToday = _ymd(day) == _ymd(DateTime.now());
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.lg,
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      DateFormat.MMMEd(locale).format(day),
                                      style: context.type.titleSmall?.copyWith(
                                        color: isToday ? c.actionText : c.ink,
                                      ),
                                    ),
                                    if (isToday) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      StatusPill(
                                        label: l.tabToday,
                                        tone: AppTone.brand,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                          if ((byDay[_ymd(_weekStart.add(Duration(days: d)))] ??
                                  const [])
                              .isEmpty)
                            Text(
                              l.plannerEmptyDay,
                              style: context.type.bodySmall?.copyWith(
                                color: c.ink3,
                              ),
                            )
                          else
                            for (final item
                                in byDay[_ymd(
                                  _weekStart.add(Duration(days: d)),
                                )]!)
                              PlannerRow(item: item),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One planner entry (used on Today and in the planner).
class PlannerRow extends ConsumerWidget {
  const PlannerRow({super.key, required this.item});

  final PlannerItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final (label, tone, icon) = switch (item.type) {
      'routine' => (
        l.plannerTypeRoutine,
        AppTone.accent,
        Icons.wb_sunny_rounded,
      ),
      'task_deadline' => (
        l.plannerTypeDeadline,
        AppTone.warning,
        Icons.flag_rounded,
      ),
      _ => (l.plannerTypeEvent, AppTone.info, Icons.event_rounded),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: item.type == 'event'
            ? () async {
                await showEventSheet(context, eventId: item.sourceId);
                ref.invalidate(plannerProvider);
              }
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                item.allDay ? l.plannerAllDay : (item.time ?? ''),
                style: context.type.labelLarge?.copyWith(color: c.ink2),
              ),
            ),
            Icon(icon, color: c.tone(tone).foreground, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.type.titleSmall),
                  if ((item.location ?? '').isNotEmpty)
                    Text(
                      item.location!,
                      style: context.type.bodySmall?.copyWith(color: c.ink2),
                    ),
                ],
              ),
            ),
            for (final id in item.childIds.take(3))
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 2),
                child: ChildAvatarById(childId: id, size: 26),
              ),
            const SizedBox(width: AppSpacing.xs),
            ExcludeSemantics(
              child: StatusPill(label: label, tone: tone),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create or edit a planner event.
Future<void> showEventSheet(BuildContext context, {String? eventId}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EventSheet(eventId: eventId),
    );

class _EventSheet extends ConsumerStatefulWidget {
  const _EventSheet({this.eventId});

  final String? eventId;

  @override
  ConsumerState<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<_EventSheet> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 0);
  bool _allDay = false;
  bool _weekly = false;
  int? _remind = 30;
  final Set<String> _children = {};
  bool _busy = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final e = await ref.read(hubRepositoryProvider).event(widget.eventId!);
      final start = DateTime.parse(e['starts_at'] as String).toLocal();
      setState(() {
        _title.text = e['title'] as String? ?? '';
        _location.text = e['location'] as String? ?? '';
        _date = start;
        _time = TimeOfDay.fromDateTime(start);
        _allDay = e['all_day'] as bool? ?? false;
        _weekly = e['recurrence'] == 'weekly';
        _remind = (e['reminder_minutes_before'] as num?)?.toInt();
        _children
          ..clear()
          ..addAll(((e['child_ids'] as List?) ?? const []).whereType<String>());
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    final l = context.l10n;
    setState(() => _busy = true);
    final hh = _allDay ? '00' : _time.hour.toString().padLeft(2, '0');
    final mm = _allDay ? '00' : _time.minute.toString().padLeft(2, '0');
    try {
      await ref.read(hubRepositoryProvider).saveEvent({
        'title': _title.text.trim(),
        'location': _location.text.trim().isEmpty
            ? null
            : _location.text.trim(),
        'starts_at': '${_ymd(_date)} $hh:$mm',
        'all_day': _allDay,
        'recurrence': _weekly ? 'weekly' : 'none',
        'reminder_minutes_before': _remind,
        'child_ids': _children.toList(),
      }, eventId: widget.eventId);
      ref.invalidate(plannerProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showResultSnack(context, l.plannerSaved);
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(l));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final children = ref.watch(childLookupProvider).values.toList();
    if (_loading) return const SizedBox(height: 240, child: LoadingView());
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.eventId == null ? l.plannerNewEvent : l.plannerTitle,
                style: context.type.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _title,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l.plannerEventTitle),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(DateFormat.yMMMd(locale).format(_date)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(
                        _allDay ? l.plannerAllDay : _time.format(context),
                      ),
                      onPressed: _allDay
                          ? null
                          : () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _time,
                              );
                              if (picked != null) {
                                setState(() => _time = picked);
                              }
                            },
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.plannerAllDay),
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.plannerRepeatWeekly),
                value: _weekly,
                onChanged: (v) => setState(() => _weekly = v),
              ),
              TextField(
                controller: _location,
                maxLength: 160,
                decoration: InputDecoration(labelText: l.plannerLocation),
              ),
              Text(l.plannerRemind, style: context.type.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text(l.plannerRemindNone),
                    selected: _remind == null,
                    onSelected: (_) => setState(() => _remind = null),
                  ),
                  for (final m in const [0, 15, 30, 60, 1440])
                    ChoiceChip(
                      label: Text(switch (m) {
                        0 => l.plannerRemindAtStart,
                        60 => l.plannerRemindHour,
                        1440 => l.plannerRemindDay,
                        _ => l.plannerRemindMinutes(m),
                      }),
                      selected: _remind == m,
                      onSelected: (_) => setState(() => _remind = m),
                    ),
                ],
              ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(l.plannerForWho, style: context.type.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilterChip(
                      label: Text(l.plannerEveryone),
                      selected: _children.isEmpty,
                      onSelected: (_) => setState(_children.clear),
                    ),
                    for (final ch in children)
                      FilterChip(
                        avatar: ChildAvatarById(childId: ch.id, size: 24),
                        label: Text(ch.name),
                        selected: _children.contains(ch.id),
                        onSelected: (s) => setState(
                          () => s
                              ? _children.add(ch.id)
                              : _children.remove(ch.id),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _busy || _title.text.trim().isEmpty ? null : _save,
                child: Text(l.commonSave),
              ),
              if (widget.eventId != null)
                TextButton(
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: l.plannerDeleteEvent,
                      confirmLabel: l.plannerDeleteEvent,
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref
                        .read(hubRepositoryProvider)
                        .deleteEvent(widget.eventId!);
                    ref.invalidate(plannerProvider);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(l.plannerDeleteEvent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
