import 'package:flutter/material.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Parent way in: create a family account or sign in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: AppContentFrame(
          maxWidth: 520,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.xlAll,
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [c.brand.background, c.warning.background],
                  ),
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 88)),
                    PositionedDirectional(
                      top: 20,
                      start: 20,
                      child: MamilyBrandMark(size: 48),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Semantics(
                header: true,
                child: Text(
                  l.parentEntryTitle,
                  style: context.type.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.parentEntrySubtitle,
                style: context.type.bodyLarge?.copyWith(color: c.ink2),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton.icon(
                icon: const Icon(Icons.login_rounded),
                label: Text(l.authLoginAction),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(l.authCreateAccount),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RegisterScreen(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Biometric sign-in is deferred — shown honestly as unavailable.
              Row(
                children: [
                  Icon(Icons.fingerprint_rounded, color: c.ink3),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.authBiometricUnavailable,
                      style: context.type.bodySmall?.copyWith(color: c.ink2),
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
