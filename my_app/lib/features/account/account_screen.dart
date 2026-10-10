import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../core/localization/app_locales.dart';
import '../../core/localization/l10n.dart';
import '../../core/localization/locale_controller.dart';
import '../auth/application/auth_controller.dart';
import '../auth/data/auth_requests.dart';
import '../auth/data/models/family_membership.dart';
import '../devices/presentation/devices_screen.dart';
import '../family/presentation/family_selection_screen.dart';
import '../family_hub/presentation/hub_widgets.dart';
import '../notifications/presentation/inbox_screen.dart';
import '../profile/edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'surfaces_settings_screen.dart';

/// Account: who I am, how Mamily reaches me, this device, and signing out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final auth = ref.watch(authControllerProvider);
    final user = auth.session?.user;
    final membership = auth.activeMembership;
    final locale = ref.watch(localeControllerProvider);
    void open(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

    return SafeArea(
      child: AppContentFrame(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            PageTitle(title: l.accountTitle),
            AppCard(
              onTap: () => open(const EditProfileScreen()),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: c.brand.background,
                    child: Text(
                      (user?.firstName.isNotEmpty ?? false)
                          ? user!.firstName.characters.first.toUpperCase()
                          : '?',
                      style: context.type.headlineSmall?.copyWith(
                        color: c.brand.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            user?.firstName,
                            user?.lastName,
                          ].whereType<String>().join(' '),
                          style: context.type.titleMedium,
                        ),
                        if (user?.email != null)
                          Text(
                            user!.email!,
                            style: context.type.bodySmall?.copyWith(
                              color: c.ink2,
                            ),
                          ),
                        if (membership != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: StatusPill(
                              label:
                                  '${membership.family.name} · ${_role(l, membership.role)}',
                              tone: AppTone.info,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_rounded, color: c.ink3),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            NavTile(
              icon: Icons.language_rounded,
              tone: AppTone.info,
              title: l.accountLanguage,
              subtitle: _languageName(l, locale),
              onTap: () => _pickLanguage(context, ref),
            ),
            const SizedBox(height: AppSpacing.sm),
            NavTile(
              icon: Icons.notifications_active_rounded,
              tone: AppTone.brand,
              title: l.accountNotifications,
              onTap: () => open(const NotificationSettingsScreen()),
            ),
            const SizedBox(height: AppSpacing.sm),
            NavTile(
              icon: Icons.inbox_rounded,
              tone: AppTone.neutral,
              title: l.accountInbox,
              onTap: () => open(const NotificationInboxScreen()),
            ),
            const SizedBox(height: AppSpacing.sm),
            NavTile(
              icon: Icons.widgets_rounded,
              tone: AppTone.accent,
              title: l.accountSurfaces,
              onTap: () => open(const SurfacesSettingsScreen()),
            ),
            const SizedBox(height: AppSpacing.sm),
            NavTile(
              icon: Icons.devices_rounded,
              tone: AppTone.neutral,
              title: l.accountThisDevice,
              onTap: () => open(const DevicesScreen()),
            ),
            if ((auth.session?.memberships.length ?? 0) > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              NavTile(
                icon: Icons.swap_horiz_rounded,
                tone: AppTone.neutral,
                title: l.accountSwitchFamily,
                onTap: () => open(const FamilySelectionScreen()),
              ),
            ],
            if (auth.hasParkedChild) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                color: c.warning.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.accountHandBackGeneric,
                      style: context.type.titleSmall,
                    ),
                    Text(
                      l.accountHandBackBody,
                      style: context.type.bodySmall?.copyWith(color: c.ink2),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .handBackToChild(),
                      icon: const Icon(Icons.child_care_rounded),
                      label: Text(l.accountHandBackGeneric),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await confirmAction(
                  context,
                  title: l.authLogoutConfirm,
                  confirmLabel: l.authLogout,
                  destructive: true,
                );
                if (ok) {
                  await ref.read(authControllerProvider.notifier).logout();
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(l.authLogout),
            ),
          ],
        ),
      ),
    );
  }

  String _role(AppLocalizations l, FamilyRole role) => switch (role) {
    FamilyRole.owner => l.profileRoleOwner,
    FamilyRole.parent => l.profileRoleParent,
    FamilyRole.caregiver => l.profileRoleCaregiver,
  };

  String _languageName(AppLocalizations l, Locale locale) =>
      switch (locale.languageCode) {
        'ar' => l.languageArabic,
        'he' => l.languageHebrew,
        'en' => l.languageEnglish,
        _ => locale.languageCode,
      };

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final current = ref.read(localeControllerProvider);
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final loc in AppLocales.supported)
              ListTile(
                title: Text(_languageName(l, loc)),
                trailing: loc.languageCode == current.languageCode
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheet).pop(loc),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ref.read(localeControllerProvider.notifier).setLocale(selected);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            ProfileUpdateInput(preferredLanguage: selected.languageCode),
          );
    } catch (_) {
      // The local switch already applied; account sync can retry later.
    }
  }
}
