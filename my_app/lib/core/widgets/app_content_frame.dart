import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Caps its child to a readable column on wide screens (tablets, landscape,
/// desktop) and centres it. On phones — anything narrower than [maxWidth] —
/// it returns the child untouched, so existing layouts and tight constraints
/// are unaffected.
///
/// Also keeps content clear of the bottom and side system insets (home
/// indicator, landscape notch); the app bar already covers the top. Nested
/// frames add nothing, because the outer one consumes the insets.
class AppContentFrame extends StatelessWidget {
  const AppContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppSizes.maxContentWidth,
    this.safeArea = true,
  });

  final Widget child;
  final double maxWidth;

  /// False inside sheets/dialogs or other already-inset parents.
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final frame = _frame();
    return safeArea ? SafeArea(top: false, child: frame) : frame;
  }

  Widget _frame() {
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
