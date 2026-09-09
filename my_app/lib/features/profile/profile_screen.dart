import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_locales.dart';
import '../../core/localization/l10n.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../auth/application/auth_controller.dart';
import '../auth/data/auth_requests.dart';
import '../auth/data/models/family_membership.dart';
import 'edit_profile_screen.dart';

/// Account tab — shows the real authenticated user and their family role, opens
/// profile editing, switches UI language, and signs out (revoking the token
/// server-side).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final membership = ref.watch(activeMembershipProvider);
    final locale = ref.watch(localeControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.profileTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.teal,
                    child: Icon(
                      Icons.person_rounded,
                      size: 46,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.displayName.isNotEmpty == true
                        ? user!.displayName
                        : '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _roleLabel(l, membership?.role),
                    style: const TextStyle(color: Color(0xFFD8DDEC)),
                  ),
                  if ((user?.contact ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user!.contact,
                      style: const TextStyle(
                        color: Color(0xFFB9C1DA),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            _Item(
              icon: Icons.person_outline_rounded,
              title: l.profileEditTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            _Item(
              icon: Icons.language_rounded,
              title: l.profileLanguage,
              trailing: _languageName(l, locale),
              onTap: () => _pickLanguage(context, ref),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout_rounded, color: AppColors.coral),
              label: Text(
                l.authLogout,
                style: const TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations l, FamilyRole? role) => switch (role) {
    FamilyRole.owner => l.profileRoleOwner,
    FamilyRole.parent => l.profileRoleParent,
    FamilyRole.caregiver => l.profileRoleCaregiver,
    null => '',
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
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final loc in AppLocales.supported)
              ListTile(
                title: Text(_languageName(l, loc)),
                onTap: () => Navigator.of(context).pop(loc),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ref.read(localeControllerProvider.notifier).setLocale(selected);
    // Best-effort: also persist the preference on the account.
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

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(l.authLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.authLogout),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.teal),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
