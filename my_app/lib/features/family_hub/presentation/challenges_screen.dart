import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/util/client_id.dart';
import '../../kid/data/kid_models.dart';
import '../application/hub_providers.dart';
import '../data/hub_repository.dart';
import 'hub_widgets.dart';

String challengeStatusLabel(AppLocalizations l, String s) => switch (s) {
  'achieved' => l.challengeStatusAchieved,
  'rewarded' => l.challengeStatusRewarded,
  'ended' => l.challengeStatusEnded,
  'cancelled' => l.challengeStatusCancelled,
  _ => l.challengeStatusActive,
};

AppTone challengeTone(String s) => switch (s) {
  'achieved' || 'rewarded' => AppTone.success,
  'ended' || 'cancelled' => AppTone.neutral,
  _ => AppTone.accent,
};

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(challengesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.challengesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ChallengeFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.challengeNew),
      ),
      body: AppContentFrame(
        maxWidth: 760,
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(challengesProvider),
          ),
          data: (list) => list.isEmpty
              ? EmptyView(emoji: '🤝', message: l.challengesEmpty)
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(challengesProvider),
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
                    itemBuilder: (context, i) =>
                        _ChallengeTile(challenge: list[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({required this.challenge});

  final FamilyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final ch = challenge;
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChallengeDetailScreen(challengeId: ch.id),
        ),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: ch.progress,
            size: 60,
            stroke: 7,
            color: c.accent.foreground,
            semanticsLabel: ch.title,
            center: Text(
              '${(ch.progress * 100).round()}%',
              style: context.type.labelSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ch.title, style: context.type.titleSmall),
                Text(
                  '${ch.progressValue}/${ch.targetValue}${ch.unitLabel == null ? '' : ' ${ch.unitLabel}'}',
                  style: context.type.bodySmall?.copyWith(color: c.ink2),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    for (final p in ch.participants.take(5))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 2),
                        child: ChildAvatar(
                          name: p.name,
                          avatarKey: p.avatarKey,
                          colorHex: p.avatarColor,
                          seed: p.id,
                          size: 24,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          StatusPill(
            label: challengeStatusLabel(l, ch.status),
            tone: challengeTone(ch.status),
          ),
        ],
      ),
    );
  }
}

class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeDetailScreen> createState() =>
      _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  bool _busy = false;
  String? _pendingClientId;

  Future<void> _do(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(challengeProvider(widget.challengeId))
        ..invalidate(challengesProvider)
        ..invalidate(pulseProvider);
      if (done != null && mounted) {
        Celebration.show(context, message: done, emoji: '🏆');
      }
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _log(FamilyChallenge ch) async {
    final l = context.l10n;
    final amount = TextEditingController(text: '10');
    final ok = await confirmAction(
      context,
      title: l.challengeLog,
      confirmLabel: l.commonSave,
      extra: TextField(
        controller: amount,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: ch.unitLabel ?? l.challengeTarget,
        ),
      ),
    );
    final n = int.tryParse(amount.text.trim()) ?? 0;
    amount.dispose();
    if (!ok || n < 1) return;
    _pendingClientId ??= newClientId();
    await _do(() async {
      await ref
          .read(hubRepositoryProvider)
          .contributeChallenge(ch.id, n, clientId: _pendingClientId);
      _pendingClientId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final async = ref.watch(challengeProvider(widget.challengeId));
    return Scaffold(
      appBar: AppBar(),
      body: AppContentFrame(
        maxWidth: 760,
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async =>
                ref.invalidate(challengeProvider(widget.challengeId)),
          ),
          data: (ch) {
            final ends = DateTime.tryParse(ch.endsOn);
            final daysLeft = ends
                ?.difference(DateTime.now())
                .inDays
                .clamp(0, 999);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              children: [
                Center(
                  child: ProgressRing(
                    value: ch.progress,
                    size: 160,
                    stroke: 14,
                    color: ch.status == 'achieved' || ch.status == 'rewarded'
                        ? c.success.foreground
                        : c.accent.foreground,
                    semanticsLabel: ch.title,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${ch.progressValue}',
                          style: context.type.displaySmall,
                        ),
                        Text(
                          '/ ${ch.targetValue}${ch.unitLabel == null ? '' : ' ${ch.unitLabel}'}',
                          style: context.type.bodySmall?.copyWith(
                            color: c.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  ch.title,
                  style: context.type.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if ((ch.description ?? '').isNotEmpty)
                  Text(
                    ch.description!,
                    style: context.type.bodyLarge?.copyWith(color: c.ink2),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusPill(
                      label: challengeStatusLabel(l, ch.status),
                      tone: challengeTone(ch.status),
                    ),
                    if (ends != null && ch.isActive)
                      StatusPill(
                        label: l.challengeDaysLeft(daysLeft!),
                        tone: AppTone.neutral,
                        icon: Icons.schedule_rounded,
                      ),
                    if (ends != null)
                      StatusPill(
                        label:
                            '${l.challengeEnds} ${DateFormat.MMMd(locale).format(ends)}',
                        tone: AppTone.neutral,
                      ),
                    if (ch.rewardPoints > 0)
                      StatusPill(
                        label: l.kidPoints(ch.rewardPoints),
                        tone: AppTone.warning,
                        icon: Icons.star_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: l.challengeWho,
                  subtitle: l.challengeNoRanking,
                ),
                for (final p in ch.participants)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ChildAvatar(
                      name: p.name,
                      avatarKey: p.avatarKey,
                      colorHex: p.avatarColor,
                      seed: p.id,
                      size: 40,
                    ),
                    title: Text(p.name, style: context.type.titleSmall),
                    trailing: ch.contributionsByChild.containsKey(p.id)
                        ? Text(
                            '+${ch.contributionsByChild[p.id]}',
                            style: context.type.labelLarge,
                          )
                        : null,
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (ch.status == 'achieved')
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _do(
                            () => ref
                                .read(hubRepositoryProvider)
                                .awardChallenge(ch.id),
                            done: l.challengeStatusRewarded,
                          ),
                    icon: const Icon(Icons.emoji_events_rounded),
                    label: Text(l.challengeAward),
                  ),
                if (ch.isActive && ch.isManual)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _log(ch),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l.challengeLog),
                  ),
                if (ch.isActive && !ch.isManual)
                  Text(
                    l.kidChallengeCountsAuto,
                    style: context.type.bodySmall?.copyWith(color: c.ink2),
                    textAlign: TextAlign.center,
                  ),
                if (ch.isActive || ch.status == 'achieved')
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final ok = await confirmAction(
                              context,
                              title: l.challengeCancel,
                              confirmLabel: l.challengeCancel,
                              destructive: true,
                            );
                            if (ok) {
                              await _do(
                                () => ref
                                    .read(hubRepositoryProvider)
                                    .cancelChallenge(ch.id),
                              );
                            }
                          },
                    child: Text(l.challengeCancel),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ChallengeFormScreen extends ConsumerStatefulWidget {
  const ChallengeFormScreen({super.key});

  @override
  ConsumerState<ChallengeFormScreen> createState() =>
      _ChallengeFormScreenState();
}

class _ChallengeFormScreenState extends ConsumerState<ChallengeFormScreen> {
  final _title = TextEditingController();
  final _target = TextEditingController(text: '10');
  final _unit = TextEditingController();
  final _reward = TextEditingController(text: '20');
  String _metric = 'manual';
  DateTime _ends = DateTime.now().add(const Duration(days: 6));
  final Set<String> _children = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _children.addAll(ref.read(childLookupProvider).keys);
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _unit.dispose();
    _reward.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final l = context.l10n;
    final target = int.tryParse(_target.text.trim()) ?? 0;
    if (_title.text.trim().length < 2 || target < 1 || _children.isEmpty) {
      setState(() => _error = l.validationRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await ref.read(hubRepositoryProvider).createChallenge({
        'title': _title.text.trim(),
        'metric': _metric,
        'target_value': target,
        'unit_label': _unit.text.trim().isEmpty ? null : _unit.text.trim(),
        'starts_on': _ymd(DateTime.now()),
        'ends_on': _ymd(_ends),
        'reward_points': int.tryParse(_reward.text.trim()) ?? 0,
        'child_ids': _children.toList(),
      });
      ref.invalidate(challengesProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ChallengeDetailScreen(challengeId: created.id),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.localizedMessage(l));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final children = ref.watch(childLookupProvider).values.toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.challengeNew)),
      body: AppContentFrame(
        maxWidth: 640,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            if (_error != null) ...[
              NoticeBanner(tone: AppTone.danger, message: _error!),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _title,
              maxLength: 120,
              decoration: InputDecoration(labelText: l.challengeName),
            ),
            Text(l.challengeMetric, style: context.type.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<String>(
              groupValue: _metric,
              onChanged: (v) => setState(() => _metric = v ?? _metric),
              child: Column(
                children: [
                  for (final (value, label) in [
                    ('manual', l.challengeMetricManual),
                    ('tasks', l.challengeMetricTasks),
                    ('routines', l.challengeMetricRoutines),
                  ])
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: value,
                      title: Text(label),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _target,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l.challengeTarget),
                  ),
                ),
                if (_metric == 'manual') ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      maxLength: 40,
                      decoration: InputDecoration(
                        labelText: l.challengeUnit,
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded),
              label: Text(
                '${l.challengeEnds} ${DateFormat.yMMMd(locale).format(_ends)}',
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _ends,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 120)),
                );
                if (picked != null) setState(() => _ends = picked);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _reward,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.challengeReward),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l.challengeWho, style: context.type.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final ch in children)
                  FilterChip(
                    avatar: ChildAvatarById(childId: ch.id, size: 24),
                    label: Text(ch.name),
                    selected: _children.contains(ch.id),
                    onSelected: (s) => setState(
                      () => s ? _children.add(ch.id) : _children.remove(ch.id),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.challengeNoRanking,
              style: context.type.bodySmall?.copyWith(
                color: context.mamily.ink2,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(l.challengeStart),
            ),
          ],
        ),
      ),
    );
  }
}
