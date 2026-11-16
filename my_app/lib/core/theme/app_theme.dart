import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_typography.dart';
import 'contrast.dart';
import 'design_tokens.dart';
import 'mamily_colors.dart';

/// The Mamily theme, assembled from the design tokens.
///
/// Components should read `context.mamily`, `context.type` and the
/// [AppSpacing]/[AppRadii]/[AppSizes] tokens rather than hard-coding colours,
/// sizes or radii.
class AppTheme {
  const AppTheme._();

  /// The shipped theme.
  ///
  /// Dark tokens exist ([MamilyColors.dark]) but no dark [ThemeData] is exposed
  /// or wired into `MaterialApp` yet.
  static final ThemeData light = _build(
    MamilyColors.light,
    rubikEverywhere: true,
  );

  /// The child experience: same system, sunnier surfaces, rounder shapes and
  /// larger touch targets.
  static final ThemeData kid = _build(
    MamilyColors.kid,
    rubikEverywhere: true,
    kid: true,
  );

  /// Builds a theme from arbitrary tokens so tests can verify the prepared dark
  /// tokens go through the same pipeline. Not part of the app.
  @visibleForTesting
  static ThemeData buildFor(
    MamilyColors colors, {
    bool rubikEverywhere = true,
    bool kid = false,
  }) => _build(colors, rubikEverywhere: rubikEverywhere, kid: kid);

  /// [rubikEverywhere] also makes Rubik the default for plain `Text` in
  /// existing screens. Off until it is safe — see
  /// [AppTypography.legacyFontFamily]. Components always use Rubik through
  /// `context.type`, whatever this is.
  static ThemeData _build(
    MamilyColors c, {
    bool rubikEverywhere = true,
    bool kid = false,
  }) {
    final textTheme = AppTypography.textTheme(ink: c.ink);
    final scheme = _scheme(c);

    final inputBorder = OutlineInputBorder(
      borderRadius: AppRadii.smallAll,
      borderSide: BorderSide(
        color: c.borderStrong,
        width: AppSizes.borderWidth,
      ),
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xxl,
      vertical: AppSpacing.md,
    );
    final buttonMinimum = Size(
      64,
      kid ? AppSizes.minTouchTargetKid : AppSizes.minTouchTarget,
    );
    final labelLarge = textTheme.labelLarge;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: rubikEverywhere
          ? AppTypography.fontFamily
          : AppTypography.legacyFontFamily,
      textTheme: rubikEverywhere ? textTheme : null,
      iconTheme: IconThemeData(color: c.ink, size: AppSizes.iconMd),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: AppSizes.borderWidth,
        space: AppSizes.borderWidth,
      ),
      // Transparent, as before: the scaffold background already matches, and
      // the welcome screen draws a gradient behind its app bar.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.ink,
        iconTheme: IconThemeData(color: c.ink),
        actionsIconTheme: IconThemeData(color: c.ink),
        titleTextStyle: textTheme.titleLarge,
        // A transparent bar would otherwise be read as dark, giving white
        // status-bar icons on the light background.
        systemOverlayStyle:
            ThemeData.estimateBrightnessForColor(c.background) ==
                Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: kid ? AppRadii.largeAll : AppRadii.mediumAll,
          side: BorderSide(color: c.border, width: AppSizes.borderWidth),
        ),
      ),
      // Filters and choices. Selected chips use the accent tone (text stays
      // ink-on-tint, ≥ 4.5:1) plus a checkmark, so state is never colour-only.
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accent.background,
        checkmarkColor: c.accent.foreground,
        side: BorderSide(color: c.border, width: AppSizes.borderWidth),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge?.copyWith(color: c.ink),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      // One shape and one minimum height for every button. Heights are minimums
      // (never fixed) so larger text sizes can grow the button.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.onAction,
          minimumSize: buttonMinimum,
          padding: buttonPadding,
          shape: const StadiumBorder(),
          textStyle: labelLarge,
          elevation: 0,
        ).copyWith(overlayColor: _overlay(c.onAction)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.onAction,
          minimumSize: buttonMinimum,
          padding: buttonPadding,
          shape: const StadiumBorder(),
          textStyle: labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(overlayColor: _overlay(c.onAction)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: buttonMinimum,
          padding: buttonPadding,
          shape: const StadiumBorder(),
          textStyle: labelLarge,
          side: BorderSide(
            color: c.borderStrong,
            width: AppSizes.borderWidthStrong,
          ),
        ).copyWith(overlayColor: _overlay(c.ink)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent.foreground,
          minimumSize: buttonMinimum,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const StadiumBorder(),
          textStyle: labelLarge,
        ).copyWith(overlayColor: _overlay(c.accent.foreground)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSizes.minTouchTarget),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.action,
        foregroundColor: c.onAction,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: c.border, width: AppSizes.borderWidth),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: c.focus, width: AppSizes.focusWidth),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: c.danger.foreground,
            width: AppSizes.borderWidthStrong,
          ),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: c.danger.foreground,
            width: AppSizes.focusWidth,
          ),
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: c.ink3),
        labelStyle: textTheme.bodyLarge?.copyWith(color: c.ink2),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: c.ink2),
        helperStyle: textTheme.bodySmall?.copyWith(color: c.ink2),
        errorStyle: textTheme.bodySmall?.copyWith(color: c.danger.foreground),
        errorMaxLines: 3,
        prefixIconColor: c.ink2,
        suffixIconColor: c.ink2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smallAll),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.largeAll),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.ink2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.large),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.action,
        linearTrackColor: c.surfaceStrong,
        circularTrackColor: c.surfaceStrong,
      ),
      extensions: [
        c,
        MamilyTypography(textTheme),
        MamilyMode(isKid: kid),
      ],
    );
  }

  /// Every role, derived from the tokens so the two can never drift apart.
  static ColorScheme _scheme(MamilyColors c) {
    Color on(Color solid) =>
        Contrast.bestOn(solid, const [Colors.white, MamilyPalette.navy800]);

    return ColorScheme(
      brightness: c.brightness,
      primary: c.action,
      onPrimary: c.onAction,
      primaryContainer: c.brand.background,
      onPrimaryContainer: c.brand.foreground,
      secondary: c.accent.foreground,
      onSecondary: on(c.accent.foreground),
      secondaryContainer: c.accent.background,
      onSecondaryContainer: c.accent.foreground,
      tertiary: c.info.foreground,
      onTertiary: on(c.info.foreground),
      tertiaryContainer: c.info.background,
      onTertiaryContainer: c.info.foreground,
      error: c.danger.foreground,
      onError: on(c.danger.foreground),
      errorContainer: c.danger.background,
      onErrorContainer: c.danger.foreground,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.ink2,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.surfaceMuted,
      outline: c.borderStrong,
      outlineVariant: c.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: c.ink,
      onInverseSurface: c.background,
      // Snackbar action text: bright teal on the dark navy snackbar; coral on
      // the light snackbar the dark tokens would produce.
      inversePrimary: c.isDark
          ? MamilyColors.light.actionText
          : MamilyPalette.decorTeal,
      surfaceTint: Colors.transparent,
    );
  }

  static WidgetStateProperty<Color?> _overlay(Color base) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return base.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.focused) ||
            states.contains(WidgetState.hovered)) {
          return base.withValues(alpha: 0.10);
        }
        return null;
      });
}

/// Which experience a subtree belongs to. Components read `context.isKid` to
/// pick rounder shapes and larger targets without separate widget sets.
@immutable
class MamilyMode extends ThemeExtension<MamilyMode> {
  const MamilyMode({required this.isKid});

  final bool isKid;

  @override
  MamilyMode copyWith({bool? isKid}) => MamilyMode(isKid: isKid ?? this.isKid);

  @override
  MamilyMode lerp(ThemeExtension<MamilyMode>? other, double t) =>
      t < 0.5 || other is! MamilyMode ? this : other;
}

extension MamilyModeContext on BuildContext {
  bool get isKid => Theme.of(this).extension<MamilyMode>()?.isKid ?? false;
}
