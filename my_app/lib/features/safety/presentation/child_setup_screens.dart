import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../device_rules/data/device_rules_repository.dart';
import '../../device_rules/presentation/device_rules_screen.dart';
import '../application/kid_safety_providers.dart' show lessonKeys;
import '../application/parent_safety_providers.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';
import 'family_map_screen.dart';
import 'safe_places_screen.dart';
import 'safety_centre_screen.dart';

enum _Step { done, todo, impossible }

/// Real completion status for one child's phone, built from what the server
/// and the phone actually reported — not from what the parent tapped.
class ChildSetupScreen extends ConsumerWidget {
  const ChildSetupScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.onPair,
  });

  final String childId;
  final String childName;
  final VoidCallback? onPair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rules = ref.watch(deviceRulesProvider(childId));
    final map = ref.watch(familyMapProvider);
    final centre = ref.watch(parentSafetyCentreProvider);
    final places = ref.watch(safePlacesProvider);
    void open(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

    if (rules.isLoading || map.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.setupTitle)),
        body: const LoadingView(),
      );
    }
    final r = rules.valueOrNull;
    final snap = map.valueOrNull?.value.children
        .where((c) => c.childId == childId)
        .firstOrNull;
    final devices = r?.devices ?? const [];
    final linked = devices.isNotEmpty;
    String best(String key) {
      const rank = [
        'available',
        'permission_needed',
        'setup_needed',
        'unknown',
        'unsupported',
      ];
      final vals = devices.map((d) => d.capability(key)).toList();
      if (vals.isEmpty) return 'unknown';
      vals.sort((a, b) => rank.indexOf(a).compareTo(rank.indexOf(b)));
      return vals.first;
    }

    _Step cap(String key) => switch (best(key)) {
      'available' => _Step.done,
      'unsupported' || 'setup_needed' => _Step.impossible,
      _ => _Step.todo,
    };
    final android = devices.any((d) => d.platform == 'android');
    final perm = snap?.locationPermission;

    final items =
        <({String title, _Step step, String? how, VoidCallback? action})>[
          (
            title: l.setupLinked,
            step: linked ? _Step.done : _Step.todo,
            how: linked ? null : l.setupLinkedHow,
            action: linked ? null : onPair,
          ),
          (
            title: l.setupLocationSharing,
            step: (snap?.sharingEnabled ?? false) ? _Step.done : _Step.todo,
            how: null,
            action: () => open(FamilyMapScreen(focusChildId: childId)),
          ),
          (
            title: l.setupLocationPermission,
            step: perm == 'always' || perm == 'while_in_use'
                ? _Step.done
                : _Step.todo,
            how: l.setupLocationPermissionHow,
            action: null,
          ),
          (
            title: l.setupRulesEnforce,
            step: linked ? cap('app_blocking') : _Step.todo,
            how: devices.any((d) => d.platform == 'ios')
                ? l.capSetupHelpIos
                : (android ? l.capSetupHelpAndroid : null),
            action: () =>
                open(DeviceRulesScreen(childId: childId, childName: childName)),
          ),
          (
            title: l.setupUsage,
            step: linked ? cap('usage_reporting') : _Step.todo,
            how: android ? l.setupUsageHowAndroid : l.capSetupHelpIos,
            action: null,
          ),
          (
            title: l.setupRulesConfirmed,
            step:
                devices.any(
                  (d) => d.state == 'active' || d.state == 'partially_active',
                )
                ? _Step.done
                : _Step.todo,
            how: null,
            action: () =>
                open(DeviceRulesScreen(childId: childId, childName: childName)),
          ),
          (
            title: l.setupContacts,
            step: (centre.valueOrNull?.value.contacts.isNotEmpty ?? false)
                ? _Step.done
                : _Step.todo,
            how: null,
            action: () => open(const SafetyCentreScreen()),
          ),
          (
            title: l.setupPlaces,
            step: (places.valueOrNull?.isNotEmpty ?? false)
                ? _Step.done
                : _Step.todo,
            how: null,
            action: () => open(const SafePlacesScreen()),
          ),
        ];

    return Scaffold(
      appBar: AppBar(title: Text(l.setupTitle)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: () async => ref
            ..invalidate(deviceRulesProvider(childId))
            ..invalidate(familyMapProvider)
            ..invalidate(parentSafetyCentreProvider)
            ..invalidate(safePlacesProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l.setupIntro(childName), style: context.type.bodyLarge),
              const SizedBox(height: AppSpacing.lg),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    onTap: i.action,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBadge(
                          icon: switch (i.step) {
                            _Step.done => Icons.check_circle_rounded,
                            _Step.todo => Icons.radio_button_unchecked_rounded,
                            _Step.impossible =>
                              Icons.remove_circle_outline_rounded,
                          },
                          tone: switch (i.step) {
                            _Step.done => AppTone.success,
                            _Step.todo => AppTone.warning,
                            _Step.impossible => AppTone.neutral,
                          },
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.title, style: context.type.titleSmall),
                              Text(switch (i.step) {
                                _Step.done => l.setupDone,
                                _Step.todo => l.setupTodo,
                                _Step.impossible => l.setupNotPossible,
                              }, style: context.type.labelMedium),
                              if (i.step != _Step.done && i.how != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(i.how!, style: context.type.bodySmall),
                              ],
                            ],
                          ),
                        ),
                        if (i.action != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context.mamily.ink3,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parent: family agreements for one child, and safety-lesson progress.
class ChildAgreementsScreen extends ConsumerWidget {
  const ChildAgreementsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(childAgreementsProvider(childId));
    Future<void> edit([Agreement? a]) async {
      final saved = await showAgreementEditor(
        context,
        ref,
        childId: childId,
        existing: a,
      );
      if (saved) ref.invalidate(childAgreementsProvider(childId));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.agreementsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: edit,
        icon: const Icon(Icons.add_rounded),
        label: Text(l.agreementNew),
      ),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async =>
                ref.invalidate(childAgreementsProvider(childId)),
          ),
          data: (d) {
            final done = d.lessons.where((x) => x.done).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                96,
              ),
              children: [
                Text(
                  l.agreementsIntro(childName),
                  style: context.type.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final a in d.agreements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppListTile(
                      leading: const IconBadge(icon: Icons.handshake_rounded),
                      title: a.title,
                      subtitle: a.items
                          .map((i) => '• ${i.text}')
                          .take(3)
                          .join('\n'),
                      subtitleMaxLines: 3,
                      trailing: StatusPill(
                        label: a.childAgreedCurrent
                            ? l.agreementChildAgreed(childName)
                            : l.agreementWaiting(childName),
                        tone: a.childAgreedCurrent
                            ? AppTone.success
                            : AppTone.info,
                      ),
                      onTap: () => edit(a),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Row(
                    children: [
                      const IconBadge(
                        icon: Icons.shield_rounded,
                        tone: AppTone.info,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          l.lessonsProgress(done, lessonKeys.length),
                          style: context.type.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<bool> showAgreementEditor(
  BuildContext context,
  WidgetRef ref, {
  required String childId,
  Agreement? existing,
}) async {
  final l = context.l10n;
  final title = TextEditingController(text: existing?.title ?? '');
  final rows = [
    for (final i
        in existing?.items ?? const <({String section, String text})>[])
      (section: i.section, text: TextEditingController(text: i.text)),
  ];
  if (rows.isEmpty) {
    rows.add((section: 'devices', text: TextEditingController()));
  }

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, set) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
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
                TextField(
                  controller: title,
                  maxLength: 120,
                  decoration: InputDecoration(labelText: l.agreementTitle),
                ),
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          children: [
                            for (final (k, label) in [
                              ('devices', l.agreementSectionDevices),
                              (
                                'responsibilities',
                                l.agreementSectionResponsibilities,
                              ),
                              ('rewards', l.agreementSectionRewards),
                            ])
                              ChoiceChip(
                                label: Text(label),
                                selected: rows[i].section == k,
                                onSelected: (_) => set(
                                  () => rows[i] = (
                                    section: k,
                                    text: rows[i].text,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        TextField(
                          controller: rows[i].text,
                          maxLength: 200,
                          maxLines: 2,
                          minLines: 1,
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => set(
                    () => rows.add((
                      section: rows.last.section,
                      text: TextEditingController(),
                    )),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.agreementAddItem),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () async {
                    final items = [
                      for (final r in rows)
                        if (r.text.text.trim().isNotEmpty)
                          (section: r.section, text: r.text.text.trim()),
                    ];
                    if (title.text.trim().isEmpty || items.isEmpty) return;
                    try {
                      await ref
                          .read(safetyRepositoryProvider)
                          .saveAgreement(
                            childId,
                            title.text.trim(),
                            items,
                            id: existing?.id,
                          );
                      if (sheet.mounted) Navigator.of(sheet).pop(true);
                    } on ApiException catch (e) {
                      if (sheet.mounted) {
                        showResultSnack(sheet, e.localizedMessage(l));
                      }
                    }
                  },
                  child: Text(l.commonSave),
                ),
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(safetyRepositoryProvider)
                            .deleteAgreement(childId, existing.id);
                        if (sheet.mounted) Navigator.of(sheet).pop(true);
                      } catch (_) {}
                    },
                    child: Text(l.commonDelete),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  title.dispose();
  for (final r in rows) {
    r.text.dispose();
  }
  return saved ?? false;
}
