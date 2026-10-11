import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import '../application/auth_controller.dart';
import 'pairing_screen.dart';
import 'welcome_screen.dart';

/// First screen for a signed-out install: "I'm a parent" / "I'm a child".
///
/// The choice only picks the way in. What a session may do is decided by the
/// server for the credentials used (parent account vs. child pairing code).
class RoleEntryScreen extends ConsumerWidget {
  const RoleEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = context.mamily;
    final hasParked = ref.watch(
      authControllerProvider.select((s) => s.hasParkedChild),
    );

    return Scaffold(
      body: SafeArea(
        child: AppContentFrame(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxxl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              const Center(child: MamilyBrandMark(size: 84)),
              const SizedBox(height: AppSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  l.roleEntryTitle,
                  textAlign: TextAlign.center,
                  style: context.type.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.roleEntrySubtitle,
                textAlign: TextAlign.center,
                style: context.type.bodyLarge?.copyWith(color: c.ink2),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _RoleCard(
                emoji: '🧑‍🍼',
                title: l.roleParent,
                subtitle: l.roleParentHint,
                tone: c.brand,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WelcomeScreen(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _RoleCard(
                emoji: '🧒',
                title: l.roleChild,
                subtitle: l.roleChildHint,
                tone: c.warning,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PairingScreen(),
                  ),
                ),
              ),
              if (hasParked) ...[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .resumeParkedChild(),
                  icon: const Icon(Icons.child_care_rounded),
                  label: Text(l.roleResumeChild),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                l.roleChoiceNote,
                textAlign: TextAlign.center,
                style: context.type.bodySmall?.copyWith(color: c.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final ToneColors tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: tone.background,
      borderRadius: AppRadii.xlAll,
      semanticLabel: '$title. $subtitle',
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.mamily.surface,
              borderRadius: AppRadii.largeAll,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 34)),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.type.titleLarge?.copyWith(
                    color: tone.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: context.type.bodyMedium?.copyWith(
                    color: context.mamily.ink2,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: tone.foreground),
        ],
      ),
    );
  }
}
