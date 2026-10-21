import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../children/application/children_controller.dart';
import '../application/parent_safety_providers.dart';
import '../data/safety_models.dart';
import '../data/safety_repository.dart';

/// Contacts, pickup plan, emergency number and who receives urgent alerts —
/// everything a child's safety card shows, editable in one place.
class SafetyCentreScreen extends ConsumerWidget {
  const SafetyCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(parentSafetyCentreProvider);
    final children =
        ref.watch(childrenControllerProvider).valueOrNull?.children ?? const [];
    final repo = ref.read(safetyRepositoryProvider);

    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
        ref.invalidate(parentSafetyCentreProvider);
      } on ApiException catch (e) {
        if (context.mounted) showResultSnack(context, e.localizedMessage(l));
      }
    }

    Future<void> editText(
      String title,
      String? current,
      String hint,
      Future<void> Function(String?) save, {
      bool multiline = false,
      TextInputType? keyboard,
    }) async {
      final c = TextEditingController(text: current ?? '');
      final ok = await confirmAction(
        context,
        title: title,
        confirmLabel: l.commonSave,
        extra: TextField(
          controller: c,
          maxLines: multiline ? 4 : 1,
          keyboardType: keyboard,
          decoration: InputDecoration(hintText: hint),
        ),
      );
      final v = c.text.trim();
      c.dispose();
      if (ok) await run(() => save(v.isEmpty ? null : v));
    }

    Future<void> editContact([EmergencyContact? existing]) async {
      final name = TextEditingController(text: existing?.name ?? '');
      final phone = TextEditingController(text: existing?.phone ?? '');
      final relation = TextEditingController(text: existing?.relation ?? '');
      var pickup = existing?.canPickUp ?? false;
      final ok = await confirmAction(
        context,
        title: existing == null ? l.safetyContactAdd : existing.name,
        confirmLabel: l.commonSave,
        extra: StatefulBuilder(
          builder: (context, set) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l.safetyContactName),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l.safetyContactPhone),
              ),
              TextField(
                controller: relation,
                decoration: InputDecoration(labelText: l.safetyContactRelation),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: pickup,
                title: Text(l.safetyContactPickup),
                onChanged: (v) => set(() => pickup = v),
              ),
            ],
          ),
        ),
      );
      final body = {
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'relation': relation.text.trim().isEmpty ? null : relation.text.trim(),
        'can_pick_up': pickup,
      };
      for (final c in [name, phone, relation]) {
        c.dispose();
      }
      if (ok &&
          (body['name'] as String).isNotEmpty &&
          (body['phone'] as String).isNotEmpty) {
        await run(() => repo.saveContact(body, id: existing?.id));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.safetyCentreTitle)),
      body: AppContentFrame(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(parentSafetyCentreProvider),
          ),
          data: (fresh) {
            final s = fresh.value;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                NoticeBanner(
                  tone: AppTone.info,
                  icon: Icons.badge_rounded,
                  message: l.safetyChildSees,
                ),
                SectionHeader(
                  title: l.safetyContacts,
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.md,
                  ),
                ),
                for (final c in s.contacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppListTile(
                      leading: const IconBadge(icon: Icons.person_rounded),
                      title: c.name,
                      subtitle: [
                        c.phone,
                        ?c.relation,
                        if (c.canPickUp) l.safetyContactPickup,
                      ].join(' · '),
                      onTap: () => editContact(c),
                      trailing: IconButton(
                        tooltip: l.commonDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => run(() => repo.deleteContact(c.id)),
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: editContact,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.safetyContactAdd),
                ),
                SectionHeader(
                  title: l.safetyPickup,
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.md,
                  ),
                ),
                AppListTile(
                  leading: const IconBadge(icon: Icons.directions_car_rounded),
                  title: (s.pickupInstructions ?? '').isEmpty
                      ? l.safetyPickupHint
                      : s.pickupInstructions!,
                  titleMaxLines: 6,
                  onTap: () => editText(
                    l.safetyPickup,
                    s.pickupInstructions,
                    l.safetyPickupHint,
                    (v) => repo.updateCentre(
                      pickup: v,
                      emergencyNumber: s.emergencyNumber,
                    ),
                    multiline: true,
                  ),
                ),
                SectionHeader(
                  title: l.safetyEmergencyNumber,
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.md,
                  ),
                ),
                AppListTile(
                  leading: const IconBadge(
                    icon: Icons.emergency_rounded,
                    tone: AppTone.danger,
                  ),
                  title: (s.emergencyNumber ?? '').isEmpty
                      ? l.safetyEmergencyHint
                      : s.emergencyNumber!,
                  onTap: () => editText(
                    l.safetyEmergencyNumber,
                    s.emergencyNumber,
                    l.safetyEmergencyHint,
                    (v) => repo.updateCentre(
                      pickup: s.pickupInstructions,
                      emergencyNumber: v,
                    ),
                    keyboard: TextInputType.phone,
                  ),
                ),
                SectionHeader(
                  title: l.safetyWhoGetsAlerts,
                  subtitle: l.safetyWhoGetsAlertsBody,
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.md,
                  ),
                ),
                for (final m in s.caregivers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: m.receivesUrgentAlerts,
                            title: Text(m.name),
                            subtitle:
                                m.role == 'caregiver' &&
                                    !m.permissions.contains('manage_safety')
                                ? Text(l.safetyCaregiverNeedsPermission)
                                : null,
                            onChanged: (v) => run(
                              () => repo.updateMemberAccess(
                                m.memberId,
                                urgent: v,
                              ),
                            ),
                          ),
                          if (m.role == 'caregiver')
                            AppListTile(
                              leading: const IconBadge(
                                icon: Icons.child_care_rounded,
                              ),
                              title: l.safetyEditAccess,
                              subtitle: m.childScope == 'all'
                                  ? l.safetyChildrenAll
                                  : l.safetyChildrenSome(
                                      children
                                          .where(
                                            (c) => m.childIds.contains(c.id),
                                          )
                                          .map((c) => c.name)
                                          .join(', '),
                                    ),
                              onTap: () async {
                                final selected = m.childScope == 'all'
                                    ? {for (final c in children) c.id}
                                    : m.childIds.toSet();
                                final ok = await confirmAction(
                                  context,
                                  title: l.safetyEditAccess,
                                  confirmLabel: l.commonSave,
                                  extra: StatefulBuilder(
                                    builder: (context, set) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final c in children)
                                          CheckboxListTile(
                                            value: selected.contains(c.id),
                                            title: Text(c.name),
                                            onChanged: (v) => set(
                                              () => v == true
                                                  ? selected.add(c.id)
                                                  : selected.remove(c.id),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                                if (!ok) return;
                                final all = selected.length == children.length;
                                await run(
                                  () => repo.updateMemberAccess(
                                    m.memberId,
                                    childScope: all ? 'all' : 'selected',
                                    childIds: all
                                        ? const []
                                        : selected.toList(),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
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
