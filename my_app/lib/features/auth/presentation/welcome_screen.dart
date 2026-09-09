import 'package:flutter/material.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Unauthenticated entry point. Visual design preserved from the original
/// `main.dart` welcome screen; copy comes from l10n; the buttons now route to
/// the real login/registration flows and biometric sign-in is honestly disabled.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      body: AppBackground(
        darkHeader: true,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  size: 74,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l.appTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 80),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 44, 28, 34),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(50),
                    topRight: Radius.circular(50),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      l.authWelcomeTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.authWelcomeSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 38),
                    PrimaryButton(
                      text: l.authCreateAccount,
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SecondaryButton(
                      text: l.authHaveAccount,
                      icon: Icons.login_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: Color(0xFFDDE1EA)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Text(
                            l.authOr,
                            style: const TextStyle(color: Color(0xFF9AA3B5)),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Color(0xFFDDE1EA)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Biometric sign-in is a deferred feature — shown, but
                    // explicitly disabled rather than faking success.
                    TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.fingerprint_rounded, size: 26),
                      label: Text(l.authBiometricUnavailable),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF9AA3B5),
                        disabledForegroundColor: const Color(0xFFB6BDC9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
