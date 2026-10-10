import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Caps its child to a readable column on wide screens (tablets, landscape,
/// desktop) and centres it. On phones — anything narrower than [maxWidth] —
/// it returns the child untouched, so existing layouts and tight constraints
/// are unaffected.
class AppContentFrame extends StatelessWidget {
  const AppContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppSizes.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Align(
          alignment: AlignmentDirectional.topCenter,
          // Keep the incoming height so scroll views and fill-height children
          // behave exactly as they would full-width.
          child: SizedBox(
            width: maxWidth,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
