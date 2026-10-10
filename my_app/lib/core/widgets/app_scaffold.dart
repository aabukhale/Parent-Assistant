import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';
import 'app_content_frame.dart';

/// The base page scaffold for redesigned screens.
///
/// * The app bar is styled once, in the theme — screens pass a [title] (or a
///   [titleWidget], e.g. the child switcher) and never restyle it.
/// * The body sits in an [AppContentFrame], so on tablets it stays a readable
///   640dp column and on phones it is untouched.
/// * The body is wrapped in a [SafeArea] for the sides and bottom.
///
/// Existing screens keep their own `Scaffold` until they are redesigned.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.appBarBottom,
    required this.body,
    this.padding = EdgeInsets.zero,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.maxContentWidth = AppSizes.maxContentWidth,
    this.resizeToAvoidBottomInset,
  }) : assert(
         title == null || titleWidget == null,
         'Use either title or titleWidget, not both',
       );

  /// Plain-text title. Prefer this.
  final String? title;

  /// Custom title content (only when [title] cannot express it).
  final Widget? titleWidget;

  final List<Widget>? actions;
  final Widget? leading;

  /// Shown under the app bar (e.g. a `TabBar`).
  final PreferredSizeWidget? appBarBottom;

  final Widget body;

  /// Padding around [body] inside the content frame. Zero by default so
  /// scroll views can own their padding and scroll edge-to-edge.
  final EdgeInsetsGeometry padding;

  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final double maxContentWidth;
  final bool? resizeToAvoidBottomInset;

  bool get _hasAppBar =>
      title != null ||
      titleWidget != null ||
      actions != null ||
      leading != null ||
      appBarBottom != null;

  @override
  Widget build(BuildContext context) {
    final background = backgroundColor ?? context.mamily.background;

    Widget content = body;
    if (padding != EdgeInsets.zero) {
      content = Padding(padding: padding, child: content);
    }

    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: _hasAppBar
          ? AppBar(
              leading: leading,
              // AppBar already exposes its title as the route's heading.
              title: title != null ? Text(title!) : titleWidget,
              actions: actions,
              bottom: appBarBottom,
            )
          : null,
      body: SafeArea(
        // The app bar already handles the top inset.
        top: !_hasAppBar,
        child: AppContentFrame(maxWidth: maxContentWidth, child: content),
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
