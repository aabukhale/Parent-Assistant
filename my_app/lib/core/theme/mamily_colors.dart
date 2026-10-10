import 'package:flutter/material.dart';

/// Semantic tone of a pill, banner, tile or icon badge. A tone always maps to
/// a foreground/background pair that meets WCAG AA — colour alone must still
/// never be the only signal (pair it with an icon and a word).
enum AppTone { neutral, brand, accent, success, warning, danger, info, sleep }

/// Foreground/background/border trio for one [AppTone].
@immutable
class ToneColors {
  const ToneColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  /// Text and icons on [background]. Also readable on the plain surface.
  final Color foreground;

  /// Soft tint fill.
  final Color background;

  /// Decorative outline for tinted containers (not required for meaning).
  final Color border;

  static ToneColors lerp(ToneColors a, ToneColors b, double t) => ToneColors(
    foreground: Color.lerp(a.foreground, b.foreground, t)!,
    background: Color.lerp(a.background, b.background, t)!,
    border: Color.lerp(a.border, b.border, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is ToneColors &&
      other.foreground == foreground &&
      other.background == background &&
      other.border == border;

  @override
  int get hashCode => Object.hash(foreground, background, border);
}

/// Raw brand colours that are shared by every mode.
///
/// The bright brand hues are **decorative only** (illustrations, avatars,
/// fills behind dark ink). They fail contrast as text or as a white-text
/// button fill — use the tokens on [MamilyColors] for those.
class MamilyPalette {
  const MamilyPalette._();

  static const navy800 = Color(0xFF2E3B63);

  /// Brand teal, decorative. Dark ink on it is 6.45:1.
  static const decorTeal = Color(0xFF62D9D4);

  /// Brand amber, decorative. Dark ink on it is 6.36:1.
  static const decorAmber = Color(0xFFFFB84D);

  /// Brand coral, decorative. Dark ink on it is only 3.7:1 — never put text on
  /// it.
  static const decorCoral = Color(0xFFFF624E);
}

/// Mamily's colour tokens, exposed as a [ThemeExtension] so widgets read
/// `context.mamily` instead of hard-coding hex values.
///
/// [light] is the shipped mode. [dark] is prepared (and contrast-tested) so a
/// future dark UI is a wiring job, but no dark theme is active yet.
@immutable
class MamilyColors extends ThemeExtension<MamilyColors> {
  const MamilyColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceStrong,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.action,
    required this.onAction,
    required this.actionPressed,
    required this.actionText,
    required this.focus,
    required this.neutral,
    required this.brand,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.sleep,
  });

  final Brightness brightness;

  // Surfaces.
  final Color background;
  final Color surface;
  final Color surfaceMuted;

  /// Progress tracks and pressed fills. Holds no text; if it ever must, use
  /// [ink] or [ink2] ([ink3] is only 4.3:1 here).
  final Color surfaceStrong;

  /// Decorative hairlines (card edges, dividers).
  final Color border;

  /// Boundaries that identify a control on their own (inputs, outlined
  /// buttons): at least 3:1 on every surface.
  final Color borderStrong;

  // Text.
  /// Headings and primary text.
  final Color ink;

  /// Secondary text.
  final Color ink2;

  /// Captions and hints. ≥ 4.5:1 on [background], [surface] and
  /// [surfaceMuted].
  final Color ink3;

  // Primary action (coral).
  /// Fill of primary buttons.
  final Color action;

  /// Label/icon on [action].
  final Color onAction;

  /// Pressed / hovered [action].
  final Color actionPressed;

  /// Coral-coloured *text* or icon on [background]/[surface]. Darker than
  /// [action], which is only AA as a button fill.
  final Color actionText;

  /// Keyboard/switch-access focus ring.
  final Color focus;

  // Tones.
  final ToneColors neutral;
  final ToneColors brand;
  final ToneColors accent;
  final ToneColors success;
  final ToneColors warning;
  final ToneColors danger;
  final ToneColors info;
  final ToneColors sleep;

  bool get isDark => brightness == Brightness.dark;

  ToneColors tone(AppTone tone) => switch (tone) {
    AppTone.neutral => neutral,
    AppTone.brand => brand,
    AppTone.accent => accent,
    AppTone.success => success,
    AppTone.warning => warning,
    AppTone.danger => danger,
    AppTone.info => info,
    AppTone.sleep => sleep,
  };

  /// The shipped light mode.
  static const light = MamilyColors(
    brightness: Brightness.light,
    background: Color(0xFFF7F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEFF1F8),
    surfaceStrong: Color(0xFFE6E9F3),
    border: Color(0xFFE0E3EB),
    borderStrong: Color(0xFF77819B),
    ink: MamilyPalette.navy800,
    ink2: Color(0xFF55607A),
    ink3: Color(0xFF626C87),
    action: Color(0xFFD43A26),
    onAction: Color(0xFFFFFFFF),
    actionPressed: Color(0xFFB3311F),
    actionText: Color(0xFFB3311F),
    focus: Color(0xFF0F766E),
    neutral: ToneColors(
      foreground: Color(0xFF55607A),
      background: Color(0xFFEFF1F8),
      border: Color(0xFFE0E3EB),
    ),
    brand: ToneColors(
      foreground: Color(0xFFB3311F),
      background: Color(0xFFFFF1EE),
      border: Color(0xFFF7CFC7),
    ),
    accent: ToneColors(
      foreground: Color(0xFF0F766E),
      background: Color(0xFFE6F7F5),
      border: Color(0xFFB7E4DF),
    ),
    success: ToneColors(
      foreground: Color(0xFF166534),
      background: Color(0xFFE8F6EE),
      border: Color(0xFFBFE3CE),
    ),
    warning: ToneColors(
      foreground: Color(0xFF8A5300),
      background: Color(0xFFFFF4DC),
      border: Color(0xFFF1D9A0),
    ),
    danger: ToneColors(
      foreground: Color(0xFFB42318),
      background: Color(0xFFFEF3F2),
      border: Color(0xFFF6C6C1),
    ),
    info: ToneColors(
      foreground: Color(0xFF4A5892),
      background: Color(0xFFEEF0FA),
      border: Color(0xFFCBD2EE),
    ),
    sleep: ToneColors(
      foreground: Color(0xFF5B4BA0),
      background: Color(0xFFF0EDFB),
      border: Color(0xFFD6CFF0),
    ),
  );

  /// Prepared dark tokens. Not wired into the app yet — see [light].
  static const dark = MamilyColors(
    brightness: Brightness.dark,
    background: Color(0xFF0F1428),
    surface: Color(0xFF171E38),
    surfaceMuted: Color(0xFF1F2848),
    surfaceStrong: Color(0xFF2A3459),
    border: Color(0xFF2E3860),
    borderStrong: Color(0xFF8792B5),
    ink: Color(0xFFEEF1FA),
    ink2: Color(0xFFB9C1D9),
    ink3: Color(0xFF98A2BF),
    action: Color(0xFFFF8F7E),
    onAction: Color(0xFF3D0C05),
    actionPressed: Color(0xFFFFB4A8),
    actionText: Color(0xFFFF8F7E),
    focus: Color(0xFF6EDDD3),
    neutral: ToneColors(
      foreground: Color(0xFFB9C1D9),
      background: Color(0xFF232B4A),
      border: Color(0xFF2E3860),
    ),
    brand: ToneColors(
      foreground: Color(0xFFFFB4A8),
      background: Color(0xFF3A1A1A),
      border: Color(0xFF5A2A2A),
    ),
    accent: ToneColors(
      foreground: Color(0xFF6EDDD3),
      background: Color(0xFF0E3436),
      border: Color(0xFF1D5558),
    ),
    success: ToneColors(
      foreground: Color(0xFF7FD9A3),
      background: Color(0xFF123626),
      border: Color(0xFF1E5238),
    ),
    warning: ToneColors(
      foreground: Color(0xFFF5C36B),
      background: Color(0xFF3A2C0E),
      border: Color(0xFF5A4416),
    ),
    danger: ToneColors(
      foreground: Color(0xFFFFA39B),
      background: Color(0xFF3F1719),
      border: Color(0xFF5F2A2D),
    ),
    info: ToneColors(
      foreground: Color(0xFFA9B6F0),
      background: Color(0xFF212B52),
      border: Color(0xFF37447A),
    ),
    sleep: ToneColors(
      foreground: Color(0xFFC0B4F5),
      background: Color(0xFF2B2352),
      border: Color(0xFF41387A),
    ),
  );

  @override
  MamilyColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceStrong,
    Color? border,
    Color? borderStrong,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? action,
    Color? onAction,
    Color? actionPressed,
    Color? actionText,
    Color? focus,
    ToneColors? neutral,
    ToneColors? brand,
    ToneColors? accent,
    ToneColors? success,
    ToneColors? warning,
    ToneColors? danger,
    ToneColors? info,
    ToneColors? sleep,
  }) => MamilyColors(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    surfaceStrong: surfaceStrong ?? this.surfaceStrong,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    action: action ?? this.action,
    onAction: onAction ?? this.onAction,
    actionPressed: actionPressed ?? this.actionPressed,
    actionText: actionText ?? this.actionText,
    focus: focus ?? this.focus,
    neutral: neutral ?? this.neutral,
    brand: brand ?? this.brand,
    accent: accent ?? this.accent,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    sleep: sleep ?? this.sleep,
  );

  @override
  MamilyColors lerp(ThemeExtension<MamilyColors>? other, double t) {
    if (other is! MamilyColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    ToneColors tc(ToneColors a, ToneColors b) => ToneColors.lerp(a, b, t);
    return MamilyColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      surfaceStrong: c(surfaceStrong, other.surfaceStrong),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      action: c(action, other.action),
      onAction: c(onAction, other.onAction),
      actionPressed: c(actionPressed, other.actionPressed),
      actionText: c(actionText, other.actionText),
      focus: c(focus, other.focus),
      neutral: tc(neutral, other.neutral),
      brand: tc(brand, other.brand),
      accent: tc(accent, other.accent),
      success: tc(success, other.success),
      warning: tc(warning, other.warning),
      danger: tc(danger, other.danger),
      info: tc(info, other.info),
      sleep: tc(sleep, other.sleep),
    );
  }
}

/// `context.mamily` — the active colour tokens. Falls back to [MamilyColors.light]
/// when a test pumps a bare `MaterialApp` without the app theme.
extension MamilyThemeContext on BuildContext {
  MamilyColors get mamily =>
      Theme.of(this).extension<MamilyColors>() ?? MamilyColors.light;
}
