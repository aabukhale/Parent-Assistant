import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/util/client_id.dart';
import '../../kid/presentation/kid_feedback.dart';
import '../../kid/presentation/kid_widgets.dart';
import '../application/kid_safety_providers.dart';
import '../application/location_reporter.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';
import 'kid_help_screen.dart';

String _hhmm(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Shown on Today while a journey is running: where to, by when, and the
/// three things the child may want to do next.
class JourneyBanner extends ConsumerWidget {
  const JourneyBanner({super.key, required this.journey});

  final Journey journey;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() f,
  ) async {
    try {
      await f();
      ref.invalidate(kidJourneyProvider);
    } catch (e) {
      if (context.mounted) showKidError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final repo = ref.read(kidSafetyRepositoryProvider);
    final tone = journey.isOverdue ? c.warning : c.info;
    return KidCard(
      color: tone.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_walk_rounded,
                size: 36,
                color: tone.foreground,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.kidJourneyOnWay(journey.destinationName),
                      style: context.type.titleMedium,
                    ),
                    Text(
                      journey.isOverdue
                          ? l.kidJourneyOverdue
                          : l.kidJourneyExpected(
                              _hhmm(context, journey.expectedAt),
                            ),
                      style: context.type.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            icon: const Icon(Icons.where_to_vote_rounded),
            label: Text(l.kidCheckArrived),
            onPressed: () => _act(context, ref, () async {
              await repo.finishJourney(journey.id, arrived: true);
              ref.read(locationReporterProvider).stopJourneyTracking();
              if (context.mounted) showResultSnack(context, l.kidCheckSent);
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _act(
                    context,
                    ref,
                    () => repo.extendJourney(journey.id, 15),
                  ),
                  child: Text(
                    l.kidJourneyMoreTime,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextButton(
                  onPressed: () => _act(context, ref, () async {
                    await repo.finishJourney(journey.id, arrived: false);
                    ref.read(locationReporterProvider).stopJourneyTracking();
                  }),
                  child: Text(l.kidJourneyCancel, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "I'm going somewhere": pick a safe place (or name one) and a time.
Future<void> showStartJourneySheet(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(kidSafetyRepositoryProvider);
  List<SafePlace> places = const [];
  try {
    places = await repo.safePlaces();
  } catch (_) {}
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _JourneySheet(places: places),
  );
  ref.invalidate(kidJourneyProvider);
}

class _JourneySheet extends ConsumerStatefulWidget {
  const _JourneySheet({required this.places});

  final List<SafePlace> places;

  @override
  ConsumerState<_JourneySheet> createState() => _JourneySheetState();
}

class _JourneySheetState extends ConsumerState<_JourneySheet> {
  String? _placeId;
  bool _other = false;
  final _name = TextEditingController();
  int _minutes = 20;
  bool _busy = false;
  final _clientId = newClientId();

  @override
  void initState() {
    super.initState();
    if (widget.places.isEmpty) _other = true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready =>
      (_placeId != null || (_other && _name.text.trim().isNotEmpty));

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(kidSafetyRepositoryProvider)
          .startJourney(
            safePlaceId: _other ? null : _placeId,
            destinationName: _other ? _name.text.trim() : null,
            expectedAt: DateTime.now().add(Duration(minutes: _minutes)),
            clientId: _clientId,
          );
      ref.read(locationReporterProvider)
        ..reportNow(source: 'journey')
        ..startJourneyTracking();
      if (mounted) {
        final l = context.l10n;
        Navigator.of(context).pop();
        showResultSnack(context, l.kidJourneyShared);
      }
    } catch (e) {
      if (mounted) showKidError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
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
              Text(l.kidJourneyWhere, style: context.type.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final p in widget.places)
                    ChoiceChip(
                      avatar: Icon(placeIcon(p.kind), size: 18),
                      label: Text(p.name),
                      selected: !_other && _placeId == p.id,
                      onSelected: (_) => setState(() {
                        _placeId = p.id;
                        _other = false;
                      }),
                    ),
                  ChoiceChip(
                    avatar: const Icon(
                      Icons.edit_location_alt_rounded,
                      size: 18,
                    ),
                    label: Text(l.kidJourneyOther),
                    selected: _other,
                    onSelected: (_) => setState(() => _other = true),
                  ),
                ],
              ),
              if (_other) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _name,
                  maxLength: 80,
                  decoration: InputDecoration(labelText: l.kidJourneyName),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(l.kidJourneyWhen, style: context.type.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final m in const [10, 20, 30, 45, 60, 90])
                    ChoiceChip(
                      label: Text(l.kidJourneyInMinutes(m)),
                      selected: _minutes == m,
                      onSelected: (_) => setState(() => _minutes = m),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l.kidJourneyShared,
                style: context.type.bodyMedium?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _ready && !_busy ? _start : null,
                icon: const Icon(Icons.directions_walk_rounded),
                label: Text(l.kidJourneyGo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData placeIcon(String kind) => switch (kind) {
  'home' => Icons.home_rounded,
  'school' => Icons.school_rounded,
  _ => Icons.place_rounded,
};

/// Shown once after a parent turns location sharing on: the child is told
/// plainly, then the OS permission prompt follows.
Future<void> showLocationExplainSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final l = context.l10n;
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 56,
              color: sheet.mamily.info.foreground,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l.kidLocationTitle,
              style: sheet.type.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.kidLocationBody,
              style: sheet.type.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(sheet).pop(),
              child: Text(l.kidLocationOk),
            ),
          ],
        ),
      ),
    ),
  );
  try {
    await ref.read(kidSafetyRepositoryProvider).markInformed();
  } catch (_) {}
  await LocationReporter.requestPermission();
  ref.invalidate(kidLocationSettingsProvider);
  await ref.read(locationReporterProvider).refresh();
}

/// The child's safety card: grown-ups to call, pickup plan, local emergency
/// number. Served from cache when offline.
class KidSafetyCardScreen extends ConsumerWidget {
  const KidSafetyCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final async = ref.watch(kidSafetyCentreProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.kidSafetyCard)),
      body: AppContentFrame(
        maxWidth: 640,
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(kidSafetyCentreProvider),
          ),
          data: (fresh) {
            final s = fresh.value;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (fresh.fromCache)
                  FreshnessLine(fetchedAt: fresh.fetchedAt, fromCache: true),
                KidSectionTitle(l.kidTrustedAdults),
                if (s.people.isEmpty && s.contacts.isEmpty)
                  Text(
                    l.kidNoPhone,
                    style: context.type.bodyLarge?.copyWith(color: c.ink2),
                  ),
                for (final p in s.people)
                  _PersonRow(name: p.name, phone: p.phone),
                for (final ct in s.contacts)
                  _PersonRow(
                    name: ct.name,
                    phone: ct.phone,
                    subtitle: ct.relation,
                  ),
                if ((s.pickupInstructions ?? '').isNotEmpty) ...[
                  KidSectionTitle(l.kidPickup),
                  KidCard(
                    child: Text(
                      s.pickupInstructions!,
                      style: context.type.bodyLarge,
                    ),
                  ),
                ],
                if ((s.emergencyNumber ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.danger.foreground,
                      side: BorderSide(color: c.danger.border),
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: () => callNumber(s.emergencyNumber!),
                    icon: const Icon(Icons.emergency_rounded),
                    label: Text(l.kidEmergencyCall(s.emergencyNumber!)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l.kidEmergencyNote,
                    textAlign: TextAlign.center,
                    style: context.type.bodySmall?.copyWith(color: c.ink2),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.name, this.phone, this.subtitle});

  final String name;
  final String? phone;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: KidCard(
        child: Row(
          children: [
            const IconTile(icon: Icons.person_rounded, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.type.titleSmall),
                  if (subtitle != null)
                    Text(subtitle!, style: context.type.bodySmall),
                ],
              ),
            ),
            if (phone != null)
              IconButton.filled(
                tooltip: l.kidCallPerson(name),
                onPressed: () => callNumber(phone!),
                icon: const Icon(Icons.call_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class KidAgreementsScreen extends ConsumerWidget {
  const KidAgreementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final async = ref.watch(kidAgreementsProvider);
    String section(String s) => switch (s) {
      'devices' => l.agreementSectionDevices,
      'rewards' => l.agreementSectionRewards,
      _ => l.agreementSectionResponsibilities,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.kidAgreements)),
      body: AppContentFrame(
        maxWidth: 640,
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(kidAgreementsProvider),
          ),
          data: (list) => list.isEmpty
              ? EmptyView(
                  icon: Icons.handshake_rounded,
                  message: l.kidAgreementsEmpty,
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final a in list) ...[
                      KidCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(a.title, style: context.type.titleLarge),
                            for (final s in const [
                              'devices',
                              'responsibilities',
                              'rewards',
                            ])
                              if (a.items.any((i) => i.section == s)) ...[
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  section(s),
                                  style: context.type.labelLarge?.copyWith(
                                    color: c.brand.foreground,
                                  ),
                                ),
                                for (final i in a.items.where(
                                  (i) => i.section == s,
                                ))
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.xs,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.check_rounded,
                                          size: 20,
                                          color: c.ink2,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Text(
                                            i.text,
                                            style: context.type.bodyLarge,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            const SizedBox(height: AppSpacing.lg),
                            if (a.childAgreedCurrent)
                              StatusPill(
                                label: l.kidAgreed,
                                tone: AppTone.success,
                                icon: Icons.check_circle_rounded,
                              )
                            else ...[
                              if (a.childAgreedAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: Text(
                                    l.kidAgreementChanged,
                                    style: context.type.bodyMedium,
                                  ),
                                ),
                              FilledButton.icon(
                                icon: const Icon(Icons.handshake_rounded),
                                label: Text(l.kidAgree),
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(kidSafetyRepositoryProvider)
                                        .agree(a.id);
                                    ref.invalidate(kidAgreementsProvider);
                                  } catch (e) {
                                    if (context.mounted) {
                                      showKidError(context, e);
                                    }
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

({String title, List<String> pages, IconData icon}) lessonContent(
  AppLocalizations l,
  String key,
) => switch (key) {
  'scams' => (
    title: l.lessonScamsTitle,
    pages: [l.lessonScams1, l.lessonScams2, l.lessonScams3],
    icon: Icons.card_giftcard_rounded,
  ),
  'bullying' => (
    title: l.lessonBullyingTitle,
    pages: [l.lessonBullying1, l.lessonBullying2, l.lessonBullying3],
    icon: Icons.shield_rounded,
  ),
  'passwords' => (
    title: l.lessonPasswordsTitle,
    pages: [l.lessonPasswords1, l.lessonPasswords2, l.lessonPasswords3],
    icon: Icons.password_rounded,
  ),
  'photo_sharing' => (
    title: l.lessonPhotosTitle,
    pages: [l.lessonPhotos1, l.lessonPhotos2, l.lessonPhotos3],
    icon: Icons.photo_camera_rounded,
  ),
  _ => (
    title: l.lessonStrangersTitle,
    pages: [l.lessonStrangers1, l.lessonStrangers2, l.lessonStrangers3],
    icon: Icons.person_search_rounded,
  ),
};

class KidLessonsScreen extends ConsumerWidget {
  const KidLessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final done = {
      for (final p
          in ref.watch(kidLessonsProvider).valueOrNull ??
              const <LessonProgress>[])
        if (p.done) p.key,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.kidLessons)),
      body: AppContentFrame(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            for (final key in lessonKeys) ...[
              Builder(
                builder: (context) {
                  final content = lessonContent(l, key);
                  return KidCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _LessonPlayer(lessonKey: key),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconTile(icon: content.icon, size: 52),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            content.title,
                            style: context.type.titleMedium,
                          ),
                        ),
                        if (done.contains(key))
                          StatusPill(
                            label: l.kidLessonDoneBadge,
                            tone: AppTone.success,
                            icon: Icons.check_rounded,
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonPlayer extends ConsumerStatefulWidget {
  const _LessonPlayer({required this.lessonKey});

  final String lessonKey;

  @override
  ConsumerState<_LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends ConsumerState<_LessonPlayer> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final content = lessonContent(l, widget.lessonKey);
    final last = _page == content.pages.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(content.title)),
      body: SafeArea(
        child: AppContentFrame(
          maxWidth: 640,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProgressBar(
                  value: (_page + 1) / content.pages.length,
                  semanticsLabel: content.title,
                ),
                const Spacer(),
                Icon(
                  content.icon,
                  size: 72,
                  color: context.mamily.brand.foreground,
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    content.pages[_page],
                    style: context.type.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    if (!last) {
                      setState(() => _page++);
                      return;
                    }
                    try {
                      await ref
                          .read(kidSafetyRepositoryProvider)
                          .completeLesson(widget.lessonKey);
                      ref.invalidate(kidLessonsProvider);
                    } catch (_) {}
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(last ? l.kidLessonFinish : l.kidLessonNext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
