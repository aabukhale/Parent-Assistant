import 'package:flutter/material.dart';

import '../../core/localization/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/state_views.dart';

/// AI parenting coach. There is **no backend** for this — the Mamily API has no
/// coach/chat endpoint. Anwar's original screen faked the assistant's replies
/// locally; that has been removed. This is now an honest "not available yet"
/// state with no chat input and no fabricated advice.
class AiParentingScreen extends StatelessWidget {
  const AiParentingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.aiCoachTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ComingSoonView(
          icon: Icons.auto_awesome_rounded,
          title: l.aiCoachUnavailableTitle,
          body: l.aiCoachUnavailableBody,
        ),
      ),
    );
  }
}
