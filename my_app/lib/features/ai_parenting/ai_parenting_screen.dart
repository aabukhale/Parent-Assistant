import 'package:flutter/material.dart';

import '../../core/localization/l10n.dart';
import '../../core/design_system.dart';

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
      appBar: AppBar(title: Text(l.aiCoachTitle)),
      body: AppContentFrame(
        child: ComingSoonView(
          icon: Icons.auto_awesome_rounded,
          title: l.aiCoachUnavailableTitle,
          body: l.aiCoachUnavailableBody,
        ),
      ),
    );
  }
}
