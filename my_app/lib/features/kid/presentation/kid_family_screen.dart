import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../../device_rules/application/device_rules_sync.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/presentation/inbox_screen.dart';
import '../../remote/presentation/kid_remote_layer.dart';
import '../../safety/application/kid_safety_providers.dart';
import '../../safety/data/safety_models.dart';
import '../../safety/presentation/kid_help_screen.dart';
import '../../safety/presentation/kid_safety_widgets.dart';
import '../application/kid_providers.dart';
import 'kid_feedback.dart';
import 'kid_requests_screen.dart';
import 'kid_widgets.dart';
import 'mood_sheet.dart';
import 'together_screen.dart';

/// "Family": talk to my family, tell them where I am, how I feel, and
/// everything we agreed — each behind one clearly labelled card.
class KidFamilyScreen extends ConsumerWidget {
  const KidFamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final sharing =
        ref.watch(kidLocationSettingsProvider).valueOrNull?.sharing ?? false;
    final journey = ref.watch(kidJourneyProvider).valueOrNull;
    final newMessages =
        (ref.watch(kidEncouragementsProvider).valueOrNull?.value ?? const [])
            .where((e) => e.seenAt == null)
            .length;

    void open(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

    Future<void> refresh() async {
      ref
        ..invalidate(kidSafetyCentreProvider)
        ..invalidate(kidLocationSettingsProvider)
        ..invalidate(kidJourneyProvider)
        ..invalidate(kidEncouragementsProvider)
        ..invalidate(kidChallengesProvider)
        ..invalidate(unreadCountProvider);
    }

    return SafeArea(
      bottom: false,
      child: AppContentFrame(
        maxWidth: 720,
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              Semantics(
                header: true,
                child: Text(l.kidTabFamily, style: context.type.headlineSmall),
              ),
              if (sharing) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusPill(
                    label: l.kidLocationOnBadge,
                    tone: AppTone.info,
                    icon: Icons.location_on_rounded,
                  ),
                ),
              ],
              KidSectionTitle(l.kidFamilyTalk),
              _TalkButtons(),
              if (journey == null || !journey.isLive) ...[
                const SizedBox(height: AppSpacing.md),
                _BigAction(
                  icon: Icons.directions_walk_rounded,
                  label: l.kidJourneyStart,
                  tone: c.info,
                  onTap: () => showStartJourneySheet(context, ref),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                JourneyBanner(journey: journey),
              ],
              KidSectionTitle(l.kidQuickTitle),
              const QuickCheckins(),
              KidSectionTitle(l.kidHowFeel),
              _BigAction(
                icon: Icons.emoji_emotions_rounded,
                label: l.kidFeelShare,
                tone: c.accent,
                onTap: () => showMoodSheet(context),
              ),
              KidSectionTitle(l.kidMyThings),
              _DestinationGrid(
                items: [
                  _Dest(
                    Icons.mail_rounded,
                    l.kidMessages,
                    badge: newMessages,
                    onTap: () => open(
                      Scaffold(
                        appBar: AppBar(title: Text(l.kidMessages)),
                        body: const TogetherScreen(),
                      ),
                    ),
                  ),
                  _Dest(
                    Icons.handshake_rounded,
                    l.kidAgreements,
                    onTap: () => open(const KidAgreementsScreen()),
                  ),
                  _Dest(
                    Icons.shield_rounded,
                    l.kidLessons,
                    onTap: () => open(const KidLessonsScreen()),
                  ),
                  _Dest(
                    Icons.badge_rounded,
                    l.kidSafetyCard,
                    onTap: () => open(const KidSafetyCardScreen()),
                  ),
                  _Dest(
                    Icons.inbox_rounded,
                    l.kidMyRequests,
                    onTap: () => open(const KidRequestsScreen()),
                  ),
                  _Dest(
                    Icons.notifications_rounded,
                    l.kidNotifications,
                    badge: unread,
                    onTap: () => open(const NotificationInboxScreen()),
                  ),
                ],
              ),
              KidSectionTitle(l.kidGrownUps),
              const _GrownUps(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TalkButtons extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final people =
        ref.watch(kidSafetyCentreProvider).valueOrNull?.value.people ??
        const <TrustedPerson>[];

    Future<TrustedPerson?> choose({bool needPhone = false}) async {
      final list = needPhone
          ? people.where((p) => p.phone != null).toList()
          : people;
      if (list.isEmpty) {
        showResultSnack(context, l.kidNoPhone);
        return null;
      }
      if (list.length == 1) return list.first;
      return showModalBottomSheet<TrustedPerson>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final p in list)
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: Text(p.name),
                  onTap: () => Navigator.of(sheet).pop(p),
                ),
            ],
          ),
        ),
      );
    }

    Future<void> ask(String kind) async {
      final p = await choose();
      if (p == null) return;
      try {
        await ref.read(kidRemoteProvider.notifier).ask(kind, p.id);
      } catch (e) {
        if (context.mounted) showKidError(context, e);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BigAction(
          icon: Icons.call_rounded,
          label: l.kidCallMyParent,
          tone: c.success,
          onTap: () async {
            final p = await choose(needPhone: true);
            if (p?.phone != null) await callNumber(p!.phone!);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _BigAction(
                icon: Icons.videocam_rounded,
                label: l.kidVideoCall,
                tone: c.brand,
                compact: true,
                onTap: () => ask('video_call'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _BigAction(
                icon: Icons.support_agent_rounded,
                label: l.kidAskHelpInApp,
                tone: c.brand,
                compact: true,
                onTap: () => ask('in_app_help'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final ToneColors tone;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => KidCard(
    color: tone.background,
    onTap: onTap,
    semanticLabel: label,
    padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
    child: compact
        ? Column(
            children: [
              Icon(icon, size: 32, color: tone.foreground),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.type.titleSmall,
              ),
            ],
          )
        : Row(
            children: [
              Icon(icon, size: 32, color: tone.foreground),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: context.type.titleMedium)),
              Icon(Icons.chevron_right_rounded, color: context.mamily.ink3),
            ],
          ),
  );
}

class _Dest {
  const _Dest(this.icon, this.label, {required this.onTap, this.badge = 0});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
}

class _DestinationGrid extends StatelessWidget {
  const _DestinationGrid({required this.items});

  final List<_Dest> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final cols = large ? 1 : (box.maxWidth >= 560 ? 3 : 2);
      final w = (box.maxWidth - AppSpacing.sm * (cols - 1)) / cols;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final d in items)
            SizedBox(
              width: w,
              child: KidCard(
                onTap: d.onTap,
                semanticLabel: d.badge > 0 ? '${d.label}, ${d.badge}' : d.label,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Badge(
                      isLabelVisible: d.badge > 0,
                      label: Text('${d.badge}'),
                      child: IconTile(icon: d.icon, size: 44),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(d.label, style: context.type.titleSmall),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _GrownUps extends ConsumerWidget {
  const _GrownUps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final locked =
        ref.watch(deviceEnforcementActiveProvider).valueOrNull ?? false;
    final caps = ref.watch(deviceCapabilitiesProvider).valueOrNull ?? const {};
    final native = ref.read(nativeEnforcementProvider);
    final setupSteps = <(String, String)>[
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          caps['app_blocking'] == 'permission_needed')
        (l.kidSetupScreenTime, 'family_controls'),
      if (defaultTargetPlatform == TargetPlatform.android &&
          caps['usage_reporting'] == 'permission_needed')
        (l.kidSetupUsage, 'usage_access'),
      if (defaultTargetPlatform == TargetPlatform.android &&
          caps['app_blocking'] == 'available' &&
          caps['exact_alarms'] == 'permission_needed')
        (l.kidSetupAlarms, 'exact_alarms'),
    ];
    final celebrate = ref.watch(celebrationsEnabledProvider);
    return KidCard(
      color: c.surfaceMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (setupSteps.isNotEmpty) ...[
            Text(l.kidSetupTitle, style: context.type.titleSmall),
            Text(
              l.kidSetupBody,
              style: context.type.bodySmall?.copyWith(color: c.ink2),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (label, what) in setupSteps)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings_rounded),
                  label: Text(label),
                  onPressed: () async {
                    await native.openSetup(what);
                    ref.invalidate(deviceCapabilitiesProvider);
                    ref.read(deviceRulesSyncProvider).sync();
                  },
                ),
              ),
            const Divider(),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: celebrate,
            title: Text(l.kidCelebrations),
            subtitle: Text(l.kidCelebrationsBody),
            onChanged: (v) =>
                ref.read(celebrationsEnabledProvider.notifier).set(v),
          ),
          const Divider(),
          Text(
            l.kidGrownUpsBody,
            style: context.type.bodyMedium?.copyWith(color: c.ink2),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.lock_person_rounded),
            label: Text(l.kidParentSignIn),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (locked)
            // Rules applied by the phone itself must not disappear because a
            // child signed out: a grown-up removes the phone instead.
            Text(
              l.kidSignOutLocked,
              style: context.type.bodySmall?.copyWith(color: c.ink2),
            )
          else
            TextButton(
              onPressed: () async {
                final ok = await confirmAction(
                  context,
                  title: l.kidSignOutDevice,
                  body: l.kidSignOutConfirm,
                  confirmLabel: l.commonSignOut,
                  destructive: true,
                );
                if (ok) {
                  await ref.read(authControllerProvider.notifier).logout();
                }
              },
              child: Text(l.kidSignOutDevice),
            ),
        ],
      ),
    );
  }
}
